`timescale 1ns/1ps

// Line-oriented monitor. Commands are uppercase; hex words accept either case.
// Host waits for each response. CR, LF and CRLF are accepted.
module uart_program_loader #(
    parameter integer INITIAL_WORDS = 4
) (
    input wire clk, input wire reset,
    input wire [7:0] rx_data, input wire rx_valid, input wire rx_error,
    output wire [7:0] tx_data, output wire tx_valid, input wire tx_ready,
    output reg running, output reg restart, output reg [8:0] loaded_words,
    output reg program_we, output reg [7:0] program_addr,
    output reg [31:0] program_data,
    input wire halted, input wire [31:0] result,
    input wire [31:0] fault_cause, input wire [31:0] fault_pc
);
    reg loading;
    reg [63:0] line;
    reg [3:0] length;
    reg [31:0] hex_word;
    reg bad_line, non_hex, previous_cr;
    reg [271:0] reply;
    reg [5:0] remaining;
    reg deferred_error;
    // Encode CR/LF as byte constants: Verilog string escapes do not define \r.
    wire newline = rx_data == 8'h0d || rx_data == 8'h0a;
    wire hex_valid = (rx_data >= "0" && rx_data <= "9") ||
                     (rx_data >= "a" && rx_data <= "f") ||
                     (rx_data >= "A" && rx_data <= "F");
    wire [7:0] digit = rx_data <= "9" ? rx_data - "0" :
                      (rx_data <= "F" ? rx_data - "A" + 8'd10 :
                                             rx_data - "a" + 8'd10);
    assign tx_valid = remaining != 0;
    assign tx_data = reply[271:264];

    function [63:0] hex_ascii;
        input [31:0] value;
        integer n;
        reg [3:0] nibble;
        begin
            for (n = 0; n < 8; n = n + 1) begin
                nibble = value[28 - 4*n +: 4];
                hex_ascii[63 - 8*n -: 8] = nibble < 10 ?
                    (8'h30 + {4'd0, nibble}) : (8'h41 + {4'd0, nibble} - 8'd10);
            end
        end
    endfunction

    always @(posedge clk) begin
        program_we <= 0;
        restart <= 0;
        if (reset) begin
            running <= 0;
            loading <= 0;
            // Keep instruction RAM and its valid extent across button reset.
            line <= 0;
            length <= 0;
            hex_word <= 0;
            bad_line <= 0;
            non_hex <= 0;
            previous_cr <= 0;
            reply <= 0;
            remaining <= 0;
            deferred_error <= 0;
            program_addr <= 0;
            program_data <= 0;
        end else begin
            if (tx_valid && tx_ready) begin
                reply <= {reply[263:0], 8'd0};
                remaining <= remaining - 1;
            end
            if (remaining == 0 && deferred_error) begin
                reply <= {"ERR", 8'h0d, 8'h0a, 232'd0};
                remaining <= 5;
                deferred_error <= 0;
            end
            if (rx_error) bad_line <= 1;
            if (rx_valid) begin
                previous_cr <= rx_data == 8'h0d;
                if (newline) begin
                    if (!(rx_data == 8'h0a && previous_cr) &&
                        (length != 0 || bad_line)) begin
                        if (remaining != 0 || deferred_error)
                            deferred_error <= 1;
                        else begin
                            reply <= {"ERR", 8'h0d, 8'h0a, 232'd0};
                            remaining <= 5;
                            if (!bad_line) begin
                                if (length == 4 && line == "LOAD") begin
                                    running <= 0;
                                    loading <= 1;
                                    loaded_words <= 0;
                                    reply <= {"OK", 8'h0d, 8'h0a, 240'd0};
                                    remaining <= 4;
                                end else if (length == 3 && line == "RUN" && loaded_words != 0) begin
                                    running <= 1;
                                    restart <= 1;
                                    loading <= 0;
                                    reply <= {"OK", 8'h0d, 8'h0a, 240'd0};
                                    remaining <= 4;
                                end else if (length == 4 && line == "STOP") begin
                                    running <= 0;
                                    loading <= 0;
                                    reply <= {"OK", 8'h0d, 8'h0a, 240'd0};
                                    remaining <= 4;
                                end else if (length == 6 && line == "STATUS") begin
                                    reply <= {"S ", (running ? 8'h31 : 8'h30), " ",
                                        (halted ? 8'h31 : 8'h30), " ", hex_ascii(result), " ",
                                        hex_ascii(fault_cause), " ", hex_ascii(fault_pc), 8'h0d, 8'h0a};
                                    remaining <= 34;
                                end else if (loading && length == 8 && !non_hex && loaded_words < 256) begin
                                    program_we <= 1;
                                    program_addr <= loaded_words[7:0];
                                    program_data <= hex_word;
                                    loaded_words <= loaded_words + 1;
                                    reply <= {"OK", 8'h0d, 8'h0a, 240'd0};
                                    remaining <= 4;
                                end
                            end
                        end
                    end
                    line <= 0;
                    length <= 0;
                    hex_word <= 0;
                    bad_line <= 0;
                    non_hex <= 0;
                end else if (length < 8) begin
                    line <= {line[55:0], rx_data};
                    length <= length + 1;
                    hex_word <= {hex_word[27:0], digit[3:0]};
                    if (!hex_valid) non_hex <= 1;
                end else bad_line <= 1;
            end
        end
    end
    initial loaded_words = INITIAL_WORDS[8:0];
endmodule
