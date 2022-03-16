package BFloat16;

import Vector::*;
import FIFO::*;
import FloatingPoint::*;
import Float32::*;

typedef FloatingPoint#(8,7)  BFloat16;

// float 16 : sign 1 bit, exponent 5 bits, fraction 10 bits

import "BDPI" function Bit#(16) bdpi_divisor_bfloat(Bit#(16) a, Bit#(16) b);

typedef 9 MultLatency16;
typedef 9 AddLatency16;
typedef 9 SubLatency16;
typedef 13 DivLatency16;
typedef 16 FmaLatency16;

import "BVI" bf_sub16 =
module mkBfSubImport16#(Clock aclk, Reset arst) (FpPairImportIfc#(16));
	default_clock no_clock;
	default_reset no_reset;

	input_clock (aclk) = aclk;
	method m_axis_result_tdata get enable(m_axis_result_tready) ready(m_axis_result_tvalid) clocked_by(aclk);

	method enqa(s_axis_a_tdata) enable(s_axis_a_tvalid) ready(s_axis_a_tready) clocked_by(aclk);
	method enqb(s_axis_b_tdata) enable(s_axis_b_tvalid) ready(s_axis_b_tready) clocked_by(aclk);

	schedule (
		get, enqa, enqb
	) CF (
		get, enqa, enqb
	);
endmodule
import "BVI" bf_add16 =
module mkBfAddImport16#(Clock aclk, Reset arst) (FpPairImportIfc#(16));
	default_clock no_clock;
	default_reset no_reset;

	input_clock (aclk) = aclk;
	method m_axis_result_tdata get enable(m_axis_result_tready) ready(m_axis_result_tvalid) clocked_by(aclk);

	method enqa(s_axis_a_tdata) enable(s_axis_a_tvalid) ready(s_axis_a_tready) clocked_by(aclk);
	method enqb(s_axis_b_tdata) enable(s_axis_b_tvalid) ready(s_axis_b_tready) clocked_by(aclk);

	schedule (
		get, enqa, enqb
	) CF (
		get, enqa, enqb
	);
endmodule
import "BVI" bf_mult16 =
module mkBfMultImport16#(Clock aclk, Reset arst) (FpPairImportIfc#(16));
	default_clock no_clock;
	default_reset no_reset;

	input_clock (aclk) = aclk;
	method m_axis_result_tdata get enable(m_axis_result_tready) ready(m_axis_result_tvalid) clocked_by(aclk);

	method enqa(s_axis_a_tdata) enable(s_axis_a_tvalid) ready(s_axis_a_tready) clocked_by(aclk);
	method enqb(s_axis_b_tdata) enable(s_axis_b_tvalid) ready(s_axis_b_tready) clocked_by(aclk);

	schedule (
		get, enqa, enqb
	) CF (
		get, enqa, enqb
	);
endmodule
import "BVI" bf_div16 =
module mkBfDivImport16#(Clock aclk, Reset arst) (FpPairImportIfc#(16));
	default_clock no_clock;
	default_reset no_reset;

	input_clock (aclk) = aclk;
	method m_axis_result_tdata get enable(m_axis_result_tready) ready(m_axis_result_tvalid) clocked_by(aclk);

	method enqa(s_axis_a_tdata) enable(s_axis_a_tvalid) ready(s_axis_a_tready) clocked_by(aclk);
	method enqb(s_axis_b_tdata) enable(s_axis_b_tvalid) ready(s_axis_b_tready) clocked_by(aclk);

	schedule (
		get, enqa, enqb
	) CF (
		get, enqa, enqb
	);
