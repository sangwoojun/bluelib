package BLHashFunctions;
import FIFO::*;
import BRAMFIFO::*;
import Vector::*;

interface HashFunction32Ifc#(type dtype);
	method Action put(dtype data);
	method ActionValue#(Bit#(32)) get;
endinterface

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

	Vector#(dwords, FIFO#(Bit#(dsz))) intermediateQs <- replicateM(mkFIFO);
	Vector#(dwords, FIFO#(Bit#(32))) intermediateHashQs <- replicateM(mkFIFO);
	FIFO#(Bit#(32)) midQ <- mkFIFO;

	for (Integer i = 0; i < valueOf(dwords); i=i+1) begin
		rule step;
			let d = intermediateQs[i].first;
			let h = intermediateHashQs[i].first;
			intermediateHashQs[i].deq;
			intermediateQs[i].deq;

			Bit#(32) chunk = truncate(d);
			chunk = chunk * c1;
			chunk = ((chunk<<r1) | (chunk>>(32-r1)));
			chunk = (chunk * c2);

			Bit#(32) hash = h ^ chunk;
			hash = ((hash<<r2) | (hash>>(32-r2)));
			hash = (hash*m)+n;
			
			if ( i +1 < valueOf(dwords) ) begin
				intermediateHashQs[i+1].enq(hash);
				intermediateQs[i+1].enq(d);
			end else begin
				midQ.enq(hash);
			end
		endrule
	end

	FIFO#(Bit#(32)) outQ <- mkFIFO;
	rule scramble;
		let h = midQ.first;
		midQ.deq;

		h = h ^ (h>>16);
		h = h * 32'h85ebca6b;
		h = h ^ (h>>13);
		h = h * 32'hc2b2ae35;
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
