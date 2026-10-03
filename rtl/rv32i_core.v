`timescale 1ns/1ps

module rv32i_core (
    input  wire        clk,
    input  wire        reset,

    // Instruction memory: hold req/address until completion.
    output wire        imem_req,
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_rdata,
    input  wire        imem_ready,

    // Data memory: byte addresses and word-relative byte strobes.
    output wire        dmem_req,
    output wire [31:0] dmem_addr,
    output wire        dmem_we,
    output wire [31:0] dmem_wdata,
    output wire [3:0]  dmem_wstrb,
    input  wire [31:0] dmem_rdata,
    input  wire        dmem_ready,

    // Initial fault reporting; reset is required to resume execution.
    output wire        halted,
    output wire [31:0] fault_cause,
    output wire [31:0] fault_pc
);

    // Controller commands and datapath feedback stay internal to the core.
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

    control_unit u_control_unit (
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

    datapath u_datapath (
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

endmodule

