# rv32cpu

A multi-cycle **RV32I** CPU core written in Verilog. The project is a learning exercise in processor design: each module is documented here with what it does and why it exists.

## Overview

rv32cpu implements the RV32I base integer instruction set using a **multi-cycle** architecture. A central FSM-based control unit steps each instruction through five stages: **Fetch → Decode → Execute → Memory → Writeback**. Registers between stages hold values so that later stages can use them even if earlier hardware has moved on.

### Single-cycle vs. pipelined vs. multi-cycle

- **Single-cycle**: every instruction completes entirely before the next begins. Simple, but the hardware for unused stages sits idle.
- **Pipelined**: as soon as an instruction leaves a stage, the next instruction enters it, so all stages stay busy. This is much faster but needs temporary registers after each stage.
- **Multi-cycle (this project)**: each instruction takes several clock cycles, one per stage, driven by a control FSM. The inter-stage registers described below are used here as well.

## Architecture

```
            +-------------------+
            |   Control Unit    |  (FSM: FETCH → DECODE → EXECUTE → MEMORY → WRITEBACK, HALT)
            +---------+---------+
                      |  control signals
  +---------+   +-----v-----+   +-----------+   +-----+   +-------------+
  |   PC    |-->|  Memory   |-->|  Decoder  |-->| ALU |-->| Load/Store  |
  | + mux   |   | Interface |   | + ImmGen  |   +-----+   |    Unit     |
  +---------+   +-----------+   +-----------+             +-------------+
                                      |                          |
                                +-----v-----+              Writeback mux
                                | Register  |<-------------------+
                                |   File    |
                                +-----------+
```

## Modules

### Register File
A bank of 32 registers, each 32 bits wide.

- `x0` is hardwired to zero: reads return 0 and writes are ignored.
- Two read ports (source registers `rs1`, `rs2`) output their data.
- One write port takes the destination register index `rd` and the data to write.
- A **write enable** signal gates writes; data is only written to `rd` when it is high.

### Immediate Generator
An *immediate* is a constant encoded directly inside an instruction. For example, in `addi x1, x2, 10` the value `10` is the immediate.

The immediate's bits are laid out differently depending on the instruction format (I, S, B, U, J). The immediate generator gathers the scattered bits for the current format and assembles them into the final 32-bit value.

### ALU (Arithmetic Logic Unit)
The main calculation block. It is **combinational** (unclocked), so results appear without waiting for a clock edge. It takes two operands and an operation select, and produces a result.

| Operation | Description |
|-----------|-------------|
| ADD | `a + b` |
| SUB | `a - b` |
| AND | bitwise AND |
| OR | bitwise OR |
| XOR | bitwise XOR |
| SLL | shift `a` left by `b[4:0]`; low bits filled with 0 |
| SRL | logical shift `a` right by `b[4:0]` |
| SRA | arithmetic shift right (preserves the sign bit) |
| SLT | 1 if `a < b` (signed) |
| SLTU | 1 if `a < b` (unsigned) |

Only the lower 5 bits of `b` are used for shifts, since 2⁵ = 32 is the maximum useful shift on a 32-bit value.

### Decoder
The decoder does two jobs:

1. **Field extraction**: splits the instruction into `opcode`, `funct3`, `funct7`, `rs1`, `rs2`, `rd`, etc.
2. **Classification**: uses the opcode to assign each instruction a *kind*:

| Kind | Purpose |
|------|---------|
| `kind_alu_reg` | Arithmetic/logic using two registers |
| `kind_alu_imm` | Arithmetic/logic using a register and an immediate |
| `kind_load` | Load data from memory into a register |
| `kind_store` | Store register data to memory |
| `kind_branch` | Conditional branch: add an offset to the PC when a condition holds |
| `kind_jal` | Jump and link: jump to PC + offset, saving the return address |
| `kind_jalr` | Jump and link register: jump to register + 12-bit offset, saving the return address (used for function returns) |
| `kind_lui` | Load upper immediate: place a 20-bit immediate in the upper bits of `rd` |
| `kind_auipc` | Add upper immediate to PC: `rd = PC + (imm << 12)` |
| `kind_system` | System instructions (reserved for CSR support) |
| `kind_fence` | Memory ordering fence |
| `kind_invalid` | Unrecognized opcode |

### Branch Unit
Evaluates branch conditions. Inputs are the two operands (from `rs1` and `rs2`) and `funct3`, which selects the comparison:

| funct3 | Instruction | Branch taken when |
|--------|-------------|-------------------|
| BEQ | Equal | `a == b` |
| BNE | Not equal | `a != b` |
| BLT | Less than (signed) | `a < b` |
| BGE | Greater or equal (signed) | `a >= b` |
| BLTU | Less than (unsigned) | `a < b` |
| BGEU | Greater or equal (unsigned) | `a >= b` |

