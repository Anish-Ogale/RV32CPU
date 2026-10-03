`timescale 1ns/1ps

// Define CORE_TOP_TEST to run the same program through rv32i_core.
// Otherwise test the datapath and controller connected directly.
module datapath_tb;
    reg clk = 1'b0;
    reg reset = 1'b1;
    wire fetch_enable;
    wire load_enable;
    wire store_enable;
    wire lsu_load_enable;
    wire lsu_store_enable;
    wire instruction_write_enable;
    wire operand_write_enable;
    wire alu_result_write_enable;
    wire load_result_write_enable;
    wire register_write_enable;
    wire pc_write_enable;
    wire [1:0] alu_select_a;
    wire alu_select_b;
    wire [3:0] alu_operation;
    wire [1:0] writeback_select;
    wire [1:0] next_pc_select;
    wire [31:0] instruction;
    wire [31:0] instruction_pc;
    wire [3:0] instruction_kind;
    wire illegal_opcode;
    wire fetch_complete;
    wire data_complete;
    wire branch_taken;
    wire next_pc_misaligned;
    wire load_store_misaligned;
    wire load_store_illegal;
    wire imem_req;
    wire [31:0] imem_addr;
    wire [31:0] imem_rdata;
    wire imem_ready;
    wire dmem_req;
    wire [31:0] dmem_addr;
    wire dmem_we;
    wire [31:0] dmem_wdata;
    wire [3:0] dmem_wstrb;
    wire [31:0] dmem_rdata;
    wire dmem_ready;
    wire halted;
    wire [31:0] fault_cause, fault_pc;
    reg [31:0] rom [0:63];
    reg [31:0] ram [0:255];
    integer cycle = 0;
    integer failures = 0;
    integer stores = 0;
    integer i;
    reg fetch_waiting = 1'b0;
    reg data_waiting = 1'b0;
    reg [31:0] previous_imem_addr;
    reg [31:0] previous_dmem_addr, previous_dmem_data;
    reg [3:0] previous_strobe;
    reg previous_we;

    always #5 clk = ~clk;
    assign imem_rdata = rom[imem_addr[7:2]];
    assign imem_ready = imem_req && (cycle % 3 == 0);
    assign dmem_rdata = ram[dmem_addr[9:2]];
    assign dmem_ready = dmem_req && (cycle % 4 == 0);

`ifdef CORE_TOP_TEST
    `define TEST_REGISTERS dut.u_datapath.u_register_file.registers
    rv32i_core dut (
        .clk(clk), .reset(reset),
        .imem_req(imem_req),
        .imem_addr(imem_addr),
        .imem_rdata(imem_rdata),
        .imem_ready(imem_ready),
        .dmem_req(dmem_req),
        .dmem_addr(dmem_addr),
        .dmem_we(dmem_we),
        .dmem_wdata(dmem_wdata),
        .dmem_wstrb(dmem_wstrb),
        .dmem_rdata(dmem_rdata),
        .dmem_ready(dmem_ready),
        .halted(halted),
        .fault_cause(fault_cause),
        .fault_pc(fault_pc)
    );
`else
    `define TEST_REGISTERS dut.u_register_file.registers
    datapath dut (
        .clk(clk),
        .reset(reset),
        .fetch_enable(fetch_enable),
        .load_enable(load_enable),
        .store_enable(store_enable),
        .lsu_load_enable(lsu_load_enable),
        .lsu_store_enable(lsu_store_enable),
        .instruction_write_enable(instruction_write_enable),
        .operand_write_enable(operand_write_enable),
        .alu_result_write_enable(alu_result_write_enable),
        .load_result_write_enable(load_result_write_enable),
        .register_write_enable(register_write_enable),
        .pc_write_enable(pc_write_enable),
        .alu_select_a(alu_select_a),
        .alu_select_b(alu_select_b),
        .alu_operation(alu_operation),
        .writeback_select(writeback_select),
        .next_pc_select(next_pc_select),
        .instruction(instruction),
        .instruction_pc(instruction_pc),
        .instruction_kind(instruction_kind),
        .illegal_opcode(illegal_opcode),
        .fetch_complete(fetch_complete),
        .data_complete(data_complete),
        .branch_taken(branch_taken),
        .next_pc_misaligned(next_pc_misaligned),
        .load_store_misaligned(load_store_misaligned),
        .load_store_illegal(load_store_illegal),
        .imem_req(imem_req),
        .imem_addr(imem_addr),
        .imem_rdata(imem_rdata),
        .imem_ready(imem_ready),
        .dmem_req(dmem_req),
        .dmem_addr(dmem_addr),
        .dmem_we(dmem_we),
        .dmem_wdata(dmem_wdata),
        .dmem_wstrb(dmem_wstrb),
        .dmem_rdata(dmem_rdata),
        .dmem_ready(dmem_ready)
    );

    control_unit controller (
        .clk(clk),
        .reset(reset),
        .fetch_enable(fetch_enable),
        .load_enable(load_enable),
        .store_enable(store_enable),
        .lsu_load_enable(lsu_load_enable),
        .lsu_store_enable(lsu_store_enable),
        .instruction_write_enable(instruction_write_enable),
        .operand_write_enable(operand_write_enable),
        .alu_result_write_enable(alu_result_write_enable),
        .load_result_write_enable(load_result_write_enable),
        .register_write_enable(register_write_enable),
        .pc_write_enable(pc_write_enable),
        .alu_select_a(alu_select_a),
        .alu_select_b(alu_select_b),
        .alu_operation(alu_operation),
        .writeback_select(writeback_select),
        .next_pc_select(next_pc_select),
        .instruction(instruction),
        .instruction_pc(instruction_pc),
        .instruction_kind(instruction_kind),
        .illegal_opcode(illegal_opcode),
        .fetch_complete(fetch_complete),
        .data_complete(data_complete),
        .branch_taken(branch_taken),
        .next_pc_misaligned(next_pc_misaligned),
        .load_store_misaligned(load_store_misaligned),
        .load_store_illegal(load_store_illegal),
        .halted(halted),
        .fault_cause(fault_cause),
        .fault_pc(fault_pc)
    );
`endif

    task check;
        input condition;
        input [511:0] description;
        begin
            if (condition !== 1'b1) begin
                $display("FAIL: %0s", description);
                failures = failures + 1;
            end
        end
    endtask

    always @(posedge clk) begin
        if (reset) begin
            cycle <= 0;
            fetch_waiting <= 1'b0;
            data_waiting <= 1'b0;
        end
        else begin
            cycle <= cycle + 1;
            if (fetch_waiting)
                check(imem_req && imem_addr == previous_imem_addr,
                      "instruction request stays stable while waiting");
            if (data_waiting)
                check(dmem_req && dmem_addr == previous_dmem_addr &&
                      dmem_wdata == previous_dmem_data &&
                      dmem_wstrb == previous_strobe && dmem_we == previous_we,
                      "data request stays stable while waiting");
            fetch_waiting <= imem_req && !imem_ready;
            data_waiting <= dmem_req && !dmem_ready;
            previous_imem_addr <= imem_addr;
            previous_dmem_addr <= dmem_addr;
            previous_dmem_data <= dmem_wdata;
            previous_strobe <= dmem_wstrb;
            previous_we <= dmem_we;
            if (dmem_req && dmem_ready && dmem_we) begin
                stores = stores + 1;
                for (i = 0; i < 4; i = i + 1)
                    if (dmem_wstrb[i])
                        ram[dmem_addr[9:2]][8*i +: 8] <= dmem_wdata[8*i +: 8];
            end
        end
    end

    initial begin
        for (i = 0; i < 64; i = i + 1) rom[i] = 32'h0000_0013;
        for (i = 0; i < 256; i = i + 1) ram[i] = 32'd0;
        rom[0] = 32'h10000093; // ADDI x1, x0, 256
        rom[1] = 32'hfff00113; // ADDI x2, x0, -1
        rom[2] = 32'h0020a023; // SW x2, 0(x1)
        rom[3] = 32'h00308183; // LB x3, 3(x1)
        rom[4] = 32'h0030c203; // LBU x4, 3(x1)
        rom[5] = 32'h00409223; // SH x4, 4(x1)
        rom[6] = 32'h0040d283; // LHU x5, 4(x1)
        rom[7] = 32'h0000a303; // LW x6, 0(x1)
        rom[8] = 32'h005203b3; // ADD x7, x4, x5
        rom[9] = 32'h00738463; // BEQ x7, x7, +8
        rom[10] = 32'h06300413; // Skipped
        rom[11] = 32'h00800413; // ADDI x8, x0, 8
        rom[12] = 32'h008004ef; // JAL x9, +8
        rom[13] = 32'h06300413; // Skipped
        rom[14] = 32'h00000517; // AUIPC x10, 0
        rom[15] = 32'h123455b7; // LUI x11, 0x12345
        rom[16] = 32'h04d00613; // ADDI x12, x0, 77
        rom[17] = 32'h000606e7; // JALR x13, 0(x12): clears bit 0
        rom[18] = 32'h06300413; // Skipped
        rom[19] = 32'h00412733; // SLT x14, x2, x4
        rom[20] = 32'h004137b3; // SLTU x15, x2, x4
        rom[21] = 32'h0000000f; // FENCE
        rom[22] = 32'h00100073; // EBREAK
        repeat (2) @(negedge clk);
        reset = 1'b0;
        wait (halted);
        #1;
        check(fault_cause == 32'd3 && fault_pc == 32'd88,
              "program ends at EBREAK with correct address");
        check(`TEST_REGISTERS[1] == 32'd256, "ADDI base address");
        check(`TEST_REGISTERS[3] == 32'hffffffff, "LB sign extension");
        check(`TEST_REGISTERS[4] == 32'd255, "LBU zero extension");
        check(`TEST_REGISTERS[5] == 32'd255, "SH/LHU path");
        check(`TEST_REGISTERS[6] == 32'hffffffff, "SW/LW path");
        check(`TEST_REGISTERS[7] == 32'd510, "register ADD");
        check(`TEST_REGISTERS[8] == 32'd8, "branches and jumps skip instructions");
        check(`TEST_REGISTERS[9] == 32'd52, "JAL link address");
        check(`TEST_REGISTERS[10] == 32'd56, "AUIPC uses instruction PC");
        check(`TEST_REGISTERS[11] == 32'h12345000, "LUI upper immediate");
        check(`TEST_REGISTERS[13] == 32'd72, "JALR link and bit zero clearing");
        check(`TEST_REGISTERS[14] == 32'd1, "signed comparison");
        check(`TEST_REGISTERS[15] == 32'd0, "unsigned comparison");
        check(stores == 2, "no repeated writes during memory waits");
        check(!imem_req && !dmem_req, "halt disables memory requests");
        if (failures == 0)
            $display("PASS: CPU integration and stalled memory");
        else
            $display("FAIL: %0d checks failed", failures);
        $finish;
    end

    initial begin
        repeat (300) @(posedge clk);
        $display("FAIL: simulation timeout");
        $finish;
    end
endmodule
`undef TEST_REGISTERS

