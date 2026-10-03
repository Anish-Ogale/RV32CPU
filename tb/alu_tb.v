`timescale 1ns/1ps
module alu_tb;
    reg [31:0] operand_a, operand_b;
    reg [3:0] operation;
    wire [31:0] result;
    integer op, i, k;
    reg [31:0] expected;
    reg [31:0] edges [0:7];
    alu dut (.operand_a(operand_a), .operand_b(operand_b),
             .operation(operation), .result(result));

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

    // Bit-by-bit shifts avoid relying on signed expression sizing in the oracle.
    function [31:0] reference;
        input [31:0] a, b;
        input [3:0] operation_code;
        integer bit_index, amount;
        reg less;
        begin
            reference = 0;
            amount = b % 32;
            less = (a[31] != b[31]) ? a[31] : (a < b);
            case (operation_code)
                0: reference = a + b;
                1: reference = a - b;
                2: reference = a & b;
                3: reference = a | b;
                4: reference = a ^ b;
                5: for (bit_index = 0; bit_index < 32; bit_index = bit_index+1)
                       if (bit_index >= amount)
                           reference[bit_index] = a[bit_index-amount];
                6, 7:
                   for (bit_index = 0; bit_index < 32; bit_index = bit_index+1)
                       if (bit_index+amount < 32)
                           reference[bit_index] = a[bit_index+amount];
                       else
                           reference[bit_index] = (operation_code == 7) && a[31];
                8: reference = less ? 1 : 0;
                9: reference = (a < b) ? 1 : 0;
                default: reference = 0;
            endcase
        end
    endfunction

    initial begin
        edges[0]=0; edges[1]=1; edges[2]=32'hffffffff; edges[3]=32'h80000000;
        edges[4]=32'h7fffffff; edges[5]=32'haaaaaaaa;
        edges[6]=32'h55555555; edges[7]=32'hfffffffe;
        for (op=0; op<16; op=op+1) begin
            operation=op;
            for (i=0; i<8; i=i+1)
                for (k=0; k<8; k=k+1) begin
                    operand_a=edges[i]; operand_b=edges[k]; #1;
                    expected=reference(operand_a,operand_b,operation);
                    check(result === expected, "ALU boundary operand pair");
                end
            for (i=0; i<128; i=i+1) begin
                operand_a=$random; operand_b=$random; #1;
                check(result === reference(operand_a,operand_b,operation),
                      "ALU randomized operand pair");
            end
        end
        for (op=5; op<=7; op=op+1)
            for (i=0; i<64; i=i+1) begin
                operation=op; operand_a=32'h80000001;
                operand_b=i; #1;
                check(result === reference(operand_a,operand_b,operation),
                      "all shift counts; high count bits ignored");
            end

        if (failures == 0) $display("PASS: alu (%0d checks)", checks);
        else $display("FAIL: alu (%0d failures)", failures);
        $finish;

    end
endmodule

