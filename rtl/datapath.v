`timescale 1ns/1ps

module datapath (
    input  wire        clk,
    input  wire        reset,

    // Commands from the control unit
    input  wire        fetch_enable,
    input  wire        load_enable,
    input  wire        store_enable,
    input  wire        lsu_load_enable,
    input  wire        lsu_store_enable,
    input  wire        instruction_write_enable,
    input  wire        operand_write_enable,
    input  wire        alu_result_write_enable,
    input  wire        load_result_write_enable,
    input  wire        register_write_enable,
    input  wire        pc_write_enable,
    input  wire [1:0]  alu_select_a,
    input  wire        alu_select_b,
    input  wire [3:0]  alu_operation,
    input  wire [1:0]  writeback_select,
    input  wire [1:0]  next_pc_select,

    // Instruction information and feedback to the control unit
    output wire [31:0] instruction,
    output wire [31:0] instruction_pc,
    output wire [3:0]  instruction_kind,
    output wire        illegal_opcode,
    output wire        fetch_complete,
    output wire        data_complete,
    output wire        branch_taken,
    output wire        next_pc_misaligned,
    output wire        load_store_misaligned,
    output wire        load_store_illegal,

    // External memory ports
    output wire        imem_req,
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_rdata,
    input  wire        imem_ready,
    output wire        dmem_req,
    output wire [31:0] dmem_addr,
    output wire        dmem_we,
    output wire [31:0] dmem_wdata,
    output wire [3:0]  dmem_wstrb,
    input  wire [31:0] dmem_rdata,
    input  wire        dmem_ready
);

    // Internal connections between the existing modules
    wire [31:0] current_pc;
    wire [31:0] next_pc;
    wire [31:0] fetched_instruction;
    wire [4:0] rs1_addr, rs2_addr, rd_addr;
    wire [2:0] funct3;
    wire [31:0] rs1_data, rs2_data;
    wire [31:0] immediate;
    wire [31:0] saved_operand_a, saved_operand_b;
    wire [31:0] alu_operand_a, alu_operand_b;
    wire [31:0] alu_result, saved_alu_result;
    wire [31:0] memory_read_data;
    wire [31:0] load_data, saved_load_data;
    wire [31:0] store_data;
    wire [3:0] store_strobe;
    wire [31:0] writeback_data;
    wire data_fault;

    assign data_fault = load_store_misaligned || load_store_illegal;

    // Fetch and preserve the current instruction and its original address.
    program_counter u_pc (
        .clk(clk), .reset(reset), .write_enable(pc_write_enable),
        .next_pc(next_pc), .current_pc(current_pc), .pc_plus_four()
    );

    instruction_register u_instruction_register (
        .clk(clk), .reset(reset),
        .write_enable(instruction_write_enable),
        .fetched_instruction(fetched_instruction), .fetch_pc(current_pc),
        .instruction(instruction), .instruction_pc(instruction_pc)
    );

    decoder u_decoder (
        .instruction(instruction), .opcode(), .rd_addr(rd_addr),
        .funct3(funct3), .rs1_addr(rs1_addr), .rs2_addr(rs2_addr),
        .funct7(), .instruction_kind(instruction_kind),
        .illegal_opcode(illegal_opcode)
    );

    immediate_gen u_immediate_gen (
        .instruction(instruction), .immediate(immediate)
    );

    // Read source registers and preserve their values at the decode edge.
    register_file u_register_file (
        .clk(clk), .rs1_addr(rs1_addr), .rs2_addr(rs2_addr),
        .rs1_data(rs1_data), .rs2_data(rs2_data),
        .rd_write_enable(register_write_enable && !reset),
        .rd_addr(rd_addr), .rd_data(writeback_data)
    );

    operand_registers u_operand_registers (
        .clk(clk), .reset(reset), .write_enable(operand_write_enable),
        .rs1_data(rs1_data), .rs2_data(rs2_data),
        .operand_a(saved_operand_a), .operand_b(saved_operand_b)
    );

    // Execute arithmetic, logic, or address calculations.
    alu_input_mux u_alu_input_mux (
        .saved_operand_a(saved_operand_a), .saved_operand_b(saved_operand_b),
        .immediate(immediate), .instruction_pc(instruction_pc),
        .select_a(alu_select_a), .select_b(alu_select_b),
        .alu_operand_a(alu_operand_a), .alu_operand_b(alu_operand_b)
    );

    alu u_alu (
        .operand_a(alu_operand_a), .operand_b(alu_operand_b),
        .operation(alu_operation), .result(alu_result)
    );

    alu_result_register u_alu_result_register (
        .clk(clk), .reset(reset), .write_enable(alu_result_write_enable),
        .alu_result(alu_result), .saved_result(saved_alu_result)
    );

    // Compare the actual source values, not the ALU's PC/immediate inputs.
    branch_unit u_branch_unit (
        .operand_a(saved_operand_a), .operand_b(saved_operand_b),
        .funct3(funct3), .branch_taken(branch_taken), .illegal_branch()
    );

    // The saved ALU result is the byte address for loads and stores.
    load_store_unit u_load_store_unit (
        .load_enable(lsu_load_enable), .store_enable(lsu_store_enable),
        .funct3(funct3), .address_offset(saved_alu_result[1:0]),
        .register_data(saved_operand_b), .memory_read_data(memory_read_data),
        .load_data(load_data), .memory_write_data(store_data),
        .memory_write_strobe(store_strobe),
        .misaligned(load_store_misaligned),
        .illegal_operation(load_store_illegal)
    );

    memory_interface u_memory_interface (
        .fetch_enable(fetch_enable), .fetch_address(current_pc),
        .fetched_instruction(fetched_instruction), .fetch_complete(fetch_complete),
        .load_enable(load_enable), .store_enable(store_enable),
        .data_fault(data_fault), .data_address(saved_alu_result),
        .store_data(store_data), .store_strobe(store_strobe),
        .memory_read_data(memory_read_data), .data_complete(data_complete),
        .imem_req(imem_req), .imem_addr(imem_addr),
        .imem_rdata(imem_rdata), .imem_ready(imem_ready),
        .dmem_req(dmem_req), .dmem_addr(dmem_addr), .dmem_we(dmem_we),
        .dmem_wdata(dmem_wdata), .dmem_wstrb(dmem_wstrb),
        .dmem_rdata(dmem_rdata), .dmem_ready(dmem_ready)
    );

    load_result_register u_load_result_register (
        .clk(clk), .reset(reset), .write_enable(load_result_write_enable),
        .load_data(load_data), .saved_load_data(saved_load_data)
    );

    // Select the architectural register result and the next fetch address.
    writeback_mux u_writeback_mux (
        .saved_alu_result(saved_alu_result), .saved_load_data(saved_load_data),
        .instruction_pc(instruction_pc), .select(writeback_select),
        .writeback_data(writeback_data)
    );

    // The controller commits the PC in WRITEBACK, after the target is saved.
    next_pc_select u_next_pc_select (
        .instruction_pc(instruction_pc), .alu_result(saved_alu_result),
        .select(next_pc_select), .next_pc(next_pc),
        .misaligned(next_pc_misaligned)
    );

endmodule
