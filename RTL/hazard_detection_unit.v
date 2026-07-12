module HAZARD_UNIT(
    input [31:0] IF_ID_IR,
    input [31:0] ID_EX_IR,
    input [31:0] EX_MEM_IR,
    input [31:0] MEM_WB_IR,

    output reg load_hazard,
    output reg [1:0] ForwardA,
    output reg [1:0] ForwardB
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
// Instruction Type Detection
//==================================================
wire EX_MEM_isRtype;
wire EX_MEM_isItype;
wire EX_MEM_isLW;

wire MEM_WB_isRtype;
wire MEM_WB_isItype;
wire MEM_WB_isLW;

wire ID_EX_isLW;

assign EX_MEM_isRtype =
       (EX_MEM_IR[31:26] >= ADD) &&
       (EX_MEM_IR[31:26] <= MUL);

assign EX_MEM_isItype =
       (EX_MEM_IR[31:26] >= ADDI) &&
       (EX_MEM_IR[31:26] <= SLTI);

assign EX_MEM_isLW =
       (EX_MEM_IR[31:26] == LW);

assign MEM_WB_isRtype =
       (MEM_WB_IR[31:26] >= ADD) &&
       (MEM_WB_IR[31:26] <= MUL);

assign MEM_WB_isItype =
       (MEM_WB_IR[31:26] >= ADDI) &&
       (MEM_WB_IR[31:26] <= SLTI);

assign MEM_WB_isLW =
       (MEM_WB_IR[31:26] == LW);

assign ID_EX_isLW =
       (ID_EX_IR[31:26] == LW);

//==================================================
// Convenience: source register addresses being read
// by the instruction currently sitting in ID/EX
// (i.e. the one about to enter EX and use the ALU)
//==================================================
wire [4:0] rs_ID_EX = ID_EX_IR[25:21];
wire [4:0] rt_ID_EX = ID_EX_IR[20:16];

//==================================================
// Forwarding Logic
//==================================================
always @(*)
begin
    ForwardA = 2'b00;
    ForwardB = 2'b00;

    //------------------------------
    // Operand A : Rs
    //------------------------------
    if(rs_ID_EX != 5'd0)
    begin
        if(EX_MEM_isRtype &&
           (EX_MEM_IR[15:11] == rs_ID_EX))
        begin
            ForwardA = 2'b10;
        end
        else if((EX_MEM_isItype || EX_MEM_isLW) &&
                (EX_MEM_IR[20:16] == rs_ID_EX))
        begin
            ForwardA = 2'b10;
        end
        else if(MEM_WB_isRtype &&
                (MEM_WB_IR[15:11] == rs_ID_EX))
        begin
            ForwardA = 2'b01;
        end
        else if(MEM_WB_isItype &&
                (MEM_WB_IR[20:16] == rs_ID_EX))
        begin
            ForwardA = 2'b01;
        end
        else if(MEM_WB_isLW &&
                (MEM_WB_IR[20:16] == rs_ID_EX))
        begin
            ForwardA = 2'b11;
        end
    end

    //------------------------------
    // Operand B : Rt
    //------------------------------
    if(rt_ID_EX != 5'd0)
    begin
        if(EX_MEM_isRtype &&
           (EX_MEM_IR[15:11] == rt_ID_EX))
        begin
            ForwardB = 2'b10;
        end
        else if((EX_MEM_isItype || EX_MEM_isLW) &&
                (EX_MEM_IR[20:16] == rt_ID_EX))
        begin
            ForwardB = 2'b10;
        end
        else if(MEM_WB_isRtype &&
                (MEM_WB_IR[15:11] == rt_ID_EX))
        begin
            ForwardB = 2'b01;
        end
        else if(MEM_WB_isItype &&
                (MEM_WB_IR[20:16] == rt_ID_EX))
        begin
            ForwardB = 2'b01;
        end
        else if(MEM_WB_isLW &&
                (MEM_WB_IR[20:16] == rt_ID_EX))
        begin
            ForwardB = 2'b11;
        end
    end
end

//==================================================
// Load Hazard Detection
//==================================================
always @(*)
begin
    load_hazard = 1'b0;

    // If instruction in ID/EX (about to enter EX) is LW,
    // and instruction currently in IF/ID (in ID stage) needs
    // that same destination register, we must stall one cycle.
    if(ID_EX_isLW && (ID_EX_IR[20:16] != 5'd0))
    begin
        if((ID_EX_IR[20:16] == IF_ID_IR[25:21]) ||
           (ID_EX_IR[20:16] == IF_ID_IR[20:16]))
        begin
            load_hazard = 1'b1;
        end
    end
end

endmodule