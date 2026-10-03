`timescale 1ns/1ps

module branch_unit (
    input  wire [31:0] operand_a,
    input  wire [31:0] operand_b,
    input  wire [2:0]  funct3,
    output reg         branch_taken,
    output reg         illegal_branch
);

    wire signed [31:0] signed_a;
    wire signed [31:0] signed_b;

    assign signed_a = operand_a;
    assign signed_b = operand_b;

    always @(*) begin
        branch_taken  = 1'b0;
        illegal_branch = 1'b0;

        case (funct3)
            3'b000: branch_taken = (operand_a == operand_b); // BEQ
            3'b001: branch_taken = (operand_a != operand_b); // BNE
            3'b100: branch_taken = (signed_a < signed_b);     // BLT
            3'b101: branch_taken = (signed_a >= signed_b);    // BGE
            3'b110: branch_taken = (operand_a < operand_b);   // BLTU
            3'b111: branch_taken = (operand_a >= operand_b);  // BGEU

            default: begin
                branch_taken   = 1'b0;
                illegal_branch = 1'b1;
            end
        endcase
    end

endmodule
