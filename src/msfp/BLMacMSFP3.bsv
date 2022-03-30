package BLMacMSFP3;
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
    Bit#(15) mantissa; // 7 bits for bfloat16, 7 bits for potential shifting for alignment, one bit for MSB
} MSFPTempFrac deriving(Eq,Bits);
interface BLMacMSFP12_3ChannelIfc;
    method Action enq(Vector#(3,Vector#(3,Bit#(8))) pixels);
    method Vector#(3,BFloat16) first;
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
                expn = expn -1;
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
module mkBLMacMSFP12_3#(Bit#(53) block1, Bit#(53) block2, Bit#(53) block3) (BLMacMSFP12_3ChannelIfc);
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
    
    FIFO#(Vector#(3,BFloat16)) sumQ <- mkFIFO;
    Vector#(3,BLMSFPtoBFloat16Ifc) msfp2bf <- replicateM(mkMSFPtoBFloat16(pack(maxexp)+127+4));  // shifting by 4 to adjust for mantissa shift in mkBLMacMSFP12
    Vector#(3, FIFO#(Tuple2#(Bit#(1), Bit#(17)))) signmanQ_1 <- replicateM(mkFIFO);
	Vector#(3, FIFO#(Tuple2#(Bit#(1), Bit#(17)))) signmanQ_2 <- replicateM(mkFIFO);
    Vector#(3, Vector#(3, FIFO#(MSFPTempFrac))) psumQ <- replicateM(replicateM(mkSizedFIFO(4)));

    
    for ( Integer i = 0; i < 3; i= i+1) begin
		rule transpose_psum;
            pev[i].deq;
            Vector#(3, MSFPTempFrac) temp = pev[i].first;
            psumQ[i][0].enq(temp[0]);
            psumQ[i][1].enq(temp[1]);
            psumQ[i][2].enq(temp[2]);
		endrule
    end

    for ( Integer col = 0; col < 3; col = col + 1) begin
        rule sumchannels_1;
                    MSFPTempFrac psum = psumQ[0][col].first; psumQ[0][col].deq;
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
					signmanQ_1[col].enq(tuple2(sign, mantissa));
        endrule
        rule sumchannels_2;
                    MSFPTempFrac psum = psumQ[1][col].first; psumQ[1][col].deq;
					let d_ = signmanQ_1[col].first; signmanQ_1[col].deq;
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
                    signmanQ_2[col].enq(tuple2(sign, mantissa));
        endrule
        rule sumchannels_3;
                    MSFPTempFrac psum = psumQ[2][col].first; psumQ[2][col].deq;
                    let d_ = signmanQ_2[col].first; signmanQ_2[col].deq;
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
                    msfp2bf[col].enq(sign, truncateLSB(mantissa));
        endrule
    end
    
    rule collectBfloat16;
        Vector#(3,BFloat16) temps;
        for ( Integer i = 0; i < 3; i=i+1 ) begin
            temps[i] = msfp2bf[i].first;
            msfp2bf[i].deq;
        end
        sumQ.enq(temps);
    endrule
    method Action enq(Vector#(3,Vector#(3,Bit#(8))) _pixels);
        for (Integer i = 0; i < 3; i=i+1 ) begin
            pev[i].enq(_pixels[i]);
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
    method Vector#(3,MSFPTempFrac) first;
    method Action deq;
endinterface
module mkBLMacMSFP12#(Bit#(53) block, Integer channel) (BLMacMSFP12Ifc);
    Int#(8) exponent = unpack(block[7:0]-127);
    Vector#(3,Vector#(3,MSFP12Frac)) fracs = unpack(truncate(block>>8));
    Int#(8) expi = 0; // 256 is 1 now
    FIFO#(Vector#(3,MSFPTempFrac)) psumQ <- mkFIFO;
    Vector#(2, FIFO#(Vector#(3,Bit#(17)))) psumForward <- replicateM(mkFIFO);
    Vector#(2, FIFO#(Vector#(3,Bit#(1)))) psignForward <- replicateM(mkFIFO);
    Vector#(2, FIFO#(Bit#(8))) pixelsQ <- replicateM(mkSizedFIFO(4));

    rule step_calc_b;
        let pixels = pixelsQ[0].first; pixelsQ[0].deq;
        Vector#(3,Bit#(17)) psum = psumForward[0].first;
        psumForward[0].deq;
        Vector#(3,Bit#(1)) psign = psignForward[0].first;
        psignForward[0].deq;
        for ( Integer j = 0; j < 3; j=j+1 ) begin
            Bit#(1) sign = fracs[1][j].sign;
            // FIXME? only compute top 4 bits of pixel
            Bit#(8) nmantissa = (zeroExtend(fracs[1][j].mantissa)<<4);
            if ( exponent < expi ) begin
                Int#(8) ediff = expi-exponent;
                nmantissa = (nmantissa>>ediff);
            end
            Bit#(16) mantissa_t = zeroExtend(nmantissa) * zeroExtend(pixels); 
            Bit#(15) mantissa = truncateLSB(mantissa_t); 
            if ( psign[j] == sign ) begin
                psum[j] = psum[j] + zeroExtend(mantissa);
            end else if ( psum[j] > zeroExtend(mantissa)) begin
                psum[j] = psum[j] - zeroExtend(mantissa);
            end else begin
                psign[j] = ~psign[j];
                psum[j] = zeroExtend(mantissa) - psum[j];
            end
        end
        psumForward[1].enq(psum);
        psignForward[1].enq(psign);
    endrule
    rule step_calc_c;
        let pixels = pixelsQ[1].first; pixelsQ[1].deq;
        Vector#(3,Bit#(17)) psum = psumForward[1].first;
        psumForward[1].deq;
        Vector#(3,Bit#(1)) psign = psignForward[1].first;
        psignForward[1].deq;
        for ( Integer j = 0; j < 3; j=j+1 ) begin
            Bit#(1) sign = fracs[2][j].sign;
            // FIXME? only compute top 4 bits of pixel
            Bit#(8) nmantissa = (zeroExtend(fracs[2][j].mantissa)<<4);
            if ( exponent < expi ) begin
                Int#(8) ediff = expi-exponent;
                nmantissa = (nmantissa>>ediff);
            end
            Bit#(16) mantissa_t = zeroExtend(nmantissa) * zeroExtend(pixels); 
            Bit#(15) mantissa = truncateLSB(mantissa_t); 
            if ( psign[j] == sign ) begin
                psum[j] = psum[j] + zeroExtend(mantissa);
            end else if ( psum[j] > zeroExtend(mantissa) ) begin
                psum[j] = psum[j] - zeroExtend(mantissa);
            end else begin
                psign[j] = ~psign[j];
                psum[j] = zeroExtend(mantissa) - psum[j];
            end
        end
        Vector#(3,MSFPTempFrac) tbf;
        for ( Integer i = 0; i < 3; i=i+1 ) begin
            MSFPTempFrac bf = MSFPTempFrac{
                sign: psign[i],
                mantissa:truncateLSB(psum[i])
            };
            tbf[i] = bf;
            //$write( "A: %d>> %d,%d %d %d\n",channel, exponent, expi, psign[i], psum[i] );
        end
        psumQ.enq(tbf);
    endrule
    method Action enq(Vector#(3,Bit#(8)) pixels);
        if ( exponent > expi ) begin
            Int#(8) ediff = exponent-expi;
            for ( Integer i = 0; i < 3; i=i+1 ) begin
                pixels[i] = pixels[i]>>ediff;
            end
        end 
		pixelsQ[0].enq(pixels[1]);
		pixelsQ[1].enq(pixels[2]);
        Vector#(3,Bit#(17)) psum = replicate(0);
        Vector#(3,Bit#(1)) psign = replicate(0);
        for ( Integer j = 0; j < 3; j=j+1 ) begin
            Bit#(1) sign = fracs[0][j].sign;
            // FIXME? only compute top 4 bits of pixel
            Bit#(8) nmantissa = (zeroExtend(fracs[0][j].mantissa)<<4);
            if ( exponent < expi ) begin
                Int#(8) ediff = expi-exponent;
                nmantissa = (nmantissa>>ediff);
            end
            Bit#(16) mantissa_t = (zeroExtend(nmantissa) * zeroExtend(pixels[0])); 
			Bit#(15) mantissa = truncateLSB(mantissa_t); 
            if ( psign[j] == sign ) begin
                psum[j] = psum[j] + zeroExtend(mantissa);
            end else if ( psum[j] > zeroExtend(mantissa) ) begin
                psum[j] = psum[j] - zeroExtend(mantissa);
            end else begin
                psign[j] = ~psign[j];
                psum[j] = zeroExtend(mantissa) - psum[j];
            end
        end
        psumForward[0].enq(psum);
        psignForward[0].enq(psign);
    endmethod
    method Vector#(3,MSFPTempFrac) first;
        return psumQ.first;
    endmethod
    method Action deq;
        psumQ.deq;
    endmethod
endmodule


endpackage: BLMacMSFP3
