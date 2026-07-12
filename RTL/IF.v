module IF(

    input clk,
    input reset,

    input branch_flag,
    input load_hazard,

    input [31:0] branch_target,

    input [31:0] instruction_bus,

    output [31:0] instruction_address_bus,

    output reg [31:0] IF_ID_IR,
    output reg [31:0] IF_ID_NPC

);

reg [31:0] PC;

//--------------------------------------------
// Instruction Memory Address
//--------------------------------------------

assign instruction_address_bus = PC;

//--------------------------------------------
// PC Update
//--------------------------------------------

always @(posedge clk)
begin

    if(reset)
        PC <= 32'd0;

    else if(branch_flag)
        PC <= branch_target;

    else if(load_hazard)
        PC <= PC;          // Stall

    else
        PC <= PC + 32'd1;  // Use +4 if byte addressed

end

//--------------------------------------------
// IF/ID Pipeline Register
//--------------------------------------------

always @(posedge clk)
begin

    if(reset)
    begin
        IF_ID_IR  <= 32'd0;
        IF_ID_NPC <= 32'd0;
    end

    // Flush on taken branch
    else if(branch_flag)
    begin
        IF_ID_IR  <= 32'd0;      // NOP
        IF_ID_NPC <= 32'd0;
    end

    // Stall on load hazard
    else if(load_hazard)
    begin
        IF_ID_IR  <= IF_ID_IR;
        IF_ID_NPC <= IF_ID_NPC;
    end

    // Normal Operation
    else
    begin
        IF_ID_IR  <= instruction_bus;
        IF_ID_NPC <= PC + 32'd1;
    end

end

endmodule