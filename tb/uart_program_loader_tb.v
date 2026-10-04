`timescale 1ns/1ps
module uart_program_loader_tb;
    reg clk = 0, reset = 1, rx_valid = 0, rx_error = 0;
    reg [7:0] rx_data = 0;
    wire [7:0] tx_data;
    wire tx_valid, running, restart, program_we;
    wire [8:0] loaded_words;
    wire [7:0] program_addr;
    wire [31:0] program_data;
    integer failures = 0, writes = 0, n;
    integer received = 0;
    reg [7:0] transcript [0:2047];
    uart_program_loader dut (
        .clk(clk), .reset(reset), .rx_data(rx_data), .rx_valid(rx_valid), .rx_error(rx_error),
        .tx_data(tx_data), .tx_valid(tx_valid), .tx_ready(1'b1),
        .running(running), .restart(restart), .loaded_words(loaded_words),
        .program_we(program_we), .program_addr(program_addr), .program_data(program_data),
        .halted(1'b0), .result(32'd0), .fault_cause(32'd0), .fault_pc(32'd0));
    always #5 clk = ~clk;
    always @(posedge clk) if (tx_valid && !reset) begin
        transcript[received] = tx_data;
        received = received + 1;
    end
    always @(posedge clk) if (program_we) begin
        if (program_addr !== writes[7:0] || program_data !== 32'h00000013) begin
            $display("FAIL: loader RAM write/address"); failures = failures + 1;
        end
        writes = writes + 1;
    end
    task byte_in;
        input [7:0] value;
        begin
            @(negedge clk); rx_data = value; rx_valid = 1;
            @(negedge clk); rx_valid = 0;
        end
    endtask
    task protocol_check;
        input [63:0] command;
        input integer command_length;
        input [271:0] expected;
        input integer expected_length;
        integer start, j;
        begin
            start = received;
            for (j = command_length-1; j >= 0; j = j-1)
                byte_in(command[j*8 +: 8]);
            byte_in(8'h0a);
            repeat (40) @(negedge clk);
            if (received != start + expected_length) begin
                $display("FAIL: protocol reply length"); failures = failures + 1;
            end
            for (j = 0; j < expected_length; j = j+1)
                if (transcript[start+j] !== expected[(expected_length-1-j)*8 +: 8]) begin
                    $display("FAIL: protocol byte %0d: received %02x expected %02x", j,
                        transcript[start+j], expected[(expected_length-1-j)*8 +: 8]);
                    failures = failures + 1;
                end
        end
    endtask
    task word_in;
        begin
            byte_in("0"); byte_in("0"); byte_in("0"); byte_in("0");
            byte_in("0"); byte_in("0"); byte_in("1"); byte_in("3");
            byte_in(8'h0d); byte_in(8'h0a);
            repeat (8) @(negedge clk);
        end
    endtask
    initial begin
        // Also allow the FPGA primitive models' startup reset to finish.
        repeat (20) @(negedge clk); reset = 0;
        protocol_check("STATUS", 6, {"S 0 0 00000000 00000000 00000000", 8'h0d, 8'h0a}, 34);
        protocol_check("STOP", 4, {"OK", 8'h0d, 8'h0a}, 4);
        protocol_check("bad!", 4, {"ERR", 8'h0d, 8'h0a}, 5);
        byte_in("L"); byte_in("O"); byte_in("A"); byte_in("D"); byte_in(8'h0a);
        repeat (8) @(negedge clk);
        for (n = 0; n < 256; n = n + 1) word_in;
        if (writes != 256 || loaded_words != 256) begin
            $display("FAIL: RAM capacity/CRLF uploads"); failures = failures + 1;
        end
        word_in;
        if (writes != 256 || loaded_words != 256) begin
            $display("FAIL: overflow wraps instruction RAM"); failures = failures + 1;
        end
        byte_in("R"); byte_in("U"); byte_in("N"); byte_in(8'h0a);
        repeat (8) @(negedge clk);
        if (!running) begin $display("FAIL: full RAM program cannot run"); failures = failures + 1; end
        reset = 1; repeat (3) @(negedge clk);
        if (running || loaded_words != 256) begin
            $display("FAIL: button reset/valid program retention"); failures = failures + 1;
        end
        if (failures == 0) $display("PASS: uart_program_loader (exact reply bytes, CRLF, full RAM, overflow, reset)");
        else $display("FAIL: uart_program_loader (%0d failures)", failures);
        $finish;
    end
    initial begin #200000; $display("FAIL: loader timeout"); $finish; end
endmodule
