package Serializer;

import FIFO::*;
import Assert::*;

interface SerializerIfc#(numeric type srcSz, numeric type multiplier);
	method Action put(Bit#(srcSz) data);
	method ActionValue#(Bit#(TDiv#(srcSz,multiplier))) get;
endinterface

interface DeSerializerIfc#(numeric type srcSz, numeric type multiplier);
	method Action put(Bit#(srcSz) data);
	method ActionValue#(Bit#(TMul#(srcSz,multiplier))) get;
endinterface

module mkSerializer (SerializerIfc#(srcSz, multiplier))
	provisos (
		Div#(srcSz, multiplier, dstSz),
		Add#(a__, dstSz, srcSz)
	);
	FIFO#(Bit#(srcSz)) inQ <- mkFIFO;
	FIFO#(Bit#(dstSz)) outQ <- mkFIFO;

	Reg#(Bit#(srcSz)) buffer <- mkReg(0);
	Reg#(Bit#(TLog#(multiplier))) bufIdx <- mkReg(0);

	rule procin;
		if ( bufIdx == 0 ) begin
			inQ.deq;
			let d = inQ.first;
			buffer <= (d>>valueOf(dstSz));
			bufIdx <= fromInteger(valueOf(multiplier)-1);
			outQ.enq(truncate(d));
		end else begin
			outQ.enq(truncate(buffer));
			buffer <= (buffer>>valueOf(dstSz));
			bufIdx <= bufIdx - 1;
		end
	endrule

	method Action put(Bit#(srcSz) data);
		inQ.enq(data);
	endmethod
	method ActionValue#(Bit#(dstSz)) get;
		outQ.deq;
		return outQ.first;
	endmethod
endmodule

module mkDeSerializer (DeSerializerIfc#(srcSz, multiplier))
	provisos (
		Mul#(srcSz, multiplier, dstSz),
		Add#(a__, srcSz, dstSz),
		Add#(b__, 2, multiplier)
	);
	FIFO#(Bit#(srcSz)) inQ <- mkFIFO;
	FIFO#(Bit#(dstSz)) outQ <- mkFIFO;

	Reg#(Bit#(dstSz)) buffer <- mkReg(0);
	Reg#(Bit#(TAdd#(1,TLog#(multiplier)))) bufIdx <- mkReg(0);

	rule procin;
		Integer shiftup = (valueOf(multiplier)-1)*valueOf(srcSz);
		if ( bufIdx + 2 <= fromInteger(valueOf(multiplier)) ) begin
			let d = inQ.first;
			inQ.deq;

			buffer <= (buffer>>valueOf(srcSz)) | (zeroExtend(d)<<(shiftup) );
			bufIdx <= bufIdx + 1;
		end else begin
			let d = inQ.first;
			inQ.deq;
			Bit#(dstSz) td = (buffer>>valueOf(srcSz)) | (zeroExtend(d)<<(shiftup) );

			buffer <= 0;
			bufIdx <= 0;
			outQ.enq(td);
		end
	endrule

	method Action put(Bit#(srcSz) data);
		inQ.enq(data);
	endmethod
	method ActionValue#(Bit#(dstSz)) get;
		outQ.deq;
		return outQ.first;
	endmethod
endmodule

module mkStreamSkip#(Integer framesize, Integer offset) (FIFO#(dtype))
	provisos( Bits#(dtype, dtypeSz) );
	staticAssert(framesize<256, "mkStreamSkip framesize must be less than 256" );
	staticAssert(offset<framesize, "mkStreamSkip offset must be less than the framesize" );
	
	Reg#(Bit#(8)) skipIdx <- mkReg(0);
	FIFO#(dtype) outQ <- mkFIFO;


	method Action enq(dtype data);
		if ( skipIdx == fromInteger(offset) ) begin
			outQ.enq(data);
		end

		if ( skipIdx +1 >= fromInteger(framesize) ) begin
			skipIdx <= 0;
		end else begin
			skipIdx <= skipIdx + 1;
		end
	endmethod
	method deq = outQ.deq;
	method first = outQ.first;
	method clear = outQ.clear;
endmodule

endpackage: Serializer
