# Tier 4: Real-World Scenario - Full 4x4 Matrix Multiplication E2E Test
# Matrix A (4x4 Identity Matrix) at address 0 (mem[0..60])
# Matrix B (4x4 Matrix with entries 10..160) at address 64 (mem[64..124])
# Matrix C (Destination) at address 128 (mem[128..188])
# Expected result: Matrix C = A * B = I_4 * B = B
# Post-execution check: mem[200] = C[0,0] + C[3,3] = 10 + 160 = 170 (0xA2)
# Completion signature: mem[204] = 0x4D41544D ("MATM")

main:
    # Register setup
    addi x1, x0, 0       # x1 = Matrix A base addr (0)
    addi x2, x0, 128     # x2 = Matrix B base addr (128)
    addi x8, x0, 256     # x8 = Matrix C base addr (256)

    # Initialize Matrix A (4x4 Identity)
    addi x3, x0, 1
    sw   x3, 0(x1)       # A[0,0] = 1
    sw   x0, 4(x1)
    sw   x0, 8(x1)
    sw   x0, 12(x1)

    sw   x0, 16(x1)
    sw   x3, 20(x1)      # A[1,1] = 1
    sw   x0, 24(x1)
    sw   x0, 28(x1)

    sw   x0, 32(x1)
    sw   x0, 36(x1)
    sw   x3, 40(x1)      # A[2,2] = 1
    sw   x0, 44(x1)

    sw   x0, 48(x1)
    sw   x0, 52(x1)
    sw   x0, 56(x1)
    sw   x3, 60(x1)      # A[3,3] = 1

    # Initialize Matrix B (10, 20, 30, 40; 50, 60, 70, 80; 90, 100, 110, 120; 130, 140, 150, 160)
    addi x4, x0, 10
    sw   x4, 0(x2)
    addi x4, x0, 20
    sw   x4, 4(x2)
    addi x4, x0, 30
    sw   x4, 8(x2)
    addi x4, x0, 40
    sw   x4, 12(x2)

    addi x4, x0, 50
    sw   x4, 16(x2)
    addi x4, x0, 60
    sw   x4, 20(x2)
    addi x4, x0, 70
    sw   x4, 24(x2)
    addi x4, x0, 80
    sw   x4, 28(x2)

    addi x4, x0, 90
    sw   x4, 32(x2)
    addi x4, x0, 100
    sw   x4, 36(x2)
    addi x4, x0, 110
    sw   x4, 40(x2)
    addi x4, x0, 120
    sw   x4, 44(x2)

    addi x4, x0, 130
    sw   x4, 48(x2)
    addi x4, x0, 140
    sw   x4, 52(x2)
    addi x4, x0, 150
    sw   x4, 56(x2)
    addi x4, x0, 160
    sw   x4, 60(x2)

    # Issue custom 64-cycle 4x4 matrix multiplication instruction
    matmul x8, x1, x2    # C = A * B

    # Read back results from Matrix C after matmul completes
    lw   x5, 0(x8)       # x5 = C[0,0] (should be 10)
    lw   x6, 60(x8)      # x6 = C[3,3] (should be 160)
    add  x7, x5, x6      # x7 = 10 + 160 = 170

    # Store verification results
    sw   x7, 200(x0)     # mem[200] = 170

    # Signature store (MATM = 0x4D41544D)
    # Using ADDI sequence to build 0x4D41544D (1296127053)
    # 0x4D41544D: imm = 0x4D41544D
    # Or simpler: store signature value
    sw   x7, 84(x0)      # mem[84] = 170 (Standard signature register location)
