/**
Description: Collects tagged data in separate buffers, and emits them in grouped tag order.
Tag order is supplied via req
Not wire-speed. Things may get blocked according to request order.
Wire-speed option is in BLBurstOrderMerger

Interface parameters: 
bufcnt: how many buffers (tags)?
dcnt: how many elements in each buffer?
dtype: Data type in buffer?

Module parameter: 
reqQCount: size of request input queue
**/



package BLBurstOrderChain;

import FIFO::*;
import BRAMFIFO::*;
import Vector::*;

import BLMergeN::*;

interface BLBurstOrderChainIfc#(numeric type bufcnt, numeric type dcnt, type dtype);
	method Action enq(dtype data, Bit#(TLog#(bufcnt)) idx);
	method dtype first;
	method Action deq;

	method Action req(Bit#(TLog#(bufcnt)) idx, Bit#(TAdd#(1,TLog#(dcnt))) burst);
endinterface

module mkBLBurstOrderChain#(Integer reqQCount) (BLBurstOrderChainIfc#(bufcnt, dcnt, dtype))
	provisos(
		Bits#(dtype, dsz), Add#(a__, 1, dsz), Log#(bufcnt, bisz),
		Add#(c__, TAdd#(1, TLog#(dcnt)), 32)
	);

	Integer dataCount = valueOf(dcnt);
	Integer bufferCount = valueOf(bufcnt);

	Vector#(bufcnt, FIFO#(dtype)) bufferQs <- replicateM(mkSizedBRAMFIFO(dataCount));
	Vector#(bufcnt, FIFO#(Tuple2#(dtype,Bit#(bisz)))) inQs <- replicateM(mkFIFO);
	Vector#(bufcnt, FIFO#(Tuple2#(Bit#(bisz),Bit#(TAdd#(1,TLog#(dcnt)))))) reqQs <- replicateM(mkFIFO);
	Vector#(bufcnt, FIFO#(dtype)) outQs <- replicateM(mkFIFO);
	FIFO#(Tuple2#(Bit#(bisz),Bit#(TAdd#(1,TLog#(dcnt))))) reqQ <- mkSizedFIFO(reqQCount);

	for ( Integer i = 0; i < bufferCount; i=i+1 ) begin
		rule routeInput;
			inQs[i].deq;
			let d_ = inQs[i].first;
			let d = tpl_1(d_);
			let idx = tpl_2(d_);

			if ( idx == fromInteger(i) ) begin
				bufferQs[i].enq(d);
			end else if ( i < bufferCount-1 ) begin
				inQs[i+1].enq(d_);
			end
		endrule
		Reg#(Bit#(32)) upstreamReqTotal <- mkReg(0);
		Reg#(Bit#(TAdd#(1,TLog#(dcnt)))) currentReq <- mkReg(0);
		rule routeReq ( currentReq == 0 );
			let r_ = reqQs[i].first;
			reqQs[i].deq;
			let dst = tpl_1(r_);
			let cnt = tpl_2(r_);
			if ( dst == fromInteger(i) ) begin
				currentReq <= cnt;
				//$write("Starting data read from %d -- %d\n", dst, cnt );
			end else if ( i < bufferCount - 1 ) begin
				reqQs[i+1].enq(r_);
				upstreamReqTotal <= upstreamReqTotal + zeroExtend(cnt);
			end
		endrule
		rule routeOut;
			if ( upstreamReqTotal > 0 ) begin
				if ( i < bufferCount - 1 ) begin
					outQs[i+1].deq;
					outQs[i].enq(outQs[i+1].first);
					upstreamReqTotal <= upstreamReqTotal - 1;
				end
			end else if ( currentReq > 0 ) begin
				bufferQs[i].deq;
				outQs[i].enq(bufferQs[i].first);
				currentReq <= currentReq - 1;
			end
		endrule
	end
	rule relayReq;
		reqQ.deq;
		reqQs[0].enq(reqQ.first);
	endrule

	method Action enq(dtype data, Bit#(TLog#(bufcnt)) idx);
		inQs[0].enq(tuple2(data,idx));
	endmethod
	method dtype first;
		return outQs[0].first;
	endmethod
	method Action deq;
		outQs[0].deq;
	endmethod
	method Action req(Bit#(TLog#(bufcnt)) idx, Bit#(TAdd#(1,TLog#(dcnt))) burst);
		reqQ.enq(tuple2(idx,burst));
		//$write("BurstOrderChain req %d\n", idx );
	endmethod
endmodule
endpackage: BLBurstOrderChain
