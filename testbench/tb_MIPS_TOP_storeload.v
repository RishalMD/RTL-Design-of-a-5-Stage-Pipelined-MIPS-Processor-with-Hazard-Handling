`timescale 1ns/1ps

module tb_MIPS_TOP_storeload;

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
        $dumpfile("wave_storeload.vcd");
        $dumpvars(0, tb_MIPS_TOP_storeload);
    end

    initial begin
        #300;

        $display("---------------------------------------------");
        $display("R1 = %0d  (expect 77)",  dut.id_stage.registerbank[1]);
        $display("R2 = %0d  (expect 4)",   dut.id_stage.registerbank[2]);
        $display("R3 = %0d  (expect 55)",  dut.id_stage.registerbank[3]);
        $display("R4 = %0d  (expect 77, loaded back from memory)", dut.id_stage.registerbank[4]);
        $display("R5 = %0d  (expect 78)",  dut.id_stage.registerbank[5]);
        $display("R6 = %0d  (expect 1)",   dut.id_stage.registerbank[6]);
        $display("---------------------------------------------");

        if (dut.id_stage.registerbank[1] == 32'd77 &&
            dut.id_stage.registerbank[2] == 32'd4  &&
            dut.id_stage.registerbank[3] == 32'd55 &&
            dut.id_stage.registerbank[4] == 32'd77 &&
            dut.id_stage.registerbank[5] == 32'd78 &&
            dut.id_stage.registerbank[6] == 32'd1)
            $display("TEST PASSED: store/load round-trip correct");
        else
            $display("TEST FAILED: check DATA_MEMORY read/write timing");

        $finish;
    end

endmodule
