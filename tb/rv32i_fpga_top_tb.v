`timescale 1ns/1ps
module rv32i_fpga_top_tb;
    localparam BIT_NS = 100; // Ten clock ticks per bit for fast simulation.
    reg clk = 0, reset = 1, rx = 1;
    wire tx, halted;
    wire [7:0] leds;
    integer failures = 0, received = 0, k, mark, word_number;
    reg [31:0] example_words [0:13];
    reg [7:0] transcript [0:8191];
    reg [7:0] byte_value;
    rv32i_fpga_top #(.BAUD(10000000)) dut (
        .clk(clk), .reset(reset), .uart_rx(rx), .uart_tx(tx), .leds(leds), .halted(halted));
    always #5 clk = ~clk;

    // Decode the physical TX wire independently of the DUT UART.
    initial forever begin
        @(negedge tx);
        #(BIT_NS + BIT_NS/2);
        for (k = 0; k < 8; k = k + 1) begin
            byte_value[k] = tx;
            #(BIT_NS);
        end
        if (tx !== 1) begin
            $display("FAIL: UART TX stop bit"); failures = failures + 1;
        end
        transcript[received] = byte_value;
        received = received + 1;
    end
    task check;
        input condition;
        input [511:0] description;
        begin
            if (condition !== 1) begin
                $display("FAIL: %0s", description); failures = failures + 1;
            end
        end
    endtask
    task send_byte;
        input [7:0] value;
        integer bit_number;
        begin
            rx = 0; #(BIT_NS);
            for (bit_number = 0; bit_number < 8; bit_number = bit_number + 1) begin
                rx = value[bit_number]; #(BIT_NS);
            end
            rx = 1; #(BIT_NS);
        end
    endtask
    task command;
        input [255:0] text;
        input integer size;
        input integer response_size;
        input [271:0] expected;
        integer j, start;
        begin
            start = received;
            for (j = size-1; j >= 0; j = j-1) send_byte(text[j*8 +: 8]);
            send_byte(8'h0d);
            wait(received >= start + response_size);
            for (j = 0; j < response_size; j = j+1)
                check(transcript[start+j] == expected[(response_size-1-j)*8 +: 8],
                      "serial monitor response");
            #(BIT_NS);
        end
    endtask
    function [63:0] hex_line;
        input [31:0] value;
        integer index;
        reg [3:0] nibble;
        begin
            for (index = 0; index < 8; index = index + 1) begin
                nibble = value[28-4*index +: 4];
                hex_line[63-8*index -: 8] = nibble < 10 ? 8'h30+nibble : 8'h41+nibble-10;
            end
        end
    endfunction
    initial begin
        $readmemh("examples/uart_add.hex", example_words);
        repeat (4) @(negedge clk); reset = 0;
        repeat (5) @(negedge clk);
        check(!dut.running && dut.core_reset, "CPU waits for RUN on power-up");
        command("LOAD", 4, 4, {"OK", 8'h0d, 8'h0a});
        command("RUN", 3, 5, {"ERR", 8'h0d, 8'h0a});
        command("bad!", 4, 5, {"ERR", 8'h0d, 8'h0a});
        command("123456789", 9, 5, {"ERR", 8'h0d, 8'h0a});
        check(dut.loaded_words == 0, "invalid input cannot change program extent");
        // x1=LED base; x2=7, x3=5, x4=x2+x3. Result=12. Then EBREAK.
        command("100000b7", 8, 4, {"OK", 8'h0d, 8'h0a});
        command("00700113", 8, 4, {"OK", 8'h0d, 8'h0a});
        command("00500193", 8, 4, {"OK", 8'h0d, 8'h0a});
        command("00310233", 8, 4, {"OK", 8'h0d, 8'h0a});
        command("0040a023", 8, 4, {"OK", 8'h0d, 8'h0a});
        command("00100073", 8, 4, {"OK", 8'h0d, 8'h0a});
        check(dut.rom[3] == 32'h00310233 && dut.loaded_words == 6,
              "UART writes instruction RAM in order");
        command("RUN", 3, 4, {"OK", 8'h0d, 8'h0a});
        wait(halted); @(negedge clk);
        check(leds == 12 && dut.result == 12, "uploaded arithmetic program executes");
        command("STATUS", 6, 34, {"S 1 1 0000000C 00000003 00000014", 8'h0d, 8'h0a});
        command("00100073", 8, 5, {"ERR", 8'h0d, 8'h0a}); // Cannot write while running.
        command("RUN", 3, 4, {"OK", 8'h0d, 8'h0a}); // Restarts even after HALT.
        wait(halted);
        check(dut.fault_pc == 20 && leds == 12, "RUN restarts an uploaded program");
        command("STOP", 4, 4, {"OK", 8'h0d, 8'h0a});
        check(dut.core_reset && !dut.running, "STOP holds CPU in reset");
        // Reuse the existing RAM/byte-lane regression via serial uploads.
        command("LOAD", 4, 4, {"OK", 8'h0d, 8'h0a});
        command("08000093", 8, 4, {"OK", 8'h0d, 8'h0a});
        command("fff00113", 8, 4, {"OK", 8'h0d, 8'h0a});
        command("0020a023", 8, 4, {"OK", 8'h0d, 8'h0a});
        command("0000a183", 8, 4, {"OK", 8'h0d, 8'h0a});
        command("05a00113", 8, 4, {"OK", 8'h0d, 8'h0a});
        command("002080a3", 8, 4, {"OK", 8'h0d, 8'h0a});
        command("0010c203", 8, 4, {"OK", 8'h0d, 8'h0a});
        command("00209123", 8, 4, {"OK", 8'h0d, 8'h0a});
        command("0020d283", 8, 4, {"OK", 8'h0d, 8'h0a});
        command("10000337", 8, 4, {"OK", 8'h0d, 8'h0a});
        command("00532023", 8, 4, {"OK", 8'h0d, 8'h0a});
        command("00034383", 8, 4, {"OK", 8'h0d, 8'h0a});
        command("00100073", 8, 4, {"OK", 8'h0d, 8'h0a});
        command("RUN", 3, 4, {"OK", 8'h0d, 8'h0a}); wait(halted);
        check(dut.ram[32] == 32'h005a5aff && leds == 8'h5a,
              "RAM stores and word/byte/halfword loads work after upload");
        check(dut.u_core.u_datapath.u_register_file.registers[3] == 32'hffffffff &&
              dut.u_core.u_datapath.u_register_file.registers[7] == 32'h5a,
              "RAM word read and result-register readback");
        // CPU UART output, including consecutive stores with backpressure.
        command("LOAD", 4, 4, {"OK", 8'h0d, 8'h0a});
        command("100000b7", 8, 4, {"OK", 8'h0d, 8'h0a});
        command("04100113", 8, 4, {"OK", 8'h0d, 8'h0a});
        command("00208223", 8, 4, {"OK", 8'h0d, 8'h0a}); // SB x2,4(x1)
        command("00208223", 8, 4, {"OK", 8'h0d, 8'h0a});
        command("00100073", 8, 4, {"OK", 8'h0d, 8'h0a});
        mark = received;
        // ACK is emitted first, then the two CPU characters.
        command("RUN", 3, 4, {"OK", 8'h0d, 8'h0a});
        wait(halted && received >= mark + 6);
        check(transcript[mark+4] == "A" && transcript[mark+5] == "A",
              "CPU UART writes emit exactly one character per store");
        #(2*BIT_NS);
        command("STATUS", 6, 34, {"S 1 1 00000000 00000003 00000010", 8'h0d, 8'h0a});
        command("LOAD", 4, 4, {"OK", 8'h0d, 8'h0a});
        for (word_number = 0; word_number < 14; word_number = word_number + 1)
            command(hex_line(example_words[word_number]), 8, 4, {"OK", 8'h0d, 8'h0a});
        mark = received;
        command("RUN", 3, 4, {"OK", 8'h0d, 8'h0a});
        wait(halted && received >= mark+8);
        check(leds == 12 && transcript[mark+4] == "O" && transcript[mark+5] == "K" &&
              transcript[mark+6] == 8'h0d && transcript[mark+7] == 8'h0a,
              "shipped example calculates 7+5 and prints OK with newline");
        #(2*BIT_NS);
        command("STATUS", 6, 34, {"S 1 1 0000000C 00000003 00000034", 8'h0d, 8'h0a});
        // Short replacement cannot execute stale trailing instructions.
        command("LOAD", 4, 4, {"OK", 8'h0d, 8'h0a});
        command("00000013", 8, 4, {"OK", 8'h0d, 8'h0a});
        command("RUN", 3, 4, {"OK", 8'h0d, 8'h0a}); wait(halted);
        check(dut.fault_cause == 2 && dut.fault_pc == 4,
              "fetch past uploaded extent faults rather than executing old RAM");
        // Button reset stops execution but preserves uploaded instructions/RAM.
        reset = 1; repeat (4) @(negedge clk); reset = 0;
        repeat (5) @(negedge clk);
        check(!dut.running && dut.loaded_words == 1 && dut.ram[32] == 32'h005a5aff,
              "button reset preserves RAM and stops CPU");
        command("RUN", 3, 4, {"OK", 8'h0d, 8'h0a}); wait(halted);
        if (failures == 0) $display("PASS: rv32i_fpga_top (serial upload, execution, output, reset)");
        else $display("FAIL: rv32i_fpga_top (%0d failures)", failures);
        $finish;
    end
    initial begin
        #2000000;
        $display("FAIL: rv32i_fpga_top timeout"); $finish;
    end
endmodule
