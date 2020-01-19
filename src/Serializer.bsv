package Serializer;

import FIFO::*;
import SpecialFIFOs::*;
import Vector::*;
import Assert::*;
import GetPut::*;

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

module mkStreamReplicate#(Integer framesize) (FIFO#(dtype))
	provisos( Bits#(dtype, dtypeSz) );
	staticAssert(framesize<256, "mkStreamReplicate framesize must be less than 256" );
	staticAssert(framesize>0, "mkStreamReplicate framesize must be larger than 0" );
	
	Reg#(Bit#(8)) repIdx <- mkReg(0);
	Reg#(dtype) buffer <- mkReg(?);
	FIFO#(dtype) outQ <- mkFIFO;
	FIFO#(dtype) inQ <- mkFIFO;


	rule replicate;
		if ( repIdx == 0 ) begin
			repIdx <= fromInteger(framesize-1);

			let d = inQ.first;
			inQ.deq;

			outQ.enq(d);
			buffer <= d;
		end else begin
			repIdx <= repIdx - 1;
			outQ.enq(buffer);
		end
	endrule

	method enq = inQ.enq;
	method deq = outQ.deq;
	method first = outQ.first;
	method clear = outQ.clear;
endmodule

module mkStreamSerializeLast#(Integer framesize) (FIFO#(Bool));
	staticAssert(framesize<256, "mkStreamReplicate framesize must be less than 256" );
	staticAssert(framesize>0, "mkStreamReplicate framesize must be larger than 0" );
	
	Reg#(Bit#(8)) repIdx <- mkReg(0);
	FIFO#(Bool) outQ <- mkFIFO;
	FIFO#(Bool) inQ <- mkFIFO;
	Reg#(Bool) isLast <- mkReg(False);


	rule replicate;
		if ( repIdx == 0 ) begin
			repIdx <= fromInteger(framesize-1);

			let d = inQ.first;
			inQ.deq;

			outQ.enq(False);
			isLast <= d;
		end else begin
			repIdx <= repIdx - 1;
			if ( repIdx == 1 ) begin
				outQ.enq(isLast);
			end else begin
				outQ.enq(False);
			end
		end
	endrule

	method enq = inQ.enq;
	method deq = outQ.deq;
	method first = outQ.first;
	method clear = outQ.clear;
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

interface PipelineShiftIfc#(numeric type sz, numeric type shiftsz);
   method Action put(Bit#(sz) v, Bit#(shiftsz) shift);
   method ActionValue#(Bit#(sz)) get;
endinterface

module mkPipelineShiftRight(PipelineShiftIfc#(sz, shiftsz));
   
   Integer numStages =  valueOf(shiftsz);
   
   Vector#(shiftsz, FIFO#(Tuple2#(Bit#(sz), Bit#(shiftsz)))) stageFifos <- replicateM(mkFIFO);
   
   FIFO#(Bit#(sz)) outputFifo <- mkBypassFIFO;
   
   for (Integer i = numStages - 1; i >= 0; i = i - 1) begin
      rule doStage;
         let args <- toGet(stageFifos[i]).get();
         let val = tpl_1(args);
         let shift = tpl_2(args);
         
         if ( shift[i] == 1 ) begin
            val = val >> (1<<i);
         end
         
         if ( i > 0 ) begin
            stageFifos[i-1].enq(tuple2(val,shift));
         end
         else begin
            outputFifo.enq(val);
         end
      endrule
   end
      
   method Action put(Bit#(sz) v, Bit#(shiftsz) shift);
      stageFifos[numStages-1].enq(tuple2(v,shift));
   endmethod
   method ActionValue#(Bit#(sz)) get;
      let v <- toGet(outputFifo).get();
      return v;
   endmethod
endmodule


interface SerializerFreeformIfc#(numeric type srcSz, numeric type dstSz);
	method Action put(Bit#(srcSz) data);
	method ActionValue#(Bit#(dstSz)) get;
endinterface

module mkSerializerFreeform(SerializerFreeformIfc#(srcSz, dstSz))
	provisos (
		Add#(a__, dstSz, srcSz),
		Add#(b__, srcSz, TMul#(srcSz,2)),
		Add#(c__, dstSz, TMul#(srcSz,2))
	);
	Integer idst = valueOf(dstSz);
	Integer isrc = valueOf(srcSz);

	FIFO#(Bit#(srcSz)) inQ <- mkFIFO;
	FIFO#(Bit#(dstSz)) outQ <- mkFIFO;

	Reg#(Bit#(srcSz)) buffer <- mkReg(0);
	Reg#(Bit#(TAdd#(1,TLog#(srcSz)))) offset <- mkReg(0);

	PipelineShiftIfc#(TMul#(srcSz,2), TAdd#(1,TLog#(srcSz))) shifter <- mkPipelineShiftRight;

	rule serialize;
		if ( offset == 0 ) begin
			inQ.deq;
			let nbuf = zeroExtend(inQ.first);

			buffer <= inQ.first;
			offset <= fromInteger(idst);
			shifter.put(nbuf, 0);
		end else if ( offset + fromInteger(idst) < fromInteger(isrc) ) begin
			offset <= offset + fromInteger(idst);
			shifter.put(zeroExtend(buffer), offset);
		end else if ( offset + fromInteger(idst) == fromInteger(isrc) ) begin
			offset <= 0;
			shifter.put(zeroExtend(buffer), offset);
		end else begin
			inQ.deq;
			buffer <= inQ.first;
			
			let hbuf = {inQ.first, buffer};
			shifter.put(hbuf, offset);

			offset <= offset - fromInteger(isrc-idst);
		end
	endrule

	method Action put(Bit#(srcSz) data);
		inQ.enq(data);
	endmethod
	method ActionValue#(Bit#(dstSz)) get;
		let d <- shifter.get;
		return truncate(d);
	endmethod
endmodule

endpackage: Serializer

