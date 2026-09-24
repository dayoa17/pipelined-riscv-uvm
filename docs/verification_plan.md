# Verification Plan

## Objective

The goal of the verification environment is to validate the architectural correctness of the 5-stage pipelined RV32I processor and exercise key pipeline behaviors using directed and constrained-random testing.

Verification is performed through a UVM-based SystemVerilog testbench using a retirement-level monitor, architectural reference model, scoreboard, and functional coverage.

---

## Verification Environment

The UVM environment contains the following components:

- **Sequencer** – provides instruction-program transactions
- **Driver** – initializes instruction/data memory and controls reset
- **Monitor** – observes retired instructions and architectural side effects
- **Reference Model** – independently computes expected RV32I behavior
- **Scoreboard** – compares DUT retirement results against the reference model
- **Functional Coverage** – records exercised instruction and behavior categories

The retirement interface exposes:

- Retired program counter
- Retired instruction
- Register write enable
- Destination register
- Register write data
- Memory write enable
- Memory address
- Memory write data
- Illegal-instruction indication

This allows architectural correctness to be checked independently of internal pipeline timing.

---

## Features Under Verification

### Instruction Execution

Verify correct behavior for supported RV32I instruction groups:

- Register-register arithmetic and logical operations
- Immediate arithmetic and logical operations
- Shift instructions
- Loads
- Stores
- Conditional branches
- JAL and JALR
- LUI and AUIPC
- Illegal instruction handling

---

## Pipeline Behavior

The verification environment targets the following pipeline behaviors:

### Data Forwarding

Verify that dependent instructions receive the correct operand values through:

- EX/MEM forwarding
- MEM/WB forwarding

### Load-Use Hazards

Verify that an instruction dependent on a preceding load is stalled until the loaded value becomes available.

### Control Hazards

Verify that:

- Taken branches redirect the program counter correctly
- Jumps redirect execution correctly
- Wrong-path instructions are flushed
- Wrong-path instructions do not retire

### Register File Behavior

Verify that:

- Register writes produce the expected architectural value
- Register `x0` remains hardwired to zero

### Memory Operations

Verify supported:

- Byte loads
- Halfword loads
- Word loads
- Unsigned byte loads
- Unsigned halfword loads
- Byte stores
- Halfword stores
- Word stores

---

## Directed Test Strategy

The directed test intentionally targets known pipeline scenarios and corner cases.

Scenarios include:

- Arithmetic dependencies requiring forwarding
- Load followed immediately by a dependent instruction
- Taken branch and pipeline flush
- Store followed by load
- Arithmetic right shift behavior
- Basic register and memory correctness

The directed test is focused on behavior rather than coverage closure.

### Final Directed Regression

| Metric | Result |
|---|---:|
| Retired instructions | 73 |
| Scoreboard errors | 0 |
| Functional coverage | 52.00% |

---

## Coverage-Directed and Constrained-Random Strategy

The broader test begins with coverage-targeted instructions to exercise supported RV32I functional categories, followed by constrained-random ALU and immediate instructions.

Coverage-targeted scenarios include:

- LUI
- AUIPC
- JAL
- JALR
- All supported conditional branch types
- All supported load widths
- All supported store widths
- Register-register ALU operation categories
- Immediate ALU operation categories
- Arithmetic and logical shift variants
- FENCE handling
- Illegal instruction handling

The constrained-random portion introduces additional operand and instruction combinations beyond the fixed directed scenarios.

### Final Coverage-Directed / Constrained-Random Regression

| Metric | Result |
|---|---:|
| Retired instructions | 172 |
| Scoreboard errors | 0 |
| Defined functional coverage bins hit | 100% |

---

## Functional Coverage Plan

Functional coverage tracks the following categories:

- RV32I opcode classes
- Conditional branch types
- Load types
- Store types
- Register-register ALU operation categories
- Immediate ALU operation categories
- Arithmetic versus logical shift variants
- Register write behavior
- Memory write behavior
- Illegal-instruction behavior

Coverage is used to identify unexercised functional categories.

A covered bin indicates that a behavior was exercised, but does not by itself prove correctness. Correctness is established through scoreboard comparison against the architectural reference model.

---

## Scoreboard Strategy

The scoreboard maintains an independent architectural model containing:

- General-purpose register state
- Memory state
- Expected program counter

For every retired instruction, the reference model decodes and executes the instruction and predicts the expected architectural result.

The scoreboard checks:

- Destination register
- Register write enable
- Register write value
- Store enable
- Store address
- Store data
- Illegal-instruction status

Any mismatch is reported as a UVM error.

---

## Pass Criteria

A regression is considered successful when:

- The simulation compiles and elaborates successfully
- No UVM fatal errors occur
- No UVM errors occur
- The scoreboard reports zero architectural mismatches
- The expected instruction scenarios are exercised
- Coverage results are recorded and reviewed

---

## Final Verification Status

Both final verification tests completed successfully with zero scoreboard mismatches.

| Test | Retired Instructions | Scoreboard Errors | Functional Coverage |
|---|---:|---:|---:|
| Directed | 73 | 0 | 52.00% |
| Coverage-Directed / Constrained-Random | 172 | 0 | 100.00% |

The 100% result represents coverage of the functional bins defined by this verification environment and does not imply exhaustive verification of all possible RV32I processor states or instruction sequences.

---

## Out of Scope

The following are outside the scope of this project:

- Privileged RISC-V architecture
- CSR implementation
- Interrupts and exceptions beyond basic illegal-instruction detection
- Virtual memory
- Caches
- Multi-core operation
- Formal verification
- Full ISA compliance certification