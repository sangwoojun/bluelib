package LZAH;

import FIFO::*;
import FIFOF::*;
import Vector::*;
import BRAM::*;

import BLShifter::*;

function Bit#(16) calcHash16(Bit#(tsz) data);
	Bit#(16) curHash = 0;
	for ( Integer i = 0; i < valueOf(tsz); i=i+16) begin
		curHash = curHash ^ zeroExtend(data[7:0]) ^ zeroExtend(data[15:8]<<7);
		data = data >> 16;
	end
	return curHash;
endfunction

interface LZAHIfc#(numeric type tsz, numeric type hsz);
	method Action enq(Bit#(tsz) data);
	method Action deq;
	method Bit#(tsz) first;
endinterface

module mkLZAH(LZAHIfc#(tsz, hsz))
	provisos(Add#(32,a__,tsz), Add#(tsz,tsz,tbsz), Log#(tsz,tlsz), Add#(tlsz,1,trsz),
		Add#(1, b__, hsz),Add#(c__, hsz, 16),
		Add#(d__, hsz, tbsz),
		Add#(2, e__, trsz),
		Add#(1, f__, tbsz)
		
		);

	Integer tSize = valueOf(tsz);
	Integer hSize = valueOf(hsz);

    BRAM2Port#(Bit#(hsz), Bit#(tsz)) hashtable <- mkBRAM2Server(defaultValue); 

	Reg#(Bit#(tsz)) headerBitMap <- mkReg(0);
	Reg#(Bit#(trsz)) headerLeft <- mkReg(0);

	FIFO#(Bit#(tsz)) inQ <- mkFIFO;
	FIFO#(Bit#(tsz)) outQ <- mkFIFO;
	
	Reg#(Bit#(tbsz)) bodyInBuffer <- mkReg(0);
	Reg#(Bit#(trsz)) bodyInLeft <- mkReg(0);

	rule getHeader ( headerLeft == 0 );
		headerLeft <= fromInteger(tSize);
		headerBitMap <= inQ.first;
		inQ.deq;

		bodyInLeft <= 0;
		//$write("Header: %x\n", inQ.first);
	endrule

	BLShiftIfc#(Bit#(tbsz), trsz, 2) shifter <- mkPipelinedShift(True);
	FIFO#(Bool) isHashHitQ <- mkSizedFIFO(valueOf(trsz)/2 + 1);

	rule relayBody ( headerLeft != 0 );
		let bbuf = bodyInBuffer;
		if ( headerBitMap[0] == 1 ) begin // hash match
			if ( bodyInLeft < fromInteger(hSize) ) begin
				bodyInBuffer <= zeroExtend(inQ.first);
				bbuf = {inQ.first, truncate(bbuf)};
				inQ.deq;
				bodyInLeft <= bodyInLeft + fromInteger(tSize-hSize);
			end else begin
				bodyInLeft <= bodyInLeft - fromInteger(hSize); // never happens?
			end
			shifter.enq(bbuf, fromInteger(tSize)-bodyInLeft);
			isHashHitQ.enq(True);
		end else begin // verbatim
			if ( bodyInLeft < fromInteger(tSize) ) begin
				bodyInBuffer <= zeroExtend(inQ.first);
				bbuf = {inQ.first, truncate(bbuf)};
				inQ.deq;
				// bodyInLeft does not change
			end else begin
				bodyInLeft <= bodyInLeft - fromInteger(tSize); // never happens?
			end
			shifter.enq(bbuf, fromInteger(tSize)-bodyInLeft);
			isHashHitQ.enq(False);
		end

		headerLeft <= headerLeft - 1;
		headerBitMap <= (headerBitMap>>1);
	endrule

	FIFO#(Tuple2#(Bool,Bit#(tsz))) verbatimQ <- mkFIFO;
	rule procShifted;
		let sd = shifter.first;
		shifter.deq;
		let hit = isHashHitQ.first;
		isHashHitQ.deq;
			
		//$write("Hit: %s -- %x\n", hit? "yes" : "no", sd);


		verbatimQ.enq(tuple2(hit, truncate(sd)));
		if ( hit ) begin
			hashtable.portB.request.put(BRAMRequest{write:False, responseOnWrite:False, address: truncate(sd), datain: ?});
		end
	endrule

	rule procHashRead;
		verbatimQ.deq;
		let v = verbatimQ.first;
		let vv = tpl_2(v);
		if ( tpl_1(v) == True ) begin
			let v_ <- hashtable.portB.response.get;
			vv = v_;
		end
		
		//$write("Hit: %s -- %x\n", tpl_1(v)? "yes" : "no", vv);
		
		outQ.enq(vv);

		//if ( !tpl_1(v) ) begin
		let hash = calcHash16(vv);
		hashtable.portA.request.put(BRAMRequest{write:True, responseOnWrite:False, address: truncate(hash), datain:vv});
		//end
	endrule

	method Action enq(Bit#(tsz) data);
		inQ.enq(data);
	endmethod
	method Action deq;
		outQ.deq;
	endmethod
	method Bit#(tsz) first;
		return outQ.first;
	endmethod
endmodule

endpackage: LZAH
