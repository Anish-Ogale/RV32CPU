`timescale 1ns/1ps

module load_store_unit (
    input  wire        load_enable,
    input  wire        store_enable,
    input  wire [2:0]  funct3,
    input  wire [1:0]  address_offset,
    input  wire [31:0] register_data,
    input  wire [31:0] memory_read_data,

    output reg  [31:0] load_data,
    output reg  [31:0] memory_write_data,
    output reg  [3:0]  memory_write_strobe,
    output reg         misaligned,
    output reg         illegal_operation
);

    reg [31:0] shifted_read_data;

    always @(*) begin
        load_data           = 32'd0;
        memory_write_data   = 32'd0;
        memory_write_strobe = 4'b0000;
        misaligned          = 1'b0;
        illegal_operation   = 1'b0;

        shifted_read_data = memory_read_data >>
                            {address_offset, 3'b000};

        if (load_enable) begin
            case (funct3)
                3'b000: // LB
                    load_data = {{24{shifted_read_data[7]}},
                                 shifted_read_data[7:0]};

                3'b001: begin // LH
                    load_data = {{16{shifted_read_data[15]}},
                                 shifted_read_data[15:0]};
                    misaligned = address_offset[0];
                end

                3'b010: begin // LW
                    load_data = memory_read_data;
                    misaligned = |address_offset;
                end

                3'b100: // LBU
                    load_data = {24'd0, shifted_read_data[7:0]};

                3'b101: begin // LHU
                    load_data = {16'd0, shifted_read_data[15:0]};
                    misaligned = address_offset[0];
                end

                default:
                    illegal_operation = 1'b1;
            endcase
        end
        else if (store_enable) begin
            case (funct3)
                3'b000: begin // SB
                    memory_write_data = register_data <<
                                        {address_offset, 3'b000};
                    memory_write_strobe = 4'b0001 << address_offset;
                end

                3'b001: begin // SH
                    memory_write_data = register_data <<
                                        {address_offset, 3'b000};
                    memory_write_strobe = 4'b0011 << address_offset;
                    misaligned = address_offset[0];
                end

                3'b010: begin // SW
                    memory_write_data = register_data;
                    memory_write_strobe = 4'b1111;
                    misaligned = |address_offset;
                end

                default:
                    illegal_operation = 1'b1;
            endcase
        end
    end

endmodule
