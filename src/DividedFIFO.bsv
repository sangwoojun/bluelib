/* This module helps create a large FIFO with no timing issues. */

package DividedFIFO;
import FIFO::*;
import Vector::*;
import BRAM::*;
import BRAMFIFO::*;

interface DividedBRAMFIFOIfc#(type t, numeric type srcSz, numeric type steps);
    method Action enq(t d);
    method t first;
    method Action deq;
endinterface

interface DividedFIFOIfc#(type t, numeric type srcSz, numeric type steps);
    method Action enq(t d);
    method t first;
    method Action deq;
endinterface


module mkDividedBRAMFIFO (DividedBRAMFIFOIfc#(t, srcSz, steps))
    provisos (
        Bits#(t , a__),
        Add#(1, b__, a__),
        Div#(srcSz, steps, dstSz)
    );
    FIFO#(t) inQ <- mkFIFO;
    FIFO#(t) outQ <- mkFIFO;

    Vector#(steps, FIFO#(t)) fifos <- replicateM(mkSizedBRAMFIFO(valueOf(dstSz)));

    for (Integer i = 0; i < valueOf(steps) - 1; i = i + 1) begin
        rule relay;
            fifos[i].deq;
            fifos[i+1].enq(fifos[i].first);
        endrule
    end

    rule in_queue;
        inQ.deq;
        fifos[0].enq(inQ.first);
    endrule

    rule de_queue;
        fifos[valueOf(steps) - 1].deq;
        outQ.enq(fifos[valueOf(steps) - 1].first);
    endrule

    method Action enq(t d);
        inQ.enq(d);
    endmethod
    method t first;
        return outQ.first;
    endmethod
    method Action deq;
        outQ.deq;
    endmethod
endmodule

module mkDividedFIFO (DividedFIFOIfc#(t, srcSz, steps))
    provisos (
        Bits#(t , a__),
        Add#(1, b__, a__),
        Div#(srcSz, steps, dstSz)
    );
    FIFO#(t) inQ <- mkFIFO;
    FIFO#(t) outQ <- mkFIFO;

    Vector#(steps, FIFO#(t)) fifos <- replicateM(mkSizedFIFO(valueOf(dstSz)));

    for (Integer i = 0; i < valueOf(steps) - 1; i = i + 1) begin
        rule relay;
            fifos[i].deq;
            fifos[i+1].enq(fifos[i].first);
        endrule
    end

    rule in_queue;
        inQ.deq;
        fifos[0].enq(inQ.first);
    endrule

    rule de_queue;
        fifos[valueOf(steps) - 1].deq;
        outQ.enq(fifos[valueOf(steps) - 1].first);
    endrule

    method Action enq(t d);
        inQ.enq(d);
    endmethod
    method t first;
        return outQ.first;
    endmethod
    method Action deq;
        outQ.deq;
    endmethod
endmodule

endpackage: DividedFIFO
