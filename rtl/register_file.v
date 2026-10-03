`timescale 1ns/1ps

module register_file (
    input  wire        clk,

    input  wire [4:0]  rs1_addr,
    input  wire [4:0]  rs2_addr,
    output wire [31:0] rs1_data,
    output wire [31:0] rs2_data,

    input  wire        rd_write_enable,
    input  wire [4:0]  rd_addr,
    input  wire [31:0] rd_data
);

    reg [31:0] registers [0:31];

    // Reads are combinational. Register x0 always reads as zero.
    assign rs1_data = (rs1_addr == 5'd0) ? 32'd0 : registers[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? 32'd0 : registers[rs2_addr];

    // Writes occur on the rising clock edge. Writes to x0 are ignored.
    always @(posedge clk) begin
        if (rd_write_enable && (rd_addr != 5'd0)) begin
            registers[rd_addr] <= rd_data;
        end
    end

endmodule
