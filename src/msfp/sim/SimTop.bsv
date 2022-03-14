import BLMacMSFP::*;
import Vector::*;

import "BDPI" function ActionValue#(Bit#(32)) bdpi_readinput(Bit#(32) addr);
import "BDPI" function Action bdpi_writeoutput(Bit#(64) data);

module mkSimTop(Empty);
	Reg#(Bit#(32)) inputCounter <- mkReg(0);
	//BLMacMSFP12Ifc pe <- mkBLMacMSFP12(53'h01abcb223c54a7d);
	BLMacMSFP12_3ChannelIfc pe <- mkBLMacMSFP12_3(53'h01abcb223c54a7d, 53'h01eccb634c5ae7d, 53'h01dc674c46d8c7a);
	rule insertInput(inputCounter < 1 );
		Bit#(32) pixelinput <- bdpi_readinput(inputCounter);
		Vector#(3,Bit#(8)) channel = unpack(truncate(pixelinput));
		Vector#(3,Vector#(3,Bit#(8))) channel3 = replicate(channel);
		pe.enq(channel3);
	endrule
	rule getOutput;
		let d = pe.first;
		pe.deq;
		bdpi_writeoutput(zeroExtend(pack(d)));
	endrule


//53'h00d6b5ad6b5ad7d
//53'h01bdef7bdef7b7a
endmodule
