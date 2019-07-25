/*
WARNING: Due to fixed point representation limitations, SinCos takes input in radians, between ranges of -pi to +pi
Similarly, Atan also takes input in the range of -1 to +1
*/



package Cordic;

import Float32::*;
import FIFO::*;
import Vector::*;

import "BDPI" function Bit#(32) bdpi_sincos(Bit#(32) data);
import "BDPI" function Bit#(32) bdpi_atan(Bit#(32) x, Bit#(32) y);

typedef 16 CordicLatency16;

interface CordicSinCosImportIfc;
	method Action enq(Bit#(16) data);
	method ActionValue#(Bit#(32)) get;
endinterface

interface CordicAtanImportIfc;
	method Action enq(Bit#(32) data);
	method ActionValue#(Bit#(16)) get;
endinterface

interface CordicSinCosIfc;
	method Action enq(Bit#(16) data);
	method Action deq;
	method Tuple2#(Bit#(16), Bit#(16)) first;
endinterface

interface CordicAtanIfc;
	method Action enq(Bit#(16) x, Bit#(16) y);
	method Action deq;
	method Bit#(16) first;
endinterface

import "BVI" cordic_sincos =
module mkCordicSinCosImport#(Clock aclk, Reset arst) (CordicSinCosImportIfc);
	default_clock no_clock;
	default_reset no_reset;

	input_clock (aclk) = aclk;
	method m_axis_dout_tdata get enable(m_axis_dout_tready) ready(m_axis_dout_tvalid) clocked_by(aclk);

	method enq(s_axis_phase_tdata) enable(s_axis_phase_tvalid) ready(s_axis_phase_tready) clocked_by(aclk);
	
	schedule (
		get, enq
	) CF (
		get, enq
	);
endmodule

import "BVI" cordic_atan =
module mkCordicAtanImport#(Clock aclk, Reset arst) (CordicAtanImportIfc);
	default_clock no_clock;
	default_reset no_reset;

	input_clock (aclk) = aclk;
	method m_axis_dout_tdata get enable(m_axis_dout_tready) ready(m_axis_dout_tvalid) clocked_by(aclk);

	method enq(s_axis_cartesian_tdata) enable(s_axis_cartesian_tvalid) ready(s_axis_cartesian_tready) clocked_by(aclk);
	
	schedule (
		get, enq
	) CF (
		get, enq
	);
endmodule

module mkCordicSinCos (CordicSinCosIfc);
	Clock curClk <- exposeCurrentClock;
	Reset curRst <- exposeCurrentReset;
	FIFO#(Tuple2#(Bit#(16), Bit#(16))) outQ <- mkFIFO;

`ifdef BSIM
	Vector#(CordicLatency16, FIFO#(Bit#(32))) latencyQs <- replicateM(mkFIFO);
	for (Integer i = 0; i < valueOf(CordicLatency16)-1; i=i+1 ) begin
		rule relay;
			latencyQs[i].deq;
			latencyQs[i+1].enq(latencyQs[i].first);
		endrule
	end
	rule relayOut;
		Integer lastIdx = valueOf(CordicLatency16)-1;
		latencyQs[lastIdx].deq;
		let r = latencyQs[lastIdx].first;
		outQ.enq(tuple2(truncate(r>>16), truncate(r)));
	endrule
`else
	CordicSinCosImportIfc sincos <- mkCordicSinCosImport(curClk, curRst);
	rule getOut;
		let r <- sincos.get;
		outQ.enq(tuple2(truncate(r>>16), truncate(r)));
	endrule
`endif

	method Action enq(Bit#(16) data);
`ifdef BSIM
	latencyQs[0].enq(bdpi_sincos(zeroExtend(data)));
`else
	sincos.enq(data);
`endif
	endmethod
	method Action deq;
		outQ.deq;
	endmethod
	method Tuple2#(Bit#(16), Bit#(16)) first;
		return outQ.first;
	endmethod
endmodule

module mkCordicAtan (CordicAtanIfc);
	Clock curClk <- exposeCurrentClock;
	Reset curRst <- exposeCurrentReset;
	FIFO#(Bit#(16)) outQ <- mkFIFO;

`ifdef BSIM
	Vector#(CordicLatency16, FIFO#(Bit#(16))) latencyQs <- replicateM(mkFIFO);
	for (Integer i = 0; i < valueOf(CordicLatency16)-1; i=i+1 ) begin
		rule relay;
			latencyQs[i].deq;
			latencyQs[i+1].enq(latencyQs[i].first);
		endrule
	end
	rule relayOut;
		Integer lastIdx = valueOf(CordicLatency16)-1;
		latencyQs[lastIdx].deq;
		let r = latencyQs[lastIdx].first;
		outQ.enq(r);
	endrule
`else
	CordicAtanImportIfc atan <- mkCordicAtanImport(curClk, curRst);
	rule getOut;
		let r <- atan.get;
		outQ.enq(r);
	endrule
`endif

	method Action enq(Bit#(16) x, Bit#(16) y);
`ifdef BSIM
	latencyQs[0].enq(truncate(bdpi_atan(zeroExtend(x), zeroExtend(y))));
`else
	atan.enq({y,x});
`endif
	endmethod
	method Action deq;
		outQ.deq;
	endmethod
	method Bit#(16) first;
		return outQ.first;
	endmethod
endmodule

endpackage: Cordic
