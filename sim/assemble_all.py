#!/usr/bin/env python3
"""
Assemble all Tier 1-4 test programs for the 5-stage pipelined RISC-V processor.
"""

import os
import glob
from assembler import assemble_file

def assemble_all():
    sim_dir = os.path.dirname(os.path.abspath(__file__))
    s_files = sorted(glob.glob(os.path.join(sim_dir, "t*.s")))
    
    print(f"Found {len(s_files)} test assembly files:")
    for s_file in s_files:
        base_name = os.path.basename(s_file)
        hex_file = s_file.rsplit('.', 1)[0] + '.hex'
        instrs = assemble_file(s_file, hex_file)
        print(f"  [OK] {base_name:25s} -> {os.path.basename(hex_file):25s} ({len(instrs)} instructions)")

if __name__ == "__main__":
    assemble_all()
