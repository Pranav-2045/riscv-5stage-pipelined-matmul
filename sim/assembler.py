#!/usr/bin/env python3
"""
RISC-V RV32I + Custom Matmul Assembler
Converts RISC-V assembly source (.s) to hex memory format (.hex).
"""

import sys
import os
import re

REG_MAP = {
    'x0': 0, 'zero': 0,
    'x1': 1, 'ra': 1,
    'x2': 2, 'sp': 2,
    'x3': 3, 'gp': 3,
    'x4': 4, 'tp': 4,
    'x5': 5, 't0': 5,
    'x6': 6, 't1': 6,
    'x7': 7, 't2': 7,
    's0': 8, 'fp': 8, 'x8': 8,
    's1': 9, 'x9': 9,
    'a0': 10, 'x10': 10,
    'a1': 11, 'x11': 11,
    'a2': 12, 'x12': 12,
    'a3': 13, 'x13': 13,
    'a4': 14, 'x14': 14,
    'a5': 15, 'x15': 15,
    'a6': 16, 'x16': 16,
    'a7': 17, 'x17': 17,
    's2': 18, 'x18': 18,
    's3': 19, 'x19': 19,
    's4': 20, 'x20': 20,
    's5': 21, 'x21': 21,
    's6': 22, 'x22': 22,
    's7': 23, 'x23': 23,
    's8': 24, 'x24': 24,
    's9': 25, 'x25': 25,
    's10': 26, 'x26': 26,
    's11': 27, 'x27': 27,
    't3': 28, 'x28': 28,
    't4': 29, 'x29': 29,
    't5': 30, 'x30': 30,
    't6': 31, 'x31': 31,
}

def parse_reg(reg_str):
    reg_str = reg_str.strip().lower()
    if reg_str in REG_MAP:
        return REG_MAP[reg_str]
    if reg_str.startswith('x') and reg_str[1:].isdigit():
        val = int(reg_str[1:])
        if 0 <= val <= 31:
            return val
    raise ValueError(f"Invalid register name: '{reg_str}'")

def parse_imm(imm_str, bits=12):
    imm_str = imm_str.strip()
    if imm_str.startswith('0x') or imm_str.startswith('0X'):
        val = int(imm_str, 16)
    elif imm_str.startswith('0b') or imm_str.startswith('0B'):
        val = int(imm_str, 2)
    else:
        val = int(imm_str)
    
    # Mask to specified bits signed
    min_val = -(1 << (bits - 1))
    max_val = (1 << (bits - 1)) - 1
    if not (min_val <= val <= max_val or 0 <= val < (1 << bits)):
        # clamp/wrap
        val = val & ((1 << bits) - 1)
    return val & ((1 << bits) - 1)

def encode_r_type(opcode, funct3, funct7, rd, rs1, rs2):
    val = ((funct7 & 0x7F) << 25) | ((rs2 & 0x1F) << 20) | ((rs1 & 0x1F) << 15) | ((funct3 & 0x7) << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)
    return f"{val:08x}"

def encode_i_type(opcode, funct3, rd, rs1, imm12):
    val = ((imm12 & 0xFFF) << 20) | ((rs1 & 0x1F) << 15) | ((funct3 & 0x7) << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)
    return f"{val:08x}"

def encode_s_type(opcode, funct3, rs1, rs2, imm12):
    imm_11_5 = (imm12 >> 5) & 0x7F
    imm_4_0 = imm12 & 0x1F
    val = (imm_11_5 << 25) | ((rs2 & 0x1F) << 20) | ((rs1 & 0x1F) << 15) | ((funct3 & 0x7) << 12) | (imm_4_0 << 7) | (opcode & 0x7F)
    return f"{val:08x}"

def encode_b_type(opcode, funct3, rs1, rs2, imm13):
    imm12 = (imm13 >> 12) & 0x1
    imm10_5 = (imm13 >> 5) & 0x3F
    imm4_1 = (imm13 >> 1) & 0xF
    imm11 = (imm13 >> 11) & 0x1
    val = (imm12 << 31) | (imm10_5 << 25) | ((rs2 & 0x1F) << 20) | ((rs1 & 0x1F) << 15) | ((funct3 & 0x7) << 12) | (imm4_1 << 8) | (imm11 << 7) | (opcode & 0x7F)
    return f"{val:08x}"

def encode_j_type(opcode, rd, imm21):
    imm20 = (imm21 >> 20) & 0x1
    imm10_1 = (imm21 >> 1) & 0x3FF
    imm11 = (imm21 >> 11) & 0x1
    imm19_12 = (imm21 >> 12) & 0xFF
    val = (imm20 << 31) | (imm10_1 << 21) | (imm11 << 20) | (imm19_12 << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)
    return f"{val:08x}"

