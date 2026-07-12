`timescale 1ns/1ps

module tb_MIPS_TOP_loaduse;

    reg clk;
    reg reset;

    MIPS_TOP dut(
        .clk   (clk),
        .reset (reset)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        reset = 1;
        #12;
        reset = 0;
    end

    initial begin
        $dumpfile("wave_loaduse.vcd");
        $dumpvars(0, tb_MIPS_TOP_loaduse);
    end

    initial begin
        #300;

        $display("---------------------------------------------");
        $display("R1 = %0d  (expect 88)", dut.id_stage.registerbank[1]);
        $display("R2 = %0d  (expect 8)",  dut.id_stage.registerbank[2]);
        $display("R5 = %0d  (expect 88, loaded from memory)", dut.id_stage.registerbank[5]);
        $display("R6 = %0d  (expect 88 -- must stall + forward via MEM_WB_LMD, not read stale garbage)", dut.id_stage.registerbank[6]);
        $display("R7 = %0d  (expect 5)",  dut.id_stage.registerbank[7]);
        $display("R8 = %0d  (expect 93)", dut.id_stage.registerbank[8]);
        $display("---------------------------------------------");

        if (dut.id_stage.registerbank[1] == 32'd88 &&
            dut.id_stage.registerbank[2] == 32'd8  &&
            dut.id_stage.registerbank[5] == 32'd88 &&
            dut.id_stage.registerbank[6] == 32'd88 &&
            dut.id_stage.registerbank[7] == 32'd5  &&
            dut.id_stage.registerbank[8] == 32'd93)
            $display("TEST PASSED: load-use hazard stall + forwarding correct");
        else
            $display("TEST FAILED: check load_hazard detection / stall / ForwardA-B==2'b11 path");

        $finish;
    end

endmodule
