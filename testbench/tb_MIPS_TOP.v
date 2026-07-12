`timescale 1ns/1ps

module tb_MIPS_TOP;

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
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_MIPS_TOP);
    end

    //==================================================
    // Run and check result
    //==================================================
    initial begin
        // enough cycles for 5 instructions to fully drain
        // through IF->ID->EX->MEM->WB, plus reset time
        #200;

        $display("---------------------------------------------");
        $display("R1 = %0d", dut.id_stage.registerbank[1]);
        $display("R2 = %0d", dut.id_stage.registerbank[2]);
        $display("R3 = %0d", dut.id_stage.registerbank[3]);
        $display("R4 = %0d", dut.id_stage.registerbank[4]);
        $display("---------------------------------------------");

        if (dut.id_stage.registerbank[4] == 32'd60)
            $display("TEST PASSED: R4 = 60 as expected");
        else
            $display("TEST FAILED: R4 = %0d, expected 60", dut.id_stage.registerbank[4]);

        $finish;
    end

endmodule
