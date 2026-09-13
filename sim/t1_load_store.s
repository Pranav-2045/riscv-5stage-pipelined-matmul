# Tier 1: Feature Coverage - Load and Store instructions
# Tests SW and LW without load-use hazard
# Expected success marker: mem[84] = 42 (0x2A)

main:
    addi x1, x0, 42     # x1 = 42
    nop
    nop
    sw   x1, 0(x0)      # mem[0] = 42
    nop
    nop
    lw   x2, 0(x0)      # x2 = mem[0] = 42
    nop
    nop
    sw   x2, 4(x0)      # mem[4] = 42
    sw   x2, 84(x0)     # mem[84] = 42 (Success signature)
