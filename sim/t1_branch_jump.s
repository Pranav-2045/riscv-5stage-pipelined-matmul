# Tier 1: Feature Coverage - Branch and Jump instructions
# Tests BEQ (taken and not taken) and JAL
# Expected success marker: mem[84] = 77 (0x4D)

main:
    addi x1, x0, 5
    addi x2, x0, 5
    addi x3, x0, 10
    nop
    nop
    beq  x1, x3, fail_target  # 5 == 10 False, not taken
    nop
    nop
    beq  x1, x2, pass_target  # 5 == 5 True, taken!
    nop
    nop
    addi x4, x0, 99           # Bypassed
    sw   x4, 0(x0)

pass_target:
    nop
    nop
    jal  x5, end_target       # Jump to end
    nop
    nop

fail_target:
    addi x4, x0, 99
    sw   x4, 4(x0)

end_target:
    addi x6, x0, 77
    sw   x6, 84(x0)           # mem[84] = 77 (Success signature)
