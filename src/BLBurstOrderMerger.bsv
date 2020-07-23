package BLBurstOrderMerger;

import FIFO::*;
import Vector::*;
import BRAMFIFO::*;
import MergeN::*;
import BLMergeN::*;

interface BLBurstReqMergerIfc#(numeric type cnt, numeric type isz, type dtype, numeric type burstsz);
	interface Vector#(cnt, BLMergeEnqIfc#(dtype)) enq;
	method dtype first;
	method Action deq;

	method Action req(Bit#(isz) idx, Bit#(burstsz) burst);
endinterface

module mkBLBurstReqMerger (BLBurstReqMergerIfc#(cnt, isz,dtype,burstsz))
	provisos( 
		Bits#(dtype, dsz), Log#(cnt, cntsz), Add#(burstsz,1,bsz),
		Add#(a__, 2, isz),
		Add#(b__, 1, isz)
		//Add#(1, TLog#(TDiv#(cnt, 2)), cntsz)
	);


	FIFO#(dtype) outQ <- mkFIFO;

	if ( valueOf(cnt) > 4 ) begin
		Vector#(4, BLBurstReqMergerIfc#(TDiv#(cnt,4), isz,dtype,burstsz)) m1 <- replicateM(mkBLBurstReqMerger);
		Reg#(Bit#(bsz)) burstLeft <- mkReg(0);
		Reg#(Bit#(2)) burstIdx <- mkReg(0);
		FIFO#(Tuple2#(Bit#(isz),Bit#(burstsz))) burstReqQ <- mkFIFO;
		FIFO#(Tuple2#(Bit#(isz),Bit#(burstsz))) burstReqLocalQ <- mkSizedFIFO(valueOf(cntsz)/2+1);
		//BLBurstReqMergerIfc#(2,dtype,1) m0 <- mkBLBurstReqMerger;

		rule relayBurst;
			burstReqQ.deq;
			let b_ = burstReqQ.first;
			burstReqLocalQ.enq(b_);
			let idx = tpl_1(b_);
			Bit#(2) sel = truncate(idx>>(valueOf(cntsz)-2));
			Bit#(isz) nidxmask = (1<<(valueOf(cntsz)-2))-1;
			Bit#(isz) nidx = (idx&nidxmask);
			m1[sel].req(nidx,tpl_2(b_));
		endrule

		rule procLocalBurst;
			if ( burstLeft == 0 ) begin
				burstReqLocalQ.deq;
				let b_ = burstReqLocalQ.first;
				let idx = tpl_1(b_);
				Bit#(2) sel = truncate(idx>>(valueOf(cntsz)-2));
				//Bit#(TSub#(cntsz,1)) nidx = truncate(idx);
				burstIdx <= sel;
				let b = tpl_2(b_);
				if ( b != 0 ) begin
					m1[sel].deq;
					outQ.enq(m1[sel].first);
					burstLeft <= zeroExtend(b)-1;
				end
			end else begin
				burstLeft <= burstLeft - 1;
				m1[burstIdx].deq;
				outQ.enq(m1[burstIdx].first);
			end
		endrule

		Vector#(n, BLMergeEnqIfc#(dtype)) enq_;
		for ( Integer i = 0; i < valueOf(cnt); i=i+1 ) begin
			enq_[i] = interface BLMergeEnqIfc;
				method Action enq(dtype data);
					if ( i < valueOf(cnt)/4 ) begin
						m1[0].enq[i%(valueOf(cnt)/4)].enq(data);
					end else if ( i < valueOf(cnt)/2 ) begin
						m1[1].enq[i%(valueOf(cnt)/4)].enq(data);
					end else if ( i < valueOf(cnt)*3/4 ) begin
						m1[2].enq[i%(valueOf(cnt)/4)].enq(data);
					end else begin
						m1[3].enq[i%(valueOf(cnt)/4)].enq(data);
					end
				endmethod
			endinterface;
		end
		interface enq = enq_;
		method dtype first;
			return outQ.first;
		endmethod
		method Action deq;
			outQ.deq;
		endmethod
		method Action req(Bit#(isz) idx, Bit#(burstsz) burst);
			burstReqQ.enq(tuple2(idx,burst));
		endmethod

	end else if ( valueOf(cnt) == 4 ) begin
		Reg#(Bit#(bsz)) burstLeft <- mkReg(0);
		Reg#(Bit#(2)) burstIdx <- mkReg(0);
		
		FIFO#(Tuple2#(Bit#(2),Bit#(burstsz))) burstReqQ <- mkFIFO;
		Vector#(4,FIFO#(dtype)) inQ <- replicateM(mkFIFO);
		rule doBurst;
			if ( burstLeft == 0 ) begin
				burstReqQ.deq;
				let b_ = burstReqQ.first;
				let i = tpl_1(b_);
				burstIdx <= i;
				let b = tpl_2(b_);
				if ( b != 0 ) begin
					inQ[i].deq;
					outQ.enq(inQ[i].first);
					burstLeft <= zeroExtend(b)-1;
				end
			end else begin
				burstLeft <= burstLeft - 1;
				inQ[burstIdx].deq;
				outQ.enq(inQ[burstIdx].first);
			end
		endrule

		Vector#(cnt, BLMergeEnqIfc#(dtype)) enq_;
		for ( Integer i = 0; i < valueOf(cnt); i=i+1 ) begin
			enq_[i] = interface BLMergeEnqIfc;
				method Action enq(dtype data);
					inQ[i].enq(data);
				endmethod
			endinterface;
		end
		interface enq = enq_;
		method dtype first;
			return outQ.first;
		endmethod
		method Action deq;
			outQ.deq;
		endmethod
		method Action req(Bit#(isz) idx, Bit#(burstsz) burst);
			burstReqQ.enq(tuple2(idx[1:0],burst));
		endmethod
	end else if ( valueOf(cnt) > 2) begin
		Vector#(2, BLBurstReqMergerIfc#(TDiv#(cnt,2), isz,dtype,burstsz)) m1 <- replicateM(mkBLBurstReqMerger);
		Reg#(Bit#(bsz)) burstLeft <- mkReg(0);
		Reg#(Bit#(1)) burstIdx <- mkReg(0);
		FIFO#(Tuple2#(Bit#(isz),Bit#(burstsz))) burstReqQ <- mkFIFO;
		FIFO#(Tuple2#(Bit#(isz),Bit#(burstsz))) burstReqLocalQ <- mkSizedFIFO(valueOf(cntsz)/2+1);
		//BLBurstReqMergerIfc#(2,dtype,1) m0 <- mkBLBurstReqMerger;

		rule relayBurst;
			burstReqQ.deq;
			let b_ = burstReqQ.first;
			burstReqLocalQ.enq(b_);
			let idx = tpl_1(b_);
			Bit#(1) sel = truncate(idx>>(valueOf(cntsz)-1));
			Bit#(isz) nidxmask = (1<<(valueOf(cntsz)-1))-1;
			Bit#(isz) nidx = (idx&nidxmask);
			m1[sel].req(nidx,tpl_2(b_));
		endrule

		rule procLocalBurst;
			if ( burstLeft == 0 ) begin
				burstReqLocalQ.deq;
				let b_ = burstReqLocalQ.first;
				let idx = tpl_1(b_);
				Bit#(1) sel = truncate(idx>>(valueOf(cntsz)-1));
				//Bit#(TSub#(cntsz,1)) nidx = truncate(idx);
				burstIdx <= sel;
				let b = tpl_2(b_);
				if ( b != 0 ) begin
					m1[sel].deq;
					outQ.enq(m1[sel].first);
					burstLeft <= zeroExtend(b)-1;
				end
			end else begin
				burstLeft <= burstLeft - 1;
				m1[burstIdx].deq;
				outQ.enq(m1[burstIdx].first);
			end
		endrule

		Vector#(n, BLMergeEnqIfc#(dtype)) enq_;
		for ( Integer i = 0; i < valueOf(cnt); i=i+1 ) begin
			enq_[i] = interface BLMergeEnqIfc;
				method Action enq(dtype data);
					if ( i < valueOf(cnt)/2 ) begin
						m1[0].enq[i%(valueOf(cnt)/2)].enq(data);
					end else begin
						m1[1].enq[i%(valueOf(cnt)/2)].enq(data);
					end
				endmethod
			endinterface;
		end
		interface enq = enq_;
		method dtype first;
			return outQ.first;
		endmethod
		method Action deq;
			outQ.deq;
		endmethod
		method Action req(Bit#(isz) idx, Bit#(burstsz) burst);
			burstReqQ.enq(tuple2(idx,burst));
		endmethod
	end else if ( valueOf(cnt) == 2 ) begin
		Reg#(Bit#(bsz)) burstLeft <- mkReg(0);
		Reg#(Bit#(1)) burstIdx <- mkReg(0);
		
		FIFO#(Tuple2#(Bit#(1),Bit#(burstsz))) burstReqQ <- mkFIFO;
		Vector#(2,FIFO#(dtype)) inQ <- replicateM(mkFIFO);
		rule doBurst;
			if ( burstLeft == 0 ) begin
				burstReqQ.deq;
				let b_ = burstReqQ.first;
				let i = tpl_1(b_);
				burstIdx <= i;
				let b = tpl_2(b_);
				if ( b != 0 ) begin
					inQ[i].deq;
					outQ.enq(inQ[i].first);
					burstLeft <= zeroExtend(b)-1;
				end
			end else begin
				burstLeft <= burstLeft - 1;
				inQ[burstIdx].deq;
				outQ.enq(inQ[burstIdx].first);
			end
		endrule

		Vector#(n, BLMergeEnqIfc#(dtype)) enq_;
		enq_[0] = interface BLMergeEnqIfc;
			method Action enq(dtype data);
				inQ[0].enq(data);
			endmethod
		endinterface;
		enq_[1] = interface BLMergeEnqIfc;
			method Action enq(dtype data);
				inQ[1].enq(data);
			endmethod
		endinterface;
		interface enq = enq_;
		method dtype first;
			return outQ.first;
		endmethod
		method Action deq;
			outQ.deq;
		endmethod
		method Action req(Bit#(isz) idx, Bit#(burstsz) burst);
			burstReqQ.enq(tuple2(idx[0],burst));
		endmethod
	end else begin // cnt == 1
		Reg#(Bit#(bsz)) burstLeft <- mkReg(0);
		
		FIFO#(Bit#(burstsz)) burstReqQ <- mkFIFO;
		FIFO#(dtype) inQ <- mkFIFO;
		rule doBurst;
			if ( burstLeft == 0 ) begin
				burstReqQ.deq;
				let b = burstReqQ.first;
				if ( b != 0 ) begin
					inQ.deq;
					outQ.enq(inQ.first);
					burstLeft <= zeroExtend(b)-1;
				end
			end else begin
				burstLeft <= burstLeft - 1;
				inQ.deq;
				outQ.enq(inQ.first);
			end
		endrule

		Vector#(n, BLMergeEnqIfc#(dtype)) enq_;
		enq_[0] = interface BLMergeEnqIfc;
			method Action enq(dtype data);
				inQ.enq(data);
			endmethod
		endinterface;
		interface enq = enq_;
		method dtype first;
			return outQ.first;
		endmethod
		method Action deq;
			outQ.deq;
		endmethod
		method Action req(Bit#(isz) idx, Bit#(burstsz) burst);
			burstReqQ.enq(burst);
		endmethod
	end

endmodule

interface BLBurstOrderMergerIfc#(numeric type tagcnt, type dtype, numeric type burstsz);
	method Action enq(dtype data, Bit#(TLog#(tagcnt)) tag);
	method Action req(Bit#(TLog#(tagcnt)) tag, Bit#(burstsz) burst);
	method dtype first;
	method Action deq;
endinterface

module mkBLBurstOrderMerger#(Bool usebram) (BLBurstOrderMergerIfc#(tagcnt, dtype, burstsz))
	provisos(Log#(tagcnt, tagsz), Add#(1,a__,tagsz),
		Bits#(dtype, dsz), 
		Add#(1,b__,dsz),
		Add#(c__, 2, tagsz),
		Add#(d__, 2, TLog#(tagcnt)),
		Add#(e__, 1, TLog#(tagcnt)), // we need both... for some reason
		Log#(TDiv#(tagcnt, 2), f__),
		Log#(TDiv#(tagcnt, 1), g__)

	);
	Integer tag_count = valueOf(tagcnt);
	Integer burstSize = valueOf(TExp#(burstsz));


	BLBurstReqMergerIfc#(tagcnt, tagsz, dtype, burstsz) merger <- mkBLBurstReqMerger;

	Vector#(tagcnt, FIFO#(dtype)) orderBufferQ;
	BLScatterNIfc#(tagcnt, dtype) dataInS <- mkBLScatterN;

	if ( usebram ) begin
		orderBufferQ <- replicateM(mkSizedBRAMFIFO(burstSize));
	end else begin
		orderBufferQ <- replicateM(mkSizedFIFO(burstSize));
	end

	for ( Integer i = 0; i < tag_count; i=i+1 ) begin
		rule enqDataIn;
			dataInS.get[i].deq;
			let d = dataInS.get[i].first;
			orderBufferQ[i].enq(d);
		endrule
		rule relayDataMerge;
			orderBufferQ[i].deq;
			merger.enq[i].enq(orderBufferQ[i].first);
		endrule
	end


	method Action enq(dtype data, Bit#(TLog#(tagcnt)) tag);
		dataInS.enq(data, zeroExtend(tag));
	endmethod
	method Action req(Bit#(TLog#(tagcnt)) tag, Bit#(burstsz) burst);
		merger.req(tag, burst);
	endmethod
	method dtype first;
		return merger.first;
	endmethod
	method Action deq;
		merger.deq;
	endmethod
endmodule

endpackage: BLBurstOrderMerger
