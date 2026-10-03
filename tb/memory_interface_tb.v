`timescale 1ns/1ps
module memory_interface_tb;
    reg fetch_enable, load_enable, store_enable, data_fault;
    reg [31:0] fetch_address, data_address, store_data;
    reg [3:0] store_strobe;
    reg [31:0] imem_rdata, dmem_rdata;
    reg imem_ready, dmem_ready;
    wire [31:0] fetched_instruction, memory_read_data;
    wire fetch_complete, data_complete, imem_req, dmem_req, dmem_we;
    wire [31:0] imem_addr, dmem_addr, dmem_wdata;
    wire [3:0] dmem_wstrb;
    reg expected_req, expected_we;
    integer pattern,i;
    memory_interface dut (
        .fetch_enable(fetch_enable), .fetch_address(fetch_address),
        .fetched_instruction(fetched_instruction), .fetch_complete(fetch_complete),
        .load_enable(load_enable), .store_enable(store_enable), .data_fault(data_fault),
        .data_address(data_address), .store_data(store_data), .store_strobe(store_strobe),
        .memory_read_data(memory_read_data), .data_complete(data_complete),
        .imem_req(imem_req), .imem_addr(imem_addr), .imem_rdata(imem_rdata),
        .imem_ready(imem_ready), .dmem_req(dmem_req), .dmem_addr(dmem_addr),
        .dmem_we(dmem_we), .dmem_wdata(dmem_wdata), .dmem_wstrb(dmem_wstrb),
        .dmem_rdata(dmem_rdata), .dmem_ready(dmem_ready)
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

    initial begin
        for (pattern=0; pattern<64; pattern=pattern+1)
            for (i=0; i<16; i=i+1) begin
                fetch_enable=pattern[0]; imem_ready=pattern[1];
                load_enable=pattern[2]; store_enable=pattern[3];
                data_fault=pattern[4]; dmem_ready=pattern[5];
                fetch_address=$random; data_address=$random;
                store_data=$random; store_strobe=i;
                imem_rdata=$random; dmem_rdata=$random;
                expected_req=(load_enable != store_enable) && !data_fault;
                expected_we=expected_req && store_enable; #1;
                check(imem_req === fetch_enable && imem_addr === fetch_address &&
                      fetched_instruction === imem_rdata &&
                      fetch_complete === (fetch_enable && imem_ready),
                      "fetch wiring and completion; ready alone cannot complete");
                check(dmem_req === expected_req && dmem_addr === data_address &&
                      dmem_we === expected_we &&
                      dmem_wdata === (expected_we ? store_data : 32'd0) &&
                      dmem_wstrb === (expected_we ? store_strobe : 4'd0),
                      "data request, fault/conflict suppression, write lanes");
                check(memory_read_data === dmem_rdata &&
                      data_complete === (expected_req && dmem_ready),
                      "data return wiring and completion");
            end

        if (failures == 0) $display("PASS: memory_interface (%0d checks)", checks);
        else $display("FAIL: memory_interface (%0d failures)", failures);
        $finish;

    end
endmodule

