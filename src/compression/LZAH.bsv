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
	
	Reg#(Bit#(trsz)) bodyInLeft <- mkReg(0);
	Reg#(Bit#(trsz)) bodyInOffset <- mkReg(0);
	Reg#(Bit#(tbsz)) bodyInBuffer <- mkReg(0);

	rule getHeader ( headerLeft == 0 );
		headerLeft <= fromInteger(tSize);
		headerBitMap <= inQ.first;
		inQ.deq;

		bodyInOffset <= 0;
		bodyInLeft <= 0;
	endrule

	
	BLShiftIfc#(Bit#(tbsz), trsz, 2) shifter <- mkPipelinedShift(True);
	FIFO#(Bool) isHashHitQ <- mkSizedFIFO(valueOf(trsz)/2 + 1);

	rule relayBody ( headerLeft != 0 );
		let bbuf = bodyInBuffer;
		let bl = bodyInLeft;
		let bo = bodyInOffset;
		if ( bodyInLeft < fromInteger(tSize) ) begin
			bbuf = {inQ.first, truncate(bodyInBuffer>>tSize)};
			bl = bodyInLeft + fromInteger(tSize);
			bo = bodyInOffset - fromInteger(tSize);
			inQ.deq;

			bodyInBuffer <= bbuf;
		end

		if ( headerBitMap[0] == 1 ) begin // hash match
			shifter.enq(bodyInBuffer, bo);

			bo = bo + fromInteger(hSize);
			bl = bl - fromInteger(hSize);
			isHashHitQ.enq(True);

		end else begin // verbatim
			shifter.enq(bodyInBuffer, bo);

			bo = bo + fromInteger(tSize);
			bl = bl - fromInteger(tSize);
			isHashHitQ.enq(False);
		end

		bodyInLeft <= bl;
		
		headerLeft <= headerLeft - 1;
		headerBitMap <= (headerBitMap>>1);
	endrule

	FIFO#(Tuple2#(Bool,Bit#(tsz))) verbatimQ <- mkFIFO;
	rule procShifted;
		let sd = shifter.first;
		shifter.deq;
		let hit = isHashHitQ.first;
		isHashHitQ.deq;

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
		
		outQ.enq(vv);

		let hash = calcHash16(vv);
		hashtable.portA.request.put(BRAMRequest{write:True, responseOnWrite:False, address: truncate(hash), datain:vv});
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
