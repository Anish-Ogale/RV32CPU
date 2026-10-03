`timescale 1ns/1ps
module next_pc_select_tb;
    reg [31:0] instruction_pc, alu_result;
    reg [1:0] select;
    wire [31:0] next_pc;
    wire misaligned;
    reg [31:0] expected;
    integer s,i;
    next_pc_select dut (.instruction_pc(instruction_pc), .alu_result(alu_result),
        .select(select), .next_pc(next_pc), .misaligned(misaligned));

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
        for (s=0; s<4; s=s+1)
            for (i=0; i<128; i=i+1) begin
                instruction_pc=($random & 32'hfffffffc) | (i % 4);
                alu_result=($random & 32'hfffffffc) | (i % 4);
                select=s; #1;
                case (s)
                    1: expected=alu_result;
                    2: expected=alu_result & 32'hfffffffe;
                    default: expected=instruction_pc+32'd4;
                endcase
                check(next_pc === expected && misaligned === (expected % 4 != 0),
                      "all selections, alignment combinations, JALR clearing");
            end
        select=0; instruction_pc=32'hfffffffc; #1;
        check(next_pc === 0 && !misaligned,"sequential PC wraps");
        select=2; alu_result=32'h103; #1;
        check(next_pc === 32'h102 && misaligned,
              "clearing JALR bit zero does not clear bit one");

        if (failures == 0) $display("PASS: next_pc_select (%0d checks)", checks);
        else $display("FAIL: next_pc_select (%0d failures)", failures);
        $finish;

    end
endmodule

