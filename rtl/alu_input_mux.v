`timescale 1ns/1ps

module alu_input_mux (
    input  wire [31:0] saved_operand_a,
    input  wire [31:0] saved_operand_b,
    input  wire [31:0] immediate,
    input  wire [31:0] instruction_pc,
    input  wire [1:0]  select_a,
    input  wire        select_b,

    output reg  [31:0] alu_operand_a,
    output wire [31:0] alu_operand_b
);

    localparam A_REGISTER = 2'd0;
    localparam A_PC       = 2'd1;
    localparam A_ZERO     = 2'd2;

    always @(*) begin
        case (select_a)
            A_REGISTER: alu_operand_a = saved_operand_a;
            A_PC:       alu_operand_a = instruction_pc;
            A_ZERO:     alu_operand_a = 32'd0;
            default:    alu_operand_a = 32'd0;
        endcase
    end

    // 0 selects the second register value; 1 selects the immediate.
    assign alu_operand_b = select_b ? immediate : saved_operand_b;

endmodule
