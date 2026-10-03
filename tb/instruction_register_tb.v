`timescale 1ns/1ps
module instruction_register_tb;
    reg clk = 0, reset = 1, write_enable = 1;
    integer i;
    reg [31:0] fetched_instruction = 32'hdeadbeef;
    wire [31:0] instruction;
    reg [31:0] expected_instruction;
    reg [31:0] fetch_pc = 32'hdeadbeef;
    wire [31:0] instruction_pc;
    reg [31:0] expected_instruction_pc;

    instruction_register dut (.clk(clk), .reset(reset), .write_enable(write_enable), .fetched_instruction(fetched_instruction), .instruction(instruction), .fetch_pc(fetch_pc), .instruction_pc(instruction_pc));

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
        expected_instruction = 32'h00000013;
        check(instruction === expected_instruction, "reset overrides enabled capture");
        expected_instruction_pc = 32'd0;
        check(instruction_pc === expected_instruction_pc, "reset overrides enabled capture");
        reset = 0;
        for (i = 0; i < 64; i = i + 1) begin
            write_enable = (i % 3 != 0);
            fetched_instruction = $random;
            fetch_pc = $random;
            #1;
            check(instruction === expected_instruction, "output cannot change before clock edge");
            check(instruction_pc === expected_instruction_pc, "output cannot change before clock edge");
            tick;
            if (write_enable) expected_instruction = fetched_instruction;
            check(instruction === expected_instruction, "enabled capture or disabled hold");
            if (write_enable) expected_instruction_pc = fetch_pc;
            check(instruction_pc === expected_instruction_pc, "enabled capture or disabled hold");

        end

        reset = 1;
        #1;
        check(instruction === expected_instruction, "reset is synchronous");
        check(instruction_pc === expected_instruction_pc, "reset is synchronous");
        tick;
        check(instruction === 32'h00000013, "reset clears captured value");
        check(instruction_pc === 32'd0, "reset clears captured value");

        if (failures == 0) $display("PASS: instruction_register (%0d checks)", checks);
        else $display("FAIL: instruction_register (%0d failures)", failures);
        $finish;

    end
endmodule

