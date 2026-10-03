`timescale 1ns/1ps
module load_result_register_tb;
    reg clk = 0, reset = 1, write_enable = 1;
    integer i;
    reg [31:0] load_data = 32'hdeadbeef;
    wire [31:0] saved_load_data;
    reg [31:0] expected_saved_load_data;

    load_result_register dut (.clk(clk), .reset(reset), .write_enable(write_enable), .load_data(load_data), .saved_load_data(saved_load_data));

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
        expected_saved_load_data = 32'd0;
        check(saved_load_data === expected_saved_load_data, "reset overrides enabled capture");
        reset = 0;
        for (i = 0; i < 64; i = i + 1) begin
            write_enable = (i % 3 != 0);
            load_data = $random;
            #1;
            check(saved_load_data === expected_saved_load_data, "output cannot change before clock edge");
            tick;
            if (write_enable) expected_saved_load_data = load_data;
            check(saved_load_data === expected_saved_load_data, "enabled capture or disabled hold");

        end

        reset = 1;
        #1;
        check(saved_load_data === expected_saved_load_data, "reset is synchronous");
        tick;
        check(saved_load_data === 32'd0, "reset clears captured value");

        if (failures == 0) $display("PASS: load_result_register (%0d checks)", checks);
        else $display("FAIL: load_result_register (%0d failures)", failures);
        $finish;

    end
endmodule

