`timescale 1ns/1ps

module memory_interface (
    // Internal CPU signals
    input  wire        fetch_enable,
    input  wire [31:0] fetch_address,
    output wire [31:0] fetched_instruction,
    output wire        fetch_complete,

    input  wire        load_enable,
    input  wire        store_enable,
    input  wire        data_fault,
    input  wire [31:0] data_address,
    input  wire [31:0] store_data,
    input  wire [3:0]  store_strobe,
    output wire [31:0] memory_read_data,
    output wire        data_complete,

    // External instruction memory port
    output wire        imem_req,
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_rdata,
    input  wire        imem_ready,

    // External data memory port
    output wire        dmem_req,
    output wire [31:0] dmem_addr,
    output wire        dmem_we,
    output wire [31:0] dmem_wdata,
    output wire [3:0]  dmem_wstrb,
    input  wire [31:0] dmem_rdata,
    input  wire        dmem_ready
);

    // The controller holds enables and request payloads stable until ready.
    // Completion is sampled at a rising clock edge with req && ready.
    assign imem_req = fetch_enable;
    assign imem_addr = fetch_address;
    assign fetched_instruction = imem_rdata;
    assign fetch_complete = imem_req && imem_ready;

    // Block faulty accesses and simultaneous load/store requests.
    // data_fault combines LSU misalignment and illegal-operation flags.
    assign dmem_req = (load_enable ^ store_enable) && !data_fault;
    assign dmem_addr = data_address;
    assign dmem_we = dmem_req && store_enable;
    assign dmem_wdata = dmem_we ? store_data : 32'd0;
    assign dmem_wstrb = dmem_we ? store_strobe : 4'b0000;
    assign memory_read_data = dmem_rdata;
    assign data_complete = dmem_req && dmem_ready;

    // Addresses are byte addresses. Reads return the complete aligned word
    // containing dmem_addr; the LSU uses data_address[1:0] to select bytes.
    // Write strobes refer to byte lanes in that same aligned word.

endmodule
