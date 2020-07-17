package BLMergeN;

import FIFO::*;
import Vector::*;

interface BLScatterDeqIfc#(type t);
	method Action deq;
	method t first;
endinterface

interface BLScatterNInternalIfc#(numeric type n, numeric type nszo, type t);
	method Action enq(t data, Bit#(nszo) dst);
	interface Vector#(n,BLScatterDeqIfc#(t)) get;
endinterface

interface BLScatterNIfc#(numeric type n, type t);
	method Action enq(t data, Bit#(TLog#(n)) dst);
	interface Vector#(n,BLScatterDeqIfc#(t)) get;
endinterface

module mkBLScatterNInternal (BLScatterNInternalIfc#(n, nszo,t))
	provisos(Bits#(t, a__), Log#(n,nsz)
	);

	if ( valueOf(n) > 4 ) begin
		Vector#(4,BLScatterNInternalIfc#(TDiv#(n,4), nszo, t)) sa <- replicateM(mkBLScatterNInternal);
		FIFO#(Tuple2#(t,Bit#(nszo))) inQ <- mkFIFO;

		rule relayInput;
			let d = inQ.first;
			inQ.deq;
			let data =tpl_1(d);
			let dst = tpl_2(d);
			if ( dst < fromInteger(valueOf(n)/4) ) sa[0].enq(data,dst);
			else if ( dst < fromInteger(valueOf(n)/2) ) sa[1].enq(data,dst-fromInteger(valueOf(n)/4));
			else if ( dst < fromInteger(valueOf(n)*3/4) ) sa[2].enq(data,dst-fromInteger(valueOf(n)*2/4));
			else sa[3].enq(data, dst-fromInteger(valueOf(n)*3/4));
		endrule

		//Vector#(2,FIFO#(t)) vOutQ <- replicateM(mkFIFO);
		Vector#(n, BLScatterDeqIfc#(t)) get_;
		for ( Integer i = 0; i < valueOf(n); i=i+1) begin
			get_[i] = interface BLScatterDeqIfc;
				method Action deq;
					if ( i < valueOf(n)/4 ) begin
						sa[0].get[i].deq;
					end else if ( i < valueOf(n)*2/4 ) begin
						sa[1].get[i-(valueOf(n)/4)].deq;
					end else if ( i < valueOf(n)*3/4 ) begin
						sa[2].get[i-(valueOf(n)*2/4)].deq;
					end else begin
						sa[3].get[i-(valueOf(n)*3/4)].deq;
					end
				endmethod
				method t first;
					if ( i < valueOf(n)/4 ) begin
						return sa[0].get[i].first;
					end else if ( i < valueOf(n)*2/4 ) begin
						return sa[1].get[i-(valueOf(n)/4)].first;
					end else if ( i < valueOf(n)*3/4 ) begin
						return sa[2].get[i-(valueOf(n)*2/4)].first;
					end else begin
						return sa[3].get[i-(valueOf(n)*3/4)].first;
					end
				endmethod
			endinterface;
		end
		interface get = get_;
		method Action enq(t data, Bit#(nszo) dst);
			inQ.enq(tuple2(data,dst));
		endmethod
	end else if ( valueOf(n) == 4 ) begin
		Vector#(4,FIFO#(t)) vOutQ <- replicateM(mkFIFO);
		Vector#(n, BLScatterDeqIfc#(t)) get_;
		for ( Integer i = 0; i < 4; i=i+1) begin
			get_[i] = interface BLScatterDeqIfc;
				method Action deq;
					vOutQ[i].deq;
				endmethod
				method t first;
					return vOutQ[i].first;
				endmethod
			endinterface;
		end
		interface get = get_;
		method Action enq(t data, Bit#(nszo) dst);
			Bit#(2) idx = dst[1:0];
			vOutQ[idx].enq(data);
		endmethod
	end else if ( valueOf(n) > 2 ) begin
		Vector#(2,BLScatterNInternalIfc#(TDiv#(n,2), nszo, t)) sa <- replicateM(mkBLScatterNInternal);
		FIFO#(Tuple2#(t,Bit#(nszo))) inQ <- mkFIFO;

		rule relayInput;
			let d = inQ.first;
			inQ.deq;
			let data =tpl_1(d);
			let dst = tpl_2(d);
			if ( dst < fromInteger(valueOf(n)/2) ) sa[0].enq(data,dst);
			else sa[1].enq(data, dst-fromInteger(valueOf(n)/2));
		endrule

		//Vector#(2,FIFO#(t)) vOutQ <- replicateM(mkFIFO);
		Vector#(n, BLScatterDeqIfc#(t)) get_;
		for ( Integer i = 0; i < valueOf(n); i=i+1) begin
			get_[i] = interface BLScatterDeqIfc;
				method Action deq;
					if ( i < valueOf(n)/2 ) begin
						sa[0].get[i].deq;
					end else begin
						sa[1].get[i-(valueOf(n)/2)].deq;
					end
				endmethod
				method t first;
					if ( i < valueOf(n)/2 ) begin
						return sa[0].get[i].first;
					end else begin
						return sa[1].get[i-(valueOf(n)/2)].first;
					end
				endmethod
			endinterface;
		end
		interface get = get_;
		method Action enq(t data, Bit#(nszo) dst);
			inQ.enq(tuple2(data,dst));
		endmethod

	end else if ( valueOf(n) == 2 ) begin
		Vector#(2,FIFO#(t)) vOutQ <- replicateM(mkFIFO);
		Vector#(n, BLScatterDeqIfc#(t)) get_;
		for ( Integer i = 0; i < 2; i=i+1) begin
			get_[i] = interface BLScatterDeqIfc;
				method Action deq;
					vOutQ[i].deq;
				endmethod
				method t first;
					return vOutQ[i].first;
				endmethod
			endinterface;
		end
		interface get = get_;
		method Action enq(t data, Bit#(nszo) dst);
			if ( dst[0] == 0 ) vOutQ[0].enq(data);
			else vOutQ[1].enq(data);
		endmethod

	end else begin
		FIFO#(t) inQ <- mkFIFO;
		Vector#(n, BLScatterDeqIfc#(t)) get_;
		get_[0] = interface BLScatterDeqIfc;
			method Action deq;
				inQ.deq;
			endmethod
			method t first;
				return inQ.first;
			endmethod
		endinterface;
		interface get = get_;
		method Action enq(t data, Bit#(nszo) dst);
			inQ.enq(data);
		endmethod
	end
endmodule

module mkBLScatterN (BLScatterNIfc#(n, t))
	provisos(Bits#(t, a__), Log#(n,nsz)
	);
	BLScatterNInternalIfc#(n,nsz,t) sn <- mkBLScatterNInternal;
	interface get = sn.get;
	method enq = sn.enq;
endmodule

endpackage: BLMergeN
