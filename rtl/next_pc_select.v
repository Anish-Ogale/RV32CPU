`timescale 1ns/1ps

module next_pc_select (
    input  wire [31:0] instruction_pc,
    input  wire [31:0] alu_result,
    input  wire [1:0]  select,

    output reg  [31:0] next_pc,
    output wire        misaligned
);

    localparam PC_SEQUENTIAL = 2'd0;
    localparam PC_TARGET     = 2'd1;
    localparam PC_JALR       = 2'd2;

    always @(*) begin
        case (select)
            PC_SEQUENTIAL: next_pc = instruction_pc + 32'd4;
            PC_TARGET:     next_pc = alu_result;
            // JALR requires bit 0 of the calculated target to be cleared.
            PC_JALR:       next_pc = {alu_result[31:1], 1'b0};
            default:       next_pc = instruction_pc + 32'd4;
        endcase
    end

    // RV32I without compressed instructions requires four-byte alignment.
    // The controller must check this before committing a PC update.
    assign misaligned = |next_pc[1:0];

endmodule
