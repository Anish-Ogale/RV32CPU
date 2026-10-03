`timescale 1ns/1ps
module load_store_unit_tb;
    reg load_enable,store_enable;
    reg [2:0] funct3;
    reg [1:0] address_offset;
    reg [31:0] register_data,memory_read_data;
    wire [31:0] load_data,memory_write_data;
    wire [3:0] memory_write_strobe;
    wire misaligned,illegal_operation;
    integer mode,f,offset,i,lane;
    reg expected_illegal,expected_misaligned;
    reg [31:0] expected_load;
    reg [3:0] expected_strobe;
    reg [7:0] selected_byte;
    reg [15:0] selected_half;
    load_store_unit dut (.load_enable(load_enable), .store_enable(store_enable),
        .funct3(funct3), .address_offset(address_offset), .register_data(register_data),
        .memory_read_data(memory_read_data), .load_data(load_data),
        .memory_write_data(memory_write_data), .memory_write_strobe(memory_write_strobe),
        .misaligned(misaligned), .illegal_operation(illegal_operation));

    integer checks = 0;
    integer failures = 0;
    task check;
        input condition;
        input [511:0] description;
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                failures = failures + 1;
                $display("FAIL: %0s (check %0d)", description, checks);
            end
        end
    endtask

    initial begin
        for (mode=0; mode<4; mode=mode+1)
            for (f=0; f<8; f=f+1)
                for (offset=0; offset<4; offset=offset+1)
                    for (i=0; i<64; i=i+1) begin
                        load_enable=mode[0]; store_enable=mode[1];
                        funct3=f; address_offset=offset;
                        register_data=$random; memory_read_data=$random;
                        // Include explicit byte sign boundaries.
                        if (i==0) memory_read_data=32'h7f0080ff;
                        if (i==1) memory_read_data=32'h80007fff;
                        expected_illegal=0; expected_misaligned=0;
                        expected_load=0; expected_strobe=0;
                        if (load_enable) begin
                            expected_illegal=!(f==0 || f==1 || f==2 || f==4 || f==5);
                            if (f==1 || f==5) expected_misaligned=(offset % 2 != 0);
                            if (f==2) expected_misaligned=(offset != 0);
                            selected_byte=memory_read_data[8*offset +: 8];
                            selected_half=0;
                            if (offset==0 || offset==2)
                                selected_half=memory_read_data[8*offset +: 16];
                            case (f)
                                0: begin
                                    expected_load=selected_byte;
                                    if (selected_byte[7]) expected_load=expected_load | 32'hffffff00;
                                end
                                1: begin
                                    expected_load=selected_half;
                                    if (selected_half[15]) expected_load=expected_load | 32'hffff0000;
                                end
                                2: expected_load=memory_read_data;
                                4: expected_load=selected_byte;
                                5: expected_load=selected_half;
                                default: expected_load=0;
                            endcase
                        end
                        else if (store_enable) begin
                            expected_illegal=!(f==0 || f==1 || f==2);
                            if (f==1) expected_misaligned=(offset % 2 != 0);
                            if (f==2) expected_misaligned=(offset != 0);
                            if (!expected_illegal && !expected_misaligned)
                                for (lane=0; lane<4; lane=lane+1)
                                    expected_strobe[lane]=(lane >= offset) &&
                                        (lane < offset + (1 << f));
                        end
                        #1;
                        check(illegal_operation === expected_illegal &&
                              misaligned === expected_misaligned,"legality and alignment for every mode");
                        // Output data on misaligned accesses is not used by the core.
                        if (!expected_misaligned) begin
                            check(load_data === expected_load,"load extraction/sign extension or idle zero");
                            if (store_enable && !load_enable && !expected_illegal) begin
                                check(memory_write_strobe === expected_strobe,"store byte lanes");
                                for (lane=0; lane<4; lane=lane+1)
                                    if (expected_strobe[lane])
                                        check(memory_write_data[8*lane +: 8] ===
                                              register_data[8*(lane-offset) +: 8],
                                              "active store lane contains correct source byte");
                            end
                            else
                                check(memory_write_strobe === 0 && memory_write_data === 0,
                                      "no store output for idle, load, or invalid operation");
                        end
                    end

        if (failures == 0) $display("PASS: load_store_unit (%0d checks)", checks);
        else $display("FAIL: load_store_unit (%0d failures)", failures);
        $finish;

    end
endmodule

