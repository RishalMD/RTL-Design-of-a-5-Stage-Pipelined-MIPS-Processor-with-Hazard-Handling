`timescale 1ns/1ps

module tb_MIPS_TOP_branch;

    reg clk;
    reg reset;

    MIPS_TOP dut(
        .clk   (clk),
        .reset (reset)
    );

    //==================================================
    // Clock generation
    //==================================================
    initial clk = 0;
    always #5 clk = ~clk;   // 10ns period

    //==================================================
    // Reset
    //==================================================
    initial begin
        reset = 1;
        #12;
        reset = 0;
    end

    //==================================================
    // Waveform dump
    //==================================================
    initial begin
        $dumpfile("wave_branch.vcd");
        $dumpvars(0, tb_MIPS_TOP_branch);
    end

    //==================================================
    // Run and check result
    //==================================================
    initial begin
        // extra margin for branch flush + pipeline drain
        #400;

        $display("---------------------------------------------");
        $display("R1 = %0d  (expect 0)",   dut.id_stage.registerbank[1]);
        $display("R2 = %0d  (expect 0, wrong-path, must be flushed)",   dut.id_stage.registerbank[2]);
        $display("R3 = %0d  (expect 0, wrong-path, must be flushed)",   dut.id_stage.registerbank[3]);
        $display("R4 = %0d  (expect 0, wrong-path, must be flushed)",   dut.id_stage.registerbank[4]);
        $display("R5 = %0d  (expect 99, branch target)",  dut.id_stage.registerbank[5]);
        $display("R6 = %0d  (expect 99, forwarded from R5)", dut.id_stage.registerbank[6]);
        $display("---------------------------------------------");

        if (dut.id_stage.registerbank[2] == 32'd0 &&
            dut.id_stage.registerbank[3] == 32'd0 &&
            dut.id_stage.registerbank[4] == 32'd0 &&
            dut.id_stage.registerbank[5] == 32'd99 &&
            dut.id_stage.registerbank[6] == 32'd99)
            $display("TEST PASSED: branch flush and target execution correct");
        else
            $display("TEST FAILED: check flush logic / branch target / forwarding");

        $finish;
    end

endmodule
