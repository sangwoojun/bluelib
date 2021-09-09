package CompletionQueue;

import FIFO::*;
import FIFOF::*;
import BRAM::*;
import BRAMFIFO::*;



interface CompletionQueueIfc#(numeric type szlog, numeric type szlog2, type dtype);
	method ActionValue#(Bit#(szlog2)) enq;
	method dtype first;
	method Action deq;
	method Bool available;

	method Action complete(Bit#(szlog2) addr_epoch, dtype data);
endinterface

module mkCompletionQueue(CompletionQueueIfc#(szlog, szlog2, dtype))
	provisos(Bits#(dtype,dtypesz), Add#(szlog, 2, szlog2));
    Integer max_pos = valueof(TExp#(szlog)) - 1;
	BRAM2Port#(Bit#(szlog), Tuple2#(dtype, Bit#(2))) queuemem <- mkBRAM2Server(defaultValue);
	Reg#(Bit#(szlog)) head <- mkReg(0);
	Reg#(Bit#(szlog)) tail <- mkReg(0);

	FIFOF#(dtype) headValueQ <- mkFIFOF;
    FIFO#(Bit#(szlog)) headq <- mkFIFO;
	Reg#(Bit#(4)) headReqEpochSend <- mkReg(0);
	Reg#(Bit#(4)) headReqEpochRecv <- mkReg(0);
    Reg#(Bit#(2)) head_epoch <- mkReg(1), tail_epoch <- mkReg(1);
	FIFO#(Tuple2#(Bit#(szlog), Bit#(4))) headReqQ <- mkFIFO;
	FIFOF#(Bit#(szlog)) headReqRewindQ <- mkFIFOF;

	rule pollHeadSend;// ( tail != head );
		let curreq = head;
		let epoch = headReqEpochSend;
		
		if ( headReqRewindQ.notEmpty ) begin
			headReqRewindQ.deq;
			curreq = headReqRewindQ.first;
			epoch = epoch + 1;
		end

		//$write( "CQueue checking at %d\n", curreq );
		head <= curreq + 1;
        headq.enq(curreq);

		queuemem.portA.request.put(BRAMRequest{write:False, responseOnWrite:False, address: curreq, datain: ?});

		headReqQ.enq(tuple2(curreq,epoch));
		headReqEpochSend <= epoch;
	endrule

	rule pollHeadRecv;
		match {.d, .val_epoch} <- queuemem.portA.response.get;
		headReqQ.deq;
        let h = headq.first;
        headq.deq;
		let r_ = headReqQ.first;
		let epoch = tpl_2(r_);
		let r = tpl_1(r_);
		//$write( "CQueue receive check data at %d : epoch %d\n", r, epoch );

		if ( epoch == headReqEpochRecv ) begin
			if (val_epoch == head_epoch) begin
				headValueQ.enq(d);
                if(h == fromInteger(max_pos)) head_epoch <= head_epoch + 1;
				//$write( "Completed and done at id %d\n", r );
			end else begin
				headReqRewindQ.enq(r);
				headReqEpochRecv <= headReqEpochRecv + 1;
			end
		end
	endrule

	method ActionValue#(Bit#(szlog2)) enq if ( tail + 2 != head );
		tail <= tail + 1;
        if(tail == fromInteger(max_pos)) tail_epoch <= tail_epoch + 1;
        Bit#(szlog2) addr_epoch = {tail, tail_epoch};
		return addr_epoch;
	endmethod
	method dtype first;
		return headValueQ.first;
	endmethod
	method Action deq;
		headValueQ.deq;
	endmethod
	method Bool available = headValueQ.notEmpty;

	method Action complete(Bit#(szlog2) addr_epoch, dtype data);
        Bit#(szlog) addr = truncate(addr_epoch >> 2); 
        Bit#(2) epoch = truncate(addr_epoch);
		queuemem.portB.request.put(
			BRAMRequest{write:True, responseOnWrite:False, address:addr, datain: tuple2(data, epoch)});
	endmethod
endmodule

endpackage: CompletionQueue
