module EX(

    input clk,
    input reset,

    input branch_flag,

    // ID/EX Pipeline Registers
    input [31:0] ID_EX_IR,
    input [31:0] ID_EX_NPC,
    input [31:0] ID_EX_A,
    input [31:0] ID_EX_B,
    input [31:0] ID_EX_Imm,

    // Forwarding Inputs
    input [31:0] MEM_WB_ALUOUT,
    input [31:0] MEM_WB_LMD,

    input [1:0] ForwardA,
    input [1:0] ForwardB,

    // EX/MEM Pipeline Registers
    output reg [31:0] EX_MEM_IR,
    output reg [31:0] EX_MEM_ALUOUT,
    output reg [31:0] EX_MEM_B,
    output reg        EX_MEM_COND

);

//==================================================
// Opcodes
//==================================================

parameter ADD   = 6'b000000,
          SUB   = 6'b000001,
          ANDD  = 6'b000010,
          ORR   = 6'b000011,
          SLT   = 6'b000100,
          MUL   = 6'b000101,

          LW    = 6'b001000,
          SW    = 6'b001001,
          ADDI  = 6'b001010,
          SUBI  = 6'b001011,
          SLTI  = 6'b001100,
          BNEQZ = 6'b001101,
          BEQZ  = 6'b001110;

//==================================================
// Forwarding MUXes
//==================================================

reg [31:0] ALU_A;
reg [31:0] ALU_B;

always @(*) begin

    case (ForwardA)
        2'b00: ALU_A = ID_EX_A;
        2'b10: ALU_A = EX_MEM_ALUOUT;
        2'b01: ALU_A = MEM_WB_ALUOUT;
        2'b11: ALU_A = MEM_WB_LMD;
        default: ALU_A = ID_EX_A;
    endcase

    case (ForwardB)
        2'b00: ALU_B = ID_EX_B;
        2'b10: ALU_B = EX_MEM_ALUOUT;
        2'b01: ALU_B = MEM_WB_ALUOUT;
        2'b11: ALU_B = MEM_WB_LMD;
        default: ALU_B = ID_EX_B;
    endcase

end

//==================================================
// Execute Stage
//==================================================

always @(posedge clk)
begin

    if (reset)
    begin
        EX_MEM_IR      <= 32'h00000000;   // NOP
        EX_MEM_ALUOUT  <= 32'd0;
        EX_MEM_B       <= 32'd0;
        EX_MEM_COND    <= 1'b0;
    end

    // Flush wrong-path instruction
    else if (branch_flag)
    begin
        EX_MEM_IR      <= 32'h00000000;   // NOP
        EX_MEM_ALUOUT  <= 32'd0;
        EX_MEM_B       <= 32'd0;
        EX_MEM_COND    <= 1'b0;
    end

    else
    begin

        // Default pipeline values
        EX_MEM_IR      <= ID_EX_IR;
        EX_MEM_B       <= ALU_B;
        EX_MEM_COND    <= 1'b0;

        case (ID_EX_IR[31:26])

            //==========================
            // R-Type Instructions
            //==========================

            ADD:
                EX_MEM_ALUOUT <= ALU_A + ALU_B;

            SUB:
                EX_MEM_ALUOUT <= ALU_A - ALU_B;

            ANDD:
                EX_MEM_ALUOUT <= ALU_A & ALU_B;

            ORR:
                EX_MEM_ALUOUT <= ALU_A | ALU_B;

            SLT:
                EX_MEM_ALUOUT <= ($signed(ALU_A) < $signed(ALU_B)) ? 32'd1 : 32'd0;

            MUL:
                EX_MEM_ALUOUT <= ALU_A * ALU_B;

            //==========================
            // I-Type Arithmetic
            //==========================

            ADDI:
                EX_MEM_ALUOUT <= ALU_A + ID_EX_Imm;

            SUBI:
                EX_MEM_ALUOUT <= ALU_A - ID_EX_Imm;

            SLTI:
                EX_MEM_ALUOUT <= ($signed(ALU_A) < $signed(ID_EX_Imm)) ? 32'd1 : 32'd0;

            //==========================
            // Memory Instructions
            //==========================

            LW,
            SW:
            begin
                EX_MEM_ALUOUT <= ALU_A + ID_EX_Imm;
                EX_MEM_B      <= ALU_B;
            end

            //==========================
            // Branch Instructions
            //==========================

            BEQZ:
            begin
                EX_MEM_ALUOUT <= ID_EX_NPC + ID_EX_Imm;
                EX_MEM_COND   <= (ALU_A == 32'd0);
            end

            BNEQZ:
            begin
                EX_MEM_ALUOUT <= ID_EX_NPC + ID_EX_Imm;
                EX_MEM_COND   <= (ALU_A != 32'd0);
            end

            //==========================
            // Default
            //==========================

            default:
                EX_MEM_ALUOUT <= 32'd0;

        endcase

    end

end

endmodule