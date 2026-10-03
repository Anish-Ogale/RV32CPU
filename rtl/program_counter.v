`timescale 1ns/1ps

module program_counter (
    input  wire        clk,
    input  wire        reset,
    input  wire        write_enable,
    input  wire [31:0] next_pc,

    output reg  [31:0] current_pc,
    output wire [31:0] pc_plus_four
);

    assign pc_plus_four = current_pc + 32'd4;

    always @(posedge clk) begin
        if (reset) begin
            current_pc <= 32'h0000_0000;
        end
        else if (write_enable) begin
            current_pc <= next_pc;
        end
    end

endmodule
