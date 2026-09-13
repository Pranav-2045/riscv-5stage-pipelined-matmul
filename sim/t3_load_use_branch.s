# Tier 3: Cross-Feature Combinations - Load-Use followed by Branch
# Tests LW followed immediately by BEQ on loaded register value
# Expected success marker: mem[84] = 222 (0xDE)

main:
    addi x1, x0, 30
    nop
    nop
    sw   x1, 0(x0)      # mem[0] = 30
    lw   x2, 0(x0)      # x2 = 30
    beq  x2, x1, target # Load-use hazard on x2 immediately before BEQ!
    addi x3, x0, 99
    sw   x3, 4(x0)

target:
    addi x4, x0, 222
    sw   x4, 84(x0)     # mem[84] = 222 (Success signature)
