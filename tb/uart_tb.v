`timescale 1ns/1ps
module uart_tb;
    reg clk = 0, reset = 1, rx = 1, tx_valid = 0;
    reg [7:0] tx_data = 0;
    wire tx, rx_valid, rx_error, tx_ready;
    wire [7:0] rx_data;
    integer failures = 0, rx_count = 0, errors = 0, tx_count = 0;
    integer n, bit_number;
    reg [7:0] expected_rx = 0, expected_tx = 0, captured;
    reg slow_rx = 1;
    wire [7:0] slow_data;
    wire slow_valid;
    integer slow_count = 0, slow_bit;
    localparam BIT_NS = 160;
    uart #(.CLOCK_HZ(16000000), .BAUD(1000000)) dut (
        .clk(clk), .reset(reset), .rx(rx), .tx(tx),
        .rx_data(rx_data), .rx_valid(rx_valid), .rx_error(rx_error),
        .tx_data(tx_data), .tx_valid(tx_valid), .tx_ready(tx_ready));
    // Verify the actual 100 MHz/115200 configuration as well as fast tests.
    uart board_uart (.clk(clk), .reset(reset), .rx(slow_rx), .tx(),
        .rx_data(slow_data), .rx_valid(slow_valid), .rx_error(),
        .tx_data(8'd0), .tx_valid(1'b0), .tx_ready());
    always #5 clk = ~clk;
    always @(posedge clk) begin
        if (slow_valid) begin
            slow_count = slow_count + 1;
            if (slow_data !== 8'h53) begin
                $display("FAIL: default 115200-baud receive"); failures = failures + 1;
            end
        end
        if (rx_valid) begin
            if (rx_data !== expected_rx) begin
                $display("FAIL: RX byte %h expected %h", rx_data, expected_rx);
                failures = failures + 1;
            end
            rx_count = rx_count + 1;
        end
        if (rx_error) errors = errors + 1;
    end
    initial forever begin
        @(negedge tx); #(BIT_NS + BIT_NS/2);
        for (bit_number = 0; bit_number < 8; bit_number = bit_number + 1) begin
            captured[bit_number] = tx; #(BIT_NS);
        end
        if (captured !== expected_tx || tx !== 1) begin
            $display("FAIL: TX data/stop bit"); failures = failures + 1;
        end
        tx_count = tx_count + 1;
    end
    task send;
        input [7:0] value;
        input stop;
        integer b;
        begin
            rx = 0; #(BIT_NS);
            for (b = 0; b < 8; b = b + 1) begin
                rx = value[b]; #(BIT_NS);
            end
            rx = stop; #(BIT_NS); rx = 1; #(BIT_NS);
        end
    endtask
    initial begin
        repeat (3) @(negedge clk); reset = 0;
        // Glitch shorter than half a bit must not produce a byte.
        rx = 0; #30; rx = 1; #(2*BIT_NS);
        if (rx_count != 0) begin $display("FAIL: false start"); failures = failures + 1; end
        for (n = 0; n < 256; n = n + 1) begin
            expected_rx = n; expected_tx = n;
            @(negedge clk); tx_data = n; tx_valid = 1;
            @(negedge clk); tx_valid = 0;
            send(n, 1); // Full-duplex transfer of every possible byte.
            wait(tx_ready);
        end
        if (rx_count != 256 || tx_count != 256) begin
            $display("FAIL: full-duplex byte counts"); failures = failures + 1;
        end
        send(8'h55, 0);
        if (errors != 1 || rx_count != 256) begin
            $display("FAIL: bad stop must report error and suppress data"); failures = failures + 1;
        end
        expected_rx = 8'ha5; send(8'ha5, 1);
        if (rx_count != 257) begin $display("FAIL: framing-error recovery"); failures = failures + 1; end
        #13; slow_rx = 0; #8680;
        for (slow_bit=0; slow_bit<8; slow_bit=slow_bit+1) begin
            slow_rx = (8'h53 >> slow_bit) & 1; #8680;
        end
        slow_rx = 1; #8680;
        if (slow_count != 1) begin
            $display("FAIL: default 115200-baud receive count"); failures = failures + 1;
        end
        reset = 1; repeat (3) @(negedge clk);
        if (tx !== 1 || !tx_ready) begin $display("FAIL: reset TX idle"); failures = failures + 1; end
        if (failures == 0) $display("PASS: uart (all bytes, full duplex, false start, framing error)");
        else $display("FAIL: uart (%0d failures)", failures);
        $finish;
    end
    initial begin #1000000; $display("FAIL: uart timeout"); $finish; end
endmodule
