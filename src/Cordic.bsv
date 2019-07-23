package Cordic;

interface CordicSinCosImportIfc;
	method Action enq(Bit#(16) data);
	method ActionValue#(Bit#(32)) get;
endinterface

interface CordicAtanImportIfc;
	method Action enq(Bit#(32) data);
	method ActionValue#(Bit#(16)) get;
endinterface

import "BVI" cordic_sincos =
module mkCordicSinCos#(Clock aclk, Reset arst) (CordicSinCosImportIfc);
	default_clock no_clock;
	default_reset no_reset;

	input_clock (aclk) = aclk;
	method m_axis_dout_tdata get ready(m_axis_dout_tvalid) clocked_by(aclk);

	method enq(s_axis_cartesian_tvalid) enable(s_axis_cartesian_tvalid) clocked_by(aclk);

	schedule (
		get
	) CF (
		enq
	);
endmodule




endpackage: Cordic
