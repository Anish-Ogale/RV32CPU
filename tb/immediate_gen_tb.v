`timescale 1ns/1ps
module immediate_gen_tb;
    reg [31:0] instruction;
    wire [31:0] immediate;
    integer value, op, i;
    reg [31:0] encoded, bits_value, expected;
    immediate_gen dut (.instruction(instruction), .immediate(immediate));

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

    task expect_immediate;
        input [31:0] word, constant_value;
        begin
            instruction=word; #1;
            check(immediate === constant_value, "decoded constant equals encoded value");
        end
    endtask
    task check_jump;
        input integer displacement;
        begin
            bits_value=displacement;
            encoded=((bits_value & 32'h00100000) << 11) |
                    ((bits_value & 32'h000007fe) << 20) |
                    ((bits_value & 32'h00000800) << 9) |
                    (bits_value & 32'h000ff000) | 32'h00000fef;
            expect_immediate(encoded, displacement);
        end
    endtask
    initial begin
        // Independently encode every signed 12-bit constant.
        for (value=-2048; value<2048; value=value+1) begin
            bits_value=value;
            for (op=0; op<3; op=op+1) begin
                case (op)
                    0: encoded=32'h000f8f83;
                    1: encoded=32'h000f8f93;
                    2: encoded=32'h000f8fe7;
                endcase
                encoded=encoded | ((bits_value & 32'hfff) << 20);
                expect_immediate(encoded,value);
            end
            encoded=((bits_value & 32'hfe0) << 20) |
                    ((bits_value & 32'h1f) << 7) | 32'h01ff8023;
            expect_immediate(encoded,value);
        end
        // All representable branch offsets, including negative and bit-1 targets.
        for (value=-4096; value<=4094; value=value+2) begin
            bits_value=value;
            encoded=((bits_value & 32'h1000) << 19) |
                    ((bits_value & 32'h7e0) << 20) |
                    ((bits_value & 32'h1e) << 7) |
                    ((bits_value & 32'h800) >> 4) | 32'h01ff8063;
            expect_immediate(encoded,value);
        end
        check_jump(-1048576); check_jump(-2); check_jump(0);
        check_jump(2); check_jump(1048574);
        for (i=0; i<2048; i=i+1) begin
            value=$random;
            value=value % 1048576;
            value=(value / 2) * 2;
            check_jump(value);
            expected=$random & 32'hfffff000;
            expect_immediate(expected | 32'h00000fb7,expected); // LUI
            expect_immediate(expected | 32'h00000f97,expected); // AUIPC
        end
        expect_immediate(32'hfff00093,32'hffffffff); // ADDI -1
        expect_immediate(32'h002081b3,0); // register ADD
        expect_immediate(32'h00000073,0); // SYSTEM
        expect_immediate(32'h0000000f,0); // FENCE
        expect_immediate(32'hffffffff,0); // unsupported opcode

        if (failures == 0) $display("PASS: immediate_gen (%0d checks)", checks);
        else $display("FAIL: immediate_gen (%0d failures)", failures);
        $finish;

    end
endmodule

