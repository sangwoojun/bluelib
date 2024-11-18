package BLHashFunctions;

import FIFO::*;
import BRAMFIFO::*;
import Vector::*;

interface HashFunction32Ifc#(type dtype);
	method Action put(dtype data);
	method ActionValue#(Bit#(32)) get;
endinterface

(* synthesize *)
module mkHashFunctionMurmur3_32_128_37 (HashFunction32Ifc#(Bit#(128)));
	HashFunction32Ifc#(Bit#(128)) r <- mkHashFunctionMurmur3_32(37);
	return r;
endmodule

(* synthesize *)
module mkHashFunctionMurmur3_32_128_17 (HashFunction32Ifc#(Bit#(128)));
	HashFunction32Ifc#(Bit#(128)) r <- mkHashFunctionMurmur3_32(17);
	return r;
endmodule

module mkHashFunctionMurmur3_32#(Bit#(32) seed) (HashFunction32Ifc#(dtype))
	provisos(
		Bits#(dtype, dsz), Add#(a__,1,dsz),
		Div#(dsz,32,dwords),
		Add#(b__, 32, dsz)
	);

	Bit#(32) c1 = 32'hcc9e2d51;
	Bit#(32) c2 = 32'h1b873593;
	Integer r1 = 15;
	Integer r2 = 13;
	Bit#(32) m = 5;
	Bit#(32) n = 32'he6546b64;

	Vector#(dwords, FIFO#(Bit#(dsz))) intermediateQs <- replicateM(mkSizedFIFO(4));
	Vector#(dwords, FIFO#(Bit#(32))) intermediateHashQs <- replicateM(mkSizedFIFO(4));
	FIFO#(Bit#(32)) midQ <- mkFIFO;

	for (Integer i = 0; i < valueOf(dwords); i=i+1) begin
		FIFO#(Bit#(32)) hashStep1Q <- mkFIFO;
		FIFO#(Bit#(32)) hashStep2Q <- mkFIFO;
		rule stepq1;
			let d = intermediateQs[i].first;
			intermediateQs[i].deq;
			
			if ( i +1 < valueOf(dwords) ) begin
				intermediateQs[i+1].enq(d);
			end

			Bit#(32) chunk = truncate(d);
			chunk = chunk * c1;
			chunk = ((chunk<<r1) | (chunk>>(32-r1)));

			hashStep1Q.enq(chunk);
		endrule

		rule stepq2;
			let chunk = hashStep1Q.first;
			hashStep1Q.deq;
			let h = intermediateHashQs[i].first;
			intermediateHashQs[i].deq;

			chunk = (chunk * c2);

			Bit#(32) hash = h ^ chunk;
			hash = ((hash<<r2) | (hash>>(32-r2)));
			hashStep2Q.enq(hash);
		endrule

		rule stepq3;
			let hash = hashStep2Q.first;
			hashStep2Q.deq;

			hash = (hash*m)+n;
			
			if ( i+1 < valueOf(dwords) ) begin
				intermediateHashQs[i+1].enq(hash);
			end else begin
				midQ.enq(hash);
			end
		endrule
	end

	FIFO#(Bit#(32)) out1Q <- mkFIFO;
	FIFO#(Bit#(32)) out2Q <- mkFIFO;
	FIFO#(Bit#(32)) out3Q <- mkFIFO;
	FIFO#(Bit#(32)) out4Q <- mkFIFO;
	FIFO#(Bit#(32)) outQ <- mkFIFO;
	rule scramble1;
		let h = midQ.first;
		midQ.deq;

		h = h ^ (h>>16);
		out1Q.enq(h);
	endrule
	rule scramble2;
		let h = out1Q.first;
		out1Q.deq;
		h = h * 32'h85ebca6b;
		out2Q.enq(h);
	endrule
	rule scramble3;
		let h = out2Q.first;
		out2Q.deq;
		h = h ^ (h>>13);
		out3Q.enq(h);
	endrule
	rule scramble4;
		let h = out3Q.first;
		out3Q.deq;
	
		h = h * 32'hc2b2ae35;
		out4Q.enq(h);
	endrule
	rule scramble5;
		let h = out4Q.first;
		out4Q.deq;
		h = h ^ (h>>16);
		outQ.enq(h);
	endrule
	
	method Action put(dtype data);
		intermediateHashQs[0].enq(seed);
		intermediateQs[0].enq(pack(data));
	endmethod
	method ActionValue#(Bit#(32)) get;
		outQ.deq;
		return outQ.first;
	endmethod
endmodule

endpackage: BLHashFunctions
