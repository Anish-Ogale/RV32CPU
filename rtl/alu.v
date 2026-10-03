`timescale 1ns/1ps

module alu (
    input  wire [31:0] operand_a,
    input  wire [31:0] operand_b,
    input  wire [3:0]  operation,
    output reg  [31:0] result
);

    localparam ALU_ADD  = 4'd0;
    localparam ALU_SUB  = 4'd1;
    localparam ALU_AND  = 4'd2;
    localparam ALU_OR   = 4'd3;
    localparam ALU_XOR  = 4'd4;
    localparam ALU_SLL  = 4'd5;
    localparam ALU_SRL  = 4'd6;
    localparam ALU_SRA  = 4'd7;
    localparam ALU_SLT  = 4'd8;
    localparam ALU_SLTU = 4'd9;

    wire signed [31:0] signed_a;
    assign signed_a = operand_a;

    always @(*) begin
        case (operation)
            ALU_ADD:  result = operand_a + operand_b;
            ALU_SUB:  result = operand_a - operand_b;
            ALU_AND:  result = operand_a & operand_b;
            ALU_OR:   result = operand_a | operand_b;
            ALU_XOR:  result = operand_a ^ operand_b;
            ALU_SLL:  result = operand_a << operand_b[4:0];
            ALU_SRL:  result = operand_a >> operand_b[4:0];
            ALU_SRA:  result = signed_a >>> operand_b[4:0];
            ALU_SLT:  result = ($signed(operand_a) < $signed(operand_b))
                               ? 32'd1 : 32'd0;
            ALU_SLTU: result = (operand_a < operand_b) ? 32'd1 : 32'd0;
            default:  result = 32'd0;
        endcase
    end

endmodule
