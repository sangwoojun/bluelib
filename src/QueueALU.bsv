package QueueALU;

import FIFO::*;
import FIFOF::*;
import FIFOLI::*;
import Clocks::*;
import Vector::*;

import CompletionQueue::*;


import Float32::*;
import Float64::*;
import Cordic::*;

typedef 32 DATA_WIDTH;
typedef Bit#(DATA_WIDTH) Value_t;
Integer data_width = valueof(DATA_WIDTH);

typedef Bit#(9) TailOffType;

typedef enum {
	ALUOutput, // output top to rest of processor
	ALUMult,
	ALUAdd,
	ALUSub,
	ALUSqrt,
	ALUDiv,
    SetTail
} AluCmd deriving (Eq,Bits);

typedef enum {
	ALUInput,
	ALUQueueHead,
	ALUQueueNext,
	ALUImm1,
	ALUImm2
} ParamSrc deriving (Eq,Bits);

typedef struct {
	AluCmd cmd;
	ParamSrc topSrc;
	ParamSrc nextSrc;
	Bit#(2) popCnt;
    Bit#(2) tailFlag;
    TailOffType tailOff;
    Bit#(3) flag;
} AluCommandType deriving (Eq, Bits);

interface QueueALUIfc#(numeric type simd_ways);
	// topSrcQueue == true? top from queue. otherwise from put1
	method Action command(AluCmd cmd, ParamSrc topSrc, ParamSrc nextSrc, Bit#(2) popCnt, Bit#(2) tailFlag, TailOffType tailOff, Bit#(3) flag);
	method Action putTop(Vector#(simd_ways, Value_t) data);
	method Action putNext(Vector#(simd_ways, Value_t) data);
	method ActionValue#(Vector#(simd_ways, Value_t)) get;
endinterface

typedef 9 QueueDepthSz;
typedef Bit#(QueueDepthSz) QueueDepthType;
typedef Bit#(TAdd#(QueueDepthSz, 2)) PosEpochType;
typedef TAdd#(QueueDepthSz,3) QueueDepthTaggedSz;
typedef Bit#(QueueDepthTaggedSz) QueueDepthTaggedType;

(* synthesize *)
module mkQueueALU_2(QueueALUIfc#(2));
	QueueALUIfc#(2) alu <- mkQueueALU;
	return alu;
endmodule


module mkQueueALU(QueueALUIfc#(simd_ways))
	provisos( Add#(1,a__,simd_ways) );

	FIFO#(Vector#(simd_ways, Value_t)) inQ1 <- mkFIFO;
	FIFO#(Vector#(simd_ways, Value_t)) inQ2 <- mkFIFO;
	FIFO#(Vector#(simd_ways, Value_t)) outQ <- mkFIFO;
	FIFO#(AluCommandType) cmdQ <- mkFIFO;
	FIFO#(Tuple3#(AluCommandType,Vector#(simd_ways,Value_t),Vector#(simd_ways,Value_t))) cmdQ2 <- mkFIFO;
	FIFO#(Tuple3#(AluCommandType,Vector#(simd_ways,Value_t),Vector#(simd_ways,Value_t))) cmdQ3 <- mkFIFO;
	FIFO#(Tuple3#(AluCommandType,Vector#(simd_ways,Value_t),Vector#(simd_ways,Value_t))) cmdQ4 <- mkFIFO;

	
	Vector#(2,CompletionQueueIfc#(QueueDepthSz, TAdd#(QueueDepthSz,2), Vector#(simd_ways,Value_t))) cqueue <- replicateM(mkCompletionQueue);
	Reg#(Bit#(1)) nextFirstq <- mkReg(0);
	Reg#(Bit#(1)) nextEnqq <- mkReg(0);

	function Vector#(simd_ways,Value_t) qfirst = cqueue[nextFirstq].first;
	function Vector#(simd_ways,Value_t) qnext = cqueue[~nextFirstq].first;

	function Action qdeq(Bit#(2) cnt);
		return action
			if ( cnt == 1 ) begin
				cqueue[nextFirstq].deq;
				nextFirstq <= ~nextFirstq;
			end else if ( cnt == 2 ) begin
				cqueue[0].deq;
				cqueue[1].deq;
			end
		endaction;
	endfunction



	//////////////////////////////////////////////////////////////

	// Compiler can/should change
    Value_t imm1 = 0; // 0.0
    Value_t imm2 = 32'h3f800000; // 1.0

	Vector#(simd_ways, FpPairIfc#(DATA_WIDTH)) mult <- replicateM(mkFpMult32);
	FIFOLI#(QueueDepthTaggedType, MultLatency32) multTarget <- mkFIFOLI;
	FIFOF#(Tuple2#(Vector#(simd_ways, Value_t), QueueDepthTaggedType)) multCompleteQ <- mkFIFOF;
	rule multResult;
		let t = multTarget.first;
		multTarget.deq;

		Vector#(simd_ways, Value_t) res;
		for (Integer i = 0; i < valueOf(simd_ways); i=i+1 ) begin
			res[i] = mult[i].first;
			mult[i].deq;
		end
		multCompleteQ.enq(tuple2(res,t));
		//$write( "Finishing mult command to %d\n", t);
	endrule

	Vector#(simd_ways, FpPairIfc#(DATA_WIDTH)) dadd <- replicateM(mkFpAdd32);
	FIFOLI#(QueueDepthTaggedType, AddLatency32) addTarget <- mkFIFOLI;
	FIFOF#(Tuple2#(Vector#(simd_ways, Value_t), QueueDepthTaggedType)) addCompleteQ <- mkFIFOF;
	FIFOF#(Tuple2#(Vector#(simd_ways, Value_t), QueueDepthTaggedType)) addForwardQ <- mkFIFOF;
	rule addResult;
		let t = addTarget.first;
		addTarget.deq;

		Vector#(simd_ways, Value_t) res;
		for (Integer i = 0; i < valueOf(simd_ways); i=i+1 ) begin
			res[i] = dadd[i].first;
			dadd[i].deq;
		end
		addCompleteQ.enq(tuple2(res,t));
		//$write( "Finishing add command to %d\n", t);
	endrule

	Vector#(simd_ways, FpFilterIfc#(DATA_WIDTH)) sqrt <- replicateM(mkFpSqrt32);
	FIFOLI#(QueueDepthTaggedType, SqrtLatency32) sqrtTarget <- mkFIFOLI;
	FIFOF#(Tuple2#(Vector#(simd_ways, Value_t), QueueDepthTaggedType)) sqrtCompleteQ <- mkFIFOF;
	FIFOF#(Tuple2#(Vector#(simd_ways, Value_t), QueueDepthTaggedType)) sqrtForwardQ <- mkFIFOF;
	rule sqrtResult;
		let t = sqrtTarget.first;
		sqrtTarget.deq;
		Vector#(simd_ways, Value_t) res;
		for (Integer i = 0; i < valueOf(simd_ways); i=i+1 ) begin
			res[i] = sqrt[i].first;
			sqrt[i].deq;
		end
		sqrtCompleteQ.enq(tuple2(res,t));
		//$write( "Finishing sqrt command to %d\n", t);
	endrule

	Vector#(simd_ways, FpPairIfc#(32)) ddiv <- replicateM(mkFpDiv32);
	FIFOLI#(QueueDepthTaggedType, DivLatency32) divTarget <- mkFIFOLI;
	FIFOF#(Tuple2#(Vector#(simd_ways, Value_t), QueueDepthTaggedType)) divCompleteQ <- mkFIFOF;
	FIFOF#(Tuple2#(Vector#(simd_ways, Value_t), QueueDepthTaggedType)) divForwardQ <- mkFIFOF;
	rule divResult;
		let t = divTarget.first;
		divTarget.deq;

		Vector#(simd_ways, Value_t) res;
		for (Integer i = 0; i < valueOf(simd_ways); i=i+1 ) begin
			res[i] = ddiv[i].first;
			ddiv[i].deq;
		end
		divCompleteQ.enq(tuple2(res,t));
        //$write("Cycle %1d -> [QALU %1d] div out\n", cycles, id);
	endrule

	Reg#(Bool) forwardAddLastDirection <- mkReg(False);
	rule forwardAdd;
		if ( forwardAddLastDirection ) begin
			if (multCompleteQ.notEmpty) begin
				multCompleteQ.deq;
				addForwardQ.enq(multCompleteQ.first);
				//$write( "Add - Forwarding mult\n" );
			end else begin
				addCompleteQ.deq;
				addForwardQ.enq(addCompleteQ.first);
			end
		end else begin
			if (addCompleteQ.notEmpty) begin
				addCompleteQ.deq;
				addForwardQ.enq(addCompleteQ.first);
			end else begin
				multCompleteQ.deq;
				addForwardQ.enq(multCompleteQ.first);
				//$write( "Add - Forwarding mult\n" );
			end
		end
		forwardAddLastDirection <= !forwardAddLastDirection;
	endrule
	
	Reg#(Bool) forwardSqrtLastDirection <- mkReg(False);
	rule forwardSqrt;
		if ( forwardSqrtLastDirection) begin
			if (sqrtCompleteQ.notEmpty) begin
				sqrtCompleteQ.deq;
				sqrtForwardQ.enq(sqrtCompleteQ.first);
			end else begin
				addForwardQ.deq;
				sqrtForwardQ.enq(addForwardQ.first);
				//$write( "Sqrt - Forwarding add\n" );
			end
		end else begin
			if (addForwardQ.notEmpty) begin
				addForwardQ.deq;
				sqrtForwardQ.enq(addForwardQ.first);
				//$write( "Sqrt - Forwarding add\n" );
			end else begin
				sqrtCompleteQ.deq;
				sqrtForwardQ.enq(sqrtCompleteQ.first);
			end
		end
		forwardSqrtLastDirection <= !forwardSqrtLastDirection;
	endrule

	Reg#(Bool) forwardDivLastDirection <- mkReg(False);
	rule forwardDiv;
		if ( forwardDivLastDirection) begin
			if (divCompleteQ.notEmpty) begin
				divCompleteQ.deq;
				divForwardQ.enq(divCompleteQ.first);
			end else begin
				sqrtForwardQ.deq;
				divForwardQ.enq(sqrtForwardQ.first);
				//$write( "Div - Forwarding sqrt\n" );
			end
		end else begin
			if (sqrtForwardQ.notEmpty) begin
				sqrtForwardQ.deq;
				divForwardQ.enq(sqrtForwardQ.first);
				//$write( "Div - Forwarding sqrt\n" );
			end else begin
				divCompleteQ.deq;
				divForwardQ.enq(divCompleteQ.first);
			end
		end
		forwardDivLastDirection <= !forwardDivLastDirection;
	endrule

	rule applyCompletion;
		divForwardQ.deq;
		let d_ = divForwardQ.first;
		let res = tpl_1(d_);
		let t_ = tpl_2(d_);
		Bit#(1) qidx = truncate(t_);
		PosEpochType t = truncate(t_>>1);
		cqueue[qidx].complete(t,res);
		//$write( "Completing %d %d\n", qidx, t );
	endrule
	

	
	
	
	rule procCmd2;
		cmdQ4.deq;
		let cmd_ = cmdQ4.first;
		let cmd = tpl_1(cmd_);

		Vector#(2,Vector#(simd_ways,Value_t)) params;
		params[0] = tpl_2(cmd_);
		params[1] = tpl_3(cmd_);

		let t <- cqueue[nextEnqq].enq;
        QueueDepthType curr_tail = truncate(t >> 2);
        QueueDepthType tailoff = zeroExtend(cmd.tailOff);
        if(cmd.tailFlag == 2) begin
            cqueue[nextEnqq].advance_tail(tailoff);
            cqueue[~nextEnqq].advance_tail(tailoff);
            $write("Cycle %1d -> [QALU %1d] Advance tail: curr_tail: %1d, curr_epoch: %1d, tailoff: %1d\n", 
                                            cycles, id, curr_tail, t[1:0], tailoff);
        end else begin
            Bit#(2) curr_epoch = truncate(t);
            if(cmd.tailFlag == 0)
                cqueue[nextEnqq].advance_tail(1);
            else begin
                QueueDepthType tgt_slot = curr_tail + tailoff;
                Bit#(2) tgt_epoch = curr_epoch;
                if(tgt_slot < curr_tail) tgt_epoch = curr_epoch + 1;
                t = {tgt_slot, tgt_epoch};
            end
		    nextEnqq <= ~nextEnqq;
		    QueueDepthTaggedType enqt = zeroExtend(t)<<1 | zeroExtend(nextEnqq);
		    //$write( "completion queue %d, target %d --> %d\n", nextEnqq, t, enqt );


		    case (cmd.cmd)
		        ALUMult: begin
		            for (Integer i = 0; i < valueOf(simd_ways); i=i+1 ) mult[i].enq(params[0][i], params[1][i]);
		    		multTarget.enq(enqt);
		    		//$write( "Starting mult command\n" );
		        end
		    	ALUAdd: begin
		            for (Integer i = 0; i < valueOf(simd_ways); i=i+1 ) dadd[i].enq(params[0][i], params[1][i]);
		    		addTarget.enq(enqt);
		    		//$write( "Starting add command\n" );
                    //$write("Cycle %1d -> [QALU %1d] add in.\n", cycles, id);
		    	end
		    	ALUSub: begin
                    // params[0][i] - params[1][i]
                    // use adder to implement the sub
		    		for (Integer i = 0; i < valueOf(simd_ways); i=i+1 ) begin
                        params[1][i][data_width - 1] = ~params[1][i][data_width - 1];
                        dadd[i].enq(params[0][i], params[1][i]);
                    end
		    		addTarget.enq(enqt);
		    		//$write( "Starting add command\n" );
                    //$write("Cycle %1d -> [QALU %1d] add in.\n", cycles, id);
		    	end
		        ALUSqrt: begin
		    		for (Integer i = 0; i < valueOf(simd_ways); i=i+1 ) sqrt[i].enq(params[0][i]);
		    		sqrtTarget.enq(enqt);
		    		//$write( "Starting sqrt command\n" );
		    	end
		    	ALUDiv: begin
		    		for (Integer i = 0; i < valueOf(simd_ways); i=i+1 ) ddiv[i].enq(params[0][i], params[1][i]);
		    		divTarget.enq(enqt);
		    		//$write( "Starting div command\n" );
		    	end
		    endcase
        end
	endrule
	//////////////////////////////////////////////////////////////


	rule procCmd;
		cmdQ.deq;
		let cmd = cmdQ.first;

		Vector#(simd_ways, Value_t) topd = replicate(0);
		if ( cmd.topSrc  == ALUQueueHead ) topd = qfirst;
        else if(cmd.topSrc == ALUQueueNext) topd = qnext;
		Vector#(simd_ways, Value_t) nextd = replicate(0);
		if ( cmd.nextSrc  == ALUQueueHead ) nextd = qfirst;
        else if(cmd.nextSrc == ALUQueueNext) nextd = qnext;

        Bit#(1) is_qout = cmd.flag[0];
        if(is_qout == 1)
            qdeq(1);
        else
            qdeq(cmd.popCnt);

		if ( cmd.cmd == ALUOutput ) begin
			//$write("output!\n" );
			outQ.enq(qfirst);
		end else begin
			//$write( "Command proc 1\n" );
			cmdQ2.enq(tuple3(cmd,topd,nextd));
            if(is_qout == 1) begin
			    outQ.enq(qfirst);
            end
		end
	endrule
	rule procParamInput;
		//$write( "Command proc 2\n" );
		cmdQ2.deq;
		let cmd_ = cmdQ2.first;
		let cmd = tpl_1(cmd_);
		let topd = tpl_2(cmd_);
		let nextd = tpl_3(cmd_);


		if ( cmd.topSrc == ALUInput ) begin
			topd = inQ1.first;
			inQ1.deq;
		end
		if ( cmd.nextSrc == ALUInput ) begin
			nextd = inQ2.first;
			inQ2.deq;
		end
		cmdQ3.enq(tuple3(cmd,topd,nextd));
	endrule
	rule procParamImm;
		//$write( "Command proc 3\n" );
		cmdQ3.deq;
		let cmd_ = cmdQ3.first;
		let cmd = tpl_1(cmd_);
		let topd = tpl_2(cmd_);
		let nextd = tpl_3(cmd_);

		if ( cmd.topSrc == ALUImm1 ) begin
			topd = replicate(imm1);
		end else if ( cmd.topSrc == ALUImm2 ) begin
			topd = replicate(imm2);
		end
		if ( cmd.nextSrc == ALUImm1 ) begin
			nextd = replicate(imm1);
		end else if ( cmd.nextSrc == ALUImm2 ) begin
			nextd = replicate(imm2);
		end
		cmdQ4.enq(tuple3(cmd,topd,nextd));
	endrule
	


	method Action command(AluCmd cmd, ParamSrc topSrc, ParamSrc nextSrc, Bit#(2) popCnt, Bit#(2) tailFlag, TailOffType tailOff, Bit#(3) flag);
		//$write( "Command in! popcnt %d\n", popCnt );
		cmdQ.enq(AluCommandType{
			cmd: cmd, topSrc:topSrc, nextSrc:nextSrc, popCnt:popCnt, tailFlag:tailFlag, tailOff:tailOff, flag:flag
		});
	endmethod
	method Action putTop(Vector#(simd_ways, Value_t) data);
		inQ1.enq(data);
	endmethod
	method Action putNext(Vector#(simd_ways, Value_t) data);
		inQ2.enq(data);
	endmethod
	method ActionValue#(Vector#(simd_ways, Value_t)) get;
		outQ.deq;
		return outQ.first;
	endmethod
endmodule


endpackage: QueueALU
