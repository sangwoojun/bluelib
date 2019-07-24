package Float64;

import Vector::*;
import FIFO::*;
import FloatingPoint::*;
import Float32::*;

import "BDPI" function Bit#(64) bdpi_sqrt64(Bit#(64) data);

typedef 16 MultLatency64;
typedef 15 AddLatency64;
typedef 15 SubLatency64;
typedef 58 DivLatency64;
typedef 58 SqrtLatency64;



/*
interface FpPairImportIfc64;
	method Action enqa(Bit#(64) a);
	method Action enqb(Bit#(64) b);
	method ActionValue#(Bit#(64)) get;
endinterface
interface FpPairIfc;
	method Action enq(Bit#(64) a, Bit#(64) b);
	method Action deq;
	method Bit#(64) first;
endinterface
*/

import "BVI" fp_sub64 =
module mkFpSubImport64#(Clock aclk, Reset arst) (FpPairImportIfc#(64));
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
import "BVI" fp_add64 =
module mkFpAddImport64#(Clock aclk, Reset arst) (FpPairImportIfc#(64));
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
import "BVI" fp_mult64 =
module mkFpMultImport64#(Clock aclk, Reset arst) (FpPairImportIfc#(64));
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
import "BVI" fp_div64 =
module mkFpDivImport64#(Clock aclk, Reset arst) (FpPairImportIfc#(64));
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
import "BVI" fp_sqrt64 =
module mkFpSqrtImport64#(Clock aclk, Reset arst) (FpFilterImportIfc#(64));
	default_clock no_clock;
	default_reset no_reset;

	input_clock (aclk) = aclk;
	method m_axis_result_tdata get enable(m_axis_result_tready) ready(m_axis_result_tvalid) clocked_by(aclk);
	method enq(s_axis_a_tdata) enable(s_axis_a_tvalid) ready(s_axis_a_tready) clocked_by(aclk);
  
	schedule (
		get, enq
	) CF (
		get, enq
	);
endmodule

