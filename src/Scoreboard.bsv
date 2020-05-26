import Vector::*;
import FIFOF::*;

interface ScoreboardIfc#(numeric type cnt, type dt);
	method Action enq(dt data);
	method Action deq;
	method Bool search1(dt data);
	method Bool search2(dt data);
endinterface

function Bit#(cntsz) wrapinc(Bit#(cntsz) idx, Integer cnt);
	Bit#(TAdd#(1,cntsz)) p1 = zeroExtend(idx) + 1;
	if ( p1 >= fromInteger(cnt) ) p1 = 0;
	return truncate(p1);
endfunction

module mkScoreboard(ScoreboardIfc#(cnt, dt))
	provisos(Log#(cnt, cntsz), Bits#(dt,dtsz),
		Eq#(dt), Literal#(dt));
	Integer icnt = valueOf(cnt);

	Vector#(cnt, Reg#(dt)) datav <- replicateM(mkReg(0));
	Reg#(Bit#(cntsz)) enqoff <- mkReg(0);
	Reg#(Bit#(cntsz)) deqoff <- mkReg(0);

	Wire#(Bit#(1)) enqreq <- mkDWire(0);
	Wire#(dt) enqdata <- mkDWire(0);
	Wire#(Bit#(1)) deqreq <- mkDWire(0);

	function Bool searchv(dt q);
		Bool ret = False;
		if ( q != 0 ) begin
			for (Integer i = 0; i < icnt; i=i+1) begin
				if ( datav[i] == q )  begin
					if ( enqoff > deqoff && fromInteger(i) < enqoff && fromInteger(i) >= deqoff ) ret = True;
					if ( enqoff < deqoff && (fromInteger(i) < enqoff || fromInteger(i) >= deqoff) ) ret = True;
				end
			end
		end
		return ret;
	endfunction

	rule normalize;
		let doff = deqoff;
		let eoff = enqoff;
		if ( deqreq != 0 ) begin
			doff = wrapinc(deqoff, icnt);
			deqoff <= doff;
			//$display( "- %x %x -- %x", eoff, doff, datav[deqoff] );
		end
		if ( enqreq != 0 ) begin
			eoff = wrapinc(enqoff, icnt);
			enqoff <= eoff;
			datav[enqoff] <= enqdata;
			//$display( "+ %x %x -- %x", eoff, doff, enqdata );
		end
		//for ( Integer i = 0; i < icnt; i=i+1 ) $write ( "%x ", datav[i] );
		//$display("");
	endrule

	method Action enq(dt data) if ( deqoff != wrapinc(enqoff, icnt) );
		enqreq <= 1;
		enqdata <= data;
	endmethod
	method Action deq if ( deqoff != enqoff );
		deqreq <= 1;
	endmethod
	method Bool search1(dt data);
		return searchv(data);
	endmethod
	method Bool search2(dt data);
		return searchv(data);
	endmethod
endmodule

