# Pipelined RV32I RISC-V Processor with UVM Verification

A 5-stage pipelined 32-bit RISC-V processor implementing the RV32I base integer instruction set in SystemVerilog. The processor includes pipeline hazard handling, data forwarding, branch control, and a memory interface.

The design is verified using a UVM-based environment with directed and constrained-random testing, an architectural reference model, scoreboard checking, and functional coverage.

---

## Architecture

The processor implements a classic 5-stage pipeline:

1. **IF – Instruction Fetch**
2. **ID – Instruction Decode / Register Read**
3. **EX – Execute**
4. **MEM – Memory Access**
5. **WB – Write Back**

Pipeline control includes:

- EX/MEM and MEM/WB data forwarding
- Load-use hazard detection and pipeline stalling
- Branch and jump resolution in the EX stage
- Pipeline flushing for taken branches and jumps
- Register `x0` hardwired to zero
- Byte, halfword, and word memory accesses

---

## RV32I Instruction Support

The processor supports the following RV32I instruction groups.

### Arithmetic and Logical

- ADD, SUB
- AND, OR, XOR
- SLL, SRL, SRA
- SLT, SLTU

### Immediate

- ADDI
- ANDI, ORI, XORI
- SLLI, SRLI, SRAI
- SLTI, SLTIU

### Memory

- LB, LH, LW
- LBU, LHU
- SB, SH, SW

### Control Flow

- BEQ, BNE
- BLT, BGE
- BLTU, BGEU
- JAL, JALR

### Upper Immediate

- LUI
- AUIPC

`FENCE` is treated as a no-operation for this implementation. Privileged instructions and CSR functionality are outside the scope of the core.

---

## Verification Environment

The processor is verified using a UVM-based SystemVerilog testbench.

The environment includes:

- **Sequencer** – provides instruction-program transactions
- **Driver** – loads instruction and data memory and controls reset
- **Monitor** – observes retired instructions through the processor commit interface
- **Reference Model** – independently evaluates expected architectural behavior
- **Scoreboard** – compares retired processor state against the reference model
- **Functional Coverage** – measures exercised RV32I instruction and behavior categories

Verification is performed at the processor's retirement interface, allowing architectural results to be checked independently of internal pipeline timing.

---

## Test Strategy

### Directed Testing

A directed program targets specific pipeline and control behaviors, including:

- EX/MEM and MEM/WB forwarding
- Load-use dependencies and stalls
- Taken branch handling
- Wrong-path instruction flushing
- Load/store behavior
- Arithmetic right shifts

### Directed Test Results

| Metric | Result |
|---|---:|
| Retired instructions checked | 73 |
| Scoreboard errors | 0 |
| Functional coverage | 52.00% |

The directed test is intended to target specific pipeline scenarios rather than maximize functional coverage.

---

### Coverage-Directed and Constrained-Random Testing

The broader regression combines coverage-targeted instruction sequences with constrained-random ALU and immediate operations.

The test exercises:

- RV32I opcode categories
- All supported branch types
- Load and store widths
- OP and OP-IMM operation categories
- Shift variants
- Jump instructions
- Illegal-instruction detection

### Coverage-Directed / Constrained-Random Results

| Metric | Result |
|---|---:|
| Retired instructions checked | 172 |
| Scoreboard errors | 0 |
| Defined functional coverage bins hit | 100% |

The 100% result represents coverage of the functional bins defined by this verification environment. It does not imply exhaustive verification of every possible processor state or instruction sequence.

---

## Functional Coverage

Functional coverage tracks supported architectural categories including:

- Instruction opcode classes
- Branch instruction types
- Load instruction types
- Store instruction types
- Register-register ALU operations
- Immediate ALU operations
- Arithmetic and logical shift variants
- Register write behavior
- Memory write behavior
- Illegal-instruction handling

Coverage is used alongside architectural scoreboard checking rather than as a standalone measure of correctness.

---

## Debugging and Verification Findings

Simulation and verification uncovered several implementation and testbench issues during development, including:

- A register-file elaboration conflict caused by multiple procedural writers
- Signed arithmetic-shift handling in the architectural reference model
- SystemVerilog expression signedness behavior affecting SRA/SRAI checking

Each issue was reproduced in simulation, isolated, corrected, and verified through regression testing.

Additional details are documented in bug_log.md

---

## Repository Structure

```text
.
├── rtl/
│   ├── rv32i_pkg.sv
│   ├── alu.sv
│   ├── regfile.sv
│   ├── imm_gen.sv
│   ├── control_unit.sv
│   ├── forwarding_unit.sv
│   ├── hazard_unit.sv
│   ├── core_if.sv
│   ├── rv32i_core.sv
│   └── rv32i_top.sv
│
├── tb/
│   ├── tb_top.sv
│   └── uvm/
│       └── rv32i_uvm_pkg.sv
│
├── docs/
│   ├── architecture.md
│   ├── verification_plan.md
│   └── bug_log.md
│
├── tests/
├── filelist.f
└── README.md
```

---

## Running the Simulation

The project was verified using QuestaSim with SystemVerilog and UVM 1.2.

### Directed Test

Simulate with:

```text
+UVM_TESTNAME=directed_test
```

Expected final regression result:

```text
Retired instructions checked: 73
Scoreboard errors: 0
Functional coverage: 52.00%
```

### Coverage-Directed / Constrained-Random Test

Run the simulation with:

```text
+UVM_TESTNAME=random_test
```

Expected final regression result:

```text
Retired instructions checked: 172
Scoreboard errors: 0
Defined functional coverage: 100.00%
```

A successful regression should complete with zero scoreboard errors and zero UVM errors or fatal errors.

---

## Tools and Technologies

- **SystemVerilog** – RTL design and verification
- **UVM 1.2** – verification environment
- **QuestaSim** – compilation and simulation
- **RISC-V RV32I** – processor instruction-set architecture
- **Git / GitHub** – version control and project documentation

---

## Project Scope

This project is an educational implementation focused on:

- RTL processor design
- Pipelined computer architecture
- Data hazards and forwarding
- Pipeline stalls and control hazards
- SystemVerilog design
- UVM verification
- Architectural reference modeling
- Scoreboard-based checking
- Directed and constrained-random verification
- Functional coverage

The design is not intended to implement the complete RISC-V privileged architecture or serve as a production RISC-V core.

---

## Verification Status

Both final regressions are complete with zero architectural scoreboard mismatches.

| Test | Retired Instructions | Scoreboard Errors | Functional Coverage |
|---|---:|---:|---:|
| Directed | 73 | 0 | 52.00% |
| Coverage-Directed / Constrained-Random | 172 | 0 | 100.00%* |

\*100% represents coverage of the functional bins defined by this verification environment, not exhaustive verification of all possible RV32I execution scenarios.
