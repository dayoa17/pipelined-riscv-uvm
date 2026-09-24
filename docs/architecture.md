# Processor Architecture

## Overview

This project implements a 32-bit RV32I RISC-V processor using a classic 5-stage pipeline.

The pipeline consists of:

1. **Instruction Fetch (IF)**
2. **Instruction Decode / Register Read (ID)**
3. **Execute (EX)**
4. **Memory Access (MEM)**
5. **Write Back (WB)**

Pipeline registers separate each stage and carry both data and control signals through the processor.

---

## Pipeline Overview

```text
                       +----------------------+
                       |      Register File   |
                       | read in ID /         |
                       | write in WB          |
                       +----------+-----------+
                                  |
                                  v
+------+     +------+     +------+     +------+     +------+
|  IF  | --> |  ID  | --> |  EX  | --> | MEM  | --> |  WB  |
+------+     +------+     +------+     +------+     +------+
   |            |            |            |            |
   |            |            |            |            |
 IF/ID        ID/EX        EX/MEM        MEM/WB         |
 Reg          Reg           Reg           Reg           |
                             ^                           |
                             |                           |
                             +------ Forwarding ---------+
```

The processor includes additional control paths for:

- Data forwarding
- Load-use hazard detection
- Pipeline stalls
- Branch and jump redirection
- Pipeline flushing

---

## Instruction Fetch Stage

The IF stage is responsible for:

- Maintaining the program counter
- Reading the current instruction from instruction memory
- Computing the default next PC as `PC + 4`

Normally, the PC advances sequentially.

If a branch or jump is taken, the PC is redirected to the target address generated in the execute stage.

The fetched instruction and its PC are stored in the IF/ID pipeline register.

---

## Instruction Decode Stage

The ID stage performs:

- Instruction decoding
- Register-file reads
- Immediate generation
- Control-signal generation

The instruction fields identify:

- Source register `rs1`
- Source register `rs2`
- Destination register `rd`
- Opcode
- `funct3`
- `funct7`

The control unit determines which datapath operations are required for the current instruction.

The immediate generator supports the immediate formats required by RV32I:

- I-type
- S-type
- B-type
- U-type
- J-type

Decoded values and control signals are stored in the ID/EX pipeline register.

---

## Execute Stage

The EX stage performs arithmetic, logical, address-generation, and branch operations.

The ALU supports operations including:

- Addition
- Subtraction
- AND
- OR
- XOR
- Shift left logical
- Shift right logical
- Shift right arithmetic
- Signed comparison
- Unsigned comparison

The execute stage is also responsible for:

- Computing load/store addresses
- Computing branch targets
- Computing jump targets
- Evaluating branch conditions

Branch and jump decisions are resolved in the EX stage.

---

## Memory Access Stage

The MEM stage performs data-memory accesses.

Supported loads include:

- `LB`
- `LH`
- `LW`
- `LBU`
- `LHU`

Supported stores include:

- `SB`
- `SH`
- `SW`

Load data is extended appropriately before write back:

- `LB` and `LH` use sign extension
- `LBU` and `LHU` use zero extension
- `LW` returns the full 32-bit word

Byte write strobes are used to support byte, halfword, and word stores.

---

## Write Back Stage

The WB stage writes completed results into the register file.

Possible write-back sources include:

- ALU result
- Loaded memory data
- `PC + 4` for jump instructions
- Upper-immediate results

Register `x0` is permanently hardwired to zero and cannot be modified.

---

## Register File

The processor contains 32 general-purpose 32-bit registers.

Key behavior:

- Two asynchronous read ports
- One write port
- `x0` always reads as zero
- Writes to `x0` are ignored

The register-file write occurs on the negative clock edge in this educational implementation.

This allows a value written back during the current cycle to be visible to an instruction decoding during the following positive-edge pipeline update.

---

## Data Hazards

Pipeline execution can create situations where an instruction requires a value that has not yet reached the register file.

The processor handles these dependencies through forwarding and stalling.

---

## Forwarding

The forwarding unit compares source registers in the execute stage against destination registers in later pipeline stages.

Forwarding paths are provided from:

- EX/MEM
- MEM/WB

These paths allow dependent instructions to receive recently generated values without waiting for them to be written back to the register file.

Example:

```text
ADD x3, x1, x2
SUB x4, x3, x1
```

The `SUB` instruction requires `x3` before the preceding `ADD` reaches the WB stage.

The forwarding network supplies the `ADD` result directly to the execute stage.

---

## Load-Use Hazard Detection

A load-use hazard occurs when an instruction immediately following a load requires the loaded value.

Example:

```text
LW  x5, 0(x1)
ADD x6, x5, x2
```

The loaded value is not available early enough for normal EX/MEM forwarding.

The hazard detection unit responds by:

- Stalling the PC
- Stalling the IF/ID pipeline register
- Inserting a bubble into the ID/EX stage

Execution resumes once the load result becomes available.

---

## Control Hazards

Branches and jumps are resolved in the execute stage.

Until the decision is known, younger instructions may already have entered the pipeline.

When a taken branch or jump is detected:

- The PC is redirected to the target address
- The instruction in IF/ID is flushed
- The instruction in ID/EX is flushed

This prevents wrong-path instructions from modifying architectural state.

---

## Branch Support

The following conditional branches are implemented:

- `BEQ`
- `BNE`
- `BLT`
- `BGE`
- `BLTU`
- `BGEU`

Both signed and unsigned comparisons are supported.

Branch targets are calculated using:

```text
branch_target = instruction_PC + branch_immediate
```

---

## Jump Support

### JAL

`JAL` performs an unconditional PC-relative jump.

The processor:

- Writes `PC + 4` to the destination register
- Redirects execution to the jump target

### JALR

`JALR` performs an indirect jump using a register plus immediate offset.

The target address is formed from:

```text
rs1 + immediate
```

with the least significant address bit cleared according to the RISC-V specification.

---

## Upper-Immediate Instructions

### LUI

`LUI` writes the upper immediate directly into the destination register.

### AUIPC

`AUIPC` adds the upper immediate to the instruction's PC.

---

## Pipeline Control

The processor may perform one of three primary pipeline-control actions:

### Normal Advance

All pipeline stages advance normally.

### Stall

Used for load-use hazards.

The PC and IF/ID stage are held while a bubble is inserted into ID/EX.

### Flush

Used after taken branches and jumps.

Younger wrong-path instructions are invalidated before they can retire.

---

## Retirement Interface

The processor exposes a retirement interface for verification.

The interface reports architectural effects when an instruction completes, including:

- Program counter
- Instruction
- Register write enable
- Destination register
- Register write data
- Memory write enable
- Memory address
- Memory write data
- Illegal-instruction status

The UVM monitor uses this interface to send completed instructions to the architectural scoreboard.

This allows verification to focus on architectural correctness rather than internal cycle-by-cycle pipeline timing.

---

## Supported RV32I Scope

The implementation supports the primary RV32I integer instruction groups used by the project:

- Register-register ALU operations
- Immediate ALU operations
- Loads
- Stores
- Conditional branches
- JAL
- JALR
- LUI
- AUIPC

`FENCE` is treated as a no-operation.

Privileged architecture, CSRs, interrupts, caches, and virtual memory are outside the scope of this implementation.

---

## Design Summary

The processor demonstrates the major architectural concepts of a pipelined CPU, including:

- Multi-stage instruction execution
- Pipeline registers
- Control-signal propagation
- Data forwarding
- Hazard detection
- Pipeline stalls
- Branch flushing
- Memory access
- Register write back
- Retirement-based verification