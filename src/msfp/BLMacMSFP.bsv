package BLMacMSFP;

import FIFO::*;
import Vector::*;

typedef struct {
	Bit#(1) sign;
	Bit#(8) exponent;
	Bit#(7) mantissa;
} BFloat16 deriving(Eq,Bits);

typedef struct {
	Bit#(1) sign;
	Bit#(4) mantissa;
} MSFP12Frac deriving(Eq,Bits);

interface BLMacMSFP12_3ChannelIfc;
	method Action enq(Vector#(3,Vector#(3,Bit#(8))) pixels);
	method Vector#(3,BFloat16) first;
	method Action deq;
endinterface

module mkBLMacMSFP12_3#(Bit#(53) block1, Bit#(53) block2, Bit#(53) block3) (BLMacMSFP12_3ChannelIfc);
	Vector#(3,BLMacMSFP12Ifc) pev;
	pev[0] <- mkBLMacMSFP12(block1);
	pev[1] <- mkBLMacMSFP12(block2);
	pev[2] <- mkBLMacMSFP12(block3);
	
	Vector#(3,Int#(8)) nexp;
	Vector#(3, Int#(8)) expo;
	expo[0] = unpack(block1[7:0]-127);
	expo[1] = unpack(block2[7:0]-127);
	expo[2] = unpack(block3[7:0]-127);

	Int#(8) maxexp = -126;
	for ( Integer i = 0; i < 3; i=i+1 ) begin
		Int#(8) nexp_i = expo[i]-127;
		if ( nexp_i < 0 ) nexp_i = 0; // align to pixel input
		nexp_i = 2*nexp_i;
		nexp[i] = nexp_i;
		if ( maxexp < nexp_i ) maxexp = nexp_i;
	end
	
	FIFO#(Vector#(3,BFloat16)) sumQ <- mkFIFO;

	rule sumchannels;
		Vector#(3,Vector#(3, MSFP12Frac)) psum;
		for ( Integer i = 0; i < 3; i=i+1 ) begin
			pev[i].deq;
			psum[i] = pev[i].first;
		end
		
		Vector#(3,BFloat16) temps;
		for ( Integer col = 0; col < 3; col = col + 1) begin
			Bit#(1) sign = psum[0][col].sign;
			Int#(8) expdiff0 = maxexp-expo[0];
			Bit#(5) mantissa = zeroExtend(psum[0][col].mantissa>>expdiff0);

			for ( Integer i = 1; i < 3; i=i+1 ) begin
				Int#(8) expdiff = maxexp-expo[i];
				Bit#(5) nmantissa = (zeroExtend(psum[i][col].mantissa)>>expdiff);

				if ( psum[i][col].sign == sign ) begin
					mantissa = nmantissa + mantissa;
				end else if ( nmantissa > mantissa ) begin
					sign = ~sign;
					mantissa = nmantissa - mantissa;
				end else begin
					mantissa = mantissa - nmantissa;
				end
			end
			temps[col] = BFloat16 {
				sign: sign,
				mantissa:zeroExtend(mantissa)<<2, // 5 bits to 7 // semantics is different! Top 1 MSB bit....
				exponent: pack(maxexp)+127
			};
		end
		sumQ.enq(temps);

	endrule
	
	method Action enq(Vector#(3,Vector#(3,Bit#(8))) pixels);
		for (Integer i = 0; i < 3; i=i+1 ) begin
			pev[i].enq(pixels[i]);
		end
	endmethod
	method Vector#(3,BFloat16) first;
		return sumQ.first;
	endmethod
	method Action deq;
		sumQ.deq;
	endmethod
endmodule

interface BLMacMSFP12Ifc;
	method Action enq(Vector#(3,Bit#(8)) pixels);
	method Vector#(3,MSFP12Frac) first;
	method Action deq;
endinterface
module mkBLMacMSFP12#(Bit#(53) block) (BLMacMSFP12Ifc);

	Int#(8) exponent = unpack(block[7:0]-127);
	Vector#(3,Vector#(3,MSFP12Frac)) fracs = unpack(truncate(block>>8));
	Int#(8) expi = 0; // 256 is 1 now

	FIFO#(Vector#(3,MSFP12Frac)) psumQ <- mkFIFO;
	
	method Action enq(Vector#(3,Bit#(8)) pixels);
		Vector#(3,Vector#(3,MSFP12Frac)) nfracs = fracs;
		Int#(8) nexp = exponent-127;
		if ( exponent < expi ) nexp = expi;
		nexp = (2*nexp);
		//$write( "~%d\n", nexp );


		if ( exponent < expi + 8 && exponent + 4 > expi ) begin
			if ( exponent > expi ) begin
				Int#(8) ediff = exponent-expi;
				for ( Integer i = 0; i < 3; i=i+1 ) begin
					pixels[i] = pixels[i]>>ediff;
				end
			end else begin
				Int#(8) ediff = expi-exponent;
				for ( Integer i = 0; i < 3; i=i+1 ) begin
					for ( Integer j = 0; j < 3; j=j+1 ) begin
						nfracs[i][j] = MSFP12Frac{
							sign:nfracs[i][j].sign,
							mantissa:nfracs[i][j].mantissa>>ediff};
					end
				end
			end


			Vector#(3,Bit#(9)) psum = replicate(0);
			Vector#(3,Bit#(1)) psign = replicate(0);
			for ( Integer i = 0; i < 3; i=i+1 ) begin
				for ( Integer j = 0; j < 3; j=j+1 ) begin
					Bit#(1) sign = nfracs[i][j].sign;
					// FIXME? only compute top 4 bits of pixel
					Bit#(8) mantissa = zeroExtend(nfracs[i][j].mantissa) * (pixels[i]>>4); 
					if ( psign[j] == sign ) begin
						psum[j] = psum[j] + zeroExtend(mantissa);
					end else if ( psum[j] > zeroExtend(mantissa) ) begin
						psum[j] = psum[j] - zeroExtend(mantissa);
					end else begin
						psign[j] = ~psign[j];
						psum[j] = zeroExtend(mantissa) - psum[j];
					end
				end
			end

			Vector#(3,MSFP12Frac) tbf;
			for ( Integer i = 0; i < 3; i=i+1 ) begin
				MSFP12Frac bf = MSFP12Frac{
					sign: psign[i],
					mantissa:truncate(psum[i]>>5) // 9 bits to 4
				};
				tbf[i] = bf;
			end
			psumQ.enq(tbf);
		end else begin
			psumQ.enq(unpack(0));
		end
	endmethod
	method Vector#(3,MSFP12Frac) first;
		return psumQ.first;
	endmethod
	method Action deq;
		psumQ.deq;
	endmethod
endmodule

endpackage: BLMacMSFP
