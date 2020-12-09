package BLShifter;

import FIFO::*;
import Vector::*;
//import BRAMFIFO::*;
//import SpecialFIFOs::*;

/*****

Multicycle shifter.
"shift_bits_per_stage" parameter determines how many bits to process per cycle.
shiftsz == shift_bits_per_stage returns shift results after 2 cycles

*****/


interface BLShiftIfc#(type in_type, numeric type shiftsz, numeric type shift_bits_per_stage); //
	method Action enq(in_type v, Bit#(shiftsz) shift);
	method Action deq;
	method in_type first;
endinterface


module mkPipelinedShift#(Bool shiftRight) (BLShiftIfc#(in_type, shiftsz, shift_bits_per_stage))
	provisos(Bits#(in_type, insz), 
		Bitwise#(in_type), 
		Add#(1, a__, insz), 
		Add#(shift_bits_per_stage, c__, shiftsz), Add#(1, d__, shift_bits_per_stage)
		);
	Integer fifocnt = valueOf(TDiv#(shiftsz,shift_bits_per_stage));
	Integer sbits = valueOf(shift_bits_per_stage);
   
	Vector#(TAdd#(1,TDiv#(shiftsz, shift_bits_per_stage)), FIFO#(Tuple2#(in_type, Bit#(shiftsz)))) stageQs <- replicateM(mkFIFO);
	for ( Integer i = 1; i <= fifocnt; i=i+1 ) begin
		rule shiftRelay;
			let d_ = stageQs[i-1].first;
			stageQs[i-1].deq;
			let d = tpl_1(d_);
			let a = tpl_2(d_);

			Bit#(shift_bits_per_stage) amt = truncate(a);


			in_type sd = d;
			for ( Integer j = 0; j < sbits; j=j+1 ) begin
				if (amt[j] == 1) begin
					if ( shiftRight ) begin
						sd = sd >> (1<<((i-1)*sbits+j));
					end else begin
						sd = sd << (1<<((i-1)*sbits+j));
					end
				end
			end

			//Bit#(shiftsz) ramt = (amt<<(i-1));
			//let sd = (d>>ramt);
			stageQs[i].enq(tuple2(sd, (a>>valueOf(shift_bits_per_stage))));
		endrule
	end

	method Action enq(in_type v, Bit#(shiftsz) shift);
		stageQs[0].enq(tuple2(v,shift));
	endmethod
	method Action deq;
		stageQs[fifocnt].deq;
	endmethod
	method in_type first;
		let r = stageQs[fifocnt].first;
		return tpl_1(r);
	endmethod
endmodule

endpackage
