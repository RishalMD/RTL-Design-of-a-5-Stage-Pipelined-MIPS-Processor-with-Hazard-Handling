module INSTRUCTION_MEMORY(

    input [31:0] instruction_address_bus,

    output reg [31:0] instruction_bus

);


//==================================================
// Instruction Memory
//==================================================

reg [31:0] memory [0:1023];


//==================================================
// Load Program (simulation only)
//==================================================

initial begin
    $readmemh("program_loaduse.hex", memory);
end


//==================================================
// Asynchronous Instruction Read
//==================================================

always @(*)
begin

    instruction_bus = memory[instruction_address_bus];

end


endmodule