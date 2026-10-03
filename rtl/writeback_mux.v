`timescale 1ns/1ps

module writeback_mux (
    input  wire [31:0] saved_alu_result,
    input  wire [31:0] saved_load_data,
    input  wire [31:0] instruction_pc,
    input  wire [1:0]  select,

    output reg  [31:0] writeback_data
);

    localparam WB_ALU  = 2'd0;
    localparam WB_LOAD = 2'd1;
    localparam WB_LINK = 2'd2;

    always @(*) begin
        case (select)
            WB_ALU:  writeback_data = saved_alu_result;
            WB_LOAD: writeback_data = saved_load_data;
            WB_LINK: writeback_data = instruction_pc + 32'd4;
            default: writeback_data = 32'd0;
        endcase
    end

endmodule
