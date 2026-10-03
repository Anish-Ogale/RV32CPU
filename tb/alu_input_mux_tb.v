`timescale 1ns/1ps
module alu_input_mux_tb;
    reg [31:0] saved_operand_a, saved_operand_b, immediate, instruction_pc;
    reg [1:0] select_a;
    reg select_b;
    wire [31:0] alu_operand_a, alu_operand_b;
    reg [31:0] expected_a;
    integer a,b,i;
    alu_input_mux dut (.saved_operand_a(saved_operand_a), .saved_operand_b(saved_operand_b),
        .immediate(immediate), .instruction_pc(instruction_pc), .select_a(select_a),
        .select_b(select_b), .alu_operand_a(alu_operand_a), .alu_operand_b(alu_operand_b));

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
        for (a=0; a<4; a=a+1)
            for (b=0; b<2; b=b+1)
                for (i=0; i<64; i=i+1) begin
                    saved_operand_a=$random; saved_operand_b=$random;
                    immediate=$random; instruction_pc=$random;
                    select_a=a; select_b=b; #1;
                    case (a)
                        0: expected_a=saved_operand_a;
                        1: expected_a=instruction_pc;
                        default: expected_a=0;
                    endcase
                    check(alu_operand_a === expected_a &&
                          alu_operand_b === (b ? immediate : saved_operand_b),
                          "every selection and live input changes");
                end

        if (failures == 0) $display("PASS: alu_input_mux (%0d checks)", checks);
        else $display("FAIL: alu_input_mux (%0d failures)", failures);
        $finish;

    end
endmodule

