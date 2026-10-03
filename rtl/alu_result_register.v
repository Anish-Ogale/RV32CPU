`timescale 1ns/1ps

module alu_result_register (
    input  wire        clk,
    input  wire        reset,
    input  wire        write_enable,
    input  wire [31:0] alu_result,

    output reg  [31:0] saved_result
);

    // Preserve the execution result for memory access or writeback.
    always @(posedge clk) begin
        if (reset) begin
            saved_result <= 32'd0;
        end
        else if (write_enable) begin
            saved_result <= alu_result;
        end
    end

endmodule
