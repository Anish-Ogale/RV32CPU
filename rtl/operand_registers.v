`timescale 1ns/1ps

module operand_registers (
    input  wire        clk,
    input  wire        reset,
    input  wire        write_enable,
    input  wire [31:0] rs1_data,
    input  wire [31:0] rs2_data,

    output reg  [31:0] operand_a,
    output reg  [31:0] operand_b
);

    // Capture both source values at the end of the decode cycle.
    always @(posedge clk) begin
        if (reset) begin
            operand_a <= 32'd0;
            operand_b <= 32'd0;
        end
        else if (write_enable) begin
            operand_a <= rs1_data;
            operand_b <= rs2_data;
        end
    end

endmodule
