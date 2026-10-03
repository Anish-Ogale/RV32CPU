`timescale 1ns/1ps
module alu_result_register_tb;
    reg clk = 0, reset = 1, write_enable = 1;
    integer i;
    reg [31:0] alu_result = 32'hdeadbeef;
    wire [31:0] saved_result;
    reg [31:0] expected_saved_result;

    alu_result_register dut (.clk(clk), .reset(reset), .write_enable(write_enable), .alu_result(alu_result), .saved_result(saved_result));

    integer checks = 0;
    integer failures = 0;
    task check;
        input condition;
        input [511:0] description;
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                failures = failures + 1;
                $display("FAIL: %0s (check %0d)", description, checks);
            end
        end
    endtask

    task tick;
        begin
            #5 clk = 1'b1;
            #1 clk = 1'b0;
            #4;
        end
    endtask

    initial begin
        tick;
        expected_saved_result = 32'd0;
        check(saved_result === expected_saved_result, "reset overrides enabled capture");
        reset = 0;
        for (i = 0; i < 64; i = i + 1) begin
            write_enable = (i % 3 != 0);
            alu_result = $random;
            #1;
            check(saved_result === expected_saved_result, "output cannot change before clock edge");
            tick;
            if (write_enable) expected_saved_result = alu_result;
            check(saved_result === expected_saved_result, "enabled capture or disabled hold");

        end

        reset = 1;
        #1;
        check(saved_result === expected_saved_result, "reset is synchronous");
        tick;
        check(saved_result === 32'd0, "reset clears captured value");

        if (failures == 0) $display("PASS: alu_result_register (%0d checks)", checks);
        else $display("FAIL: alu_result_register (%0d failures)", failures);
        $finish;

    end
endmodule

