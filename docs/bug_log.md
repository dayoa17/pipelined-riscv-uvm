# Debugging and Verification Log

This document records issues encountered while compiling, simulating, and verifying the pipelined RV32I processor.

The purpose of this log is to document the debugging process and distinguish RTL/elaboration issues from verification-environment issues.

---

## Issue 1: Register File Elaboration Conflict

### Type
RTL / SystemVerilog elaboration issue

### Symptom

QuestaSim failed during elaboration with an error indicating that the `regs` array was being driven by more than one process.

The register file originally initialized the register array using an `initial` block while also writing the array from an `always_ff` block.

### Root Cause

SystemVerilog `always_ff` requires variables written by the block to have a single procedural driver.

The register array was written by both:

- the `initial` initialization block
- the `always_ff @(negedge clk)` sequential block

This violated the `always_ff` single-driver requirement.

### Fix

The sequential register-file process was changed from:

```systemverilog
always_ff @(negedge clk)
```

to:

```systemverilog
always @(negedge clk)
```

This allowed the initialization block and sequential process to coexist in the simulation model.

### Result

The design successfully passed QuestaSim elaboration and simulation proceeded.

---

## Issue 2: SRAI Reference Model Mismatch

### Type
Verification environment / reference-model issue

### Symptom

During directed testing, the scoreboard reported:

```text
PC=00000030 expected x10=7fffffff got we=1 x10=ffffffff
```

The failing instruction was an arithmetic right shift immediate (`SRAI`) operating on `0xFFFFFFFF`.

The processor produced:

```text
0xFFFFFFFF
```

while the reference model expected:

```text
0x7FFFFFFF
```

### Root Cause

The DUT behavior was correct.

Arithmetic right shifting signed `0xFFFFFFFF` (-1) by one bit should produce `0xFFFFFFFF`.

The reference model used a ternary expression:

```systemverilog
res = f7[5] ?
      ($signed(a) >>> t.instr[24:20]) :
      (a >> t.instr[24:20]);
```

SystemVerilog expression sizing and signedness rules caused the arithmetic-shift result to be evaluated in an unsigned context, producing the logical-shift result.

### Fix

The ternary expression was replaced with an explicit conditional:

```systemverilog
if (f7[5])
  res = $signed(a) >>> t.instr[24:20];
else
  res = a >> t.instr[24:20];
```

### Result

The directed regression completed with:

```text
73 retired instructions
0 scoreboard errors
```

---

## Issue 3: SRA Reference Model Mismatch

### Type
Verification environment / reference-model issue

### Symptom

After expanding the coverage-directed test, the scoreboard reported:

```text
PC=0000009c expected x15=3fffffff got we=1 x15=ffffffff
```

The failing instruction was:

```text
SRA x15, x3, x2
```

with:

```text
x3 = 0xFFFFFFFF
x2 = 2
```

The DUT produced `0xFFFFFFFF`, while the reference model expected `0x3FFFFFFF`.

### Root Cause

The DUT was again correct.

The register-register `SRA` implementation in the reference model contained the same signedness issue previously discovered in the `SRAI` implementation:

```systemverilog
res = f7[5] ?
      ($signed(a) >>> b[4:0]) :
      (a >> b[4:0]);
```

The conditional expression caused the intended arithmetic shift to behave like a logical shift in the reference model.

### Fix

The expression was rewritten using an explicit conditional:

```systemverilog
if (f7[5])
  res = $signed(a) >>> b[4:0];
else
  res = a >> b[4:0];
```

### Result

The coverage-directed/constrained-random regression subsequently completed with:

```text
172 retired instructions
0 scoreboard errors
100% of defined functional coverage bins hit
```

---

## Final Regression Status

| Test | Retired Instructions | Scoreboard Errors | Functional Coverage |
|---|---:|---:|---:|
| Directed | 73 | 0 | 52.00% |
| Coverage-Directed / Constrained-Random | 172 | 0 | 100.00% |

The 100% coverage result refers specifically to the functional bins defined by the verification environment and does not represent exhaustive verification of every possible RV32I execution scenario.

---

## Lessons Learned

Development and verification of the processor highlighted several important SystemVerilog and verification concepts:

- `always_ff` imposes stricter single-driver requirements than a general `always` block.
- Signed and unsigned expression handling can affect arithmetic operations in SystemVerilog.
- A scoreboard or reference model can contain bugs independently of the DUT.
- A scoreboard mismatch should be investigated before assuming that the RTL is incorrect.
- Directed testing is useful for isolating specific pipeline behaviors and corner cases.
- Functional coverage helps identify untested instruction categories but does not by itself prove correctness.
- Regression testing after each fix is necessary to ensure that a correction does not introduce new failures.