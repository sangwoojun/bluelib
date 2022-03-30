////////////////////////////////////////////////////////////////////////////////
// Sang-Woo Jun, 2021
////////////////////////////////////////////////////////////////////////////////
// Subnormal numbers are ignored
// NaN, Inf, etc are all ignored
////////////////////////////////////////////////////////////////////////////////


package SimpleBFloat;
import Vector::*;
import FIFO::*;
interface BFloat16AddIfc;
	method Action put(Bit#(16) a, Bit#(16) b);
	method ActionValue#(Bit#(16)) get;
endinterface

module mkBFloat16Add(BFloat16AddIfc);
	FIFO#(Tuple2#(Bit#(16), Bit#(16))) inputQ <- mkFIFO;
	FIFO#(Tuple3#(Bool,Bit#(17), Bit#(17))) calcQ <- mkFIFO;
	FIFO#(Tuple3#(Bit#(1), Bit#(8), Bit#(9))) normalizeQ <- mkFIFO;
	FIFO#(Tuple3#(Bit#(1), Bit#(8), Bit#(9))) normalizeQ1 <- mkFIFO;
	FIFO#(Tuple3#(Bit#(1), Bit#(8), Bit#(9))) normalizeQ2 <- mkFIFO;
	FIFO#(Tuple3#(Bit#(1), Bit#(8), Bit#(9))) normalizeQ3 <- mkFIFO;
	FIFO#(Bit#(16)) outputQ <- mkFIFO;

	rule step_1;
		inputQ.deq;
		let data = inputQ.first;
		let d_a = tpl_1(data);
		let d_b = tpl_2(data);
		Bit#(8) mantissa_a = zeroExtend(d_a[6:0]) | (1<<7); // omitted MSB
		Bit#(8) mantissa_b = zeroExtend(d_b[6:0]) | (1<<7);
		Bit#(8) expa = d_a[14:7];
		Bit#(8) expb = d_b[14:7];
		Bit#(1) signa = d_a[15];
		Bit#(1) signb = d_b[15];

		Bool alarger = ((expa > expb) || (expa == expb && mantissa_a > mantissa_b));
		Bit#(8) expdiff = (expa > expb)? (expa - expb):(expb - expa);
        mantissa_a = (alarger? mantissa_a:(mantissa_a>>expdiff));
		mantissa_b = (alarger? (mantissa_b>>expdiff):mantissa_b);

		calcQ.enq(tuple3(alarger, {signa, expa, mantissa_a}, {signb, expb, mantissa_b}));
    endrule

	rule step_2;
		calcQ.deq;
		let d_ = calcQ.first;
		Bool alarger = tpl_1(d_);
		let d_a = (tpl_2(d_));
		let d_b = (tpl_3(d_));
		Bit#(8) mantissa_a = d_a[7:0];
		Bit#(8) mantissa_b = d_b[7:0];
		Bit#(8) expa = d_a[15:8];
		Bit#(8) expb = d_b[15:8];
		Bit#(1) signa = d_a[16];
		Bit#(1) signb = d_b[16];
		
		Bit#(8) new_exp = alarger? expa : expb;
		Bit#(1) new_sign = alarger? signa : signb;

        Bit#(9) new_mantissa;
		if ( signa == signb ) begin
            new_mantissa = zeroExtend(mantissa_a) + zeroExtend(mantissa_b);
		end else begin
            new_mantissa = (mantissa_a > mantissa_b)? zeroExtend(mantissa_a - mantissa_b): zeroExtend(mantissa_b - mantissa_a);
		end
		normalizeQ.enq(tuple3(new_sign,new_exp,new_mantissa));
	endrule

	rule normalize;
		normalizeQ.deq;
		let d_ = normalizeQ.first;
		let newsign = tpl_1(d_);
		let newexp = tpl_2(d_);
		let newfrac = tpl_3(d_);
		
		if ( newfrac[8] == 1 ) begin
			newfrac = newfrac>>1;
			newexp = newexp + 1;
		end
		normalizeQ1.enq(tuple3(newsign,newexp, newfrac));
	endrule
	rule normalize1;
		normalizeQ1.deq;
		let d_ = normalizeQ1.first;
		let newsign = tpl_1(d_);
		let newexp = tpl_2(d_);
		let newfrac = tpl_3(d_);

		if ( newfrac[7:4] == 0 && newfrac != 0 ) begin
			newfrac = newfrac << 4;
			newexp = newexp - 4;
		end
		normalizeQ2.enq(tuple3(newsign,newexp, newfrac));
	endrule
	rule normalize2;
		normalizeQ2.deq;
		let d_ = normalizeQ2.first;
		let newsign = tpl_1(d_);
		let newexp = tpl_2(d_);
		let newfrac = tpl_3(d_);
		if ( newfrac[7:6] == 0 && newfrac != 0 ) begin
			newfrac = newfrac << 2;
			newexp = newexp - 2;
		end
		normalizeQ3.enq(tuple3(newsign,newexp, newfrac));
	endrule
	rule normalize3;
		normalizeQ3.deq;
		let d_ = normalizeQ3.first;
		let newsign = tpl_1(d_);
		let newexp = tpl_2(d_);
		let newfrac = tpl_3(d_);
		if ( newfrac[7] == 0 && newfrac != 0 ) begin
			newfrac = newfrac << 1;
			newexp = newexp - 1;
		end 
		Bit#(7) newfrace = truncate(newfrac);
		outputQ.enq({newsign,newexp,newfrace});
	endrule

	method Action put(Bit#(16) a, Bit#(16) b);
		inputQ.enq(tuple2(a, b));
	endmethod
	method ActionValue#(Bit#(16)) get;
		outputQ.deq;
		return outputQ.first;
	endmethod
endmodule

endpackage: SimpleBFloat
