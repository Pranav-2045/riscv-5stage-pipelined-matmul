# E2E Test Infrastructure & Test Suite Documentation

## Overview
This document describes the End-to-End (E2E) Test Suite and Infrastructure created for the **5-Stage Pipelined RISC-V Processor with Custom Matmul Instruction**.

The test infrastructure is located at `pipelined/sim/` and provides automated assembly, verilog compilation (`iverilog`), simulation execution (`vvp`), signal/signature monitoring, and pass/fail reporting.

---

## Directory & File Structure (`pipelined/sim/`)

```
pipelined/sim/
├── assembler.py           # Custom RISC-V Assembler (RV32I + Custom Matmul opcode 0001011)
├── assemble_all.py       # Batch assembler script assembling all .s files -> .hex
├── testbench.v            # Parameterized Verilog E2E Testbench with +HEX_FILE & +TIMEOUT args
├── run_tests.py           # E2E Test Suite Runner (Compiles with iverilog, executes with vvp, formats reports)
├── run_tests.ps1          # PowerShell wrapper for run_tests.py
├── t1_rtype.s / .hex      # Tier 1: R-type instructions test
├── t1_itype.s / .hex      # Tier 1: I-type instructions test
├── t1_load_store.s / .hex # Tier 1: Load/Store instructions test
├── t1_branch_jump.s / .hex# Tier 1: Branch and Jump instructions test
├── t2_raw_ex_ex.s / .hex  # Tier 2: RAW EX->EX forwarding hazard test
├── t2_raw_mem_ex.s / .hex # Tier 2: RAW MEM->EX forwarding hazard test
├── t2_load_use_stall.s / .hex # Tier 2: Load-use hazard stall test
├── t2_branch_flush.s / .hex   # Tier 2: Branch control hazard flush test
├── t3_forward_branch.s / .hex # Tier 3: Forwarding into branch condition test
├── t3_load_use_branch.s / .hex# Tier 3: Load-use stall followed by branch test
├── t3_matmul_after_store.s / .hex # Tier 3: Custom Matmul following memory stores test
└── t4_matmul_full.s / .hex    # Tier 4: Real-world 4x4 matrix multiplication E2E test
```

---

## Custom RISC-V Assembler (`assembler.py`)

The assembler converts standard RISC-V assembly source files (`.s`) into 32-bit hex files (`.hex`) readable by `$readmemh`.

### Custom Instruction Encoding: `matmul rd, rs1, rs2`
- **Opcode**: `7'b0001011` (`0x0B`)
- **Funct3**: `3'b000`
- **Funct7**: `7'b0000000`
- **Encoding**: `0000000 | rs2[4:0] | rs1[4:0] | 000 | rd[4:0] | 0001011`
- **Semantics**: `rs1` = base address of Matrix A (16 32-bit words), `rs2` = base address of Matrix B (16 32-bit words), `rd` = base address of Matrix C destination (16 32-bit words).

---

## Test Suite Catalog (4 Tiers, 12 Test Cases)

| Tier | Test ID | Test Name | Description | Expected Address | Expected Value | Timeout |
|------|---------|-----------|-------------|------------------|----------------|---------|
| **1** | T1.1 | `t1_rtype` | R-type instructions (ADD, SUB, AND, OR, SLT) | `84` | `25` | 200 cycles |
| **1** | T1.2 | `t1_itype` | I-type instructions (ADDI positive/negative/zero) | `84` | `60` | 200 cycles |
| **1** | T1.3 | `t1_load_store` | Load & Store instructions (LW, SW) | `84` | `42` | 200 cycles |
| **1** | T1.4 | `t1_branch_jump` | Branch & Jump instructions (BEQ taken/not taken, JAL) | `84` | `77` | 200 cycles |
| **2** | T2.1 | `t2_raw_ex_ex` | RAW forwarding hazard from EX to EX stage | `84` | `20` | 200 cycles |
| **2** | T2.2 | `t2_raw_mem_ex` | RAW forwarding hazard from MEM to EX stage | `84` | `51` | 200 cycles |
| **2** | T2.3 | `t2_load_use_stall` | Load-use hazard requiring 1-cycle stall | `84` | `176` | 200 cycles |
| **2** | T2.4 | `t2_branch_flush` | Control hazard requiring branch speculative flush | `84` | `123` | 200 cycles |
| **3** | T3.1 | `t3_forward_branch` | Forwarding ALU result into branch condition | `84` | `200` | 250 cycles |
| **3** | T3.2 | `t3_load_use_branch` | Load-use stall immediately followed by branch | `84` | `222` | 250 cycles |
| **3** | T3.3 | `t3_matmul_after_store` | Issuing custom matmul immediately after stores | `84` | `300` | 500 cycles |
| **4** | T4.1 | `t4_matmul_full` | Full 4x4 Integer Matrix Multiplication program | `84` | `170` | 1000 cycles |

---

## Verilog Testbench (`testbench.v`)

The Verilog testbench features:
1. **Clock & Reset Generation**: 100MHz clock (10ns period), 22ns active-high reset.
2. **Dynamic Hex File Loading**: Reads `+HEX_FILE=<path>` command-line option at runtime or defaults to `riscvtest.hex`.
3. **Cycle Timeout Protection**: Configurable via `+TIMEOUT=<cycles>`, preventing infinite loops.
4. **Waveform Dumping**: Generates `riscv_tb.vcd` for GTKWave / visual debugging.
5. **Memory Monitoring**: Tracks every `memwrite` signal on falling edge of clock, logging byte address and data. Signature values written to memory address 84 (0x54) are verified.

---

## Execution Instructions

### Option 1: Python Runner (Cross-platform)
```powershell
python pipelined/sim/run_tests.py
```

### Option 2: PowerShell Runner
```powershell
powershell pipelined/sim/run_tests.ps1
```

### Option 3: Manual Assembly & Iverilog Execution
```powershell
# Assemble single test program
python pipelined/sim/assembler.py pipelined/sim/t4_matmul_full.s pipelined/sim/t4_matmul_full.hex

# Compile RTL and Testbench
iverilog -g2012 -I pipelined/rtl -o pipelined/sim/pipelined_tb.vvp pipelined/sim/testbench.v pipelined/rtl/*.v

# Execute simulation with vvp
vvp pipelined/sim/pipelined_tb.vvp +HEX_FILE=pipelined/sim/t4_matmul_full.hex +TIMEOUT=1000
```

---

## Initial Compilation Verification Results

All 12 assembly programs assemble cleanly, and `iverilog -g2012` successfully compiles `testbench.v` with all RTL files in `pipelined/rtl/` with zero compilation errors.
