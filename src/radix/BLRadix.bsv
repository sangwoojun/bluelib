package BLRadix;

import FIFO::*;
import FIFOF::*;
import Vector::*;
import BRAM::*;
import BRAMFIFO::*;



/**
WARNING: tupleCnt MUST be power of two!
Some output may have mixed buckets. Best to handle the mixed tuples separately
**/

interface BLRadixIfc#(numeric type lenSz, numeric type waysSz, numeric type tupleCnt, type dtype, numeric type subBitOff, numeric type subBitLen);
	method Action enq(Vector#(tupleCnt, dtype) data);
	method Vector#(tupleCnt, dtype) first;
	method Action deq;
	method Bool notEmpty;
	method ActionValue#(Bit#(lenSz)) burstReady;

	method Action flush;
endinterface

module mkBLRadixSub#(Integer bucketOff) (BLRadixIfc#(lenSz,waysSz,tupleCnt,dtype,subBitOff,subBitLen))
	provisos(
		Add#(lenSz,TLog#(tupleCnt),waySerSz),
		Add#(waySerSz,waysSz,memAddrSz),
		Add#(burstSz,1,lenSz),
		Add#(a__, subBitLen, dsz),
		Add#(b__, waysSz, subBitLen),
		Add#(1, c__, TMul#(tupleCnt, dsz)),
		Eq#(dtype),
		Bits#(dtype,dsz)
	);
	Reg#(Bool) flushing <- mkReg(False);
    
	Reg#(Vector#(TExp#(waysSz),Bit#(waySerSz))) vHead <- mkReg(replicate(0));
	Reg#(Vector#(TExp#(waysSz),Bit#(waySerSz))) vTailTarget <- mkReg(replicate(0));
	Reg#(Vector#(TExp#(waysSz),Bit#(waySerSz))) vTail <- mkReg(replicate(0));
	BRAM2Port#(Bit#(memAddrSz), dtype) mem <- mkBRAM2Server(defaultValue); 
	Integer iTupleCnt = valueOf(tupleCnt);
	Integer halfBufferLen = valueOf(TExp#(waySerSz))/2;


	Reg#(Bit#(32)) cycleCounter <- mkReg(0);
	rule incCycle;
		cycleCounter <= cycleCounter + 1;
	endrule

	FIFO#(Vector#(tupleCnt, dtype) ) inputQ <- mkSizedBRAMFIFO(256);
	FIFO#(dtype) serialInputQ <- mkFIFO;
	Reg#(Vector#(TSub#(tupleCnt,1),dtype)) serializerBuffer <- mkReg(?);
	Reg#(Bit#(TLog#(tupleCnt))) serializerCnt <- mkReg(0);
	rule inputSerialize;
		
		if ( serializerCnt == 0 ) begin
			inputQ.deq;
			let v = inputQ.first;
			serialInputQ.enq(v[0]);

			//if (!(v[0] == v[1] && v[1] == v[2] && v[2] == v[3] )) begin
			Vector#(TSub#(tupleCnt,1), dtype) nb;

			Bit#(TLog#(tupleCnt)) diffcnt = 0;

			for ( Integer i = 0; i < fromInteger(iTupleCnt-1); i=i+1) begin
				nb[i] = v[i+1];
				if ( v[i+1] != v[0] ) diffcnt = diffcnt + 1;
			end
			serializerBuffer <= nb;
			serializerCnt <= diffcnt;
			//end
		end else begin
			serializerCnt <= serializerCnt -1;
			serialInputQ.enq(serializerBuffer[0]);
		
			Vector#(TSub#(tupleCnt,1), dtype) nb;
			for ( Integer i = 0; i < fromInteger(iTupleCnt-2); i=i+1) begin
				nb[i] = serializerBuffer[i+1];
			end
			nb[iTupleCnt-2] = ?;

			serializerBuffer <= nb;
		end

	endrule

	FIFO#(Tuple2#(Bit#(waysSz),dtype)) serialFilterQ <- mkFIFO;
	Reg#(dtype) lastVal <- mkReg(unpack(-1));
	rule filterInput;
		serialInputQ.deq;
		let d = serialInputQ.first;
		Bit#(subBitLen) bucket = truncate(pack(d)>>valueOf(subBitOff));
		if ( d != lastVal && bucket >= fromInteger(bucketOff) && bucket <= fromInteger(bucketOff+valueOf(TExp#(waysSz))-1)) begin
			let subbucket = bucket - fromInteger(bucketOff);
			serialFilterQ.enq(tuple2(truncate(subbucket),d));
			lastVal <= d;
		end
		else begin
			//$write( "bucket %d filtered out\n", bucket );
		end
	endrule


	FIFO#(Tuple3#(Bit#(waysSz),Bit#(memAddrSz), Bit#(waySerSz))) burstReadReqQ <- mkFIFO;
	rule insertInput;// (flushing == False);
		let d_ = serialFilterQ.first;
		let bucket = tpl_1(d_);
		let d = tpl_2(d_);

		let head = vHead[bucket];
		let tail = vTail[bucket];
		let tailtarget = vTailTarget[bucket];

		
		if ( head + 1 != tail ) begin
			serialFilterQ.deq;

			//insert into mem
			Bit#(memAddrSz) writeaddr = {bucket,head};
			mem.portA.request.put(BRAMRequest{write:True, responseOnWrite:False, address: writeaddr, datain: d});
			
			//$write( "enquing  %d %d\n", head, tail);
			if ( head + 1 - tailtarget >= fromInteger(halfBufferLen) ) begin
				burstReadReqQ.enq(tuple3(bucket,{bucket,tailtarget},fromInteger(halfBufferLen)));

				let ttv = vTailTarget;
				ttv[bucket] = tailtarget+fromInteger(halfBufferLen);
				vTailTarget <= ttv;
				//$write( "burst read \n");
			end

			let hv = vHead;
			hv[bucket] = head+1;
			vHead <= hv;
		end
	endrule

	Reg#(Bit#(memAddrSz)) burstReadOff <- mkReg(0);
	Reg#(Bit#(waySerSz)) burstReadLeft <- mkReg(0);
	Reg#(Bit#(waysSz)) burstReadBucket <- mkReg(0);
	Reg#(Bit#(lenSz)) burstReadyCnt <- mkReg(0);

	FIFO#(Bit#(lenSz)) burstReadyQ <- mkFIFO;
	rule procBurstRead;
		let readaddr = burstReadOff;
		let bucket = burstReadBucket;
		if ( burstReadLeft == 0 ) begin
			burstReadReqQ.deq;

			let d_ = burstReadReqQ.first;
			let addr = tpl_2(d_);
			let len = tpl_3(d_);
			bucket = tpl_1(d_);
			burstReadBucket <= bucket;
			burstReadyCnt <= truncate(len>>valueOf(TLog#(tupleCnt)));
			$write( "Burst read req to bucket %d len %d\n", bucket, tpl_3(d_) );

			burstReadLeft <= tpl_3(d_)-1;
			burstReadOff <= addr + 1;
			readaddr = addr;
		end else begin
			burstReadLeft <= burstReadLeft - 1;
			burstReadOff <= burstReadOff + 1;
			if ( burstReadLeft == 1 ) begin
				burstReadyQ.enq(burstReadyCnt);
			end
		end
		mem.portB.request.put(BRAMRequest{write:False, responseOnWrite:False, address: readaddr, datain: ?});


		let tv = vTail;
		tv[bucket] = vTail[bucket]+1;
		vTail <= tv;

	endrule

	Reg#(Vector#(TSub#(tupleCnt,1),dtype)) deserializerBuffer <- mkReg(?);
	Reg#(Bit#(TLog#(tupleCnt))) deserializerCnt <- mkReg(0);
	FIFOF#(Vector#(tupleCnt, dtype) ) outputQ <- mkFIFOF;
	rule deserializeRead;
		let d <- mem.portB.response.get;
		Vector#(TSub#(tupleCnt,1),dtype) desbuf;
		for (Integer i = 0; i < iTupleCnt-2; i=i+1 ) desbuf[i] = deserializerBuffer[i+1];
		desbuf[iTupleCnt-2] = d;

		if ( deserializerCnt == fromInteger(iTupleCnt-1) ) begin
			Vector#(tupleCnt,dtype) outv;
			for(Integer i = 0; i < iTupleCnt-1; i=i+1 ) outv[i] = deserializerBuffer[i];
			outv[iTupleCnt-1] = d;
			
			outputQ.enq(outv);
			

			deserializerCnt <= 0;
		end else begin
			deserializerCnt <= deserializerCnt + 1;
			deserializerBuffer <= desbuf;
		end
	endrule

	Reg#(Bit#(waysSz)) flushBucket <- mkReg(0);

	FIFO#(Bool) flushReqQ <- mkFIFO;
	rule startFlush(flushing == False);
		flushReqQ.deq;
		flushing <= True;
		$write("flushing!\n");
	endrule
	(* descending_urgency = "insertInput, flushOut" *)
	rule flushOut(flushing == True);
		if ( vHead[flushBucket] != vTailTarget[flushBucket] ) begin
			let wordcnt = vHead[flushBucket]-vTailTarget[flushBucket];
			burstReadReqQ.enq(tuple3(flushBucket, {flushBucket,vTailTarget[flushBucket]}, wordcnt));
		end
		flushBucket <= flushBucket + 1;

		if ( flushBucket == fromInteger(valueOf(TExp#(waysSz))-1) ) begin
			flushing <= False;
			vHead <= replicate(0);
			//vTail <= replicate(0); // FIXME!
			vTailTarget <= replicate(0);
		end
	endrule
	

	method Action enq(Vector#(tupleCnt, dtype) data);
		inputQ.enq(data);
	endmethod
	method Vector#(tupleCnt, dtype) first;
		return outputQ.first;
	endmethod
	method Action deq;
		outputQ.deq;
	endmethod
	method notEmpty = outputQ.notEmpty;

	method ActionValue#(Bit#(lenSz)) burstReady;
		burstReadyQ.deq;
		return burstReadyQ.first;
	endmethod

	method Action flush;
		flushReqQ.enq(True);
	endmethod
endmodule

module mkBLRadix (BLRadixIfc#(lenSz,subWaysSz,tupleCnt,dtype,subBitOff,subBitLen))
	provisos(
		//Add#(lenSz,TLog#(tupleCnt),waySerSz),
		//Add#(waySerSz,waysSz,memAddrSz),

		Add#(subWaysSz,waysSz,subBitLen),
		Add#(1, c__, TMul#(tupleCnt, dsz)),

		Add#(burstSz,1,lenSz),
		Add#(a__, subBitLen, dsz),
		Add#(b__, subWaysSz, subBitLen),
		Eq#(dtype),
		Bits#(dtype,dsz)
	);
	Reg#(Bit#(32)) cycleCounter <- mkReg(0);
	rule incCycle;
		cycleCounter <= cycleCounter + 1;
	endrule

	Vector#(TExp#(waysSz), BLRadixIfc#(lenSz,subWaysSz,tupleCnt,dtype,subBitOff,subBitLen)) subRadix;
	Vector#(TExp#(waysSz), FIFO#(Vector#(tupleCnt, dtype))) inputChainQ <- replicateM(mkFIFO);
	Vector#(TExp#(waysSz), FIFOF#(Vector#(tupleCnt, dtype))) outputChainQ <- replicateM(mkFIFOF);
	Vector#(TExp#(waysSz), FIFOF#(Bit#(lenSz))) outputBurstReadyQ <- replicateM(mkFIFOF);

	for ( Integer i = 0; i < valueOf(TExp#(waysSz)); i=i+1 ) begin
		subRadix[i] <- mkBLRadixSub(i*valueOf(TExp#(subWaysSz)));

		rule forwardInput;
			inputChainQ[i].deq;
			let d = inputChainQ[i].first;

			Integer bucketstart = i*valueOf(TExp#(subWaysSz));
			Integer bucketend = ((i+1)*valueOf(TExp#(subWaysSz)))-1;

			Bool matchExist = False;
			for ( Integer j = 0; j < valueOf(tupleCnt); j=j+1 ) begin
				Bit#(subBitLen) bucket = truncate(pack(d[j])>>valueOf(subBitOff));
				if ( bucket >= fromInteger(bucketstart) && bucket <= fromInteger(bucketend) ) begin
					matchExist = True;
				end
			end
			if ( matchExist ) begin
				subRadix[i].enq(d);
			end

			if ( i+1 < valueOf(TExp#(waysSz)) ) begin
				inputChainQ[i+1].enq(d);
			end
		endrule

		Integer maxBurstLen = valueOf(TExp#(lenSz))/2;
		FIFOF#(Vector#(tupleCnt, dtype)) outputQ <- mkSizedBRAMFIFOF(maxBurstLen);
		rule collectOutput;
			subRadix[i].deq;
			outputQ.enq(subRadix[i].first);
		endrule
		/*
		rule flushff;
			let d <- subRadix[i].burstReady;
		endrule
		*/

		Reg#(Bit#(lenSz)) forwardLeft <- mkReg(0);
		Reg#(Bool) isForwardLocal <- mkReg(False);
		rule forwardOutput;
			if ( forwardLeft > 0 ) begin
				forwardLeft <= forwardLeft - 1;
				if ( isForwardLocal ) begin
					outputQ.deq;
					outputChainQ[i].enq(outputQ.first);
				end else if ( i > 0 ) begin
					outputChainQ[i-1].deq;
					outputChainQ[i].enq(outputChainQ[i-1].first);
				end
			end else if ( i > 0 && outputBurstReadyQ[i-1].notEmpty ) begin
				outputBurstReadyQ[i-1].deq;
				let f = outputBurstReadyQ[i-1].first;
				forwardLeft <= f ;
				isForwardLocal <= False;
				//outputChainQ[i-1].deq;
				//outputChainQ[i].enq(outputChainQ[i-1].first);
				
				outputBurstReadyQ[i].enq(f);
			end else begin
				let f <- subRadix[i].burstReady;
				forwardLeft <= f ;
				isForwardLocal <= True;
				//outputQ.deq;
				//outputChainQ[i].enq(outputQ.first);

				outputBurstReadyQ[i].enq(f);
				//$write( "Cycle %d :Burst from subRadix %d\n", cycleCounter, i );
			end
		endrule
	end


	method Action enq(Vector#(tupleCnt, dtype) data);
		inputChainQ[0].enq(data);
	endmethod
	method Vector#(tupleCnt, dtype) first = outputChainQ[valueOf(TExp#(waysSz))-1].first;
	method Action deq = outputChainQ[valueOf(TExp#(waysSz))-1].deq;
	method Bool notEmpty = outputChainQ[valueOf(TExp#(waysSz))-1].notEmpty;
	method ActionValue#(Bit#(lenSz)) burstReady;
		outputBurstReadyQ[valueOf(TExp#(waysSz))-1].deq;
		return outputBurstReadyQ[valueOf(TExp#(waysSz))-1].first;
	endmethod

	method Action flush;
		for ( Integer i = 0; i < valueOf(TExp#(waysSz)); i=i+1 ) subRadix[i].flush();
	endmethod
endmodule

endpackage: BLRadix
