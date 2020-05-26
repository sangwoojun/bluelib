package BLDivisor;

import Vector::*;
import FIFO::*;

typedef 34 IDivLatency32;
import "BDPI" function Bit#(32) bdpi_divisor(Bit#(32) dividend, Bit#(32) divisor);
import "BDPI" function Bit#(32) bdpi_divisor_remainder(Bit#(32) dividend, Bit#(32) divisor);

interface UDivImportIfc#(numeric type width);
	method Action put_dividend(Bit#(width) dividend);
	method Action put_divisor(Bit#(width) divisor);
	method Bit#(TMul#(2,width)) get;
endinterface
interface UDivIfc#(numeric type width);
	method Action put(Bit#(width) dividend, Bit#(width) divisor);
	method ActionValue#(Tuple2#(Bit#(32), Bit#(32))) get;
endinterface


import "BVI" udiv32 =
module mkUDivImport32#(Clock aclk, Reset arst) (UDivImportIfc#(32));
	default_clock no_clock;
	default_reset no_reset;

	input_clock (aclk) = aclk;
	method m_axis_dout_tdata get ready(m_axis_dout_tvalid) clocked_by(aclk);
	method put_divisor(s_axis_divisor_tdata) enable(s_axis_divisor_tvalid) clocked_by(aclk);
	method put_dividend(s_axis_dividend_tdata) enable(s_axis_dividend_tvalid) clocked_by(aclk);
	schedule (
		get, put_dividend, put_divisor
	) CF (
		get, put_dividend, put_divisor
	);
endmodule


module mkUDiv32(UDivIfc#(32));
	Clock curClk <- exposeCurrentClock;
	Reset curRst <- exposeCurrentReset;
`ifdef BSIM
	Vector#(IDivLatency32, FIFO#(Tuple2#(Bit#(32),Bit#(32)))) latencyQs <- replicateM(mkFIFO);
	for (Integer i = 0; i < valueOf(IDivLatency32)-1; i=i+1 ) begin
		rule relay;
			latencyQs[i].deq;
			latencyQs[i+1].enq(latencyQs[i].first);
		endrule
	end
	method Action put(Bit#(32) dividend, Bit#(32) divisor);
		latencyQs[0].enq(tuple2(dividend, divisor));
	endmethod
	method ActionValue#(Tuple2#(Bit#(32), Bit#(32))) get;
		latencyQs[valueOf(IDivLatency32)-1].deq;
		let v = latencyQs[valueOf(IDivLatency32)-1].first;

		return tuple2(
			bdpi_divisor(tpl_1(v), tpl_2(v)),
			bdpi_divisor_remainder(tpl_1(v), tpl_2(v))
		);
	endmethod
`else
	UDivImportIfc#(32) di <- mkUDivImport32(curClk, curRst);
	method Action put(Bit#(32) dividend, Bit#(32) divisor);
		di.put_dividend(dividend);
		di.put_divisor(divisor);
	endmethod
	method ActionValue#(Tuple2#(Bit#(32), Bit#(32))) get;
		let r = di.get;
		return tuple2(r[63:32],r[31:0]); // quotient, remainder
	endmethod
`endif


endmodule

endpackage: BLDivisor
