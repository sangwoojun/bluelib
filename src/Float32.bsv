package Float32;

import Vector::*;
import FIFO::*;
import FloatingPoint::*;


import "BDPI" function Bit#(32) bdpi_sqrt32(Bit#(32) data);
import "BDPI" function Bit#(32) bdpi_sqrt_cube32(Bit#(32) data);
import "BDPI" function Bit#(32) bdpi_divisor_float(Bit#(32) a, Bit#(32) b);

typedef 7 MultLatency32;
typedef 12 AddLatency32;
typedef 12 SubLatency32;
typedef 29 DivLatency32;
typedef 29 SqrtLatency32;
typedef 19 FmaLatency32;
typedef 36 SqrtCubeLatency32;

interface FpFilterImportIfc#(numeric type width);
	method Action enq(Bit#(width) a);
	method ActionValue#(Bit#(width)) get;
endinterface

interface FpPairImportIfc#(numeric type width);
	method Action enqa(Bit#(width) a);
	method Action enqb(Bit#(width) b);
	method ActionValue#(Bit#(width)) get;
endinterface
interface FpThreeOpImportIfc#(numeric type width);
	method Action enqa(Bit#(width) a);
	method Action enqb(Bit#(width) b);
	method Action enqc(Bit#(width) c);
	method Action enqop(Bit#(8) op);
	method ActionValue#(Bit#(width)) get;
endinterface



interface FpFilterIfc#(numeric type width);
	method Action enq(Bit#(width) a);
	method Action deq;
	method Bit#(width) first;
endinterface
interface FpPairIfc#(numeric type width);
	method Action enq(Bit#(width) a, Bit#(width) b);
	method Action deq;
	method Bit#(width) first;
endinterface
interface FpThreeOpIfc#(numeric type width);
	method Action enq(Bit#(width) a, Bit#(width) b, Bit#(width) c, Bool addition);
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
import "BVI" fp_sqrt32 =
module mkFpSqrtImport32#(Clock aclk, Reset arst) (FpFilterImportIfc#(32));
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
import "BVI" fp_fma32 =
module mkFpFmaImport32#(Clock aclk, Reset arst) (FpThreeOpImportIfc#(32));
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
	Bool bsign = b[31] == 1;
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
	Bool bsign = b[31] == 1;
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
	Bool bsign = b[31] == 1;
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
	Vector#(DivLatency32, FIFO#(Bit#(32))) latencyQs <- replicateM(mkFIFO);
	for (Integer i = 0; i < valueOf(DivLatency32)-1; i=i+1 ) begin
		rule relay;
			latencyQs[i].deq;
			latencyQs[i+1].enq(latencyQs[i].first);
		endrule
	end
	rule relayOut;
		Integer lastIdx = valueOf(DivLatency32)-1;
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
    /* FIXME. This is the same bug as the one in "mkFpDiv64". Again, we fixed it with bdpi.
	Bool asign = a[31] == 1;
	Bool bsign = b[31] == 1;
	Bit#(8) ae = truncate(a>>23);
	Bit#(8) be = truncate(b>>23);
	Bit#(23) as = truncate(a);
	Bit#(23) bs = truncate(b);
	Float fa = Float{sign: asign, exp: ae, sfd: as};
	Float fb = Float{sign: bsign, exp: be, sfd: bs};
	Float fm = fa / fb;
	//outQ.enq( {fm.sign?1:0,fm.exp,fm.sfd} );
	latencyQs[0].enq( {fm.sign?1:0,fm.exp,fm.sfd} );
    */
	latencyQs[0].enq( bdpi_divisor_float(a,b) );
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

module mkFpSqrt32 (FpFilterIfc#(32));
	Clock curClk <- exposeCurrentClock;
	Reset curRst <- exposeCurrentReset;

	FIFO#(Bit#(32)) outQ <- mkFIFO;
`ifdef BSIM
	Vector#(SqrtLatency32, FIFO#(Bit#(32))) latencyQs <- replicateM(mkFIFO);
	for (Integer i = 0; i < valueOf(SqrtLatency32)-1; i=i+1 ) begin
		rule relay;
			latencyQs[i].deq;
			latencyQs[i+1].enq(latencyQs[i].first);
		endrule
	end
	rule relayOut;
		Integer lastIdx = valueOf(SqrtLatency32)-1;
		latencyQs[lastIdx].deq;
		outQ.enq(latencyQs[lastIdx].first);
	endrule
`else
	FpFilterImportIfc#(32) fp_sqrt <- mkFpSqrtImport32(curClk, curRst);
	rule getOut;
		let v <- fp_sqrt.get;
		outQ.enq(v);
	endrule
`endif

	method Action enq(Bit#(32) a);
`ifdef BSIM
	latencyQs[0].enq( bdpi_sqrt32(a) );
`else
		fp_sqrt.enq(a);
`endif
	endmethod
	method Action deq;
		outQ.deq;
	endmethod
	method Bit#(32) first;
		return outQ.first;
	endmethod
endmodule

module mkFpFma32 (FpThreeOpIfc#(32));
	Clock curClk <- exposeCurrentClock;
	Reset curRst <- exposeCurrentReset;

	FIFO#(Bit#(32)) outQ <- mkFIFO;
`ifdef BSIM
	Vector#(FmaLatency32, FIFO#(Bit#(32))) latencyQs <- replicateM(mkFIFO);
	for (Integer i = 0; i < valueOf(FmaLatency32)-1; i=i+1 ) begin
		rule relay;
			latencyQs[i].deq;
			latencyQs[i+1].enq(latencyQs[i].first);
		endrule
	end
	rule relayOut;
		Integer lastIdx = valueOf(FmaLatency32)-1;
		latencyQs[lastIdx].deq;
		outQ.enq(latencyQs[lastIdx].first);
	endrule
`else
	FpThreeOpImportIfc#(32) fp_fma <- mkFpFmaImport32(curClk, curRst);
	rule getOut;
		let v <- fp_fma.get;
		outQ.enq(v);
	endrule
`endif

	method Action enq(Bit#(32) a, Bit#(32) b, Bit#(32) c, Bool addition);
`ifdef BSIM
	Bool asign = a[31] == 1;
	Bool bsign = b[31] == 1;
	Bool csign = c[31] == 1;
	Bit#(8) ae = truncate(a>>23);
	Bit#(8) be = truncate(b>>23);
	Bit#(8) ce = truncate(c>>23);
	Bit#(23) as = truncate(a);
	Bit#(23) bs = truncate(b);
	Bit#(23) cs = truncate(c);
	Float fa = Float{sign: asign, exp: ae, sfd: as};
	Float fb = Float{sign: bsign, exp: be, sfd: bs};
	Float fc = Float{sign: csign, exp: ce, sfd: cs};
	Float fm = fa * fb;
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
	method Bit#(32) first;
		return outQ.first;
	endmethod
endmodule

module mkFpSqrtCube32 (FpFilterIfc#(32));
	Clock curClk <- exposeCurrentClock;
	Reset curRst <- exposeCurrentReset;

	FIFO#(Bit#(32)) outQ <- mkFIFO;
`ifdef BSIM
	Vector#(SqrtCubeLatency32, FIFO#(Bit#(32))) latencyQs <- replicateM(mkFIFO);
	for (Integer i = 0; i < valueOf(SqrtCubeLatency32)-1; i=i+1 ) begin
		rule relay;
			latencyQs[i].deq;
			latencyQs[i+1].enq(latencyQs[i].first);
		endrule
	end
	rule relayOut;
		Integer lastIdx = valueOf(SqrtCubeLatency32)-1;
		latencyQs[lastIdx].deq;
		outQ.enq(latencyQs[lastIdx].first);
	endrule
`else
	FpFilterImportIfc#(32) fp_sqrt <- mkFpSqrtImport32(curClk, curRst);
	FIFO#(Bit#(32)) relayQ <- mkFIFO;
	FpPairImportIfc#(32) fp_mult <- mkFpMultImport32(curClk, curRst);
	rule getSqrt;
		let v <- fp_sqrt.get;
        let a = relayQ.first;
        relayQ.deq;
        fp_mult.enqa(v);
        fp_mult.enqb(a);
	endrule
	rule getOut;
		let v <- fp_mult.get;
		outQ.enq(v);
	endrule
`endif

	method Action enq(Bit#(32) a);
`ifdef BSIM
	latencyQs[0].enq( bdpi_sqrt_cube32(a) );
`else
		fp_sqrt.enq(a);
        relayQ.enq(a);
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
