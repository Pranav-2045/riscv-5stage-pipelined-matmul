# Tier 1: Feature Coverage - R-type instructions
# Tests ADD, SUB, AND, OR, SLT with independent instructions (no hazards)
# Expected success marker: mem[84] = 25 (0x19)

main:
    addi x1, x0, 15     # x1 = 15
    addi x2, x0, 10     # x2 = 10
    nop
    nop
    add  x3, x1, x2     # x3 = 15 + 10 = 25
    nop
    nop
    sub  x4, x1, x2     # x4 = 15 - 10 = 5
    nop
    nop
    and  x5, x1, x2     # x5 = 15 & 10 = 10
    nop
    nop
    or   x6, x1, x2     # x6 = 15 | 10 = 15
    nop
    nop
    slt  x7, x2, x1     # x7 = (10 < 15) ? 1 : 0 = 1
    nop
    nop
    sw   x3, 0(x0)      # mem[0] = 25
    sw   x4, 4(x0)      # mem[4] = 5
    sw   x5, 8(x0)      # mem[8] = 10
    sw   x6, 12(x0)     # mem[12] = 15
    sw   x7, 16(x0)     # mem[16] = 1
    sw   x3, 84(x0)     # mem[84] = 25 (Success signature)
