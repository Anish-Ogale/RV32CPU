`timescale 1ns/1ps

module load_result_register (
    input  wire        clk,
    input  wire        reset,
    input  wire        write_enable,
    input  wire [31:0] load_data,

    output reg  [31:0] saved_load_data
);

    // Capture the formatted load value when a memory read completes.
    always @(posedge clk) begin
        if (reset) begin
            saved_load_data <= 32'd0;
        end
        else if (write_enable) begin
            saved_load_data <= load_data;
        end
    end

endmodule