module mkFpSub64 (FpPairIfc#(64));
	Clock curClk <- exposeCurrentClock;
	Reset curRst <- exposeCurrentReset;

	FIFO#(Bit#(64)) outQ <- mkFIFO;
`ifdef BSIM
	Vector#(SubLatency64, FIFO#(Bit#(64))) latencyQs <- replicateM(mkFIFO);
	for (Integer i = 0; i < valueOf(SubLatency64)-1; i=i+1 ) begin
		rule relay;
			latencyQs[i].deq;
			latencyQs[i+1].enq(latencyQs[i].first);
		endrule
	end
	rule relayOut;
		Integer lastIdx = valueOf(SubLatency64)-1;
		latencyQs[lastIdx].deq;
		outQ.enq(latencyQs[lastIdx].first);
	endrule
`else
	FpPairImportIfc#(64) fp_sub <- mkFpSubImport64(curClk, curRst);
	rule getOut;
		let v <- fp_sub.get;
		outQ.enq(v);
	endrule
`endif

	method Action enq(Bit#(64) a, Bit#(64) b);
`ifdef BSIM
	Bool asign = a[63] == 1;
	Bool bsign = b[63] == 1;
	Bit#(11) ae = truncate(a>>52);
	Bit#(11) be = truncate(b>>52);
	Bit#(52) as = truncate(a);
	Bit#(52) bs = truncate(b);
	Double fa = Double{sign: asign, exp: ae, sfd: as};
	Double fb = Double{sign: bsign, exp: be, sfd: bs};
	Double fm = fa - fb;
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
	method Bit#(64) first;
		return outQ.first;
	endmethod
endmodule


module mkFpAdd64 (FpPairIfc#(64));
	Clock curClk <- exposeCurrentClock;
	Reset curRst <- exposeCurrentReset;

	FIFO#(Bit#(64)) outQ <- mkFIFO;
`ifdef BSIM
	Vector#(AddLatency64, FIFO#(Bit#(64))) latencyQs <- replicateM(mkFIFO);
	for (Integer i = 0; i < valueOf(AddLatency64)-1; i=i+1 ) begin
		rule relay;
			latencyQs[i].deq;
			latencyQs[i+1].enq(latencyQs[i].first);
		endrule
	end
	rule relayOut;
		Integer lastIdx = valueOf(AddLatency64)-1;
		latencyQs[lastIdx].deq;
		outQ.enq(latencyQs[lastIdx].first);
	endrule
`else
	FpPairImportIfc#(64) fp_add <- mkFpAddImport64(curClk, curRst);
	rule getOut;
		let v <- fp_add.get;
		outQ.enq(v);
	endrule
`endif

	method Action enq(Bit#(64) a, Bit#(64) b);
`ifdef BSIM
	Bool asign = a[63] == 1;
	Bool bsign = b[63] == 1;
	Bit#(11) ae = truncate(a>>52);
	Bit#(11) be = truncate(b>>52);
	Bit#(52) as = truncate(a);
	Bit#(52) bs = truncate(b);
	Double fa = Double{sign: asign, exp: ae, sfd: as};
	Double fb = Double{sign: bsign, exp: be, sfd: bs};
	Double fm = fa + fb;

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
	method Bit#(64) first;
		return outQ.first;
	endmethod
endmodule

module mkFpMult64 (FpPairIfc#(64));
	Clock curClk <- exposeCurrentClock;
	Reset curRst <- exposeCurrentReset;

	FIFO#(Bit#(64)) outQ <- mkFIFO;
`ifdef BSIM
	Vector#(MultLatency64, FIFO#(Bit#(64))) latencyQs <- replicateM(mkFIFO);
	for (Integer i = 0; i < valueOf(MultLatency64)-1; i=i+1 ) begin
		rule relay;
			latencyQs[i].deq;
			latencyQs[i+1].enq(latencyQs[i].first);
		endrule
	end
	rule relayOut;
		Integer lastIdx = valueOf(MultLatency64)-1;
		latencyQs[lastIdx].deq;
		outQ.enq(latencyQs[lastIdx].first);
	endrule
`else
	FpPairImportIfc#(64) fp_mult <- mkFpMultImport64(curClk, curRst);
	rule getOut;
		let v <- fp_mult.get;
		outQ.enq(v);
	endrule
`endif

	method Action enq(Bit#(64) a, Bit#(64) b);
`ifdef BSIM
	Bool asign = a[63] == 1;
	Bool bsign = b[63] == 1;
	Bit#(11) ae = truncate(a>>52);
	Bit#(11) be = truncate(b>>52);
	Bit#(52) as = truncate(a);
	Bit#(52) bs = truncate(b);
	Double fa = Double{sign: asign, exp: ae, sfd: as};
	Double fb = Double{sign: bsign, exp: be, sfd: bs};
	Double fm = fa * fb;
	//outQ.enq( {fm.sign?1:0,fm.exp,fm.sfd} );
	latencyQs[0].enq( {fm.sign?1:0,fm.exp,fm.sfd} );
	$display( ">> %x %d %x", fa.sign?1:0, fa.exp, fa.sfd );
	$display( ">> %x %d %x", fb.sign?1:0, fb.exp, fb.sfd );
	$display( "%x %d %x", fm.sign?1:0, fm.exp, fm.sfd );
`else
		fp_mult.enqa(a);
		fp_mult.enqb(b);
`endif
	endmethod
	method Action deq;
		outQ.deq;
	endmethod
	method Bit#(64) first;
		return outQ.first;
	endmethod
endmodule

module mkFpDiv64 (FpPairIfc#(64));
	Clock curClk <- exposeCurrentClock;
	Reset curRst <- exposeCurrentReset;

	FIFO#(Bit#(64)) outQ <- mkFIFO;
`ifdef BSIM
	Vector#(DivLatency64, FIFO#(Bit#(64))) latencyQs <- replicateM(mkFIFO);
	for (Integer i = 0; i < valueOf(DivLatency64)-1; i=i+1 ) begin
		rule relay;
			latencyQs[i].deq;
			latencyQs[i+1].enq(latencyQs[i].first);
		endrule
	end
	rule relayOut;
		Integer lastIdx = valueOf(DivLatency64)-1;
		latencyQs[lastIdx].deq;
		outQ.enq(latencyQs[lastIdx].first);
	endrule
`else
	FpPairImportIfc#(64) fp_div <- mkFpDivImport64(curClk, curRst);
	rule getOut;
		let v <- fp_div.get;
		outQ.enq(v);
	endrule
`endif

	method Action enq(Bit#(64) a, Bit#(64) b);
`ifdef BSIM
	Bool asign = a[63] == 1;
	Bool bsign = b[63] == 1;
	Bit#(11) ae = truncate(a>>52);
	Bit#(11) be = truncate(b>>52);
	Bit#(52) as = truncate(a);
	Bit#(52) bs = truncate(b);
	Double fa = Double{sign: asign, exp: ae, sfd: as};
	Double fb = Double{sign: bsign, exp: be, sfd: bs};
	Double fm = fa / fb;
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
	method Bit#(64) first;
		return outQ.first;
	endmethod
endmodule

module mkFpSqrt64 (FpFilterIfc#(64));
	Clock curClk <- exposeCurrentClock;
	Reset curRst <- exposeCurrentReset;

	FIFO#(Bit#(64)) outQ <- mkFIFO;
`ifdef BSIM
	Vector#(SqrtLatency64, FIFO#(Bit#(64))) latencyQs <- replicateM(mkFIFO);
	for (Integer i = 0; i < valueOf(SqrtLatency64)-1; i=i+1 ) begin
		rule relay;
			latencyQs[i].deq;
			latencyQs[i+1].enq(latencyQs[i].first);
		endrule
	end
	rule relayOut;
		Integer lastIdx = valueOf(SqrtLatency64)-1;
		latencyQs[lastIdx].deq;
		outQ.enq(latencyQs[lastIdx].first);
	endrule
`else
	FpFilterImportIfc#(64) fp_sqrt <- mkFpSqrtImport64(curClk, curRst);
	rule getOut;
		let v <- fp_sqrt.get;
		outQ.enq(v);
	endrule
`endif

	method Action enq(Bit#(64) a);
`ifdef BSIM
	latencyQs[0].enq( bdpi_sqrt64(a) );
`else
		fp_sqrt.enq(a);
`endif
	endmethod
	method Action deq;
		outQ.deq;
	endmethod
	method Bit#(64) first;
		return outQ.first;
	endmethod
endmodule


endpackage: Float64
