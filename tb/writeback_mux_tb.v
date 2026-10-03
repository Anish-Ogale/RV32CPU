`timescale 1ns/1ps
module writeback_mux_tb;
    reg [31:0] saved_alu_result, saved_load_data, instruction_pc;
    reg [1:0] select;
    wire [31:0] writeback_data;
    reg [31:0] expected;
    integer s,i;
    writeback_mux dut (.saved_alu_result(saved_alu_result),
        .saved_load_data(saved_load_data), .instruction_pc(instruction_pc),
        .select(select), .writeback_data(writeback_data));

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
            for (i=0; i<64; i=i+1) begin
                saved_alu_result=$random; saved_load_data=$random;
                instruction_pc=$random; select=s; #1;
                case (s)
                    0: expected=saved_alu_result;
                    1: expected=saved_load_data;
                    2: expected=instruction_pc+32'd4;
                    default: expected=0;
                endcase
                check(writeback_data === expected,"every writeback source and reserved selection");
            end
        select=2; instruction_pc=32'hfffffffc; #1;
        check(writeback_data === 0,"link address wraps at 32 bits");

        if (failures == 0) $display("PASS: writeback_mux (%0d checks)", checks);
        else $display("FAIL: writeback_mux (%0d failures)", failures);
        $finish;

    end
endmodule

