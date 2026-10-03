`timescale 1ns/1ps
module register_file_tb;
    reg clk = 0;
    reg [4:0] rs1_addr = 0, rs2_addr = 0, rd_addr = 0;
    reg rd_write_enable = 0;
    reg [31:0] rd_data = 0;
    wire [31:0] rs1_data, rs2_data;
    reg [31:0] expected [0:31];
    integer i;
    register_file dut (
        .clk(clk), .rs1_addr(rs1_addr), .rs2_addr(rs2_addr),
        .rs1_data(rs1_data), .rs2_data(rs2_data),
        .rd_addr(rd_addr), .rd_data(rd_data), .rd_write_enable(rd_write_enable)
    );

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

    task tick;
        begin
            #5 clk = 1'b1;
            #1 clk = 1'b0;
            #4;
        end
    endtask

    initial begin
        expected[0] = 0;
        #1;
        check(rs1_data === 0 && rs2_data === 0, "x0 reads zero before any write");
        for (i = 1; i < 32; i = i + 1) begin
            rd_addr = i; rd_data = 32'h10203040 ^ (i * 32'h01010101);
            rd_write_enable = 1; tick; expected[i] = rd_data;
        end
        for (i = 0; i < 256; i = i + 1) begin
            rd_addr = i % 32;
            rs1_addr = rd_addr;
            rs2_addr = 31 - rd_addr;
            rd_data = $random;
            rd_write_enable = (i % 3 != 0);
            #1;
            check(rs1_data === expected[rs1_addr] && rs2_data === expected[rs2_addr],
                  "both read ports are combinational; writes wait for edge");
            tick;
            if (rd_write_enable && rd_addr != 0) expected[rd_addr] = rd_data;
            check(rs1_data === expected[rs1_addr] && rs2_data === expected[rs2_addr],
                  "write/read same address, disabled writes, x0 protection");
        end
        for (i = 0; i < 32; i = i + 1) begin
            rs1_addr = i; rs2_addr = 31-i; #1;
            check(rs1_data === expected[i] && rs2_data === expected[31-i],
                  "all registers retain independent values");
        end

        if (failures == 0) $display("PASS: register_file (%0d checks)", checks);
        else $display("FAIL: register_file (%0d failures)", failures);
        $finish;

    end
endmodule

