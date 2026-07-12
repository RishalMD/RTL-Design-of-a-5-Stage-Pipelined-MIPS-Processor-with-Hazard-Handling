module ID(

    input clk,
    input reset,

    input branch_flag,
    input load_hazard,

    input [31:0] IF_ID_NPC,
    input [31:0] IF_ID_IR,

    // Write Back Interface
    input        reg_update_flag,
    input [4:0]  reg_update_address,
    input [31:0] reg_update_data,

    // ID/EX Pipeline Registers
    output reg [31:0] ID_EX_A,
    output reg [31:0] ID_EX_B,
    output reg [31:0] ID_EX_NPC,
    output reg [31:0] ID_EX_IR,
    output reg [31:0] ID_EX_Imm

);

//====================================================
// Register Bank
//====================================================

reg [31:0] registerbank [0:31];

//====================================================
// Source Register Addresses
//====================================================

wire [4:0] rs_addr;
wire [4:0] rt_addr;

assign rs_addr = IF_ID_IR[25:21];
assign rt_addr = IF_ID_IR[20:16];

//====================================================
// Internal Write-Back Forwarding
//====================================================
integer i;
wire [31:0] rs_data;
wire [31:0] rt_data;

assign rs_data =
    (reg_update_flag &&
     (reg_update_address == rs_addr) &&
     (rs_addr != 5'd0))
    ? reg_update_data
    : registerbank[rs_addr];

assign rt_data =
    (reg_update_flag &&
     (reg_update_address == rt_addr) &&
     (rt_addr != 5'd0))
    ? reg_update_data
    : registerbank[rt_addr];

//====================================================
// Write Back
//====================================================

always @(posedge clk)
begin

    if(reset)
    begin
        

        for(i=0;i<32;i=i+1)
            registerbank[i] <= 32'd0;
    end

    else if(reg_update_flag && (reg_update_address != 5'd0))
    begin
        registerbank[reg_update_address] <= reg_update_data;
    end

end

//====================================================
// ID/EX Pipeline Register
//====================================================

always @(posedge clk)
begin

    if(reset)
    begin

        ID_EX_A   <= 32'd0;
        ID_EX_B   <= 32'd0;
        ID_EX_NPC <= 32'd0;
        ID_EX_IR  <= 32'h00000000;      // NOP
        ID_EX_Imm <= 32'd0;

    end

    // Flush on taken branch
    else if(branch_flag)
    begin

        ID_EX_A   <= 32'd0;
        ID_EX_B   <= 32'd0;
        ID_EX_NPC <= 32'd0;
        ID_EX_IR  <= 32'h00000000;      // NOP
        ID_EX_Imm <= 32'd0;

    end

    // Insert Bubble on Load Hazard
    else if(load_hazard)
    begin

        ID_EX_A   <= 32'd0;
        ID_EX_B   <= 32'd0;
        ID_EX_NPC <= 32'd0;
        ID_EX_IR  <= 32'h00000000;      // NOP
        ID_EX_Imm <= 32'd0;

    end

    // Normal Decode
    else
    begin

        ID_EX_A   <= rs_data;
        ID_EX_B   <= rt_data;

        ID_EX_NPC <= IF_ID_NPC;
        ID_EX_IR  <= IF_ID_IR;

        ID_EX_Imm <= {{16{IF_ID_IR[15]}}, IF_ID_IR[15:0]};

    end

end

endmodule