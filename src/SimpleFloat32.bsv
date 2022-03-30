////////////////////////////////////////////////////////////////////////////////
// Sang-Woo Jun, 2021
////////////////////////////////////////////////////////////////////////////////
// Subnormal numbers are ignored
// NaN, Inf, etc are all ignored
////////////////////////////////////////////////////////////////////////////////


package SimpleFloat;

import FIFO::*;

typedef struct {
    Bit#(23) mantissa;
    Bit#(8) exponent;
    Bit#(1) sign;
} MyFloat deriving (Bits,Eq);

typedef Bit#(32) Float;
typedef Bit#(23) Mantissa;
typedef Bit#(8) Exponent;
typedef Bit#(1) Sign;

interface MyFloatIfc;
	method Action put(Float a, Float b);
	method ActionValue#(Float) get;
endinterface

module mkFloatMult(MyFloatIfc);
	FIFO#(Tuple4#(Bit#(1),Bit#(9), Bit#(46), Bool)) stepQ <- mkSizedFIFO(6);
	FIFO#(Bit#(32)) outputQ <- mkFIFO;

	rule procMultResult;
		stepQ.deq;
		Bit#(1) sign = tpl_1(stepQ.first); 
		Bit#(9) expsum = tpl_2(stepQ.first); 
		Bit#(46) mres = tpl_3(stepQ.first);
        Bool isZero = tpl_4(stepQ.first);
		Mantissa newmantissa;
		Exponent newexp;    
		if ( mres[45] != 0 ) begin 
            newmantissa = truncate(mres>>22);
			newexp = truncate(expsum-126);
		end else begin
            newmantissa = truncate(mres>>21);
			newexp = truncate(expsum-127);
		end
		if ( isZero ) outputQ.enq(0);
		else outputQ.enq({sign,newexp,newmantissa,0});
	endrule
	method Action put(Float a, Float b);
		Mantissa mantissa_a = a[22:0];
		Mantissa mantissa_b = b[22:0];
		Bit#(46) newmantissa = zeroExtend(mantissa_a) * zeroExtend(mantissa_b);
		Sign newsign = a[31] ^ b[31];
		Exponent expa = a[30:23];
		Exponent expb = b[30:23];
		Bool isZero = (expa==0)||(expb==0);
		Bit#(9) expsum = zeroExtend(expa)+zeroExtend(expb);
		stepQ.enq(tuple4(newsign,expsum,newmantissa,isZero));
	endmethod
	method ActionValue#(Float) get;
		outputQ.deq;
		return unpack(outputQ.first);
	endmethod
endmodule

