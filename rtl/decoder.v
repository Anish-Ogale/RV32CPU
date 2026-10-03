`timescale 1ns/1ps

module decoder (
    input  wire [31:0] instruction,

    output wire [6:0]  opcode,
    output wire [4:0]  rd_addr,
    output wire [2:0]  funct3,
    output wire [4:0]  rs1_addr,
    output wire [4:0]  rs2_addr,
    output wire [6:0]  funct7,

    output reg  [3:0]  instruction_kind,
    output reg         illegal_opcode
);

    localparam KIND_ALU_REG = 4'd0;
    localparam KIND_ALU_IMM = 4'd1;
    localparam KIND_LOAD    = 4'd2;
    localparam KIND_STORE   = 4'd3;
    localparam KIND_BRANCH  = 4'd4;
    localparam KIND_JAL     = 4'd5;
    localparam KIND_JALR    = 4'd6;
    localparam KIND_LUI     = 4'd7;
    localparam KIND_AUIPC   = 4'd8;
    localparam KIND_SYSTEM  = 4'd9;
    localparam KIND_FENCE   = 4'd10;
    localparam KIND_INVALID = 4'd15;

    // These fields always occupy the same instruction bit positions.
    assign opcode   = instruction[6:0];
    assign rd_addr  = instruction[11:7];
    assign funct3   = instruction[14:12];
    assign rs1_addr = instruction[19:15];
    assign rs2_addr = instruction[24:20];
    assign funct7   = instruction[31:25];

    always @(*) begin
        instruction_kind = KIND_INVALID;
        illegal_opcode   = 1'b0;

        case (opcode)
            7'b0110011: instruction_kind = KIND_ALU_REG;
            7'b0010011: instruction_kind = KIND_ALU_IMM;
            7'b0000011: instruction_kind = KIND_LOAD;
            7'b0100011: instruction_kind = KIND_STORE;
            7'b1100011: instruction_kind = KIND_BRANCH;
            7'b1101111: instruction_kind = KIND_JAL;
            7'b1100111: instruction_kind = KIND_JALR;
            7'b0110111: instruction_kind = KIND_LUI;
            7'b0010111: instruction_kind = KIND_AUIPC;
            7'b1110011: instruction_kind = KIND_SYSTEM;
            7'b0001111: instruction_kind = KIND_FENCE;

            default: begin
                instruction_kind = KIND_INVALID;
                illegal_opcode   = 1'b1;
            end
        endcase
    end

endmodule
