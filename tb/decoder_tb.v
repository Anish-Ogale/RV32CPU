`timescale 1ns/1ps
module decoder_tb;
    reg [31:0] instruction;
    wire [6:0] opcode, funct7;
    wire [4:0] rd_addr, rs1_addr, rs2_addr;
    wire [2:0] funct3;
    wire [3:0] instruction_kind;
    wire illegal_opcode;
    reg [3:0] expected_kind;
    integer op, i;
    decoder dut (.instruction(instruction), .opcode(opcode), .funct7(funct7),
        .rd_addr(rd_addr), .rs1_addr(rs1_addr), .rs2_addr(rs2_addr),
        .funct3(funct3), .instruction_kind(instruction_kind),
        .illegal_opcode(illegal_opcode));

    integer checks = 0;
    integer failures = 0;
    task check;
        input condition;
        input [511:0] description;
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                failures = failures + 1;
                $display("FAIL: %0s (check %0d)", description, checks);
            end
        end
    endtask

    initial begin
        for (op=0; op<128; op=op+1) begin
            case (op)
                'h33: expected_kind=0;
                'h13: expected_kind=1;
                'h03: expected_kind=2;
                'h23: expected_kind=3;
                'h63: expected_kind=4;
                'h6f: expected_kind=5;
                'h67: expected_kind=6;
                'h37: expected_kind=7;
                'h17: expected_kind=8;
                'h73: expected_kind=9;
                'h0f: expected_kind=10;
                default: expected_kind=15;
            endcase
            for (i=0; i<16; i=i+1) begin
                instruction=($random & 32'hffffff80) | op; #1;
                check(opcode === op[6:0] && instruction_kind === expected_kind &&
                      illegal_opcode === (expected_kind == 15),
                      "every opcode and broad family");
                check(rd_addr === instruction[11:7] &&
                      rs1_addr === instruction[19:15] &&
                      rs2_addr === instruction[24:20] &&
                      funct3 === instruction[14:12] &&
                      funct7 === instruction[31:25], "all extracted fields");
            end
        end

        if (failures == 0) $display("PASS: decoder (%0d checks)", checks);
        else $display("FAIL: decoder (%0d failures)", failures);
        $finish;

    end
endmodule

