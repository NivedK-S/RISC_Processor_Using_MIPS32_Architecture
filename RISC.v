module Pipe_MIPS32(
    input clk1,
    input clk2
);
reg [31:0] PC,IF_ID_IR,IF_ID_NPC;
reg[31:0] ID_EX_IR,ID_EX_NPC,ID_EX_A,ID_EX_B,ID_EX_IMM;
reg [2:0] ID_EX_Type,EX_MEM_type,MEM_WB_type;
reg [31:0] EX_MEM_IR,EX_MEM_ALUOut,EX_MEM_B;
reg EX_MEM_Cond;
reg[31:0] MEM_WB_IR,MEM_WB_LMD,MEM_WB_ALUOut;
reg [31:0] Reg[0:31];
reg[31:0] Mem[0:1023];
parameter ADD =6'd0,
          SUB=6'd1,
          AND=6'd2,
          OR=6'd3,
          SLT=6'd4,
          MUL=6'd5,
          HLT=6'b111111,
          LW=6'd8,
          SW=6'd9,
          ADDI=6'd10,
          SUBI=6'd11,
          SLTI=6'd12,
          BNEQZ=6'd13,
          BEQZ=6'd14;
parameter RR_ALU=3'd0,
          RM_ALU=3'd1,
          LOAD=3'd2,
          STORE=3'd3,
          BRANCH=3'd4,
          HALT=3'd5;
reg HALTED;
reg TAKEN_BRANCH;
//IF STAGE
always @(posedge clk1) begin
 if(HALTED==0)
 begin
   if(((EX_MEM_IR[31:26]==BEQZ) && (EX_MEM_Cond==1))||
   ((EX_MEM_IR[31:26]==BNEQZ)&&(EX_MEM_Cond==0)))
   begin
     IF_ID_IR<=#2 Mem[EX_MEM_ALUOut];
     TAKEN_BRANCH<=#2 1'b1;
     IF_ID_NPC<=#2 EX_MEM_ALUOut+1;
     PC<=#2 MEM_WB_ALUOut+1;
   end
   else 
   begin
     IF_ID_IR<= #2 Mem[PC];
     IF_ID_NPC<=#2 PC+1;
     PC<=#2 PC+1;
   end
 end   
end

// ID Stage

always @(posedge clk2) begin
    if(HALTED==0)
    begin
      if(IF_ID_IR[25:21]==5'd0) ID_EX_A<=0;
      else ID_EX_A<=#2 Reg[IF_ID_IR[25:21]]; //rs
      if(IF_ID_IR[20:16]==5'd0)ID_EX_B<=0;
      else ID_EX_B<=#2 Reg[IF_ID_IR[20:16]];//rt
      ID_EX_NPC<=#2 IF_ID_NPC;
      ID_EX_IR<=#2 IF_ID_IR;
      ID_EX_IMM<=#2 {{16{IF_ID_IR[15]}},{IF_ID_IR[15:0]}};
      case (IF_ID_IR[31:26])
        ADD,SUB,AND,OR,SLT,MUL:ID_EX_Type<=#2 RR_ALU;
        ADDI,SUBI,SLTI:ID_EX_Type<=#2 RM_ALU;
        LW: ID_EX_Type<=#2 LOAD;
        SW:ID_EX_Type<=#2 STORE;
        BNEQZ,BEQZ:ID_EX_Type<=#2 BRANCH;
        HLT:ID_EX_Type<=#2 HALT;
        default: ID_EX_Type<=#2 HALT;
      endcase
    end
end

//EX Stage
always @(posedge clk1) // EX Stage 
 if (HALTED == 0) 
 begin 
 EX_MEM_type <= #2 ID_EX_Type; 
 EX_MEM_IR <= #2 ID_EX_IR; 
 TAKEN_BRANCH <= #2 0; 
 case (ID_EX_Type) 
 RR_ALU: begin 
 case (ID_EX_IR[31:26]) // "opcode" 
 ADD: EX_MEM_ALUOut <= #2 ID_EX_A + ID_EX_B; 
 SUB: EX_MEM_ALUOut <= #2 ID_EX_A - ID_EX_B; 
 AND: EX_MEM_ALUOut <= #2 ID_EX_A & ID_EX_B; 
 OR: EX_MEM_ALUOut <= #2 ID_EX_A | ID_EX_B; 
 SLT: EX_MEM_ALUOut <= #2 ID_EX_A < ID_EX_B; 
 MUL: EX_MEM_ALUOut <= #2 ID_EX_A * ID_EX_B; 
 default: EX_MEM_ALUOut <= #2 32'hxxxxxxxx; 
 endcase
 end
 RM_ALU: begin 
 case (ID_EX_IR[31:26]) // "opcode" 
 ADDI: EX_MEM_ALUOut <= #2 ID_EX_A + ID_EX_IMM; 
 SUBI: EX_MEM_ALUOut <= #2 ID_EX_A - ID_EX_IMM; 
 SLTI: EX_MEM_ALUOut <= #2 ID_EX_A < ID_EX_IMM; 
 default: EX_MEM_ALUOut <= #2 32'hxxxxxxxx; 
 endcase
 end
 LOAD, STORE: 
 begin 
 EX_MEM_ALUOut <= #2 ID_EX_A + ID_EX_IMM; 
 EX_MEM_B <= #2 ID_EX_B; 
 end
 BRANCH: begin 
 EX_MEM_ALUOut <= #2 ID_EX_NPC + ID_EX_IMM; 
EX_MEM_Cond <= #2 (ID_EX_A == 0); 
 end 
 endcase
 end
 //MEM Stage
 always @(posedge clk2) // MEM Stage 
 if (HALTED == 0) 
 begin 
 MEM_WB_type <= EX_MEM_type; 
 MEM_WB_IR <= #2 EX_MEM_IR; 
 case (EX_MEM_type) 
 RR_ALU, RM_ALU: 
 MEM_WB_ALUOut <= #2 EX_MEM_ALUOut; 
 LOAD: MEM_WB_LMD <= #2 Mem[EX_MEM_ALUOut]; 
 STORE: if (TAKEN_BRANCH == 0) // Disable write 
 Mem[EX_MEM_ALUOut] <= #2 EX_MEM_B; 
 endcase
 end

//WB stage
 always @(posedge clk1) // WB Stage 
 begin 
 if (TAKEN_BRANCH == 0) // Disable write if branch taken 
 case (MEM_WB_type) 
 RR_ALU: Reg[MEM_WB_IR[15:11]] <= #2 MEM_WB_ALUOut; // "rd" 
 RM_ALU: Reg[MEM_WB_IR[20:16]] <= #2 MEM_WB_ALUOut; // "rt" 
 LOAD: Reg[MEM_WB_IR[20:16]] <= #2 MEM_WB_LMD; // "rt" 
 HALT: HALTED <= #2 1'b1; 
 endcase
 end 




endmodule