module mkFloatAdd(MyFloatIfc);
	FIFO#(Tuple2#(Float, Float)) inputQ <- mkFIFO;
	FIFO#(Tuple3#(Bool,MyFloat, MyFloat)) calcQ <- mkFIFO;
	FIFO#(Tuple3#(Sign, Exponent, Bit#(24))) normalizeQ <- mkFIFO;
	FIFO#(Tuple3#(Sign, Exponent, Bit#(24))) normalizeQ1 <- mkFIFO;
	FIFO#(Tuple3#(Sign, Exponent, Bit#(24))) normalizeQ2 <- mkFIFO;
	FIFO#(Tuple3#(Sign, Exponent, Bit#(24))) normalizeQ3 <- mkFIFO;
	FIFO#(Tuple3#(Sign, Exponent, Bit#(24))) normalizeQ4 <- mkFIFO;
	FIFO#(Tuple3#(Sign, Exponent, Bit#(24))) normalizeQ5 <- mkFIFO;
	FIFO#(Float) outputQ <- mkFIFO;

	rule step_1;
		inputQ.deq;
		let data = inputQ.first;
		let d_a = tpl_1(data);
		let d_b = tpl_2(data);

		Bit#(23) mantissa_a = zeroExtend(d_a[22:1]) | (1<<22);
		Bit#(23) mantissa_b = zeroExtend(d_b[22:1]) | (1<<22);
		Exponent expa = d_a[30:23];
		Exponent expb = d_b[30:23];
		Sign signa = d_a[31];
		Sign signb = d_b[31];
		$display("%d\n", d_a[21]);
		
		$display(" exp : %d, frac : %x", expa, mantissa_a);
		$display(" exp : %d, frac : %x", expb, mantissa_b);

		Bool alarger = ((expa > expb) || (expa == expb && mantissa_a > mantissa_b));
		Bit#(8) expdiff = (expa > expb)? (expa - expb):(expb - expa);
        mantissa_a = (alarger?mantissa_a:(mantissa_a>>expdiff));
		mantissa_b = (alarger?(mantissa_b>>expdiff):mantissa_b);

		calcQ.enq(tuple3(alarger,
			MyFloat{mantissa:mantissa_a, exponent:expa, sign:signa},
			MyFloat{mantissa:mantissa_b, exponent:expb, sign:signb}
		));
    endrule

	rule step_2;
		calcQ.deq;
		let d_ = calcQ.first;
		Bool alarger = tpl_1(d_);
		let ta = (tpl_2(d_));
		let tb = (tpl_3(d_));
		let mantissa_a = ta.mantissa;
		let mantissa_b = tb.mantissa;
		let expa = ta.exponent;
		let expb = tb.exponent;
		let signa = ta.sign;
		let signb = tb.sign;
		Bit#(24) new_mantissa;
		
		Exponent new_exp = alarger? expa : expb;
		Sign new_sign = alarger? signa : signb;
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
		
		if ( newfrac[23] == 1 ) begin
			newfrac = newfrac>>1;
			newexp = newexp + 1;
		end

		$display(" exp : %d, frac : %x", newexp, newfrac);
		normalizeQ1.enq(tuple3(newsign,newexp, newfrac));
	endrule
	rule normalize1;
		normalizeQ1.deq;
		let d_ = normalizeQ1.first;
		let newsign = tpl_1(d_);
		let newexp = tpl_2(d_);
		let newfrac = tpl_3(d_);

		if ( newfrac[22:11] == 0 && newfrac != 0 ) begin
			newfrac = newfrac << 12;
			newexp = newexp - 12;
		end
		normalizeQ2.enq(tuple3(newsign,newexp, newfrac));
	endrule
	rule normalize2;
		normalizeQ2.deq;
		let d_ = normalizeQ2.first;
		let newsign = tpl_1(d_);
		let newexp = tpl_2(d_);
		let newfrac = tpl_3(d_);
		if ( newfrac[22:17] == 0 && newfrac != 0 ) begin
			newfrac = newfrac << 6;
			newexp = newexp - 6;
		end
		normalizeQ3.enq(tuple3(newsign,newexp, newfrac));
	endrule
	rule normalize3;
		normalizeQ3.deq;
		let d_ = normalizeQ3.first;
		let newsign = tpl_1(d_);
		let newexp = tpl_2(d_);
		let newfrac = tpl_3(d_);
		if ( newfrac[22:20] == 0 && newfrac != 0 ) begin
			newfrac = newfrac << 3;
			newexp = newexp - 3;
		end
		normalizeQ4.enq(tuple3(newsign,newexp, newfrac));
	endrule

	rule normalize4;
		normalizeQ4.deq;
		let d_ = normalizeQ4.first;
		let newsign = tpl_1(d_);
		let newexp = tpl_2(d_);
		let newfrac = tpl_3(d_);
		if ( newfrac[22:21] == 0 && newfrac != 0 ) begin
			newfrac = newfrac << 2;
			newexp = newexp - 2;
		end
		normalizeQ5.enq(tuple3(newsign,newexp, newfrac));
	endrule


	rule normalize5;
		normalizeQ5.deq;
		let d_ = normalizeQ5.first;
		let newsign = tpl_1(d_);
		let newexp = tpl_2(d_);
		let newfrac = tpl_3(d_);
		if ( newfrac[22] == 0 && newfrac != 0 ) begin
			newfrac = newfrac << 1;
			newexp = newexp - 1;
		end 
		Bit#(22) newfrace = truncate(newfrac);
		$display("normalize exp : %d, frac : %x", newexp, newfrace);
		outputQ.enq({newsign,newexp,newfrace,0});
	endrule

	method Action put(Float a, Float b);
		inputQ.enq(tuple2(a, b));
		Mantissa mantissa_a = a[22:0];
		Mantissa mantissa_b = b[22:0];
		Exponent expa = a[30:23];
		Exponent expb = b[30:23];
		Sign signa = a[31];
		Sign signb = b[31];
		
		$display(" exp : %d, frac : %x", expa, mantissa_a);
		$display(" exp : %d, frac : %x", expb, mantissa_b);
	endmethod
	method ActionValue#(Float) get;
		outputQ.deq;
		return outputQ.first;
	endmethod
endmodule

endpackage: SimpleFloat
