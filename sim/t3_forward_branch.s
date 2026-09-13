# Tier 3: Cross-Feature Combinations - Forwarding into Branch
# Tests forwarding ALU result directly into Branch condition evaluation
# Expected success marker: mem[84] = 200 (0xC8)

main:
    addi x1, x0, 15
    addi x2, x0, 10
    add  x3, x1, x2     # x3 = 25 (produced in EX)
    addi x4, x0, 25     # x4 = 25
    beq  x3, x4, match  # Branch relies on x3 forwarded from prior ADD
    addi x5, x0, 99     # Bypassed if branch taken
    sw   x5, 0(x0)

match:
    addi x6, x0, 200
    sw   x6, 84(x0)     # mem[84] = 200 (Success signature)
