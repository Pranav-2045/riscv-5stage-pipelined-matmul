# Tier 2: Boundary & Corner Cases - Control Hazard Branch Flush
# Tests IF/ID and ID/EX register clearing/flushing on taken branch
# Expected success marker: mem[84] = 123 (0x7B) and mem[0] = 0 (flushed instructions must NOT execute!)

main:
    addi x1, x0, 5
    addi x2, x0, 5
    nop
    nop
    beq  x1, x2, target  # Branch TAKEN!
    addi x3, x0, 99      # Speculative in IF/ID - MUST BE FLUSHED!
    sw   x3, 0(x0)       # Speculative in IF/ID - MUST BE FLUSHED!

target:
    addi x5, x0, 123     # Correct target instruction
    sw   x5, 84(x0)      # mem[84] = 123 (Success signature)
