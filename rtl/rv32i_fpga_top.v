`timescale 1ns/1ps

// FPGA integration top: CPU memory buses stay inside the FPGA.
// Writable instruction RAM and serial monitor stay outside the CPU core.
module rv32i_fpga_top #(
    parameter ROM_FILE = "",
    parameter integer CLOCK_HZ = 100000000,
    parameter integer BAUD = 115200
) (
    input wire clk,
    input wire reset,
    input wire uart_rx,
    output wire uart_tx,
    output wire [7:0] leds,
    output wire halted
);
    wire imem_req, dmem_req, dmem_we;
    wire [31:0] imem_addr, dmem_addr, dmem_wdata;
    wire [3:0] dmem_wstrb;
    reg [31:0] dmem_rdata;
    reg imem_ready, dmem_ready;
    wire [31:0] fault_cause, fault_pc;
    wire led_address;
    wire [31:0] core_dmem_rdata;
    wire running, restart;
    wire [8:0] loaded_words;
    wire program_we;
    wire [7:0] program_addr;
    wire [31:0] program_data;
    wire [7:0] rx_data, loader_tx_data;
    wire rx_valid, rx_error, loader_tx_valid, tx_ready;
    wire uart_address, uart_status_address;
    wire cpu_tx_valid;
    reg [31:0] result;
    // Synchronize the button in both directions; initialized for power-up.
    // Synchronous assertion also keeps asynchronous controls away from RAM.
    (* ASYNC_REG = "TRUE" *) reg [1:0] reset_sync = 2'b11;
    wire system_reset = reset_sync[1];
    wire core_reset = system_reset || !running || restart;
    always @(posedge clk)
        reset_sync <= {reset_sync[0], reset};

    (* ram_style = "block" *) reg [31:0] rom [0:255];
    // Synchronous reads and per-byte writes allow block RAM inference.
    (* ram_style = "block" *) reg [31:0] ram [0:255];
    integer i;
    integer lane;
    integer lane_result;

    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            rom[i] = 32'h00000013; // NOP
            ram[i] = 32'd0;
        end
        if (ROM_FILE == "") begin
            // Default demo: write 0x5a to LEDs, then loop indefinitely.
            rom[0] = 32'h100000b7; // LUI x1, 0x10000
            rom[1] = 32'h05a00113; // ADDI x2, x0, 0x5a
            rom[2] = 32'h0020a023; // SW x2, 0(x1)
            rom[3] = 32'h0000006f; // JAL x0, 0
        end else
            $readmemh(ROM_FILE, rom);
    end

    uart #(.CLOCK_HZ(CLOCK_HZ), .BAUD(BAUD)) u_uart (
        .clk(clk), .reset(system_reset), .rx(uart_rx), .tx(uart_tx),
        .rx_data(rx_data), .rx_valid(rx_valid), .rx_error(rx_error),
        .tx_data(loader_tx_valid ? loader_tx_data : dmem_wdata[7:0]),
        .tx_valid(loader_tx_valid || cpu_tx_valid), .tx_ready(tx_ready)
    );

    uart_program_loader #(.INITIAL_WORDS(ROM_FILE == "" ? 4 : 256)) u_loader (
        .clk(clk), .reset(system_reset),
        .rx_data(rx_data), .rx_valid(rx_valid), .rx_error(rx_error),
        .tx_data(loader_tx_data), .tx_valid(loader_tx_valid), .tx_ready(tx_ready),
        .running(running), .restart(restart), .loaded_words(loaded_words),
        .program_we(program_we), .program_addr(program_addr), .program_data(program_data),
        .halted(halted), .result(result), .fault_cause(fault_cause), .fault_pc(fault_pc)
    );

    // Separate RAM write port: loader only writes while the core is stopped.
    always @(posedge clk)
        if (program_we && !running && !system_reset)
            rom[program_addr] <= program_data;

    reg [31:0] instruction_word;
    always @(posedge clk)
        if (!core_reset && imem_req && !imem_ready)
            instruction_word <= rom[imem_addr[9:2]];
    // No asynchronous/reset controls on the RAM read port.
    wire valid_fetch = imem_addr[31:10] == 0 &&
                       {1'b0, imem_addr[9:2]} < loaded_words;
    assign leds = result[7:0];

    rv32i_core u_core (
        .clk(clk), .reset(core_reset),
        .imem_req(imem_req), .imem_addr(imem_addr),
        .imem_rdata(valid_fetch ? instruction_word : 32'd0), .imem_ready(imem_ready),
        .dmem_req(dmem_req), .dmem_addr(dmem_addr), .dmem_we(dmem_we),
        .dmem_wdata(dmem_wdata), .dmem_wstrb(dmem_wstrb),
        .dmem_rdata(core_dmem_rdata), .dmem_ready(dmem_ready),
        .halted(halted), .fault_cause(fault_cause), .fault_pc(fault_pc)
    );

    // Each request is serviced once. Ready is registered; on the following
    // edge the CPU consumes the response and this adapter drops ready.
    always @(posedge clk) begin
        if (core_reset) begin
            imem_ready <= 1'b0;
        end else begin
            imem_ready <= 1'b0;
            if (imem_req && !imem_ready) begin
                imem_ready <= 1'b1;
            end
        end
    end

    // Data RAM is initialized at FPGA configuration, and retained on reset.
    // Keep its read/write process free of reset for block RAM inference.
    always @(posedge clk) begin
        if (!core_reset && dmem_req && !dmem_ready && dmem_addr[31:10] == 0) begin
            dmem_rdata <= ram[dmem_addr[9:2]];
            if (dmem_we)
                for (lane = 0; lane < 4; lane = lane + 1)
                    if (dmem_wstrb[lane])
                        ram[dmem_addr[9:2]][8*lane +: 8] <=
                            dmem_wdata[8*lane +: 8];
        end
    end

    // Non-RAM reads are muxed onto the response without extra RAM ports.
    assign led_address = (dmem_addr[31:2] == 30'h04000000);
    assign uart_address = (dmem_addr[31:2] == 30'h04000001);
    assign uart_status_address = (dmem_addr[31:2] == 30'h04000002);
    assign cpu_tx_valid = !core_reset && dmem_req && !dmem_ready &&
                          dmem_we && uart_address && dmem_wstrb[0] && !loader_tx_valid;
    assign core_dmem_rdata = (dmem_addr[31:10] == 0) ?
                                dmem_rdata :
                                (led_address ? result :
                                 (uart_status_address ? {31'd0, tx_ready && !loader_tx_valid} : 32'd0));

    always @(posedge clk) begin
        if (core_reset) begin
            dmem_ready <= 1'b0;
            result <= 32'd0;
        end else begin
            dmem_ready <= 1'b0;
            if (dmem_req && !dmem_ready) begin
                // UART stores stall until the transmitter accepts their byte.
                if (!(dmem_we && uart_address && dmem_wstrb[0]) ||
                    (tx_ready && !loader_tx_valid))
                    dmem_ready <= 1'b1;
                if (dmem_we && led_address)
                    for (lane_result = 0; lane_result < 4; lane_result = lane_result + 1)
                        if (dmem_wstrb[lane_result])
                            result[8*lane_result +: 8] <= dmem_wdata[8*lane_result +: 8];
            end
        end
    end
endmodule