Any other `funct3` value is flagged as an illegal branch instruction.

### Load/Store Unit
Sits between the memory interface and the register file. For loads, it takes the word returned from memory and formats it to the requested size (byte, halfword, or word), with the appropriate sign or zero extension. For stores, it prepares the data and byte positioning for the write.

### Program Counter
Tracks the address of the next instruction. It holds the current PC and updates to a new value when its write enable is high. The next PC is selected by the PC select mux (below).

### Memory Interface
The bridge between the CPU's internal blocks and the instruction/data memories. It implements a **request/ready handshake** (similar in spirit to AXI's valid/ready) so a transfer only happens when both sides are ready.

Example, `lw x1, 8(x2)`:

1. The ALU computes `x2 + 8`, which is stored in the ALU result register.
2. The control unit asserts a load enable to the memory interface.
3. The memory interface raises `dmem_req` to the data memory.
4. The data memory responds with ready and the requested word.
5. The interface asserts *data complete*, and the control unit tells the load/store unit to capture the data for writeback to `x1`.

## Inter-Stage Registers

Because an instruction spans several cycles, its inputs and intermediate results are held in registers so they stay stable while the rest of the CPU moves on.

| Register | Holds |
|----------|-------|
| **Instruction register** | The fetched instruction and its PC, until all stages finish. The memory moves on to the next address right after the fetch, so downstream blocks like the decoder read the instruction from here. |
| **Operand registers** | `rs1`/`rs2` values read during decode. Later stages use these copies instead of re-reading the register file, in case it changes in the meantime. |
| **ALU result register** | The ALU output captured at the end of the execute stage. |
| **Load result register** | The formatted load data captured in the memory stage, delivered to the register file during writeback. |

## Multiplexers

### ALU Input Mux
The ALU's operands can come from different places depending on the instruction.

| Select | Value | Source |
|--------|-------|--------|
| `select_a` | 0 | Saved register value (`rs1`) |
| | 1 | Instruction PC (e.g. `auipc`) |
| | 2 | Zero (e.g. `lui`) |
| `select_b` | 0 | Saved register value (`rs2`) |
| | 1 | Immediate |

This lets one ALU serve `add`, `addi`, `auipc`, `lui`, and more.

### Writeback Mux
Selects the data written to `rd` in the writeback stage.

| Select | Source | Used by |
|--------|--------|---------|
| 0 | ALU result | `add`, `addi`, `lui`, `auipc`, … |
| 1 | Saved load data | Loads |
| 2 | Instruction PC + 4 | `jal`, `jalr` (return address) |

### PC Select Mux
Chooses the next PC:

- **PC + 4**: normal sequential flow.
- **ALU result**: for `jal` and taken branches, where the ALU computes the target.
- **ALU result with LSB cleared**: for `jalr`.

Instruction addresses must be 4-byte aligned. Clearing only the LSB does not guarantee this, since bit 1 could still be set, so a **misaligned** output goes high whenever the lowest two bits of the target are not `00`.

## Control Unit

The central FSM, and the largest module (~300 lines). It coordinates everything else. It does three things:

1. Decodes the instruction kind and selects the ALU operation and operands.
2. Determines the next state.
3. Stores the current state on each clock edge.

**Inputs:** instruction, instruction address, instruction kind, and status signals such as fetch/data complete, illegal opcode, and branch taken.

**Outputs:**
- Fetch, load, and store requests
- Write enables
- Selectors (ALU inputs, ALU operation, writeback source, PC source)

### Datapath selection
For each instruction kind, a combinational `case` block picks the exact instruction using `funct3`/`funct7`, then determines the ALU inputs, ALU operation, writeback value, and next PC. For branches, the next PC is either the branch target or `PC + 4`, depending on whether the branch is taken.

### States

| State | Behavior |
|-------|----------|
| **FETCH** | Asserts `fetch_enable`; moves on when `fetch_complete` is high. |
| **DECODE** | Asserts `operand_write_enable` to latch the operands. Moves to HALT if the instruction is invalid. |
| **EXECUTE** | Captures the ALU result. Loads and stores go to MEMORY; everything else goes to WRITEBACK. |
| **MEMORY** | Checks address alignment and legality, going to HALT on a fault. Otherwise issues the load/store request and moves to WRITEBACK when `data_complete` is high. |
| **WRITEBACK** | Verifies the next PC is valid and updates the PC. Writes `rd` for instructions that produce a result (loads, ALU reg/imm, etc.). Stores and branches do not write `rd`. |
| **HALT** | Terminal error state. Outputs an error code identifying the fault and records the PC where it occurred. |


## UART and WRAPPER modules

The UART and top wrapper module exists to allow us to send data directly to the FPGA without having to reprogram the board for every new program

## Project Status

Work in progress. This is primarily a learning project, with the design and documentation developed together.

## License

TBD
