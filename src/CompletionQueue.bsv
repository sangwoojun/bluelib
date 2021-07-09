package CompletionQueue;

import FIFO::*;
import FIFOF::*;
import BRAM::*;
import BRAMFIFO::*;



interface CompletionQueueIfc#(numeric type szlog, type dtype);
	method ActionValue#(Bit#(szlog)) enq;
	method dtype first;
	method Action deq;
	method Bool available;

	method Action complete(Bit#(szlog) addr, dtype data);
endinterface

module mkCompletionQueue(CompletionQueueIfc#(szlog, dtype))
	provisos(Bits#(dtype,dtypesz));
	BRAM2Port#(Bit#(szlog), Maybe#(dtype)) queuemem <- mkBRAM2Server(defaultValue);
	Reg#(Bit#(szlog)) head <- mkReg(0);
	Reg#(Bit#(szlog)) tail <- mkReg(0);

	FIFOF#(dtype) tailValueQ <- mkFIFOF;
	Reg#(Bit#(4)) tailReqEpochSend <- mkReg(0);
	Reg#(Bit#(4)) tailReqEpochRecv <- mkReg(0);
	FIFO#(Tuple2#(Bit#(szlog), Bit#(4))) tailReqQ <- mkFIFO;
	FIFOF#(Bit#(szlog)) tailReqRewindQ <- mkFIFOF;

	rule pollTailSend;// ( head != tail );
		let curreq = tail;
		let epoch = tailReqEpochSend;
		
		if ( tailReqRewindQ.notEmpty ) begin
			tailReqRewindQ.deq;
			curreq = tailReqRewindQ.first;
			epoch = epoch + 1;
		end

		//$write( "CQueue checking at %d\n", curreq );
		tail <= curreq + 1;

		queuemem.portA.request.put(BRAMRequest{write:False, responseOnWrite:False, address: curreq, datain: ?});

		tailReqQ.enq(tuple2(curreq,epoch));
		tailReqEpochSend <= epoch;
	endrule

	rule pollheadrecv;
		let t <- queuemem.portA.response.get;
		tailReqQ.deq;
		let r_ = tailReqQ.first;
		let epoch = tpl_2(r_);
		let r = tpl_1(r_);
		//$write( "CQueue receive check data at %d : epoch %d\n", r, epoch );

		if ( epoch == tailReqEpochRecv ) begin
			if ( isValid(t) ) begin
				let d = fromMaybe(?,t);
				tailValueQ.enq(d);
				//$write( "Completed and done at id %d\n", r );
			end else begin
				tailReqRewindQ.enq(r);
				tailReqEpochRecv <= tailReqEpochRecv + 1;
			end
		end
	endrule

	method ActionValue#(Bit#(szlog)) enq if ( head +2 != tail );
		head <= head + 1;
		return head;
	endmethod
	method dtype first;
		return tailValueQ.first;
	endmethod
	method Action deq;
		tailValueQ.deq;
	endmethod
	method Bool available = tailValueQ.notEmpty;

	method Action complete(Bit#(szlog) addr, dtype data);
		queuemem.portB.request.put(
			BRAMRequest{write:True, responseOnWrite:False, address:addr, datain: tagged Valid data});
	endmethod
endmodule

endpackage: CompletionQueue