def assemble_line(line, pc, labels):
    # Remove comments and whitespace
    line = re.sub(r'#.*$', '', line).strip()
    if not line:
        return None
    
    # Strip label definition if any (handled in pass 1)
    if ':' in line:
        line = line.split(':', 1)[1].strip()
        if not line:
            return None

    tokens = [t.strip() for t in re.split(r'[\s,]+', line) if t.strip()]
    if not tokens:
        return None
    
    op = tokens[0].lower()

    if op == 'nop':
        return encode_i_type(0x13, 0, 0, 0, 0)
    
    if op == 'addi':
        rd = parse_reg(tokens[1])
        rs1 = parse_reg(tokens[2])
        imm = parse_imm(tokens[3], 12)
        return encode_i_type(0x13, 0, rd, rs1, imm)

    if op in ['add', 'sub', 'and', 'or', 'slt']:
        rd = parse_reg(tokens[1])
        rs1 = parse_reg(tokens[2])
        rs2 = parse_reg(tokens[3])
        funct7 = 0x20 if op == 'sub' else 0x00
        funct3 = {'add': 0, 'sub': 0, 'slt': 2, 'or': 6, 'and': 7}[op]
        return encode_r_type(0x33, funct3, funct7, rd, rs1, rs2)

    if op == 'lw':
        rd = parse_reg(tokens[1])
        # offset(rs1)
        m = re.match(r'^(-?\d+|0x[0-9a-fA-F]+)\s*\(\s*([a-zA-Z0-9]+)\s*\)$', tokens[2])
        if not m:
            raise ValueError(f"Invalid load syntax: '{tokens[2]}'")
        imm = parse_imm(m.group(1), 12)
        rs1 = parse_reg(m.group(2))
        return encode_i_type(0x03, 2, rd, rs1, imm)

    if op == 'sw':
        rs2 = parse_reg(tokens[1])
        m = re.match(r'^(-?\d+|0x[0-9a-fA-F]+)\s*\(\s*([a-zA-Z0-9]+)\s*\)$', tokens[2])
        if not m:
            raise ValueError(f"Invalid store syntax: '{tokens[2]}'")
        imm = parse_imm(m.group(1), 12)
        rs1 = parse_reg(m.group(2))
        return encode_s_type(0x23, 2, rs1, rs2, imm)

    if op == 'beq':
        rs1 = parse_reg(tokens[1])
        rs2 = parse_reg(tokens[2])
        target = tokens[3]
        if target in labels:
            offset = labels[target] - pc
        else:
            offset = parse_imm(target, 13)
        return encode_b_type(0x63, 0, rs1, rs2, offset)

    if op == 'jal':
        rd = parse_reg(tokens[1])
        target = tokens[2]
        if target in labels:
            offset = labels[target] - pc
        else:
            offset = parse_imm(target, 21)
        return encode_j_type(0x6F, rd, offset)

    if op == 'matmul':
        # matmul rd, rs1, rs2
        rd = parse_reg(tokens[1])
        rs1 = parse_reg(tokens[2])
        rs2 = parse_reg(tokens[3])
        # opcode 0x0B (0001011), funct3 000, funct7 0000000
        return encode_r_type(0x0B, 0, 0, rd, rs1, rs2)

    raise ValueError(f"Unsupported instruction opcode: '{op}' in line: '{line}'")

def assemble_file(src_path, dst_path=None):
    with open(src_path, 'r') as f:
        raw_lines = f.readlines()
    
    # Pass 1: Collect labels and calculate PC
    labels = {}
    pc = 0
    clean_instrs = []
    
    for raw_line in raw_lines:
        line = re.sub(r'#.*$', '', raw_line).strip()
        if not line:
            continue
        
        while ':' in line:
            parts = line.split(':', 1)
            lbl = parts[0].strip()
            if lbl:
                labels[lbl] = pc
            line = parts[1].strip()
        
        if line:
            clean_instrs.append((pc, line))
            pc += 4

    # Pass 2: Assemble instructions
    hex_lines = []
    for instr_pc, line in clean_instrs:
        hex_str = assemble_line(line, instr_pc, labels)
        if hex_str:
            hex_lines.append(hex_str)

    if dst_path:
        with open(dst_path, 'w') as f:
            for h in hex_lines:
                f.write(f"{h}\n")
    
    return hex_lines

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python assembler.py <input.s> [output.hex]")
        sys.exit(1)
    src = sys.argv[1]
    dst = sys.argv[2] if len(sys.argv) > 2 else src.rsplit('.', 1)[0] + '.hex'
    res = assemble_file(src, dst)
    print(f"Assembled {len(res)} instructions from {src} -> {dst}")
