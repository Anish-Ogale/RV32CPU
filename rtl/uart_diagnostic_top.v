`timescale 1ns/1ps

// Temporary board diagnostic, using exactly the CPU top's physical ports.
// RAW_LOOPBACK=1 connects RX straight to TX, independent of clock/baud/reset.
// RAW_LOOPBACK=0 receives and re-transmits each byte using the real UART.
module uart_diagnostic_top #(
    parameter RAW_LOOPBACK = 1,
    parameter integer CLOCK_HZ = 100000000,
    parameter integer BAUD = 115200
) (
    input wire clk, input wire reset, input wire uart_rx,
    output wire uart_tx, output wire [7:0] leds, output wire halted
);
    (* ASYNC_REG = "TRUE" *) reg [1:0] reset_sync = 2'b11;
    (* ASYNC_REG = "TRUE" *) reg [1:0] rx_sync = 2'b11;
    reg [25:0] heartbeat = 0;
    reg [23:0] activity = 0;
    reg [23:0] decoded = 0;
    reg [23:0] error_visible = 0;
    wire [7:0] rx_data;
    wire rx_valid, rx_error, tx_ready, echo_tx;
    reg [7:0] pending_data;
    reg pending;
    always @(posedge clk) begin
        heartbeat <= heartbeat + 1;
        reset_sync <= {reset_sync[0], reset};
        rx_sync <= {rx_sync[0], uart_rx};
        if (!rx_sync[1]) activity <= 10000000;
        else if (activity != 0) activity <= activity - 1;
        if (rx_valid) decoded <= 10000000;
        else if (decoded != 0) decoded <= decoded - 1;
        if (rx_error) error_visible <= 10000000;
        else if (error_visible != 0) error_visible <= error_visible - 1;
        if (reset_sync[1]) begin
            pending <= 0;
            pending_data <= 0;
        end else begin
            if (pending && tx_ready) pending <= 0;
            if (rx_valid) begin
                pending <= 1;
                pending_data <= rx_data;
            end
        end
    end
    uart #(.CLOCK_HZ(CLOCK_HZ), .BAUD(BAUD)) u_uart (
        .clk(clk), .reset(reset_sync[1]), .rx(uart_rx), .tx(echo_tx),
        .rx_data(rx_data), .rx_valid(rx_valid), .rx_error(rx_error),
        .tx_data(pending_data), .tx_valid(pending), .tx_ready(tx_ready)
    );
    assign uart_tx = RAW_LOOPBACK ? uart_rx : echo_tx;
    // Discrete LEDs 0..3: clock heartbeat, RX wire activity, decoded byte, reset.
    // RGB green 0..3: frame error, transmitter active, raw mode, diagnostic ID.
    assign leds = {1'b1, (RAW_LOOPBACK != 0), !tx_ready, (error_visible != 0),
                   reset_sync[1], (decoded != 0), (activity != 0), heartbeat[25]};
    assign halted = 0;
endmodule
