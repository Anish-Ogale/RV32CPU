`timescale 1ns/1ps
module uart_diagnostic_top_tb;
    reg clk = 0, reset = 1, rx = 1;
    wire raw_tx, echo_tx;
    wire [7:0] raw_leds, echo_leds;
    wire raw_halt, echo_halt;
    integer failures = 0, bit_number;
    reg [7:0] captured;
    uart_diagnostic_top #(.BAUD(10000000)) raw (
        .clk(clk), .reset(reset), .uart_rx(rx), .uart_tx(raw_tx),
        .leds(raw_leds), .halted(raw_halt));
    uart_diagnostic_top #(.BAUD(10000000), .RAW_LOOPBACK(0)) echo (
        .clk(clk), .reset(reset), .uart_rx(rx), .uart_tx(echo_tx),
        .leds(echo_leds), .halted(echo_halt));
    always #5 clk = ~clk;
    always @(raw_tx or rx) begin
        #1;
        if (raw_tx !== rx) begin $display("FAIL: direct wire loopback"); failures = failures+1; end
    end
    initial begin
        repeat (4) @(negedge clk); reset = 0;
        repeat (4) @(negedge clk);
        rx = 0; #100;
        for (bit_number=0; bit_number<8; bit_number=bit_number+1) begin
            rx = (8'ha5 >> bit_number) & 1; #100;
        end
        rx = 1;
        @(negedge echo_tx); #150;
        for (bit_number=0; bit_number<8; bit_number=bit_number+1) begin
            captured[bit_number] = echo_tx; #100;
        end
        if (captured !== 8'ha5 || echo_tx !== 1 || !echo_leds[1] || !echo_leds[2]) begin
            $display("FAIL: decoded echo and activity LEDs"); failures = failures+1;
        end
        reset = 1; repeat (4) @(negedge clk);
        if (!raw_leds[3] || !echo_leds[3] || !raw_leds[7] || raw_halt || echo_halt) begin
            $display("FAIL: reset/diagnostic indicators"); failures = failures+1;
        end
        rx = 0; #20; // Raw mode still echoes while reset is held.
        if (raw_tx !== 0) begin $display("FAIL: raw reset independence"); failures = failures+1; end
        if (failures == 0) $display("PASS: uart_diagnostic_top (wire loopback, UART echo, indicators)");
        else $display("FAIL: uart_diagnostic_top (%0d failures)", failures);
        $finish;
    end
    initial begin #10000; $display("FAIL: diagnostic timeout"); $finish; end
endmodule
