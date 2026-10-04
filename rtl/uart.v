`timescale 1ns/1ps

// Independent full-duplex UART, 8 data bits, no parity, one stop bit.
// TX accepts a byte on tx_valid && tx_ready. RX emits a one-clock pulse.
module uart #(
    parameter integer CLOCK_HZ = 100000000,
    parameter integer BAUD = 115200
) (
    input wire clk, input wire reset,
    input wire rx, output reg tx,
    output reg [7:0] rx_data, output reg rx_valid,
    output reg rx_error,
    input wire [7:0] tx_data, input wire tx_valid,
    output wire tx_ready
);
    localparam integer TICKS = (CLOCK_HZ + BAUD/2) / BAUD;
    function integer counter_width;
        input integer value;
        begin
            counter_width = 0;
            while (value > 0) begin
                counter_width = counter_width + 1;
                value = value >> 1;
            end
        end
    endfunction
    localparam integer TIMER_BITS = counter_width(TICKS - 1);
    localparam integer FULL_COUNT = TICKS - 1;
    localparam integer HALF_COUNT = TICKS/2 - 1;
    (* ASYNC_REG = "TRUE" *) reg [1:0] rx_sync = 2'b11;
    reg [TIMER_BITS-1:0] rx_ticks, tx_ticks;
    reg [3:0] rx_state, tx_bit;
    reg [7:0] rx_shift;
    reg [9:0] tx_shift;
    reg tx_busy;
    assign tx_ready = !tx_busy;

    always @(posedge clk) begin
        rx_sync <= {rx_sync[0], rx};
        rx_valid <= 1'b0;
        rx_error <= 1'b0;
        if (reset) begin
            rx_state <= 0;
            rx_ticks <= 0;
            rx_data <= 0;
            rx_shift <= 0;
            tx <= 1;
            tx_busy <= 0;
            tx_ticks <= 0;
            tx_bit <= 0;
            tx_shift <= 10'h3ff;
        end else begin
            if (rx_state == 0) begin
                if (!rx_sync[1]) begin
                    rx_state <= 1;
                    rx_ticks <= HALF_COUNT[TIMER_BITS-1:0];
                end
            end else if (rx_ticks != 0)
                rx_ticks <= rx_ticks - 1;
            else begin
                rx_ticks <= FULL_COUNT[TIMER_BITS-1:0];
                if (rx_state == 1) begin
                    if (!rx_sync[1]) rx_state <= 2;
                    else rx_state <= 0; // Reject a short false start.
                end else if (rx_state <= 9) begin
                    rx_shift[rx_state - 2] <= rx_sync[1];
                    rx_state <= rx_state + 1;
                end else if (rx_state == 10) begin
                    if (rx_sync[1]) begin
                        rx_data <= rx_shift;
                        rx_valid <= 1;
                        rx_state <= 0;
                    end else begin
                        rx_error <= 1;
                        rx_state <= 11; // Wait for idle after break/bad stop.
                    end
                end else if (rx_sync[1]) rx_state <= 0;
            end

            if (!tx_busy) begin
                if (tx_valid) begin
                    tx_shift <= {1'b1, tx_data, 1'b0};
                    tx <= 0;
                    tx_busy <= 1;
                    tx_bit <= 0;
                    tx_ticks <= FULL_COUNT[TIMER_BITS-1:0];
                end
            end else if (tx_ticks != 0)
                tx_ticks <= tx_ticks - 1;
            else if (tx_bit == 9) begin
                tx <= 1;
                tx_busy <= 0;
            end else begin
                tx_shift <= {1'b1, tx_shift[9:1]};
                tx <= tx_shift[1];
                tx_bit <= tx_bit + 1;
                tx_ticks <= FULL_COUNT[TIMER_BITS-1:0];
            end
        end
    end
endmodule
