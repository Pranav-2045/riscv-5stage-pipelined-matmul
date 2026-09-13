# Tier 2: Boundary & Corner Cases - Load-Use Hazard Stall
# Tests 1-cycle PC & IF/ID stall + ID/EX flush on Load-Use hazard
# Expected success marker: mem[84] = 176 (0xB0)

main:
    addi x1, x0, 88
    nop
    nop
    sw   x1, 0(x0)      # mem[0] = 88
    lw   x2, 0(x0)      # x2 loaded from mem[0]
    add  x3, x2, x1      # Load-use hazard on x2! Requires 1 cycle stall + MEM->EX forward
    sw   x3, 84(x0)     # mem[84] = 88 + 88 = 176 (Success signature)
