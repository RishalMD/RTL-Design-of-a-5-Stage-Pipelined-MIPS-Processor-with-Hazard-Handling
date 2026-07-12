module DATA_MEMORY(

    input clk,
    input reset,

    input [31:0] data_bus_address,

    input read_enable,
    input write_enable,

    input [31:0] data_write_data,

    output reg [31:0] data_bus

);


//==================================================
// Memory Array
//==================================================

reg [31:0] memory [0:1023];


//==================================================
// Asynchronous Read
//==================================================

always @(*)
begin

    if(read_enable)
        data_bus = memory[data_bus_address];

    else
        data_bus = 32'd0;

end



//==================================================
// Synchronous Write
//==================================================

integer i;

always @(posedge clk)
begin

    if(reset)
    begin

        for(i=0; i<1024; i=i+1)
            memory[i] <= 32'd0;

    end

    else if(write_enable)
    begin

        memory[data_bus_address] <= data_write_data;

    end

end


endmodule