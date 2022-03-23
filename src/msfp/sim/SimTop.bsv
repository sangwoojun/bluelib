import BLMacMSFP::*;
import Vector::*;

import "BDPI" function ActionValue#(Bit#(32)) bdpi_readinput(Bit#(32) addr, Bit#(32) offset);
import "BDPI" function Action bdpi_writeoutput(Bit#(64) data);

module mkSimTop(Empty);
	Reg#(Bit#(32)) inputCounter <- mkReg(0);
	//BLMacMSFP12Ifc pe <- mkBLMacMSFP12(53'h01abcb223c54a7d);
	//BLMacMSFP12_3ChannelIfc pe <- mkBLMacMSFP12_3(53'h01abcb223c54a7d, 53'h01eccb634c5ae7d, 53'h01dc674c46d8c7a);


	// all ones
	BLMacMSFP12_3ChannelIfc pe <- mkBLMacMSFP12_3(53'h00842108421087f, 53'h00842108421087f, 53'h00842108421087f);

	rule insertInput(inputCounter < 1 );
		inputCounter <= inputCounter + 1;

		Bit#(32) pixelinput1 <- bdpi_readinput(inputCounter,0);
		Bit#(32) pixelinput2 <- bdpi_readinput(inputCounter,3);
		Bit#(32) pixelinput3 <- bdpi_readinput(inputCounter,6);
		Vector#(3,Bit#(8)) channel1 = unpack(truncate(pixelinput1));
		Vector#(3,Bit#(8)) channel2 = unpack(truncate(pixelinput2));
		Vector#(3,Bit#(8)) channel3 = unpack(truncate(pixelinput3));
		Vector#(3,Vector#(3,Bit#(8))) channels;
		channels[0] = channel1;
		channels[1] = channel2;
		channels[2] = channel3;
		pe.enq(channels);
	endrule

	Reg#(Bit#(32)) cycleCounter <- mkReg(0);
	rule incCycle;
		cycleCounter <= cycleCounter+1;
	endrule

	rule getOutput;
		let d = pe.first;
		pe.deq;
		bdpi_writeoutput(zeroExtend(pack(d)));
		$write( "Cycle: %d\n", cycleCounter );
	endrule

endmodule
