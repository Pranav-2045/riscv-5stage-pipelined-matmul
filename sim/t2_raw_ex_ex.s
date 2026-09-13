# Tier 2: Boundary & Corner Cases - RAW Forwarding EX->EX
# Tests forwarding from ALU output of EX stage directly to input of EX stage of consecutive instruction
# Expected success marker: mem[84] = 20 (0x14)

main:
    addi x1, x0, 20     # x1 = 20 (produced in EX)
    add  x2, x1, x1     # RAW EX->EX hazard on x1: x2 = 20 + 20 = 40
    sub  x3, x2, x1     # RAW EX->EX hazard on x2: x3 = 40 - 20 = 20
    sw   x3, 84(x0)     # mem[84] = 20 (Success signature)
