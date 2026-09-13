# Tier 2: Boundary & Corner Cases - RAW Forwarding MEM->EX
# Tests forwarding from MEM/WB stage register to EX stage input (1 instruction distance)
# Expected success marker: mem[84] = 51 (0x33)

main:
    addi x1, x0, 50     # x1 = 50
    addi x9, x0, 1      # Unrelated instruction
    add  x2, x1, x9     # RAW MEM->EX hazard on x1: x2 = 50 + 1 = 51
    sw   x2, 84(x0)     # mem[84] = 51 (Success signature)
