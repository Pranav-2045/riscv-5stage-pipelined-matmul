# Tier 3: Cross-Feature Combinations - Matmul following Load/Store
# Tests populating data memory with SW, then immediately issuing custom matmul instruction
# Expected success marker: mem[84] = 300 (0x12C)

main:
    # Set up pointers
    addi x1, x0, 0      # rs1 = Matrix A base addr = 0
    addi x2, x0, 64     # rs2 = Matrix B base addr = 64 (0x40)
    addi x8, x0, 128    # rd  = Matrix C base addr = 128 (0x80)

    # Store 1 to A[0,0] (mem[0]) and 2 to B[0,0] (mem[64])
    addi x3, x0, 1
    addi x4, x0, 2
    sw   x3, 0(x1)      # mem[0] = 1
    sw   x4, 0(x2)      # mem[64] = 2

    # Issue custom matmul instruction
    matmul x8, x1, x2   # Matrix C[0..15] = Matrix A * Matrix B

    # Issue SW after matmul to check pipeline resumption
    addi x5, x0, 300
    sw   x5, 84(x0)     # mem[84] = 300 (Success signature)
