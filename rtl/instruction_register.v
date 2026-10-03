`timescale 1ns/1ps

module instruction_register (
    input  wire        clk,
    input  wire        reset,
    input  wire        write_enable,
    input  wire [31:0] fetched_instruction,
    input  wire [31:0] fetch_pc,

    output reg  [31:0] instruction,
    output reg  [31:0] instruction_pc
);

    always @(posedge clk) begin
        if (reset) begin
            // ADDI x0, x0, 0 is the standard NOP instruction.
            instruction    <= 32'h0000_0013;
            instruction_pc <= 32'h0000_0000;
        end
        else if (write_enable) begin
            instruction    <= fetched_instruction;
            instruction_pc <= fetch_pc;
        end
    end

endmodule
