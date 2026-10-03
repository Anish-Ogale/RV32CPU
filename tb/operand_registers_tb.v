`timescale 1ns/1ps
module operand_registers_tb;
    reg clk = 0, reset = 1, write_enable = 1;
    integer i;
    reg [31:0] rs1_data = 32'hdeadbeef;
    wire [31:0] operand_a;
    reg [31:0] expected_operand_a;
    reg [31:0] rs2_data = 32'hdeadbeef;
    wire [31:0] operand_b;
    reg [31:0] expected_operand_b;

    operand_registers dut (.clk(clk), .reset(reset), .write_enable(write_enable), .rs1_data(rs1_data), .operand_a(operand_a), .rs2_data(rs2_data), .operand_b(operand_b));

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
        expected_operand_a = 32'd0;
        check(operand_a === expected_operand_a, "reset overrides enabled capture");
        expected_operand_b = 32'd0;
        check(operand_b === expected_operand_b, "reset overrides enabled capture");
        reset = 0;
        for (i = 0; i < 64; i = i + 1) begin
            write_enable = (i % 3 != 0);
            rs1_data = $random;
            rs2_data = $random;
            #1;
            check(operand_a === expected_operand_a, "output cannot change before clock edge");
            check(operand_b === expected_operand_b, "output cannot change before clock edge");
            tick;
            if (write_enable) expected_operand_a = rs1_data;
            check(operand_a === expected_operand_a, "enabled capture or disabled hold");
            if (write_enable) expected_operand_b = rs2_data;
            check(operand_b === expected_operand_b, "enabled capture or disabled hold");

        end

        reset = 1;
        #1;
        check(operand_a === expected_operand_a, "reset is synchronous");
        check(operand_b === expected_operand_b, "reset is synchronous");
        tick;
        check(operand_a === 32'd0, "reset clears captured value");
        check(operand_b === 32'd0, "reset clears captured value");

        if (failures == 0) $display("PASS: operand_registers (%0d checks)", checks);
        else $display("FAIL: operand_registers (%0d failures)", failures);
        $finish;

    end
endmodule

