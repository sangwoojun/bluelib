package Float32;

import Vector::*;
import FIFO::*;
import FloatingPoint::*;

typedef 7 MultLatency32;
typedef 12 AddLatency32;
typedef 12 SubLatency32;
typedef 29 DivLatency32;

interface FpPairImportIfc#(numeric type width);
	method Action enqa(Bit#(width) a);
	method Action enqb(Bit#(width) b);
	method ActionValue#(Bit#(width)) get;
endinterface

interface FpPairImportIfc32;
	method Action enqa(Bit#(32) a);
	method Action enqb(Bit#(32) b);
	method ActionValue#(Bit#(32)) get;
endinterface

interface FpPairIfc#(numeric type width);
	method Action enq(Bit#(width) a, Bit#(width) b);
	method Action deq;
	method Bit#(width) first;
endinterface

import "BVI" fp_sub32 =
module mkFpSubImport32#(Clock aclk, Reset arst) (FpPairImportIfc#(32));
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
import "BVI" fp_add32 =
module mkFpAddImport32#(Clock aclk, Reset arst) (FpPairImportIfc#(32));
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
import "BVI" fp_mult32 =
module mkFpMultImport32#(Clock aclk, Reset arst) (FpPairImportIfc#(32));
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
import "BVI" fp_div32 =
module mkFpDivImport32#(Clock aclk, Reset arst) (FpPairImportIfc#(32));
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

module mkFpSub32 (FpPairIfc#(32));
	Clock curClk <- exposeCurrentClock;
	Reset curRst <- exposeCurrentReset;

	FIFO#(Bit#(32)) outQ <- mkFIFO;
`ifdef BSIM
	Vector#(SubLatency32, FIFO#(Bit#(32))) latencyQs <- replicateM(mkFIFO);
	for (Integer i = 0; i < valueOf(SubLatency32)-1; i=i+1 ) begin
		rule relay;
			latencyQs[i].deq;
			latencyQs[i+1].enq(latencyQs[i].first);
		endrule
	end
	rule relayOut;
		Integer lastIdx = valueOf(SubLatency32)-1;
		latencyQs[lastIdx].deq;
		outQ.enq(latencyQs[lastIdx].first);
	endrule
`else
	FpPairImportIfc#(32) fp_sub <- mkFpSubImport32(curClk, curRst);
	rule getOut;
		let v <- fp_sub.get;
		outQ.enq(v);
	endrule
`endif

	method Action enq(Bit#(32) a, Bit#(32) b);
`ifdef BSIM
	Bool asign = a[31] == 1;
	Bool bsign = a[31] == 1;
	Bit#(8) ae = truncate(a>>23);
	Bit#(8) be = truncate(b>>23);
	Bit#(23) as = truncate(a);
	Bit#(23) bs = truncate(b);
	Float fa = Float{sign: asign, exp: ae, sfd: as};
	Float fb = Float{sign: bsign, exp: be, sfd: bs};
	Float fm = fa - fb;
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
	method Bit#(32) first;
		return outQ.first;
	endmethod
endmodule


module mkFpAdd32 (FpPairIfc#(32));
	Clock curClk <- exposeCurrentClock;
	Reset curRst <- exposeCurrentReset;

	FIFO#(Bit#(32)) outQ <- mkFIFO;
`ifdef BSIM
	Vector#(AddLatency32, FIFO#(Bit#(32))) latencyQs <- replicateM(mkFIFO);
	for (Integer i = 0; i < valueOf(AddLatency32)-1; i=i+1 ) begin
		rule relay;
			latencyQs[i].deq;
			latencyQs[i+1].enq(latencyQs[i].first);
		endrule
	end
	rule relayOut;
		Integer lastIdx = valueOf(AddLatency32)-1;
		latencyQs[lastIdx].deq;
		outQ.enq(latencyQs[lastIdx].first);
	endrule
`else
	FpPairImportIfc#(32) fp_add <- mkFpAddImport32(curClk, curRst);
	rule getOut;
		let v <- fp_add.get;
		outQ.enq(v);
	endrule
`endif

	method Action enq(Bit#(32) a, Bit#(32) b);
`ifdef BSIM
	Bool asign = a[31] == 1;
	Bool bsign = a[31] == 1;
	Bit#(8) ae = truncate(a>>23);
	Bit#(8) be = truncate(b>>23);
	Bit#(23) as = truncate(a);
	Bit#(23) bs = truncate(b);
	Float fa = Float{sign: asign, exp: ae, sfd: as};
	Float fb = Float{sign: bsign, exp: be, sfd: bs};
	Float fm = fa + fb;

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
	method Bit#(32) first;
		return outQ.first;
	endmethod
endmodule

module mkFpMult32 (FpPairIfc#(32));
	Clock curClk <- exposeCurrentClock;
	Reset curRst <- exposeCurrentReset;

	FIFO#(Bit#(32)) outQ <- mkFIFO;
`ifdef BSIM
	Vector#(MultLatency32, FIFO#(Bit#(32))) latencyQs <- replicateM(mkFIFO);
	for (Integer i = 0; i < valueOf(MultLatency32)-1; i=i+1 ) begin
		rule relay;
			latencyQs[i].deq;
			latencyQs[i+1].enq(latencyQs[i].first);
		endrule
	end
	rule relayOut;
		Integer lastIdx = valueOf(MultLatency32)-1;
		latencyQs[lastIdx].deq;
		outQ.enq(latencyQs[lastIdx].first);
	endrule
`else
	FpPairImportIfc#(32) fp_mult <- mkFpMultImport32(curClk, curRst);
	rule getOut;
		let v <- fp_mult.get;
		outQ.enq(v);
	endrule
`endif

	method Action enq(Bit#(32) a, Bit#(32) b);
`ifdef BSIM
	Bool asign = a[31] == 1;
	Bool bsign = a[31] == 1;
	Bit#(8) ae = truncate(a>>23);
	Bit#(8) be = truncate(b>>23);
	Bit#(23) as = truncate(a);
	Bit#(23) bs = truncate(b);
	Float fa = Float{sign: asign, exp: ae, sfd: as};
	Float fb = Float{sign: bsign, exp: be, sfd: bs};
	Float fm = fa * fb;
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
	method Bit#(32) first;
		return outQ.first;
	endmethod
endmodule

module mkFpDiv32 (FpPairIfc#(32));
	Clock curClk <- exposeCurrentClock;
	Reset curRst <- exposeCurrentReset;

	FIFO#(Bit#(32)) outQ <- mkFIFO;
`ifdef BSIM
	Vector#(MultLatency32, FIFO#(Bit#(32))) latencyQs <- replicateM(mkFIFO);
	for (Integer i = 0; i < valueOf(MultLatency32)-1; i=i+1 ) begin
		rule relay;
			latencyQs[i].deq;
			latencyQs[i+1].enq(latencyQs[i].first);
		endrule
	end
	rule relayOut;
		Integer lastIdx = valueOf(MultLatency32)-1;
		latencyQs[lastIdx].deq;
		outQ.enq(latencyQs[lastIdx].first);
	endrule
`else
	FpPairImportIfc#(32) fp_div <- mkFpDivImport32(curClk, curRst);
	rule getOut;
		let v <- fp_div.get;
		outQ.enq(v);
	endrule
`endif

	method Action enq(Bit#(32) a, Bit#(32) b);
`ifdef BSIM
	Bool asign = a[31] == 1;
	Bool bsign = a[31] == 1;
	Bit#(8) ae = truncate(a>>23);
	Bit#(8) be = truncate(b>>23);
	Bit#(23) as = truncate(a);
	Bit#(23) bs = truncate(b);
	Float fa = Float{sign: asign, exp: ae, sfd: as};
	Float fb = Float{sign: bsign, exp: be, sfd: bs};
	Float fm = fa / fb;
	//outQ.enq( {fm.sign?1:0,fm.exp,fm.sfd} );
	latencyQs[0].enq( {fm.sign?1:0,fm.exp,fm.sfd} );
`else
		fp_div.enqa(a);
		fp_div.enqb(b);
`endif
	endmethod
	method Action deq;
		outQ.deq;
	endmethod
	method Bit#(32) first;
		return outQ.first;
	endmethod
endmodule


endpackage: Float32
