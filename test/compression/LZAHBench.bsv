import FIFO::*;

import LZAH::*;

import "BDPI" function Bit#(129) bdpi_read_file(Bit#(32) offset);
import "BDPI" function Action bdpi_compare_file(Bit#(128) data, Bit#(32) offset);

module mkLZAHBench(Empty);
	LZAHIfc#(128, 10) lzah_decompressor <- mkLZAH128_10;

	Reg#(Bit#(32)) inputOffset <- mkReg(0);
	rule pushInput ( inputOffset < 1024*1024*16);
		Bit#(129) cdata = bdpi_read_file(inputOffset);
		if ( cdata[128] == 0 ) begin
			inputOffset <= inputOffset + 16;
			lzah_decompressor.enq(truncate(cdata));
		end else begin
			$write( "Benchmark done\n" );
			$finish;
		end
	endrule

	Reg#(Bit#(32)) outputOffset <- mkReg(0);
	rule getOutput;
		lzah_decompressor.deq;
		let ddata = lzah_decompressor.first;
		bdpi_compare_file(ddata, outputOffset);
		outputOffset <= outputOffset + 16;
	endrule
endmodule
	
