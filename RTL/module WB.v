module WB(

    input clk,
    input reset,

    input [31:0] MEM_WB_ALUOUT,
    input [31:0] MEM_WB_LMD,
    input [31:0] MEM_WB_IR,

    output reg        reg_update_flag,
    output reg [4:0]  reg_update_address,
    output reg [31:0] reg_update_data

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
          ADDI  = 6'b001010,
          SUBI  = 6'b001011,
          SLTI  = 6'b001100;


//==================================================
// Write Back Logic
//==================================================

always @(*)
begin

    // Default: no register update

    reg_update_flag    = 1'b0;
    reg_update_address = 5'd0;
    reg_update_data    = 32'd0;


    case(MEM_WB_IR[31:26])


        //==================================
        // R-Type Instructions
        //==================================

        ADD,
        SUB,
        ANDD,
        ORR,
        SLT,
        MUL:
        begin

            reg_update_flag    = 1'b1;

            reg_update_address = MEM_WB_IR[15:11];

            reg_update_data    = MEM_WB_ALUOUT;

        end



        //==================================
        // I-Type Arithmetic
        //==================================

        ADDI,
        SUBI,
        SLTI:
        begin

            reg_update_flag    = 1'b1;

            reg_update_address = MEM_WB_IR[20:16];

            reg_update_data    = MEM_WB_ALUOUT;

        end



        //==================================
        // Load Word
        //==================================

        LW:
        begin

            reg_update_flag    = 1'b1;

            reg_update_address = MEM_WB_IR[20:16];

            reg_update_data    = MEM_WB_LMD;

        end



        default:
        begin

            reg_update_flag = 1'b0;

        end


    endcase

end


endmodule