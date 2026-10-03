`timescale 1ns/1ps
module branch_unit_tb;
    reg [31:0] operand_a, operand_b;
    reg [2:0] funct3;
    wire branch_taken, illegal_branch;
    reg expected_taken, expected_illegal, signed_less;
    reg [31:0] edges [0:5];
    integer f, i, j;
    branch_unit dut (.operand_a(operand_a), .operand_b(operand_b),
        .funct3(funct3), .branch_taken(branch_taken), .illegal_branch(illegal_branch));

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

    task evaluate;
        begin
            signed_less = (operand_a[31] != operand_b[31])
                          ? operand_a[31] : (operand_a < operand_b);
            expected_illegal = 0;
            case (funct3)
                0: expected_taken = operand_a == operand_b;
                1: expected_taken = operand_a != operand_b;
                4: expected_taken = signed_less;
                5: expected_taken = !signed_less;
                6: expected_taken = operand_a < operand_b;
                7: expected_taken = operand_a >= operand_b;
                default: begin expected_taken=0; expected_illegal=1; end
            endcase
            #1;
            check(branch_taken === expected_taken &&
                  illegal_branch === expected_illegal, "branch decision and legality");
        end
    endtask
    initial begin
        edges[0]=0; edges[1]=1; edges[2]=32'hffffffff;
        edges[3]=32'h80000000; edges[4]=32'h7fffffff; edges[5]=32'hfffffffe;
        for (f=0; f<8; f=f+1) begin
            funct3=f;
            for (i=0; i<6; i=i+1)
                for (j=0; j<6; j=j+1) begin
                    operand_a=edges[i]; operand_b=edges[j]; evaluate;
                end
            for (i=0; i<128; i=i+1) begin
                operand_a=$random; operand_b=$random; evaluate;
            end
        end

        if (failures == 0) $display("PASS: branch_unit (%0d checks)", checks);
        else $display("FAIL: branch_unit (%0d failures)", failures);
        $finish;

    end
endmodule

