# 5-Stage Pipelined RISC-V (RV32I) Processor with 64-Cycle Matrix Multiplication Accelerator (`matmul`)

![Verilog](https://img.shields.io/badge/Language-Verilog_2001-blue.svg)
![RISC-V](https://img.shields.io/badge/ISA-RISC--V_RV32I-orange.svg)
![Simulation](https://img.shields.io/badge/Simulator-Icarus_Verilog_(iverilog)-green.svg)
![Verification](https://img.shields.io/badge/Tests-12%2F12_PASS-brightgreen.svg)

A synthesizable, cycle-accurate **5-stage pipelined RISC-V (RV32I) processor** implemented in Verilog. This core features a complete **Hazard Unit** supporting RAW data forwarding, load-use stall interlocks, and branch flushing, alongside an integrated hardware coprocessor executing a custom 64-cycle $4 \times 4$ integer matrix multiplication instruction (`matmul`).

This core represents an architectural progression from my previous **[Single-Cycle RISC-V Core](https://github.com/Pranav-2045/rv32i-single-cycle-core)**, evolving the baseline unpipelined datapath into a decoupled 5-stage execution pipeline with active hazard mitigation, stall interlocks, and dedicated coprocessor orchestration.
---

## Table of Contents
1. [Key Features](#key-features)
2. [Microarchitecture Overview](#microarchitecture-overview)
   - [5-Stage Pipeline Breakdown](#5-stage-pipeline-breakdown)
   - [Hazard Unit: Forwarding, Stalling & Flushing](#hazard-unit-forwarding-stalling--flushing)
3. [Custom Matrix Multiplier Accelerator (`matmul`)](#custom-matrix-multiplier-accelerator-matmul)
   - [Instruction Encoding & Semantics](#instruction-encoding--semantics)
   - [Why Exactly 64 Cycles?](#why-exactly-64-cycles)
   - [Memory Bus Hijacking & Arbitration](#memory-bus-hijacking--arbitration)
   - [Pipeline Stall & Drain Mechanics](#pipeline-stall--drain-mechanics)
   - [Comparison with a Systolic Array](#comparison-with-a-systolic-array-eg-google-tpu)
4. [File Inventory & Structure](#file-inventory--structure)
5. [Prerequisites & Setup](#prerequisites--setup)
6. [Verification Architecture & Automated Test Suite](#verification-architecture--automated-test-suite)
   - [Master Testbench & Test Architecture](#master-testbench--test-architecture)
   - [Are the .hex Files Combined or Run Individually?](#1-are-the-hex-files-combined-or-run-individually)
   - [Why Did We Need Python (`assembler.py`) & Multiple Tests? (Single-Cycle vs. Pipelined)](#2-why-did-we-need-python-assemblerpy-and-multiple-s--hex-files)
   - [Running the Automated Test Harness](#running-the-automated-test-harness)
7. [Executing Your Own Custom Programs](#executing-your-own-custom-programs)
8. [Step-by-Step: Uploading to GitHub with Git Bash](#step-by-step-uploading-to-github-with-git-bash)

---

## Key Features

🔗 **[Interactive HTML Schematic](https://pranav-2045.github.io/risv-5stage-pipelined-matmul/docs/schematics/interactive_schematic.html)**
- **Standard 5-Stage Pipeline**: Separate **Fetch (IF)**, **Decode (ID)**, **Execute (EX)**, **Memory (MEM)**, and **Writeback (WB)** stages with enable- and clear-capable pipeline registers (`flopenr`, `flopenrc`).
- **Comprehensive Hazard Handling**:
  - **Data Forwarding (Bypassing)**: Direct EX $\rightarrow$ EX, MEM $\rightarrow$ EX, and WB $\rightarrow$ EX forwarding paths for both source registers (`rs1`, `rs2`), preventing pipeline bubbles on RAW hazards.
  - **Load-Use Interlock**: Hardware stall detection that freezes the PC and IF/ID registers for 1 cycle while injecting a bubble (NOP) into ID/EX when an instruction depends on a preceding `lw`.
  - **Branch & Jump Flushes**: Control hazard detection in the EX stage, automatically flushing speculative instructions in the IF/ID and ID/EX registers upon a taken branch or jump.
- **Custom Hardware Accelerator (`matmul`)**:
  - Custom R-type instruction (`opcode = 7'b0001011`) multiplying two $4 \times 4$ 32-bit signed/unsigned integer matrices directly from memory:
    $$\mathbf{C}_{4 \times 4} = \mathbf{A}_{4 \times 4} \times \mathbf{B}_{4 \times 4}$$
  - Takes 3 memory base pointers via `rs1`, `rs2`, and `rd`.
  - Stalls the core and temporarily hijacks the data memory bus for exactly 64 cycles.
- **Built-in Assembler & Verification Harness**:
  - Custom Python assembler (`assembler.py`) supporting RV32I instructions and the custom `matmul` instruction.
  - Master testbench (`testbench.v`) and runner (`run_tests.py`) covering 12 targeted unit and end-to-end assembly test programs across 4 tiers.

---

## Microarchitecture Overview

```
                      [ Hazard Unit ]
            ┌──────────────┬──────────────────┬─────────────────┐
            │ ForwardAE/BE │ StallPC, StallID │ FlushID/FlushEX │
            ▼              ▼                  ▼                 ▼
 ┌──────┐ IF/ID ┌──────┐ ID/EX ┌──────┐ EX/MEM ┌──────┐ MEM/WB ┌──────┐
 │  IF  │──────>│  ID  │──────>│  EX  │───────>│  MEM │───────>│  WB  │
 └──────┘       └──────┘       └──────┘        └──────┘        └──────┘
    │              │               │               │               │
  [imem]       [regfile]         [alu]           [dmem]       [regwrite]
                                   │               ▲
                                   ▼               │
                         ┌───────────────────┐     │
                         │ matmul Coprocessor│─────┘ (Hijacks Memory Bus)
                         │    (64 Cycles)    │
                         └───────────────────┘
```

### 5-Stage Pipeline Breakdown

1. **Instruction Fetch (IF)**:
   - Tracks the current program counter (`PCF`) using `flopenr`.
   - Computes `PCPlus4F = PCF + 4`.
   - Selects next PC between `PCPlus4F` and branch/jump target (`PCTargetE`) via `PCSrcE`.
   - Reads 32-bit instruction from `imem`.
2. **Instruction Decode (ID)**:
   - Pipeline register `regID` (`flopenrc`) latches instruction and PC.
   - Dual-read, single-write 32-bit register file (`regfile`) reads `rs1` and `rs2`.
   - Multiplexed `a1D` address port enables reading the 3rd pointer (`rd`) for `matmul`.
   - Immediate generator (`extend`) unpacks I, S, B, and J type immediates.
   - Main decoder (`maindec`) and ALU decoder (`aludec`) produce stage-by-stage control signals.
3. **Execute (EX)**:
   - Pipeline register `regE` (`flopenrc`) latches register values, immediates, and control lines.
   - Forwarding multiplexers (`forwarda_mux`, `forwardb_mux`) select between register file outputs, MEM-stage forwarded results (`aluresultM`), and WB-stage forwarded results (`ResultW`).
   - ALU executes arithmetic, logic, and comparisons (ADD, SUB, AND, OR, SLT).
   - Computes branch target address: `PCTargetE = PCE + immextE`.
   - Evaluates branch conditions and jump logic to assert `PCSrcE`.
4. **Memory Access (MEM)**:
   - Pipeline register `regM` (`flopenrc`) latches ALU results and write data.
   - Reads or writes 32-bit words to/from `dmem`.
   - During normal execution, routes `aluresultM` as memory address and `writedataM` as memory write data.
5. **Writeback (WB)**:
   - Pipeline register `regW` (`flopr`) latches memory read data and ALU results.
   - Multiplexer (`resultmux`) selects between ALU result, memory read data, or `PC+4`.
   - Writes the chosen value back to register `RdW` if `RegWriteW` is asserted.

---

### Hazard Unit: Forwarding, Stalling & Flushing

Located in [`pipelined/rtl/hazard.v`](file:///c:/Users/prana/OneDrive/Desktop/risk%20V/pipelined/rtl/hazard.v), the Hazard Unit guarantees in-order correctness without software NOP insertion:

| Hazard Condition | Detection Logic | Hardware Resolution |
| :--- | :--- | :--- |
| **RAW (EX $\rightarrow$ EX)** | `(Rs1E != 0) && (Rs1E == RdM) && RegWriteM` | `ForwardAE = 2'b10`: Forwards `aluresultM` directly to ALU input A. |
| **RAW (MEM $\rightarrow$ EX)** | `(Rs1E != 0) && (Rs1E == RdW) && RegWriteW` | `ForwardAE = 2'b01`: Forwards `ResultW` directly to ALU input A. |
| **Load-Use Hazard** | `ResultSrcE[0] && ((Rs1D == RdE) \|\| (Rs2D == RdE)) && (RdE != 0)` | Stalls `PC` and `IF/ID` (`StallPC=1, StallID=1`), flushes `ID/EX` (`FlushEX=1`) for 1 cycle. |
| **Control Hazard (Branch/Jump)** | `PCSrcE != 0` (Branch taken or JAL/JALR) | Flushes speculative instructions in `IF/ID` (`FlushID=1`) and `ID/EX` (`FlushEX=1`). |
| **`matmul` Execution** | `matmul_startE \|\| matmul_busy` | Freezes `PC`, `IF/ID`, and `ID/EX` for 64 cycles while older instructions in MEM/WB drain. |

---

## Custom Matrix Multiplier Accelerator (`matmul`)

### Instruction Encoding & Semantics

The `matmul` instruction performs a full $4 \times 4$ integer matrix multiplication using three memory pointers passed via standard RISC-V registers:

```assembly
matmul rd, rs1, rs2
```

- **`rs1`**: Register containing the 32-bit base address of Matrix A (16 elements $\times$ 4 bytes = 64 bytes).
- **`rs2`**: Register containing the 32-bit base address of Matrix B (16 elements $\times$ 4 bytes = 64 bytes).
- **`rd`**: Register containing the 32-bit base address where destination Matrix C will be stored.
- **Opcode**: `7'b0001011` (`0x0B`).
- **Register Writeback**: `regwrite = 0` (Matrix C is written directly to data memory, not to the register file).

---

### Why Exactly 64 Cycles?

Because standard embedded RISC-V architectures feature a **single-port 32-bit memory bus**, memory bandwidth is limited to **one 32-bit word per clock cycle**:

$$\text{Total Execution Time} = 16 \text{ (Read A)} + 16 \text{ (Read B)} + 16 \text{ (Compute C)} + 16 \text{ (Write C)} = \mathbf{64 \text{ Clock Cycles}}$$

```
  Cycle 1..16         Cycle 17..32         Cycle 33..48         Cycle 49..64
┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│    READ_A    │ ──>│    READ_B    │ ──>│   COMPUTE    │ ──>│   WRITE_C    │
│ 16 words in  │    │ 16 words in  │    │ 16 dot prods │    │ 16 words out │
└──────────────┘    └──────────────┘    └──────────────┘    └──────────────┘
```

1. **`READ_A` (16 cycles)**: Reads 16 sequential words from `baseA + (counter << 2)` into internal register array `matA[0..15]`.
2. **`READ_B` (16 cycles)**: Reads 16 sequential words from `baseB + (counter << 2)` into internal register array `matB[0..15]`.
3. **`COMPUTE` (16 cycles)**: In each cycle, calculates 1 entry of Matrix C using 4 parallel multipliers and an adder tree:
   $$\text{matC}[i, j] = \text{matA}[i, 0] \times \text{matB}[0, j] + \text{matA}[i, 1] \times \text{matB}[1, j] + \text{matA}[i, 2] \times \text{matB}[2, j] + \text{matA}[i, 3] \times \text{matB}[3, j]$$
4. **`WRITE_C` (16 cycles)**: Sequentially writes 16 computed words from `matC[0..15]` to `baseC + (counter << 2)` in data memory.

---

### Memory Bus Hijacking & Arbitration

In [`pipelined/rtl/top.v`](file:///c:/Users/prana/OneDrive/Desktop/risk%20V/pipelined/rtl/top.v), a high-speed memory arbiter multiplexes the Data Memory interface between the normal CPU pipeline and the `matmul` engine:

```verilog
assign dmem_we    = matmul_busy ? matmul_dmem_we    : mem_we;
assign dmem_addr  = matmul_busy ? matmul_dmem_addr  : mem_addr;
assign dmem_wdata = matmul_busy ? matmul_dmem_wdata : mem_wdata;
assign mem_rdata  = dmem_rdata;
assign matmul_dmem_rdata = dmem_rdata;
```

While `matmul_busy` is asserted, the `matmul` engine directly controls the memory address, data write, and write-enable lines.

---

### Pipeline Stall & Drain Mechanics

To prevent race conditions with older instructions still in the pipeline, the Hazard Unit implements a 6-state FSM:
1. **`M_IDLE`**: Awaiting `matmul_startE`. Pointers `rs1` and `rs2` are latched from the EX stage forwarded outputs (`srcaE`, `writedataE`).
2. **`M_DRAIN1`**: Freezes `PC`, `IF/ID`, and `ID/EX`. Asserts `matmul_rd_sel` to route the `rd` register index to the register file `a1` port, latching the destination pointer into `rd_val`.
3. **`M_DRAIN2`**: Emits `matmul_start` pulse to the `matmul` accelerator. In-flight instructions in the MEM and WB stages commit cleanly.
4. **`M_WAIT_BUSY`**: Waits for `matmul_busy` from the coprocessor.
5. **`M_RUNNING`**: Holds `StallPC`, `StallID`, and `StallEX` high while the 64-cycle operation executes. Injects NOPs into the pipeline.
6. **`M_DONE`**: `matmul_busy` drops to 0. Unfreezes the pipeline registers seamlessly and resumes normal execution at the next instruction.

---

### Comparison with a Systolic Array (e.g., Google TPU)

| Metric / Feature | Our FSM Coprocessor | Systolic Array (TPU / NPU) |
| :--- | :--- | :--- |
| **Architecture** | Sequential State Machine + Local Registers | 2D Grid of Pipelined Processing Elements (PEs) |
| **Dataflow** | Memory $\rightarrow$ Registers $\rightarrow$ Multiply-Accumulate $\rightarrow$ Memory | Data streams rhythmically across adjacent PEs in a wave-front |
| **Memory Port Width** | **Single 32-bit port** (1 word/cycle) | **Wide Vector Bus** (e.g., 256-bit to 1024-bit parallel ports) |
| **Throughput** | 1 matrix product per 64 cycles | 1 matrix product per cycle (once pipeline fills) |
| **Area Overhead** | **Extremely Low** (4 multipliers, 1 adder tree, 48 registers) | **Large Area** ($N \times N$ Multiply-Accumulate Units) |
| **Ideal Use Case** | Embedded RV32I microcontroller with area constraints | High-performance machine learning inference/training accelerators |

---

## File Inventory & Structure

```
pipelined/
├── .gitignore             # Ignores simulation traces (*.vcd) and binaries (*.vvp)
├── README.md              # Complete architecture, usage, and verification guide
├── rtl/                   # Synthesizable Verilog RTL modules
│   ├── adder.v            # 32-bit adder (PC increment & branch calculation)
│   ├── alu.v              # Arithmetic Logic Unit (ADD, SUB, AND, OR, SLT)
│   ├── aludec.v           # ALU decoder translating funct and ALUOp to ALUControl
│   ├── controller.v       # Decodes opcodes and pipelines control signals across stages
│   ├── datapath.v         # 5-stage datapath, pipeline registers, and ALU/RF routing
│   ├── dmem.v             # Synchronous write, asynchronous read data memory
│   ├── extend.v           # Sign-extension unit for I, S, B, and J-type immediates
│   ├── flopenr.v          # D flip-flop with active-high synchronous/asynchronous enable
│   ├── flopenrc.v         # D flip-flop with enable and synchronous clear (flush)
│   ├── flopr.v            # Standard D flip-flop with reset
│   ├── hazard.v           # Hazard unit: forwarding, load-stalls, flushes, matmul FSM
│   ├── imem.v             # Asynchronous read instruction memory initialized from hex
│   ├── maindec.v          # Main opcode decoder (including matmul opcode 0001011)
│   ├── matmul.v           # 64-cycle 4x4 matrix multiplication hardware engine
│   ├── mux2.v             # 2-to-1 32-bit multiplexer
│   ├── mux3.v             # 3-to-1 32-bit multiplexer (forwarding and result selection)
│   ├── regfile.v          # 32x32-bit dual-read single-write register file (x0 hardwired to 0)
│   ├── riscvpipelined.v   # Top core wrapper integrating controller, datapath, hazard, matmul
│   └── top.v              # Top-level module connecting core, imem, dmem, and memory arbiter
└── sim/                   # Testbenches, assembler, and test suites
    ├── assemble_all.py    # Python script to batch-assemble all .s files to .hex
    ├── assembler.py       # Custom RV32I + matmul assembler
    ├── run_tests.ps1      # PowerShell execution script for automated testing
    ├── run_tests.py       # Master automated test harness running all 12 test cases
    ├── testbench.v        # Master Verilog testbench driving clock, reset, and memory logging
    ├── t1_rtype.s/.hex    # Tier 1 Test: ADD, SUB, AND, OR, SLT instruction execution
    ├── t1_itype.s/.hex    # Tier 1 Test: ADDI positive, negative, and zero execution
    ├── t1_load_store.s/.hex # Tier 1 Test: LW and SW memory operations
    ├── t1_branch_jump.s/.hex# Tier 1 Test: BEQ branch and JAL jump execution
    ├── t2_raw_ex_ex.s/.hex# Tier 2 Test: RAW data hazard with EX->EX forwarding
    ├── t2_raw_mem_ex.s/.hex# Tier 2 Test: RAW data hazard with MEM->EX forwarding
    ├── t2_load_use_stall.s/.hex # Tier 2 Test: Load-use 1-cycle stall interlock
    ├── t2_branch_flush.s/.hex # Tier 2 Test: Branch misprediction pipeline flush
    ├── t3_forward_branch.s/.hex # Tier 3 Test: Forwarding result into branch condition
    ├── t3_load_use_branch.s/.hex # Tier 3 Test: Load-use stall immediately followed by branch
    ├── t3_matmul_after_store.s/.hex # Tier 3 Test: Custom matmul executed right after store
    └── t4_matmul_full.s/.hex # Tier 4 Test: Full 4x4 matrix multiplication end-to-end
```

---

## Prerequisites & Setup

To compile, simulate, and assemble programs for this processor, ensure you have the following installed:

1. **Icarus Verilog (`iverilog`) & `vvp`**:
   - **Windows**: Download the installer from [bleyer.org/icarus](https://bleyer.org/icarus/) (make sure to check "Add to PATH").
   - **Linux (Ubuntu/Debian)**:
     ```bash
     sudo apt update && sudo apt install iverilog
     ```
   - **macOS**:
     ```bash
     brew install icarus-verilog
     ```
2. **Python 3.8+**:
   - Verify by running `python --version` or `python3 --version`.
3. **GTKWave (Optional)**:
   - For visual inspection of generated waveform traces (`riscv_tb.vcd`).

---

## Verification Architecture & Automated Test Suite

### Master Testbench & Test Architecture

The entire simulation ecosystem is orchestrated by **one single Master Testbench** (`sim/testbench.v`) driven by **one Master Python Test Harness** (`sim/run_tests.py`):

```
                       ┌─────────────────────────────────────────┐
                       │          run_tests.py                   │
                       │     (Master Test Harness)               │
                       └────────────────────┬────────────────────┘
                                            │
                1. Compiles RTL + testbench.v via iverilog -> pipelined_tb.vvp
                2. Feeds 12 .hex test cases sequentially via vvp +HEX_FILE=...
                                            │
                                            ▼
                       ┌─────────────────────────────────────────┐
                       │           testbench.v                   │
                       │        (Master Testbench)               │
                       └────────────────────┬────────────────────┘
                                            │
                         Drives Clock / Reset / Hex Preload
                                            │
                                            ▼
                       ┌─────────────────────────────────────────┐
                       │             top.v                       │
                       │       (Top-Level Hardware)              │
                       └───────┬────────────┬────────────┬───────┘
                               │            │            │
                         ┌─────▼──────┐ ┌───▼───┐ ┌──────▼──────┐
                         │   imem.v   │ │  dmem │ │    riscv    │
                         │(Instr Mem) │ │ (Data)│ │pipelined.v  │
                         └────────────┘ └───────┘ └─────────────┘
```

---

### 1. Are the .hex files combined or run individually?

**They are run INDIVIDUALLY (Run one $\rightarrow$ Reset CPU $\rightarrow$ Run the next).**

`run_tests.py` acts as an automated test harness. When you run `python run_tests.py`, it does the following:

- **Compiles once**: Compiles the Verilog hardware into a single simulation binary (`pipelined_tb.vvp`).
- **Loops 12 times**: For each test (`t1_rtype`, `t2_load_use_stall`, `t4_matmul_full`, etc.):
  1. Launches a fresh simulation process.
  2. Asserts `reset = 1` to clear all CPU registers, pipeline stages, and memory.
  3. Loads **only that test's `.hex` file** into Instruction Memory via `$readmemh`.
  4. Runs the simulation, checks if the expected result was written to memory, logs `PASS` or `FAIL`, and terminates that run.

---

### 2. Why did we need Python (`assembler.py`) and multiple `.s` / `.hex` files?

#### A. The Custom `matmul` Instruction
Standard RISC-V compilers (like GCC or online assemblers) only know standard RISC-V instructions (`add`, `lw`, `beq`, etc.). They have no idea what `matmul x8, x1, x2` (opcode `0001011`) means.

`assembler.py` is a lightweight custom assembler that knows standard RISC-V instructions **PLUS** your custom `matmul` instruction, converting assembly lines like `matmul x8, x1, x2` into exact 32-bit machine code bytes (`0x0020b40b`).

#### B. Single-Cycle vs. Pipeline Debugging
- **In `single_cycle`:**
  - Every instruction finishes in **1 single clock cycle** before the next instruction even starts.
  - There are no timing overlaps, no data hazards, and no stalls.
  - A single test file (`riscvtest.hex`) running 10 simple instructions is enough because there are no race conditions to test.
- **In `pipelined`:**
  - Up to **5 instructions are executing simultaneously** across Fetch, Decode, Execute, Memory, and Writeback.
  - This creates complex hazard conditions:
    - **RAW Data Hazards**: An instruction needs a value that a previous instruction hasn't written to the register file yet (resolved by Forwarding Muxes).
    - **Load-Use Hazards**: A `lw` instruction followed immediately by an ALU instruction needs a 1-cycle stall.
    - **Control Hazards**: A taken `branch` or `jump` must flush speculative instructions in IF and ID.
    - **Multi-cycle Accelerator Stalls**: `matmul` stalls the CPU for 64 cycles and hijacks the data memory bus.

If you put all of these tests into one giant hex file, a failure in cycle 800 would be extremely difficult to debug because previous hazards would corrupt subsequent instructions.

By splitting the tests into **modular tiers** (`t1` = Basic instructions, `t2` = Isolated hazards, `t3` = Combined hazards, `t4` = Full Matmul workload), we can test each pipeline capability in complete isolation.

---

### Running the Automated Test Harness

The repository includes a master test harness (`run_tests.py`) that compiles the hardware, executes 12 test programs across 4 tiers, and verifies signature memory writes.

### Run All 12 Tests Automatically:
Navigate to the `sim/` directory and execute:

```bash
cd sim
python run_tests.py
```

### Expected Output:
```text
==========================================================================
      E2E TEST SUITE RUNNER — 5-STAGE PIPELINED RISC-V CPU + MATMUL
==========================================================================
[BUILD] Compiling Verilog RTL & Testbench with iverilog...
[BUILD OK] Compilation successful -> pipelined_tb.vvp

Executing Test Cases Across Tiers 1 to 4...
--------------------------------------------------------------------------------
ID     Tier   Test Name              Description                      Status    
--------------------------------------------------------------------------------
T1.1   Tier 1  t1_rtype               R-type instructions (ADD, SUB, AND, OR, SLT) PASS      
T1.2   Tier 1  t1_itype               I-type instructions (ADDI pos/neg/zero) PASS      
T1.3   Tier 1  t1_load_store          Load/Store instructions (LW, SW) PASS      
T1.4   Tier 1  t1_branch_jump         Branch & Jump instructions (BEQ, JAL) PASS      
T2.1   Tier 2  t2_raw_ex_ex           RAW Forwarding EX -> EX Hazard   PASS      
T2.2   Tier 2  t2_raw_mem_ex          RAW Forwarding MEM -> EX Hazard  PASS      
T2.3   Tier 2  t2_load_use_stall      Load-Use Hazard 1-cycle Stall    PASS      
T2.4   Tier 2  t2_branch_flush        Control Hazard Branch Flushing   PASS      
T3.1   Tier 3  t3_forward_branch      Forwarding into Branch Condition PASS      
T3.2   Tier 3  t3_load_use_branch     Load-Use Stall followed by Branch PASS      
T3.3   Tier 3  t3_matmul_after_store  Custom Matmul immediately after Stores PASS      
T4.1   Tier 4  t4_matmul_full         Full 4x4 Matrix Multiplication E2E (64-cycle matmul) PASS      
--------------------------------------------------------------------------------
SUMMARY: 12 / 12 Tests Compiled & Harness Ready.
==========================================================================
```

---

## Executing Your Own Custom Programs

You can easily write your own assembly programs, assemble them using the built-in assembler, and simulate them on the pipelined core.

### Step 1: Write an Assembly Program (`my_prog.s`)
Create a new file in `sim/my_prog.s`. You can use any RV32I instruction and the custom `matmul` instruction:

```assembly
# Example: my_prog.s
main:
    addi x1, x0, 10       # x1 = 10
    addi x2, x0, 25       # x2 = 25
    add  x3, x1, x2       # x3 = 35 (Tests EX->EX forwarding)
    
    # Store result to signature address 84 (0x54) to signal test completion
    sw   x3, 84(x0)       # mem[84] = 35
```

### Step 2: Assemble into Hexadecimal Machine Code
Use the provided `assembler.py`:

```bash
cd sim
python assembler.py my_prog.s my_prog.hex
```
This generates a 32-bit hexadecimal instruction file (`my_prog.hex`).

### Step 3: Run Simulation with Icarus Verilog
Compile the RTL and testbench, then pass your `.hex` file using `+HEX_FILE`:

```bash
# Compile (from inside sim/ directory)
iverilog -g2012 -I../rtl -o custom_sim.vvp testbench.v ../rtl/*.v

# Execute simulation
vvp custom_sim.vvp +HEX_FILE=my_prog.hex +TIMEOUT=500
```

### Step 4: View Waveforms (Optional)
Simulation generates a waveform file `riscv_tb.vcd`. Open it in GTKWave to inspect clock-by-clock signal behavior:

```bash
gtkwave riscv_tb.vcd
```

---

