import BLRadix::*;
import Vector::*;

import "BDPI" function ActionValue#(Bit#(32)) bdpi_readinput(Bit#(32) addr);
import "BDPI" function Action bdpi_writeoutput(Bit#(32) addr, Bit#(32) data);
import "BDPI" function Action bdpi_verify(Bit#(32) cnt, Bit#(32) cycles);


module mkSimTop(Empty);
	//BLRadixIfc#(10,3,4,Bit#(32),24,7) radixSub <- mkBLRadixSub(8);
	BLRadixIfc#(10,3,4,Bit#(32),24,7) radixSub <- mkBLRadix;
	Reg#(Bit#(32)) dataInputCounter <- mkReg(0);

	Integer dataCnt = 1024*1024;
	rule inputData(dataInputCounter<fromInteger(dataCnt));
		dataInputCounter <= dataInputCounter + 1;
		Vector#(4,Bit#(32)) ind;
		ind[0] <- bdpi_readinput(dataInputCounter*4);
		ind[1] <- bdpi_readinput(dataInputCounter*4+1);
		ind[2] <- bdpi_readinput(dataInputCounter*4+2);
		ind[3] <- bdpi_readinput(dataInputCounter*4+3);
		radixSub.enq(ind);

		if ( dataInputCounter + 1 >= fromInteger(dataCnt) ) begin
			radixSub.flush();
			//bdpi_verify(fromInteger(dataCnt));
		end
	endrule

	Reg#(Bit#(32)) burstTotal <- mkReg(0);
	rule flushBurstReady;
		let d <- radixSub.burstReady;
		burstTotal <= burstTotal + zeroExtend(d);
		if ( burstTotal > 0 ) begin
			//$write("Bursting %d -> %d\n", d, burstTotal );
			//bdpi_verify(burstTotal);
		end
	endrule


	Reg#(Bit#(32)) cycleCounter <- mkReg(0);
	rule incCycle;
		cycleCounter <= cycleCounter + 1;
	endrule

	Reg#(Bit#(32)) dataOutputCounter <- mkReg(0);
	rule readOutput;
		Vector#(4,Bit#(32)) outd = radixSub.first;
		radixSub.deq;
		bdpi_writeoutput(dataOutputCounter*4, outd[0]);
		bdpi_writeoutput(dataOutputCounter*4+1, outd[1]);
		bdpi_writeoutput(dataOutputCounter*4+2, outd[2]);
		bdpi_writeoutput(dataOutputCounter*4+3, outd[3]);
		dataOutputCounter <= dataOutputCounter + 1;
		if ( dataOutputCounter + 1 >= fromInteger(dataCnt)-128 ) begin
			bdpi_verify(dataOutputCounter, cycleCounter);

		end
	endrule
endmodule
