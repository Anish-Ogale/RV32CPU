`timescale 1ns/1ps

module control_unit_tb;
    reg clk = 1'b0;
    reg reset = 1'b1;
    reg [31:0] instruction = 32'h0000_0013;
    reg [31:0] instruction_pc = 32'h0000_0100;
    reg [3:0] instruction_kind = 4'd1;
    reg illegal_opcode = 1'b0;
    reg fetch_complete = 1'b0;
    reg data_complete = 1'b0;
    reg branch_taken = 1'b0;
    reg next_pc_misaligned = 1'b0;
    reg load_store_misaligned = 1'b0;
    reg load_store_illegal = 1'b0;
    wire fetch_enable, load_enable, store_enable;
    wire instruction_write_enable, operand_write_enable;
    wire alu_result_write_enable, load_result_write_enable;
    wire register_write_enable, pc_write_enable, halted;
    wire [31:0] fault_cause, fault_pc;
    wire [3:0] alu_operation;
    wire [1:0] writeback_select;
    wire [1:0] alu_select_a, next_pc_select;
    wire alu_select_b, lsu_load_enable, lsu_store_enable;
    integer family, f, upper, stage_index;
    reg expected_valid;
    reg [3:0] expected_operation;
    reg [31:0] encoded_instruction;
    integer checks = 0;
    integer failures = 0;

    control_unit dut (
        .clk(clk), .reset(reset), .instruction(instruction),
        .instruction_pc(instruction_pc), .instruction_kind(instruction_kind),
        .illegal_opcode(illegal_opcode), .fetch_complete(fetch_complete),
        .data_complete(data_complete), .branch_taken(branch_taken),
        .next_pc_misaligned(next_pc_misaligned),
        .load_store_misaligned(load_store_misaligned),
        .load_store_illegal(load_store_illegal),
        .fetch_enable(fetch_enable), .load_enable(load_enable),
        .store_enable(store_enable),
        .instruction_write_enable(instruction_write_enable),
        .operand_write_enable(operand_write_enable),
        .alu_result_write_enable(alu_result_write_enable),
        .load_result_write_enable(load_result_write_enable),
        .register_write_enable(register_write_enable),
        .pc_write_enable(pc_write_enable), .halted(halted),
        .fault_cause(fault_cause), .fault_pc(fault_pc),
        .alu_operation(alu_operation), .writeback_select(writeback_select),
        .alu_select_a(alu_select_a), .alu_select_b(alu_select_b),
        .next_pc_select(next_pc_select), .lsu_load_enable(lsu_load_enable),
        .lsu_store_enable(lsu_store_enable)
    );

    task tick;
        begin
            #5 clk = 1'b1;
            #1;
            clk = 1'b0;
            #4;
        end
    endtask

    task check;
        input condition;
        input [511:0] description;
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                $display("FAIL: %0s", description);
                failures = failures + 1;
            end
        end
    endtask

    task start_instruction;
        input [31:0] word;
        input [3:0] kind;
        begin
            reset = 1'b1;
            instruction = word;
            instruction_kind = kind;
            illegal_opcode = 1'b0;
            branch_taken = 1'b0;
            fetch_complete = 1'b0;
            data_complete = 1'b0;
            next_pc_misaligned = 1'b0;
            load_store_misaligned = 1'b0;
            load_store_illegal = 1'b0;
            tick;
            reset = 1'b0;
            #1;
            tick;
            check(fetch_enable && !instruction_write_enable,
                  "fetch must wait without capturing an instruction");
            fetch_complete = 1'b1;
            #1;
            check(instruction_write_enable, "capture on fetch completion");
            tick;
            fetch_complete = 1'b0;
        end
    endtask

    initial begin
        start_instruction(32'h0020_81b3, 4'd0); // ADD x3, x1, x2
        check(operand_write_enable, "ADD captures operands in decode");
        tick;
        check(alu_result_write_enable && !pc_write_enable,
              "ADD captures ALU result without early retirement");
        tick;
        check(register_write_enable && pc_write_enable,
              "ADD writes register and PC in writeback");
        tick;
        check(fetch_enable, "ADD returns to fetch");

        start_instruction(32'h0000_a183, 4'd2); // LW x3, 0(x1)
        tick;
        tick;
        check(load_enable && !store_enable, "load issues read request");
        tick;
        check(load_enable && !load_result_write_enable && !pc_write_enable,
              "load waits without writing or advancing PC");
        data_complete = 1'b1;
        #1;
        check(load_result_write_enable, "load captures completed read");
        tick;
        data_complete = 1'b0;
        check(register_write_enable && writeback_select == 2'd1,
              "load selects saved data for writeback");

        start_instruction(32'h0020_a023, 4'd3); // SW x2, 0(x1)
        tick;
        tick;
        check(store_enable, "store issues write request");
        data_complete = 1'b1;
        tick;
        data_complete = 1'b0;
        check(pc_write_enable && !register_write_enable && !store_enable,
              "completed store advances PC without register write");

        start_instruction(32'h0020_a023, 4'd3);
        load_store_misaligned = 1'b1;
        tick;
        tick;
        check(!store_enable && !load_enable,
              "misaligned store must never issue a request");
        tick;
        check(halted && fault_cause == 32'd6 && fault_pc == instruction_pc,
              "misaligned store records cause and instruction address");

        start_instruction(32'h0000_00ef, 4'd5); // JAL x1, 0
        next_pc_misaligned = 1'b1;
        tick;
        tick;
        check(!register_write_enable && !pc_write_enable,
              "misaligned jump suppresses link and PC writes");
        tick;
        check(halted && fault_cause == 32'd0, "jump alignment fault");

        start_instruction(32'h0220_81b3, 4'd0); // MUL: unsupported extension
        check(!operand_write_enable, "reject unsupported ALU encoding");
        tick;
        check(halted && fault_cause == 32'd2, "illegal instruction fault");
        tick;
        check(halted && !fetch_enable && !register_write_enable,
              "halt persists until reset");

        start_instruction(32'h0000_0073, 4'd9); // ECALL
        tick;
        check(halted && fault_cause == 32'd11, "machine ECALL cause");

        start_instruction(32'h0010_0073, 4'd9); // EBREAK
        tick;
        check(halted && fault_cause == 32'd3, "breakpoint cause");

        start_instruction(32'h4020_d193, 4'd1); // SRAI x3, x1, 2
        check(alu_operation == 4'd7, "SRAI chooses arithmetic right shift");

        // Check every ALU funct3/funct7 pair for both register and immediate
        // families. For non-shift immediates, upper bits belong to the constant.
        for (family=0; family<2; family=family+1)
            for (f=0; f<8; f=f+1)
                for (upper=0; upper<128; upper=upper+1) begin
                    encoded_instruction=(upper << 25) | (f << 12) |
                                        (family == 0 ? 32'h33 : 32'h13);
                    start_instruction(encoded_instruction, family);
                    if (family == 0)
                        expected_valid=(upper == 0) ||
                                       ((f == 0 || f == 5) && upper == 32);
                    else
                        expected_valid=(f != 1 && f != 5) ||
                                       (f == 1 && upper == 0) ||
                                       (f == 5 && (upper == 0 || upper == 32));
                    check(operand_write_enable === expected_valid,
                          "exhaustive ALU encoding validation");
                    case (f)
                        0: expected_operation=(family == 0 && upper == 32) ? 1 : 0;
                        1: expected_operation=5;
                        2: expected_operation=8;
                        3: expected_operation=9;
                        4: expected_operation=4;
                        5: expected_operation=(upper == 32) ? 7 : 6;
                        6: expected_operation=3;
                        7: expected_operation=2;
                    endcase
                    if (expected_valid)
                        check(alu_operation === expected_operation &&
                              alu_select_a == 0 && alu_select_b == (family == 1) &&
                              writeback_select == 0 && next_pc_select == 0,
                              "valid ALU operation and mux selections");
                end

        for (f=0; f<8; f=f+1) begin
            start_instruction((f << 12) | 32'h03, 4'd2);
            expected_valid=(f==0 || f==1 || f==2 || f==4 || f==5);
            check(operand_write_enable === expected_valid &&
                  lsu_load_enable && !lsu_store_enable &&
                  alu_select_b && writeback_select==1, "load encoding and routing");
            start_instruction((f << 12) | 32'h23, 4'd3);
            check(operand_write_enable === (f <= 2) &&
                  lsu_store_enable && !lsu_load_enable && alu_select_b,
                  "store encoding and routing");
            start_instruction((f << 12) | 32'h63, 4'd4);
            check(operand_write_enable === (f!=2 && f!=3) &&
                  alu_select_a==1 && alu_select_b && next_pc_select==0,
                  "branch encodings and untaken target selection");
            branch_taken=1; #1;
            check(next_pc_select==1, "taken branch target selection");
            start_instruction((f << 12) | 32'h67, 4'd6);
            check(operand_write_enable === (f==0) && writeback_select==2 &&
                  next_pc_select==2 && alu_select_b, "JALR encodings and routing");
            start_instruction((f << 12) | 32'h0f, 4'd10);
            check(operand_write_enable === (f==0), "FENCE versus unsupported encodings");
        end

        start_instruction(32'h123450b7, 4'd7); // LUI
        check(alu_select_a==2 && alu_select_b && alu_operation==0, "LUI routing");
        start_instruction(32'h12345097, 4'd8); // AUIPC
        check(alu_select_a==1 && alu_select_b && alu_operation==0, "AUIPC routing");
        start_instruction(32'h000000ef, 4'd5); // JAL
        check(alu_select_a==1 && alu_select_b && writeback_select==2 &&
              next_pc_select==1, "JAL routing");

        start_instruction(32'h0020a183, 4'd2);
        load_store_misaligned=1;
        tick; tick; tick;
        check(halted && fault_cause==4 && !load_enable, "misaligned load cause");
        instruction_pc=32'h9999; tick;
        check(fault_pc==32'h100 && fault_cause==4, "fault report retained during halt");
        instruction_pc=32'h100;

        start_instruction(32'h0000a183, 4'd2);
        load_store_illegal=1;
        tick; tick; tick;
        check(halted && fault_cause==2 && !load_enable, "LSU invalid operation cause");
        start_instruction(32'h300110f3, 4'd9); tick;
        check(halted && fault_cause==2, "CSR instructions currently illegal");
        start_instruction(32'h30200073, 4'd9); tick;
        check(halted && fault_cause==2, "MRET currently illegal");
        start_instruction(32'h00000013, 4'd1);
        illegal_opcode=1; #1; tick;
        check(halted && fault_cause==2, "decoder illegal flag propagated");

        // Reset at each normal phase suppresses requests/writes and returns
        // the FSM to FETCH. Fetch/memory completion are unrelated during reset.
        for (stage_index=0; stage_index<5; stage_index=stage_index+1) begin
            start_instruction(32'h0000a183, 4'd2);
            case (stage_index)
                0: begin end // DECODE
                1: tick; // EXECUTE
                2: begin tick; tick; end // MEMORY
                3: begin tick; tick; data_complete=1; tick; end // WRITEBACK
                4: begin tick; tick; data_complete=1; tick; tick; end // FETCH
            endcase
            reset=1; #1;
            check(!fetch_enable && !load_enable && !store_enable &&
                  !instruction_write_enable && !operand_write_enable &&
                  !alu_result_write_enable && !load_result_write_enable &&
                  !register_write_enable && !pc_write_enable &&
                  !lsu_load_enable && !lsu_store_enable, "reset suppresses all side effects");
            tick; reset=0; data_complete=0; #1;
            check(fetch_enable && !halted && fault_cause==0 && fault_pc==0,
                  "reset restarts controller and clears fault report");
        end

        if (failures == 0)
            $display("PASS: control_unit (%0d checks)", checks);
        else
            $display("FAIL: %0d checks failed", failures);
        $finish;
    end
endmodule