endmodule
import "BVI" bf_fma16 =
module mkBfFmaImport16#(Clock aclk, Reset arst) (FpThreeOpImportIfc#(16));
	default_clock no_clock;
	default_reset no_reset;

	input_clock (aclk) = aclk;
	method m_axis_result_tdata get enable(m_axis_result_tready) ready(m_axis_result_tvalid) clocked_by(aclk);

	method enqa(s_axis_a_tdata) enable(s_axis_a_tvalid) ready(s_axis_a_tready) clocked_by(aclk);
	method enqb(s_axis_b_tdata) enable(s_axis_b_tvalid) ready(s_axis_b_tready) clocked_by(aclk);
	method enqc(s_axis_c_tdata) enable(s_axis_c_tvalid) ready(s_axis_c_tready) clocked_by(aclk);
	method enqop(s_axis_operation_tdata) enable(s_axis_operation_tvalid) ready(s_axis_operation_tready) clocked_by(aclk);

	schedule (
		get, enqa, enqb, enqc, enqop
	) CF (
		get, enqa, enqb, enqc, enqop
	);
endmodule

module mkBfSub16 (FpPairIfc#(16));
	Clock curClk <- exposeCurrentClock;
	Reset curRst <- exposeCurrentReset;

	FIFO#(Bit#(16)) outQ <- mkFIFO;
`ifdef BSIM
	Vector#(SubLatency16, FIFO#(Bit#(16))) latencyQs <- replicateM(mkFIFO);
	for (Integer i = 0; i < valueOf(SubLatency16)-1; i=i+1 ) begin
		rule relay;
			latencyQs[i].deq;
			latencyQs[i+1].enq(latencyQs[i].first);
		endrule
	end
	rule relayOut;
		Integer lastIdx = valueOf(SubLatency16)-1;
		latencyQs[lastIdx].deq;
		outQ.enq(latencyQs[lastIdx].first);
	endrule
`else
	FpPairImportIfc#(16) fp_sub <- mkBfSubImport16(curClk, curRst);
	rule getOut;
		let v <- fp_sub.get;
		outQ.enq(v);
	endrule
`endif

	method Action enq(Bit#(16) a, Bit#(16) b);
`ifdef BSIM
	Bool asign = a[15] == 1;
	Bool bsign = b[15] == 1;
	Bit#(8) ae = truncate(a>>7);
	Bit#(8) be = truncate(b>>7);
	Bit#(7) as = truncate(a);
	Bit#(7) bs = truncate(b);
	BFloat16 fa = BFloat16{sign: asign, exp: ae, sfd: as};
	BFloat16 fb = BFloat16{sign: bsign, exp: be, sfd: bs};
	BFloat16 fm = fa - fb;
	//outQ.enq( {fm.sign?1:0,fm.exp,fm.sfd} );
	latencyQs[0].enq( {fm.sign?1:0,fm.exp,fm.sfd} );
`else
		fp_sub.enqa(a);
		fp_sub.enqb(b);
`endif
	endmethod
	method Action deq;
		outQ.deq;
	endmethod
	method Bit#(16) first;
		return outQ.first;
	endmethod
endmodule

module mkBfAdd16 (FpPairIfc#(16));
	Clock curClk <- exposeCurrentClock;
	Reset curRst <- exposeCurrentReset;

	FIFO#(Bit#(16)) outQ <- mkFIFO;
`ifdef BSIM
	Vector#(AddLatency16, FIFO#(Bit#(16))) latencyQs <- replicateM(mkFIFO);
	for (Integer i = 0; i < valueOf(AddLatency16)-1; i=i+1 ) begin
		rule relay;
			latencyQs[i].deq;
			latencyQs[i+1].enq(latencyQs[i].first);
		endrule
	end
	rule relayOut;
		Integer lastIdx = valueOf(AddLatency16)-1;
		latencyQs[lastIdx].deq;
		outQ.enq(latencyQs[lastIdx].first);
	endrule
`else
	FpPairImportIfc#(16) fp_add <- mkBfAddImport16(curClk, curRst);
	rule getOut;
		let v <- fp_add.get;
		outQ.enq(v);
	endrule
`endif

	method Action enq(Bit#(16) a, Bit#(16) b);
`ifdef BSIM
	Bool asign = a[15] == 1;
	Bool bsign = b[15] == 1;
	Bit#(8) ae = truncate(a>>7);
	Bit#(8) be = truncate(b>>7);
	Bit#(7) as = truncate(a);
	Bit#(7) bs = truncate(b);
	BFloat16 fa = BFloat16{sign: asign, exp: ae, sfd: as};
	BFloat16 fb = BFloat16{sign: bsign, exp: be, sfd: bs};
	BFloat16 fm = fa + fb;

	//outQ.enq( {fm.sign?1:0,fm.exp,fm.sfd} );
	latencyQs[0].enq( {fm.sign?1:0,fm.exp,fm.sfd} );
`else
		fp_add.enqa(a);
		fp_add.enqb(b);
`endif
	endmethod
	method Action deq;
		outQ.deq;
	endmethod
	method Bit#(16) first;
		return outQ.first;
	endmethod
endmodule

module mkBfMult16 (FpPairIfc#(16));
	Clock curClk <- exposeCurrentClock;
	Reset curRst <- exposeCurrentReset;

	FIFO#(Bit#(16)) outQ <- mkFIFO;
`ifdef BSIM
	Vector#(MultLatency16, FIFO#(Bit#(16))) latencyQs <- replicateM(mkFIFO);
	for (Integer i = 0; i < valueOf(MultLatency16)-1; i=i+1 ) begin
		rule relay;
			latencyQs[i].deq;
			latencyQs[i+1].enq(latencyQs[i].first);
		endrule
	end
	rule relayOut;
		Integer lastIdx = valueOf(MultLatency16)-1;
		latencyQs[lastIdx].deq;
		outQ.enq(latencyQs[lastIdx].first);
	endrule
`else
	FpPairImportIfc#(16) fp_mult <- mkBfMultImport16(curClk, curRst);
	rule getOut;
		let v <- fp_mult.get;
		outQ.enq(v);
	endrule
`endif

	method Action enq(Bit#(16) a, Bit#(16) b);
`ifdef BSIM
	Bool asign = a[15] == 1;
	Bool bsign = b[15] == 1;
	Bit#(8) ae = truncate(a>>7);
	Bit#(8) be = truncate(b>>7);
	Bit#(7) as = truncate(a);
	Bit#(7) bs = truncate(b);
	BFloat16 fa = BFloat16{sign: asign, exp: ae, sfd: as};
	BFloat16 fb = BFloat16{sign: bsign, exp: be, sfd: bs};
	BFloat16 fm = fa * fb;
	//outQ.enq( {fm.sign?1:0,fm.exp,fm.sfd} );
	latencyQs[0].enq( {fm.sign?1:0,fm.exp,fm.sfd} );
`else
		fp_mult.enqa(a);
		fp_mult.enqb(b);
`endif
	endmethod
	method Action deq;
		outQ.deq;
	endmethod
	method Bit#(16) first;
		return outQ.first;
	endmethod
endmodule


(* synthesize *)
module mkBfDiv16 (FpPairIfc#(16));
	Clock curClk <- exposeCurrentClock;
	Reset curRst <- exposeCurrentReset;

	FIFO#(Bit#(16)) outQ <- mkFIFO;
`ifdef BSIM
	Vector#(DivLatency16, FIFO#(Bit#(16))) latencyQs <- replicateM(mkFIFO);
	for (Integer i = 0; i < valueOf(DivLatency16)-1; i=i+1 ) begin
		rule relay;
			latencyQs[i].deq;
			latencyQs[i+1].enq(latencyQs[i].first);
		endrule
	end
	rule relayOut;
		Integer lastIdx = valueOf(DivLatency16)-1;
		latencyQs[lastIdx].deq;
		outQ.enq(latencyQs[lastIdx].first);
	endrule
`else
	FpPairImportIfc#(16) fp_div <- mkBfDivImport16(curClk, curRst);
	rule getOut;
		let v <- fp_div.get;
		outQ.enq(v);
	endrule
`endif

	method Action enq(Bit#(16) a, Bit#(16) b);
`ifdef BSIM
    /* FIXME. This is the same bug as the one in "mkBfDiv64". Again, we fixed it with bdpi.
	Bool asign = a[15] == 1;
	Bool bsign = b[15] == 1;
	Bit#(8) ae = truncate(a>>7);
	Bit#(8) be = truncate(b>>7);
	Bit#(7) as = truncate(a);
	Bit#(7) bs = truncate(b);
	BFloat16 fa = BFloat{sign: asign, exp: ae, sfd: as};
	BFloat16 fb = BFloat{sign: bsign, exp: be, sfd: bs};
	BFloat16 fm = fa / fb;
	//outQ.enq( {fm.sign?1:0,fm.exp,fm.sfd} );
	latencyQs[0].enq( {fm.sign?1:0,fm.exp,fm.sfd} );
    */
	latencyQs[0].enq( bdpi_divisor_bfloat(a,b) );
`else
		fp_div.enqa(a);
		fp_div.enqb(b);
`endif
	endmethod
	method Action deq;
		outQ.deq;
	endmethod
	method Bit#(16) first;
		return outQ.first;
	endmethod
endmodule

module mkBfFma16 (FpThreeOpIfc#(16));
	Clock curClk <- exposeCurrentClock;
	Reset curRst <- exposeCurrentReset;

	FIFO#(Bit#(16)) outQ <- mkFIFO;
`ifdef BSIM
	Vector#(FmaLatency16, FIFO#(Bit#(16))) latencyQs <- replicateM(mkFIFO);
	for (Integer i = 0; i < valueOf(FmaLatency16)-1; i=i+1 ) begin
		rule relay;
			latencyQs[i].deq;
			latencyQs[i+1].enq(latencyQs[i].first);
		endrule
	end
	rule relayOut;
		Integer lastIdx = valueOf(FmaLatency16)-1;
		latencyQs[lastIdx].deq;
		outQ.enq(latencyQs[lastIdx].first);
	endrule
`else
	FpThreeOpImportIfc#(16) fp_fma <- mkBfFmaImport16(curClk, curRst);
	rule getOut;
		let v <- fp_fma.get;
		outQ.enq(v);
	endrule
`endif

	method Action enq(Bit#(16) a, Bit#(16) b, Bit#(16) c, Bool addition);
`ifdef BSIM
	Bool asign = a[15] == 1;
	Bool bsign = b[15] == 1;
	Bool csign = c[15] == 1;
	Bit#(8) ae = truncate(a>>7);
	Bit#(8) be = truncate(b>>7);
	Bit#(8) ce = truncate(c>>7);
	Bit#(7) as = truncate(a);
	Bit#(7) bs = truncate(b);
	Bit#(7) cs = truncate(c);
	BFloat16 fa = BFloat16{sign: asign, exp: ae, sfd: as};
	BFloat16 fb = BFloat16{sign: bsign, exp: be, sfd: bs};
	BFloat16 fc = BFloat16{sign: csign, exp: ce, sfd: cs};
	BFloat16 fm = fa * fb;
	if ( addition ) fm = fm + fc;
	else fm = fm - fc;
	//outQ.enq( {fm.sign?1:0,fm.exp,fm.sfd} );
	latencyQs[0].enq( {fm.sign?1:0,fm.exp,fm.sfd} );
`else
		fp_fma.enqa(a);
		fp_fma.enqb(b);
		fp_fma.enqc(c);
		fp_fma.enqop(addition?0:1); // addition, subtract
`endif
	endmethod
	method Action deq;
		outQ.deq;
	endmethod
	method Bit#(16) first;
		return outQ.first;
	endmethod
endmodule

endpackage: BFloat16
