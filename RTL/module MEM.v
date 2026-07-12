module MEM(

    input clk,
    input reset,

    // EX/MEM Pipeline Registers
    input [31:0] EX_MEM_ALUOUT,
    input [31:0] EX_MEM_IR,
    input [31:0] EX_MEM_B,

    // Data Memory Read Data (async, combinational from DATA_MEMORY)
    input [31:0] data_bus,

    // MEM/WB Pipeline Registers
    output reg [31:0] MEM_WB_IR,
    output reg [31:0] MEM_WB_ALUOUT,
    output reg [31:0] MEM_WB_LMD,

    // Data Memory Interface (combinational — settles within this cycle
    // so DATA_MEMORY's async read reflects THIS instruction's address
    // before MEM_WB_LMD latches it on the next clock edge)
    output [31:0] data_bus_address,
    output        read_enable,
    output        write_enable,
    output [31:0] data_write_data

);

//==================================================
// Opcodes
//==================================================

parameter LW = 6'b001000,
          SW = 6'b001001;


//==================================================
// Combinational Memory Interface
//==================================================

wire isLW = (EX_MEM_IR[31:26] == LW);
wire isSW = (EX_MEM_IR[31:26] == SW);

assign data_bus_address = EX_MEM_ALUOUT;
assign read_enable      = isLW;
assign write_enable     = isSW;
assign data_write_data  = EX_MEM_B;


//==================================================
// MEM/WB Pipeline Register
//==================================================

always @(posedge clk)
begin

    if(reset)
    begin

        MEM_WB_IR     <= 32'h00000000;
        MEM_WB_ALUOUT <= 32'd0;
        MEM_WB_LMD    <= 32'd0;

    end

    else
    begin

        MEM_WB_IR     <= EX_MEM_IR;
        MEM_WB_ALUOUT <= EX_MEM_ALUOUT;

        // data_bus already reflects THIS cycle's data_bus_address
        // (combinational read_enable/address above, async DATA_MEMORY read)
        MEM_WB_LMD    <= data_bus;

    end

end

endmodule