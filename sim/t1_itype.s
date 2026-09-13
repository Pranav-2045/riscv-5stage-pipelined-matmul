# Tier 1: Feature Coverage - I-type instructions
# Tests ADDI with positive, negative, and zero immediates
# Expected success marker: mem[84] = 60 (0x3C)

main:
    addi x1, x0, 100    # x1 = 100
    nop
    nop
    addi x2, x1, -40    # x2 = 60
    nop
    nop
    addi x3, x2, 0      # x3 = 60
    nop
    nop
    sw   x1, 0(x0)      # mem[0] = 100
    sw   x2, 4(x0)      # mem[4] = 60
    sw   x3, 8(x0)      # mem[8] = 60
    sw   x2, 84(x0)     # mem[84] = 60 (Success signature)
