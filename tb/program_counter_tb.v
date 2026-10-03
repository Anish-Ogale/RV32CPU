`timescale 1ns/1ps
module program_counter_tb;
    reg clk = 0, reset = 1, write_enable = 1;
    integer i;
    reg [31:0] next_pc = 32'hdeadbeef;
    wire [31:0] current_pc;
    reg [31:0] expected_current_pc;
    wire [31:0] pc_plus_four;
    program_counter dut (.clk(clk), .reset(reset), .write_enable(write_enable), .next_pc(next_pc), .current_pc(current_pc), .pc_plus_four(pc_plus_four));

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
        expected_current_pc = 32'd0;
        check(current_pc === expected_current_pc, "reset overrides enabled capture");
        reset = 0;
        for (i = 0; i < 64; i = i + 1) begin
            write_enable = (i % 3 != 0);
            next_pc = $random;
            #1;
            check(current_pc === expected_current_pc, "output cannot change before clock edge");
            tick;
            if (write_enable) expected_current_pc = next_pc;
            check(current_pc === expected_current_pc, "enabled capture or disabled hold");
            check(pc_plus_four === expected_current_pc + 32'd4, "PC plus four");
        end
        next_pc = 32'hfffffffc; write_enable = 1; tick;
        check(current_pc == 32'hfffffffc && pc_plus_four == 0, "PC increment wraps at 32 bits");
        expected_current_pc = current_pc;
        reset = 1;
        #1;
        check(current_pc === expected_current_pc, "reset is synchronous");
        tick;
        check(current_pc === 32'd0, "reset clears captured value");

        if (failures == 0) $display("PASS: program_counter (%0d checks)", checks);
        else $display("FAIL: program_counter (%0d failures)", failures);
        $finish;

    end
endmodule

