`timescale 1ns/1ps
// Exercise actual GCC output through the FPGA top's physical UART interface.
module compiled_c_tb;
    localparam BIT_NS = 100;
    reg clk = 0, reset = 1, rx = 1;
    wire tx, halted;
    wire [7:0] leds;
    reg [31:0] words [0:56];
    reg [7:0] transcript [0:1023];
    reg [7:0] value;
    integer received = 0, failures = 0, k, n, first, run_number;
    rv32i_fpga_top #(.BAUD(10000000)) dut (
        .clk(clk), .reset(reset), .uart_rx(rx), .uart_tx(tx), .leds(leds), .halted(halted));
    always #5 clk = ~clk;
    initial forever begin
        @(negedge tx); #(BIT_NS + BIT_NS/2);
        for (k = 0; k < 8; k = k+1) begin
            value[k] = tx; #(BIT_NS);
        end
        if (tx !== 1) begin $display("FAIL: C program UART stop bit"); failures = failures+1; end
        transcript[received] = value; received = received+1;
    end
    task send_byte;
        input [7:0] byte_value;
        integer bit_number;
        begin
            rx = 0; #(BIT_NS);
            for (bit_number = 0; bit_number < 8; bit_number = bit_number+1) begin
                rx = byte_value[bit_number]; #(BIT_NS);
            end
            rx = 1; #(BIT_NS);
        end
    endtask
    task command;
        input [63:0] text;
        input integer length;
        integer j, start;
        begin
            start = received;
            for (j = length-1; j >= 0; j = j-1) send_byte(text[j*8 +: 8]);
            send_byte(8'h0d);
            wait(received >= start+4);
            if ({transcript[start], transcript[start+1], transcript[start+2], transcript[start+3]}
                !== {"OK", 8'h0d, 8'h0a}) begin
                $display("FAIL: C upload acknowledgement"); failures = failures+1;
            end
            #(BIT_NS);
        end
    endtask
    function [63:0] hex_ascii;
        input [31:0] word;
        integer j;
        reg [3:0] digit;
        begin
            for (j = 0; j < 8; j = j+1) begin
                digit = word[28-4*j +: 4];
                hex_ascii[63-8*j -: 8] = digit < 10 ? 8'h30+digit : 8'h41+digit-10;
            end
        end
    endfunction
    initial begin
        $readmemh("examples/c/fibonacci.hex", words);
        repeat (4) @(negedge clk); reset = 0;
        repeat (5) @(negedge clk);
        command("LOAD", 4);
        for (n = 0; n < 57; n = n+1) command(hex_ascii(words[n]), 8);
        // Startup must initialize globals even after a previous program used RAM.
        dut.ram[0] = 32'hdeadbeef;
        for (run_number = 0; run_number < 2; run_number = run_number+1) begin
            first = received;
            command("RUN", 3);
            wait(halted);
            wait(received >= first+10);
            if (dut.result !== 55 || leds !== 8'h37 || dut.fault_cause !== 3 || dut.ram[0] !== 10) begin
                $display("FAIL: compiled Fibonacci result/startup on run %0d", run_number);
                failures = failures+1;
            end
            if ({transcript[first+4], transcript[first+5], transcript[first+6],
                 transcript[first+7], transcript[first+8], transcript[first+9]}
                !== {"F=55", 8'h0d, 8'h0a}) begin
                $display("FAIL: compiled C UART output"); failures = failures+1;
            end
            #(BIT_NS);
        end
        if (failures == 0) $display("PASS: compiled C (UART upload, Fibonacci=55, stack, BSS initialization, rerun)");
        else $display("FAIL: compiled C (%0d failures)", failures);
        $finish;
    end
    initial begin #3000000; $display("FAIL: compiled C timeout"); $finish; end
endmodule
