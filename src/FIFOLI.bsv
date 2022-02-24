/*
FIFO created with a chain of FIFOs, in order to get high latency but max throughput.
May be used to make routing easier over latency-insensitive queues
*/


package FIFOLI;

import FIFO::*;
import FIFOF::*;
import Vector::*;

interface FIFOLI#(type t, numeric type steps);
	method Action enq(t d);
	method t first;
	method Action deq;

	method Bool notEmpty;
	method Bool notFull;
endinterface

module mkFIFOLI(FIFOLI#(t, steps))
	provisos(Bits#(t, tSz),Div#(steps,1,hsteps));

	Vector#(hsteps,FIFOF#(t)) fifos <- replicateM(mkFIFOF);

	for ( Integer i = 0; i < valueOf(hsteps)-1; i=i+1 ) begin
		rule relay;
			fifos[i].deq;
			fifos[i+1].enq(fifos[i].first);
		endrule
	end


	method enq = fifos[0].enq;
	method first = fifos[valueOf(hsteps)-1].first;
	method deq = fifos[valueOf(hsteps)-1].deq;
	method notEmpty = fifos[valueOf(hsteps)-1].notEmpty;
	method notFull = fifos[valueOf(hsteps)-1].notFull;
endmodule

endpackage: FIFOLI

