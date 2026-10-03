`timescale 1ns/1ps

// Dedicated top-level program and fault regression with delayed memories.
module rv32i_core_tb;
    reg clk = 1'b0;
    reg reset = 1'b1;
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

        // Each phase resets control/PC, but intentionally preserves GPR contents.
        // Alignment failures must suppress both requests and architectural writes.
        @(negedge clk); reset=1;
        repeat (2) @(negedge clk);
        for (i=0; i<64; i=i+1) rom[i]=32'h00000013;
        rom[0]=32'h002000ef; // JAL x1, +2: invalid four-byte alignment
        reset=0; wait(halted); #1;
        check(fault_cause==0 && fault_pc==0, "JAL target alignment fault");
        check(`TEST_REGISTERS[1]==256, "faulting JAL cannot write its link register");

        @(negedge clk); reset=1; repeat (2) @(negedge clk);
        rom[0]=32'h0020a023; // SW x2, 0(x1), x1 is 256
        rom[1]=32'h002090a3; // SH x2, 1(x1): misaligned
        stores=0;
        reset=0; wait(halted); #1;
        check(fault_cause==6 && fault_pc==4 && stores==1,
              "misaligned SH causes no memory write");

        @(negedge clk); reset=1; repeat (2) @(negedge clk);
        rom[0]=32'h0020a183; // LW x3, 2(x1): misaligned
        reset=0; wait(halted); #1;
        check(fault_cause==4 && fault_pc==0, "misaligned LW reports load fault");
        check(`TEST_REGISTERS[3]==32'hffffffff, "faulting load cannot write rd");

        @(negedge clk); reset=1; repeat (2) @(negedge clk);
        rom[0]=32'h00000073; // ECALL
        reset=0; wait(halted); #1;
        check(fault_cause==11 && fault_pc==0, "ECALL fault reporting");

        @(negedge clk); reset=1; repeat (2) @(negedge clk);
        rom[0]=32'hffffffff; // Unrecognized opcode
        reset=0; wait(halted); #1;
        check(fault_cause==2 && fault_pc==0, "unknown opcode fault");

        @(negedge clk); reset=1; repeat (2) @(negedge clk);
        rom[0]=32'h022081b3; // MUL, unsupported extension
        reset=0; wait(halted); #1;
        check(fault_cause==2, "unsupported ALU encoding faults");

        @(negedge clk); reset=1; repeat (2) @(negedge clk);
        rom[0]=32'h0000100f; // FENCE.I, unsupported extension
        reset=0; wait(halted); #1;
        check(fault_cause==2, "unsupported FENCE.I faults");

        @(negedge clk); reset=1; repeat (2) @(negedge clk);
        rom[0]=32'h300110f3; // CSR instruction, not implemented
        reset=0; wait(halted); #1;
        check(fault_cause==2, "unsupported CSR instruction faults");

        // A false branch with a misaligned encoded target must NOT fault.
        @(negedge clk); reset=1; repeat (2) @(negedge clk);
        rom[0]=32'h00209163; // BNE x1, x2, +2: taken (256 != -1)
        reset=0; wait(halted); #1;
        check(fault_cause==0, "taken branch target alignment fault");

        @(negedge clk); reset=1; repeat (2) @(negedge clk);
        rom[0]=32'h00109163; // BNE x1, x1, +2: not taken
        rom[1]=32'h00100073;
        reset=0; wait(halted); #1;
        check(fault_cause==3 && fault_pc==4, "untaken branch ignores target alignment");

        // Attempt to write x0, then use x0 in another instruction.
        @(negedge clk); reset=1; repeat (2) @(negedge clk);
        rom[0]=32'h07b00013; // ADDI x0, x0, 123
        rom[1]=32'h00500793; // ADDI x15, x0, 5
        rom[2]=32'h00100073;
        reset=0; wait(halted); #1;
        check(`TEST_REGISTERS[15]==5, "x0 stays zero in complete core");

        // Reset while a data request is stalled, then restart at address zero.
        @(negedge clk); reset=1; repeat (2) @(negedge clk);
        rom[0]=32'h0000a183; // LW x3, 0(x1)
        rom[1]=32'h00100073;
        reset=0;
        wait(dmem_req && !dmem_ready);
        @(negedge clk); reset=1; #1;
        check(!imem_req && !dmem_req, "reset suppresses active memory requests");
        repeat (2) @(negedge clk);
        rom[0]=32'h00100073;
        reset=0; wait(halted); #1;
        check(fault_cause==3 && fault_pc==0, "reset during memory wait restarts at zero");

        if (failures == 0)
            $display("PASS: rv32i_core (program execution, faults, reset, memory waits)");
        else
            $display("FAIL: %0d checks failed", failures);
        $finish;
    end

    initial begin
        repeat (2000) @(posedge clk);
        $display("FAIL: simulation timeout");
        $finish;
    end
endmodule
`undef TEST_REGISTERS
