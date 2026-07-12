module BRANCH_PREDICTION_UNIT(

    input EX_MEM_COND,

    input [31:0] EX_MEM_IR,

    output reg branch_flag

);


//==================================================
// Opcodes
//==================================================

parameter BNEQZ = 6'b001101,
          BEQZ  = 6'b001110;


//==================================================
// Branch Detection
//==================================================

wire EX_MEM_isBranch;


assign EX_MEM_isBranch =
       (EX_MEM_IR[31:26] == BEQZ) ||
       (EX_MEM_IR[31:26] == BNEQZ);


//==================================================
// Branch Decision
//==================================================

always @(*)
begin

    branch_flag = 1'b0;

    if(EX_MEM_COND && EX_MEM_isBranch)
        branch_flag = 1'b1;

end


endmodule