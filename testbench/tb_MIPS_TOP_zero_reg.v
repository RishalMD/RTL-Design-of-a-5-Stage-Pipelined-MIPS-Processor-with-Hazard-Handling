`timescale 1ns/1ps

module tb_MIPS_TOP_zero_reg;

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
        $dumpfile("wave_zero_reg.vcd");
        $dumpvars(0, tb_MIPS_TOP_zero_reg);
    end

    initial begin
        #300;

        $display("---------------------------------------------");
        $display("R1 = %0d  (expect 25)", dut.id_stage.registerbank[1]);
        $display("R2 = %0d  (expect 17)", dut.id_stage.registerbank[2]);
        $display("R4 = %0d  (expect 0 -- must NOT be 84, which would mean $0 was wrongly forwarded)", dut.id_stage.registerbank[4]);
        $display("R5 = %0d  (expect 25)", dut.id_stage.registerbank[5]);
        $display("---------------------------------------------");

        if (dut.id_stage.registerbank[1] == 32'd25 &&
            dut.id_stage.registerbank[2] == 32'd17 &&
            dut.id_stage.registerbank[4] == 32'd0  &&
            dut.id_stage.registerbank[5] == 32'd25)
            $display("TEST PASSED: $0 forwarding exclusion works correctly");
        else
            $display("TEST FAILED: check HAZARD_UNIT $0 exclusion guard");

        $finish;
    end

endmodule
