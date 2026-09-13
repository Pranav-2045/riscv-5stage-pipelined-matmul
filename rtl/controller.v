module controller (
    input        clk,
    input        reset,
    input  [6:0] op,
    input  [2:0] funct3,
    input        funct7_5,
    input        ZeroE,
    input        StallE,
    input        FlushE,
    input        FlushM,
    output [2:0] ImmSrcD,
    output       matmul_startD,
    output       PCSrcE,
    output [1:0] ResultSrcE,
    output       ALUSrcE,
    output [2:0] ALUControlE,
    output       matmul_startE,
    output       RegWriteM,
    output       MemWriteM,
    output [1:0] ResultSrcM,
    output       RegWriteW,
    output [1:0] ResultSrcW
);

    // Decode stage signals
    wire       RegWriteD;
    wire [1:0] ResultSrcD;
    wire       MemWriteD;
    wire       JumpD;
    wire       BranchD;
    wire       JalrD;
    wire [1:0] ALUOpD;
    wire [2:0] ALUControlD;
    wire       ALUSrcD;

    // Decode stage instantiation
    maindec md (
        .op           (op),
        .regwrite     (RegWriteD),
        .immsrc       (ImmSrcD),
        .alusrc       (ALUSrcD),
        .memwrite     (MemWriteD),
        .resultsrc    (ResultSrcD),
        .branch       (BranchD),
        .jump         (JumpD),
        .jalr         (JalrD),
        .aluop        (ALUOpD),
        .matmul_start (matmul_startD)
    );

    aludec ad (
        .op_5       (op[5]),
        .funct3     (funct3),
        .funct7_5   (funct7_5),
        .aluop      (ALUOpD),
        .alucontrol (ALUControlD)
    );

    // Execute stage control signals & register
    wire       RegWriteE;
    wire       MemWriteE;
    wire       JumpE;
    wire       BranchE;
    wire       JalrE;

    flopenrc #(12) regE (
        .clk   (clk),
        .reset (reset),
        .en    (~StallE),
        .clear (FlushE),
        .d     ({RegWriteD, ResultSrcD, MemWriteD, JumpD, BranchD, JalrD, ALUControlD, ALUSrcD, matmul_startD}),
        .q     ({RegWriteE, ResultSrcE, MemWriteE, JumpE, BranchE, JalrE, ALUControlE, ALUSrcE, matmul_startE})
    );

    // Branch decision in EX stage
    assign PCSrcE = (BranchE & ZeroE) | JumpE | JalrE;

    // Memory stage control register
    flopenrc #(4) regM (
        .clk   (clk),
        .reset (reset),
        .en    (1'b1),
        .clear (FlushM),
        .d     ({RegWriteE, ResultSrcE, MemWriteE}),
        .q     ({RegWriteM, ResultSrcM, MemWriteM})
    );

    // Writeback stage control register
    flopr #(3) regW (
        .clk   (clk),
        .reset (reset),
        .d     ({RegWriteM, ResultSrcM}),
        .q     ({RegWriteW, ResultSrcW})
    );

endmodule
