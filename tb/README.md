# Verilog testbenches

Every RTL module has a dedicated `<module>_tb.v` file. All tests use
Verilog-2001 and run with Icarus Verilog (`iverilog` and `vvp`).

From the project directory, run all 23 Verilog testbenches plus nine host
uploader checks on Linux:

```bash
bash scripts/run_tests.sh
```

Run one module (example):

```bash
iverilog -g2001 -Wall -s load_store_unit_tb -o /tmp/lsu_tb rtl/*.v tb/load_store_unit_tb.v
vvp /tmp/lsu_tb
```

The runner compiles each testbench with `-g2001 -Wall` and checks the
simulation result. Any `FAIL:` message,
missing `PASS:` message, compilation failure, or nonzero simulator exit causes
the suite to fail. Simulator binaries are placed in a unique temporary folder
and removed on exit. No SystemVerilog assertions are required.

## Coverage

| Testbench | Behaviors checked |
| --- | --- |
| `register_file_tb.v` | Both read ports, all 32 addresses, synchronous writes, disabled writes, same-address read/write, x0 protection |
| `immediate_gen_tb.v` | All signed 12-bit I/S immediates, all B offsets, J boundaries and random offsets, U formats, unsupported opcodes |
| `alu_tb.v` | Every ALU operation, signed boundaries, arithmetic wraparound, all shifts 0–31, masked shift counts, unsupported operations |
| `decoder_tb.v` | All 128 opcodes and extracted fields with varied remaining bits |
| `branch_unit_tb.v` | Every funct3, equal/unequal operands, signed/unsigned boundaries and random comparisons |
| `load_store_unit_tb.v` | Every funct3 and byte offset, sign/zero extension, byte/halfword/word stores, lane data/strobes, illegal and misaligned accesses, idle and load priority |
| `program_counter_tb.v` | Reset priority, synchronous reset, enabled capture, disabled hold, PC+4 and wraparound |
| `instruction_register_tb.v` | Instruction/PC captured together, reset NOP, reset priority, capture/hold timing |
| `operand_registers_tb.v` | Both operands captured together, reset priority, capture/hold timing |
| `alu_result_register_tb.v` | Reset priority, capture/hold timing and changing input data |
| `load_result_register_tb.v` | Reset priority, capture/hold timing and changing input data |
| `alu_input_mux_tb.v` | Every A/B selection, zero input, reserved selection, changing source values |
| `writeback_mux_tb.v` | Every selection, ALU/load/link data, link wraparound, reserved selection |
| `next_pc_select_tb.v` | Every selection, all low-bit combinations, JALR bit clearing, alignment flags, PC wraparound |
| `memory_interface_tb.v` | All request/ready/fault combinations, conflicting requests, every strobe pattern, data forwarding and inactive write signals |
| `control_unit_tb.v` | State sequencing, waits, every ALU funct3/funct7 combination, load/store/branch/JALR/FENCE legality, selectors, faults, reset from each normal state |
| `datapath_tb.v` | Datapath driven by the controller: arithmetic, loads/stores, branches, jumps, AUIPC/LUI, delayed memory and request stability |
| `rv32i_core_tb.v` | Dedicated top-level program regression plus alignment/illegal/system faults, suppressed faulting writes, x0, reset during a stalled load |
| `rv32i_fpga_top_tb.v` | Serial uploads/acknowledgements, malformed input, arithmetic/STATUS, restart from HALT, STOP/reset, RAM word/byte/halfword access, CPU UART backpressure, shipped example, stale trailing instructions cannot execute |
| `uart_tb.v` | All 256 byte values in full duplex, TX framing/stop bits, false-start rejection, bad-stop error/recovery, reset idle, actual 100 MHz/115200-baud configuration |
| `uart_diagnostic_top_tb.v` | Raw wire loopback independent of reset, decoded UART echo, diagnostic/reset/activity indicators |
| `uart_program_loader_tb.v` | Exact STATUS/OK/ERR bytes including CR=0x0D and LF=0x0A, CR/LF/CRLF parsing, all 256 instruction addresses, overflow without address wraparound, reset/program retention |
| `compiled_c_tb.v` | Upload actual RV32I GCC output, Fibonacci=55 and UART text, stack access, BSS clearing with dirty RAM, repeated RUN |
| `upload_program_test.py` | Sparse readmemh/comments, input validation/bounds, acknowledged host upload ordering, upload without RUN, read-only status probe, empty-reply diagnostics, exact loopback payload and timeout/corruption handling |

The unit tests use directed boundaries, bounded pseudorandom input sequences,
and reference expectations. Integration tests initialize the GPRs they depend
on, because general-purpose registers are intentionally not reset.

For misaligned LSU accesses, the test checks the fault flag; it does not assign
meaning to the unused output data. The interface/controller tests verify those
accesses do not issue external requests.

## Current scope

This is a multi-cycle core, not a pipeline. Faults halt execution until reset;
CSR-based trap entry, MRET, and interrupts are not implemented. These tests
verify the current modules and selected complete programs, not exhaustive ISA
compliance, formal correctness, synthesis timing, or FPGA resource usage.
