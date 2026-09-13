#!/usr/bin/env python3
"""
Comprehensive E2E Test Runner for 5-Stage Pipelined RISC-V Processor with Custom Matmul
Executes tests across Tiers 1-4 using iverilog and vvp.
"""

import os
import sys
import subprocess
import glob
import re
from assembler import assemble_file

TEST_CATALOG = [
    # Tier 1: Feature Coverage
    {
        "id": "T1.1",
        "tier": 1,
        "name": "t1_rtype",
        "desc": "R-type instructions (ADD, SUB, AND, OR, SLT)",
        "expected_addr": 84,
        "expected_val": 25,
        "timeout": 200
    },
    {
        "id": "T1.2",
        "tier": 1,
        "name": "t1_itype",
        "desc": "I-type instructions (ADDI pos/neg/zero)",
        "expected_addr": 84,
        "expected_val": 60,
        "timeout": 200
    },
    {
        "id": "T1.3",
        "tier": 1,
        "name": "t1_load_store",
        "desc": "Load/Store instructions (LW, SW)",
        "expected_addr": 84,
        "expected_val": 42,
        "timeout": 200
    },
    {
        "id": "T1.4",
        "tier": 1,
        "name": "t1_branch_jump",
        "desc": "Branch & Jump instructions (BEQ, JAL)",
        "expected_addr": 84,
        "expected_val": 77,
        "timeout": 200
    },

    # Tier 2: Boundary & Corner Cases (Hazards)
    {
        "id": "T2.1",
        "tier": 2,
        "name": "t2_raw_ex_ex",
        "desc": "RAW Forwarding EX -> EX Hazard",
        "expected_addr": 84,
        "expected_val": 20,
        "timeout": 200
    },
    {
        "id": "T2.2",
        "tier": 2,
        "name": "t2_raw_mem_ex",
        "desc": "RAW Forwarding MEM -> EX Hazard",
        "expected_addr": 84,
        "expected_val": 51,
        "timeout": 200
    },
    {
        "id": "T2.3",
        "tier": 2,
        "name": "t2_load_use_stall",
        "desc": "Load-Use Hazard 1-cycle Stall",
        "expected_addr": 84,
        "expected_val": 176,
        "timeout": 200
    },
    {
        "id": "T2.4",
        "tier": 2,
        "name": "t2_branch_flush",
        "desc": "Control Hazard Branch Flushing",
        "expected_addr": 84,
        "expected_val": 123,
        "timeout": 200
    },

    # Tier 3: Cross-Feature Combinations
    {
        "id": "T3.1",
        "tier": 3,
        "name": "t3_forward_branch",
        "desc": "Forwarding into Branch Condition",
        "expected_addr": 84,
        "expected_val": 200,
        "timeout": 250
    },
    {
        "id": "T3.2",
        "tier": 3,
        "name": "t3_load_use_branch",
        "desc": "Load-Use Stall followed by Branch",
        "expected_addr": 84,
        "expected_val": 222,
        "timeout": 250
    },
    {
        "id": "T3.3",
        "tier": 3,
        "name": "t3_matmul_after_store",
        "desc": "Custom Matmul immediately after Stores",
        "expected_addr": 84,
        "expected_val": 300,
        "timeout": 500
    },

    # Tier 4: Real-World Scenarios
    {
        "id": "T4.1",
        "tier": 4,
        "name": "t4_matmul_full",
        "desc": "Full 4x4 Matrix Multiplication E2E (64-cycle matmul)",
        "expected_addr": 84,
        "expected_val": 170,
        "timeout": 1000
    }
]

def compile_testbench(sim_dir, rtl_dir, vvp_out):
    tb_file = os.path.join(sim_dir, "testbench.v")
    rtl_files = glob.glob(os.path.join(rtl_dir, "*.v"))
    
    cmd = ["iverilog", "-g2012", f"-I{rtl_dir}", "-o", vvp_out, tb_file] + rtl_files
    print(f"[BUILD] Compiling Verilog RTL & Testbench with iverilog...")
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"[BUILD ERROR] Compilation failed!\n{res.stderr}")
        return False
    print(f"[BUILD OK] Compilation successful -> {vvp_out}")
    return True

def run_single_test(test_cfg, sim_dir, vvp_out):
    test_name = test_cfg["name"]
    s_path = os.path.join(sim_dir, f"{test_name}.s")
    hex_path = os.path.join(sim_dir, f"{test_name}.hex")
    
    # Ensure hex file exists and is up to date
    if os.path.exists(s_path):
        assemble_file(s_path, hex_path)
    elif not os.path.exists(hex_path):
        return False, f"Missing assembly/hex file for {test_name}"

    # Also copy to riscvtest.hex in working directory for simulators expecting default filename
    default_hex = os.path.join(os.getcwd(), "riscvtest.hex")
    with open(hex_path, "r") as src_f, open(default_hex, "w") as dst_f:
        dst_f.write(src_f.read())

    cmd = ["vvp", vvp_out, f"+HEX_FILE={hex_path}", f"+TIMEOUT={test_cfg['timeout']}"]
    res = subprocess.run(cmd, capture_output=True, text=True)
    output = res.stdout + res.stderr

    # Parse output for signature write: "addr=0x54 (84), data=0x..." or "Signature written to addr 84: <val>"
    addr_matches = re.findall(r"Signature written to addr 84: (\d+)", output)
    if not addr_matches:
        # Fallback regex for MEMWRITE logging
        addr_matches = re.findall(r"addr=0x54 \(84\), data=0x[0-9a-fA-F]+ \((\d+)\)", output)

    if "TIMEOUT" in output:
        return False, "Simulation TIMEOUT"
    
    if not addr_matches:
        return False, "No write to signature addr 84 detected"

    actual_val = int(addr_matches[-1])
    expected_val = test_cfg["expected_val"]

    if actual_val == expected_val:
        return True, f"PASS (Value={actual_val} matched expected={expected_val})"
    else:
        return False, f"FAIL (Actual={actual_val}, Expected={expected_val})"

def main():
    sim_dir = os.path.dirname(os.path.abspath(__file__))
    root_dir = os.path.abspath(os.path.join(sim_dir, "..", ".."))
    rtl_dir = os.path.join(root_dir, "pipelined", "rtl")
    vvp_out = os.path.join(sim_dir, "pipelined_tb.vvp")

    print("==========================================================================")
    print("      E2E TEST SUITE RUNNER — 5-STAGE PIPELINED RISC-V CPU + MATMUL")
    print("==========================================================================")

    if not compile_testbench(sim_dir, rtl_dir, vvp_out):
        sys.exit(1)

    print("\nExecuting Test Cases Across Tiers 1 to 4...")
    print("-" * 80)
    print(f"{'ID':<6} {'Tier':<6} {'Test Name':<22} {'Description':<32} {'Status':<10}")
    print("-" * 80)

    passed_count = 0
    total_count = len(TEST_CATALOG)

    for test in TEST_CATALOG:
        success, msg = run_single_test(test, sim_dir, vvp_out)
        status_str = "PASS" if success else "FAIL"
        if success:
            passed_count += 1
        
        print(f"{test['id']:<6} Tier {test['tier']:<2} {test['name']:<22} {test['desc']:<32} {status_str:<10}")

    print("-" * 80)
    print(f"SUMMARY: {passed_count} / {total_count} Tests Compiled & Harness Ready.")
    print("==========================================================================")

if __name__ == "__main__":
    main()
