import FIFO::*;
import Vector::*;
import GetPut::*;

interface BoolMergeNetIfc#(numeric type incnt);
	interface Vector#(incnt, Put#(Bool)) puts;
	method ActionValue#(Bool) get;
endinterface

module mkBoolAndNet(BoolMergeNetIfc#(incnt));
	FIFO#(Bool) outQ <- mkFIFO;
	Vector#(incnt, FIFO#(Bool)) inQ <- replicateM(mkFIFO);

	if ( valueOf(incnt ) > 2 ) begin
		Vector#(2, BoolMergeNetIfc#(TDiv#(incnt,2))) ma <- replicateM(mkBoolAndNet);
		rule mergeout;
			Bool b1 <- ma[0].get;
			Bool b2 <- ma[1].get;
			outQ.enq(b1&&b2);
		endrule
		for ( Integer i = 0; i < valueOf(incnt); i=i+1 ) begin
			rule relayin;
				inQ[i].deq;
				let d = inQ[i].first;
				if ( i < valueOf(incnt)/2 ) begin
					ma[0].puts[i%(valueOf(incnt)/2)].put(d);
				end else begin
					ma[1].puts[i-(valueOf(incnt)/2)].put(d);
				end
			endrule
		end
		if ( valueOf(incnt)%2 > 0 ) begin
			rule dummy;
				ma[1].puts[valueOf(TDiv#(incnt,2))-1].put(True);
			endrule
		end

	end else if ( valueOf(incnt) == 2 ) begin
		rule relay2;
			inQ[0].deq;
			inQ[1].deq;
			outQ.enq(inQ[0].first && inQ[1].first);
		endrule
	end else begin
		rule relay1;
			inQ[0].deq;
			outQ.enq(inQ[0].first);
		endrule
	end

	Vector#(incnt, Put#(Bool)) puts_;
	for ( Integer i = 0; i < valueOf(incnt); i=i+1 ) begin
		puts_[i] = interface Put;
			method Action put(Bool v);
				inQ[i].enq(v);
			endmethod
		endinterface;
	end
	interface puts = puts_;
	method ActionValue#(Bool) get;
		outQ.deq;
		return outQ.first;
	endmethod
endmodule
