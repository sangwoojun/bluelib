package BLMacMSFP7;
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
typedef struct {
	Bit#(1) sign;
	Bit#(15) mantissa;
} MSFPTempFrac deriving(Eq,Bits);
interface BLMacMSFP12_7ChannelIfc;
	method Action enq(Vector#(3,Vector#(7,Bit#(8))) pixels);
	method BFloat16 first;
	method Action deq;
endinterface
interface BLMSFPtoBFloat16Ifc;
	method Action enq(Bit#(1) sign, Bit#(15) mantissa_e);
	method BFloat16 first;
	method Action deq;
endinterface
module mkMSFPtoBFloat16#(Bit#(8) expn_) (BLMSFPtoBFloat16Ifc);
	FIFO#(Tuple2#(Bit#(1), Bit#(15))) inQ <- mkFIFO;
	FIFO#(BFloat16) outQ <- mkFIFO;
	rule doTranslate;
		inQ.deq;
		let in = inQ.first;
		Bit#(8) expn = expn_;
		Bit#(1) sign = tpl_1(in);
		Bit#(15) mantissa = tpl_2(in);
		Bool done = False;
		for ( Integer i = 0; i < 7; i=i+1 ) begin
			if ( !done && mantissa[14] != 1 ) begin
				mantissa = (mantissa << 1);
				expn = expn-1;
			end else begin
				done = True;
			end
		end
		outQ.enq(BFloat16{
			sign: sign,
			mantissa: mantissa[13:7], // remove MSB 1
			exponent: expn - 1 // remove MSB 1
		});
	endrule
	method Action enq(Bit#(1) sign, Bit#(15) mantissa_e);
		inQ.enq(tuple2(sign,mantissa_e));
	endmethod
	method BFloat16 first;
		return outQ.first;
	endmethod
	method Action deq;
		outQ.deq;
	endmethod
endmodule
module mkBLMacMSFP12_7#(Bit#(43) block1, Bit#(43) block2, Bit#(43) block3) (BLMacMSFP12_7ChannelIfc);
	Vector#(3,BLMacMSFP12Ifc) pev;
	pev[0] <- mkBLMacMSFP12(block1, 0);
	pev[1] <- mkBLMacMSFP12(block2, 1);
	pev[2] <- mkBLMacMSFP12(block3, 2);

	Vector#(3, Int#(8)) expo;
	expo[0] = unpack(block1[7:0]-127);
	expo[1] = unpack(block2[7:0]-127);
	expo[2] = unpack(block3[7:0]-127);
	Int#(8) maxexp = -126;
	for ( Integer i = 0; i < 3; i=i+1 ) begin
		Int#(8) nexp_i = expo[i]-127;
		if ( nexp_i < 0 ) nexp_i = 0; // align to pixel input
		nexp_i = 2*nexp_i;
		if ( maxexp < nexp_i ) maxexp = nexp_i;
	end
	
	FIFO#(BFloat16) sumQ <- mkFIFO;
	BLMSFPtoBFloat16Ifc msfp2bf <- mkMSFPtoBFloat16(pack(maxexp)+127+4);  // shifting by 4 to adjust for mantissa shift in mkBLMacMSFP14
	FIFO#(Tuple2#(Bit#(1), Bit#(17))) signmanQ_1 <- mkFIFO;
	FIFO#(Tuple2#(Bit#(1), Bit#(17))) signmanQ_2 <- mkFIFO;
    Vector#(3, FIFO#(MSFPTempFrac)) psumQ <- replicateM(mkSizedFIFO(4));

	for ( Integer i = 0; i < 3; i= i+1) begin
		rule transpose_psum;
            pev[i].deq;
            psumQ[i].enq(pev[i].first);
		endrule
    end

	rule sumchannels_1;
		MSFPTempFrac psum = psumQ[0].first; psumQ[0].deq;
		Bit#(1) sign = 0;
		Bit#(17) mantissa = 0;
		Int#(8) expdiff = maxexp-expo[0];
		Bit#(15) nmantissa = (psum.mantissa>>expdiff);
		if ( psum.sign == sign ) begin
				mantissa = zeroExtend(nmantissa) + mantissa;
		end else if ( zeroExtend(nmantissa) > mantissa ) begin
				sign = ~sign;
				mantissa = zeroExtend(nmantissa) - mantissa;
		end else begin
				mantissa = mantissa - zeroExtend(nmantissa);
		end
		signmanQ_1.enq(tuple2(sign, mantissa));
	endrule
	rule sumchannels_2;
		MSFPTempFrac psum = psumQ[1].first; psumQ[1].deq;
		let d_ = signmanQ_1.first; signmanQ_1.deq;
        Bit#(1) sign = tpl_1(d_);
        Bit#(17) mantissa = tpl_2(d_);
		Int#(8) expdiff = maxexp-expo[1];
		Bit#(15) nmantissa = (psum.mantissa>>expdiff);
		if ( psum.sign == sign ) begin
				mantissa = zeroExtend(nmantissa) + mantissa;
		end else if ( zeroExtend(nmantissa) > mantissa ) begin
				sign = ~sign;
				mantissa = zeroExtend(nmantissa) - mantissa;
		end else begin
				mantissa = mantissa - zeroExtend(nmantissa);
		end
		signmanQ_2.enq(tuple2(sign, mantissa));
	endrule
	rule sumchannels_3;
		MSFPTempFrac psum = psumQ[2].first; psumQ[2].deq;
		let d_ = signmanQ_2.first; signmanQ_2.deq;
        Bit#(1) sign = tpl_1(d_);
        Bit#(17) mantissa = tpl_2(d_);
		Int#(8) expdiff = maxexp-expo[2];
		Bit#(15) nmantissa = (psum.mantissa>>expdiff);
		if ( psum.sign == sign ) begin
				mantissa = zeroExtend(nmantissa) + mantissa;
		end else if ( zeroExtend(nmantissa) > mantissa ) begin
				sign = ~sign;
				mantissa = zeroExtend(nmantissa) - mantissa;
		end else begin
				mantissa = mantissa - zeroExtend(nmantissa);
		end
		msfp2bf.enq(sign, truncateLSB(mantissa));
	endrule

	rule collectBfloat16;
		BFloat16 temps = msfp2bf.first;
		msfp2bf.deq;
		sumQ.enq(temps);
	endrule
	method Action enq(Vector#(3,Vector#(7,Bit#(8))) pixels);
		for (Integer i = 0; i < 3; i=i+1 ) begin
			pev[i].enq(pixels[i]);
		end
	endmethod
	method BFloat16 first;
		return sumQ.first;
	endmethod
	method Action deq;
		sumQ.deq;
	endmethod
endmodule

interface BLMacMSFP12Ifc;
	method Action enq(Vector#(7,Bit#(8)) pixels);
	method MSFPTempFrac first;
	method Action deq;
endinterface
module mkBLMacMSFP12#(Bit#(43) block, Integer channel) (BLMacMSFP12Ifc);
	Int#(8) exponent = unpack(block[7:0]-127);
	Vector#(7, MSFP12Frac) fracs = unpack(truncate(block>>8));  /**/
	Int#(8) expi = 0; // 256 is 1 now
	FIFO#(MSFPTempFrac) psumQ <- mkFIFO;
	Vector#(7, FIFO#(Bit#(20))) signpsumQ <- replicateM(mkFIFO);
	Vector#(7, FIFO#(Bit#(8))) pixelsQ <- replicateM(mkSizedFIFO(8));

	for ( Integer i = 0; i < 6; i=i+1 ) begin
		rule step_calc_1;
			let pixels = pixelsQ[i].first; pixelsQ[i].deq;
			let d = signpsumQ[i].first; signpsumQ[i].deq; 
			Bit#(1) psign = d[19]; Bit#(19) psum = d[18:0];
			Bit#(1) sign = fracs[i].sign;
			Bit#(8) nmantissa = (zeroExtend(fracs[i].mantissa)<<4);
			if ( exponent < expi ) begin
				Int#(8) ediff = expi-exponent;
				nmantissa = (nmantissa>>ediff);
			end
			Bit#(16) mantissa_t = zeroExtend(nmantissa) * zeroExtend(pixels); 
			Bit#(15) mantissa = truncateLSB(mantissa_t);
			if ( psign == sign ) begin
				psum = psum + zeroExtend(mantissa);
			end else if ( psum > zeroExtend(mantissa) ) begin
				psum = psum - zeroExtend(mantissa);
			end else begin
				psign = ~psign;
				psum = zeroExtend(mantissa) - psum;
			end
			signpsumQ[i+1].enq({psign, psum});
		endrule
	end

	rule step_calc_2;
		let pixels = pixelsQ[6].first; pixelsQ[6].deq;
		let d = signpsumQ[6].first; signpsumQ[6].deq; 
        Bit#(1) psign = d[19]; Bit#(19) psum = d[18:0];
		Bit#(1) sign = fracs[6].sign;
		Bit#(8) nmantissa = (zeroExtend(fracs[6].mantissa)<<4);
		if ( exponent < expi ) begin
			Int#(8) ediff = expi-exponent;
			nmantissa = (nmantissa>>ediff);
		end
		Bit#(16) mantissa_t = zeroExtend(nmantissa) * zeroExtend(pixels); 
		Bit#(15) mantissa = truncateLSB(mantissa_t);
		if ( psign == sign ) begin
			psum = psum + zeroExtend(mantissa);
		end else if ( psum > zeroExtend(mantissa) ) begin
			psum = psum - zeroExtend(mantissa);
		end else begin
			psign = ~psign;
			psum = zeroExtend(mantissa) - psum;
		end
		MSFPTempFrac bf = MSFPTempFrac{
				sign: psign,
				mantissa:truncateLSB(psum)
		};
		psumQ.enq(bf);
    endrule
	
	method Action enq(Vector#(7,Bit#(8)) pixels);
		if ( exponent > expi ) begin
			Int#(8) ediff = exponent-expi;
			for ( Integer i = 0; i < 7; i=i+1 ) begin
				pixels[i] = pixels[i]>>ediff;
			end
		end 
		for ( Integer i = 0; i < 7; i=i+1 ) begin
			pixelsQ[i].enq(pixels[i]);
		end
		signpsumQ[0].enq(0);
	endmethod
	method MSFPTempFrac first;
		return psumQ.first;
	endmethod
	method Action deq;
		psumQ.deq;
	endmethod
endmodule

endpackage: BLMacMSFP7
