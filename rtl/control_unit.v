`timescale 1ns/1ps

module control_unit (
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] instruction,
    input  wire [31:0] instruction_pc,
    input  wire [3:0]  instruction_kind,
    input  wire        illegal_opcode,
    input  wire        fetch_complete,
    input  wire        data_complete,
    input  wire        branch_taken,
    input  wire        next_pc_misaligned,
    input  wire        load_store_misaligned,
    input  wire        load_store_illegal,

    output reg         fetch_enable,
    output reg         load_enable,
    output reg         store_enable,
    output wire        lsu_load_enable,
    output wire        lsu_store_enable,
    output reg         instruction_write_enable,
    output reg         operand_write_enable,
    output reg         alu_result_write_enable,
    output reg         load_result_write_enable,
    output reg         register_write_enable,
    output reg         pc_write_enable,
    output reg  [1:0]  alu_select_a,
    output reg         alu_select_b,
    output reg  [3:0]  alu_operation,
    output reg  [1:0]  writeback_select,
    output reg  [1:0]  next_pc_select,
    output wire        halted,
    output reg  [31:0] fault_cause,
    output reg  [31:0] fault_pc
);

    // These encodings match decoder.v.
    localparam KIND_ALU_REG = 4'd0, KIND_ALU_IMM = 4'd1;
    localparam KIND_LOAD = 4'd2, KIND_STORE = 4'd3;
    localparam KIND_BRANCH = 4'd4, KIND_JAL = 4'd5;
    localparam KIND_JALR = 4'd6, KIND_LUI = 4'd7;
    localparam KIND_AUIPC = 4'd8, KIND_SYSTEM = 4'd9;
    localparam KIND_FENCE = 4'd10;

    // These encodings match alu.v and the three selection modules.
    localparam ALU_ADD = 4'd0, ALU_SUB = 4'd1;
    localparam ALU_AND = 4'd2, ALU_OR = 4'd3, ALU_XOR = 4'd4;
    localparam ALU_SLL = 4'd5, ALU_SRL = 4'd6, ALU_SRA = 4'd7;
    localparam ALU_SLT = 4'd8, ALU_SLTU = 4'd9;
    localparam A_REGISTER = 2'd0, A_PC = 2'd1, A_ZERO = 2'd2;
    localparam WB_ALU = 2'd0, WB_LOAD = 2'd1, WB_LINK = 2'd2;
    localparam PC_SEQUENTIAL = 2'd0, PC_TARGET = 2'd1, PC_JALR = 2'd2;

    localparam FETCH = 3'd0, DECODE = 3'd1, EXECUTE = 3'd2;
    localparam MEMORY = 3'd3, WRITEBACK = 3'd4, HALT = 3'd5;

    reg [2:0] state;
    reg [2:0] next_state;
    reg valid_instruction;
    reg [31:0] pending_fault_cause;
    wire [2:0] funct3;
    wire [6:0] funct7;

    assign funct3 = instruction[14:12];
    assign funct7 = instruction[31:25];
    assign halted = (state == HALT);

    // LSU formatting is separate from issuing an external memory request.
    // The datapath connects the LSU offset to the saved ALU address.
    assign lsu_load_enable = !reset && (instruction_kind == KIND_LOAD);
    assign lsu_store_enable = !reset && (instruction_kind == KIND_STORE);

    // Decode operation details and choose datapath sources.
    always @(*) begin
        valid_instruction = !illegal_opcode;
        alu_select_a = A_REGISTER;
        alu_select_b = 1'b0;
        alu_operation = ALU_ADD;
        writeback_select = WB_ALU;
        next_pc_select = PC_SEQUENTIAL;

        case (instruction_kind)
            KIND_ALU_REG, KIND_ALU_IMM: begin
                alu_select_b = (instruction_kind == KIND_ALU_IMM);
                case (funct3)
                    3'b000: begin
                        if (instruction_kind == KIND_ALU_REG) begin
                            if (funct7 == 7'b0100000)
                                alu_operation = ALU_SUB;
                            else if (funct7 != 7'b0000000)
                                valid_instruction = 1'b0;
                        end
                    end
                    3'b001: alu_operation = ALU_SLL;
                    3'b010: alu_operation = ALU_SLT;
                    3'b011: alu_operation = ALU_SLTU;
                    3'b100: alu_operation = ALU_XOR;
                    3'b101: begin
                        if (funct7 == 7'b0000000)
                            alu_operation = ALU_SRL;
                        else if (funct7 == 7'b0100000)
                            alu_operation = ALU_SRA;
                        else
                            valid_instruction = 1'b0;
                    end
                    3'b110: alu_operation = ALU_OR;
                    3'b111: alu_operation = ALU_AND;
                endcase

                // Register ALU encodings and SLLI require funct7 = 0,
                // except ADD/SUB and SRL/SRA handled above.
                if (instruction_kind == KIND_ALU_REG &&
                    funct3 != 3'b000 && funct3 != 3'b101 &&
                    funct7 != 7'b0000000)
                    valid_instruction = 1'b0;
                if (instruction_kind == KIND_ALU_IMM &&
                    funct3 == 3'b001 && funct7 != 7'b0000000)
                    valid_instruction = 1'b0;
            end

            KIND_LOAD: begin
                alu_select_b = 1'b1;
                writeback_select = WB_LOAD;
                case (funct3)
                    3'b000, 3'b001, 3'b010, 3'b100, 3'b101: ;
                    default: valid_instruction = 1'b0;
                endcase
            end
            KIND_STORE: begin
                alu_select_b = 1'b1;
                case (funct3)
                    3'b000, 3'b001, 3'b010: ;
                    default: valid_instruction = 1'b0;
                endcase
            end
            KIND_BRANCH: begin
                alu_select_a = A_PC;
                alu_select_b = 1'b1;
                next_pc_select = branch_taken ? PC_TARGET : PC_SEQUENTIAL;
                case (funct3)
                    3'b000, 3'b001, 3'b100, 3'b101, 3'b110, 3'b111: ;
                    default: valid_instruction = 1'b0;
                endcase
            end
            KIND_JAL: begin
                alu_select_a = A_PC;
                alu_select_b = 1'b1;
                writeback_select = WB_LINK;
                next_pc_select = PC_TARGET;
            end
            KIND_JALR: begin
                alu_select_b = 1'b1;
                writeback_select = WB_LINK;
                next_pc_select = PC_JALR;
                if (funct3 != 3'b000)
                    valid_instruction = 1'b0;
            end
            KIND_LUI: begin
                alu_select_a = A_ZERO;
                alu_select_b = 1'b1;
            end
            KIND_AUIPC: begin
                alu_select_a = A_PC;
                alu_select_b = 1'b1;
            end
            KIND_SYSTEM: begin
                // CSR instructions and MRET are not implemented yet.
                if (instruction != 32'h0000_0073 &&
                    instruction != 32'h0010_0073)
                    valid_instruction = 1'b0;
            end
            KIND_FENCE: begin
                // No outstanding transactions: FENCE needs no action.
                // FENCE.I belongs to a separate extension and is rejected.
                if (funct3 != 3'b000)
                    valid_instruction = 1'b0;
            end
            default: valid_instruction = 1'b0;
        endcase
    end

    // State sequencing and write/request enables.
    always @(*) begin
        next_state = state;
        pending_fault_cause = 32'd2; // Illegal instruction
        fetch_enable = 1'b0;
        load_enable = 1'b0;
        store_enable = 1'b0;
        instruction_write_enable = 1'b0;
        operand_write_enable = 1'b0;
        alu_result_write_enable = 1'b0;
        load_result_write_enable = 1'b0;
        register_write_enable = 1'b0;
        pc_write_enable = 1'b0;

        if (!reset) begin
            case (state)
                FETCH: begin
                    fetch_enable = 1'b1;
                    if (fetch_complete) begin
                        instruction_write_enable = 1'b1;
                        next_state = DECODE;
                    end
                end
                DECODE: begin
                    if (!valid_instruction)
                        next_state = HALT;
                    else if (instruction_kind == KIND_SYSTEM) begin
                        next_state = HALT;
                        pending_fault_cause = (instruction == 32'h0000_0073)
                                              ? 32'd11 : 32'd3;
                    end
                    else begin
                        operand_write_enable = 1'b1;
                        next_state = EXECUTE;
                    end
                end
                EXECUTE: begin
                    alu_result_write_enable = 1'b1;
                    if (instruction_kind == KIND_LOAD ||
                        instruction_kind == KIND_STORE)
                        next_state = MEMORY;
                    else
                        next_state = WRITEBACK;
                end
                MEMORY: begin
                    // Check the saved address before requesting memory.
                    if (load_store_illegal)
                        next_state = HALT;
                    else if (load_store_misaligned) begin
                        next_state = HALT;
                        pending_fault_cause = (instruction_kind == KIND_LOAD)
                                              ? 32'd4 : 32'd6;
                    end
                    else begin
                        load_enable = (instruction_kind == KIND_LOAD);
                        store_enable = (instruction_kind == KIND_STORE);
                        if (data_complete) begin
                            load_result_write_enable = load_enable;
                            next_state = WRITEBACK;
                        end
                    end
                end
                WRITEBACK: begin
                    // next_pc_select uses the saved ALU result here.
                    // Faulting jumps must not write their link register.
                    if (next_pc_misaligned) begin
                        next_state = HALT;
                        pending_fault_cause = 32'd0;
                    end
                    else begin
                        pc_write_enable = 1'b1;
                        case (instruction_kind)
                            KIND_ALU_REG, KIND_ALU_IMM, KIND_LOAD,
                            KIND_JAL, KIND_JALR, KIND_LUI, KIND_AUIPC:
                                register_write_enable = 1'b1;
                            default: register_write_enable = 1'b0;
                        endcase
                        next_state = FETCH;
                    end
                end
                HALT: next_state = HALT;
                default: next_state = HALT;
            endcase
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            state <= FETCH;
            fault_cause <= 32'd0;
            fault_pc <= 32'd0;
        end
        else begin
            state <= next_state;
            if (next_state == HALT && state != HALT) begin
                fault_cause <= pending_fault_cause;
                fault_pc <= instruction_pc;
            end
        end
    end

endmodule
