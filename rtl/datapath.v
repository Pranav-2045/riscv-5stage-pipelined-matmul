module datapath (
    input  wire        clk,
    input  wire        reset,

    // Hazard unit controls
    input  wire        StallPC,
    input  wire        StallID,
    input  wire        StallEX,
    input  wire        FlushID,
    input  wire        FlushEX,
    input  wire        FlushMEM,
    input  wire [1:0]  ForwardAE,
    input  wire [1:0]  ForwardBE,
    input  wire        matmul_rd_sel,
    input  wire        matmul_latch_rs,

    // Controller signals
    input  wire [2:0]  ImmSrcD,
    input  wire        matmul_startD,
    input  wire        PCSrcE,
    input  wire [1:0]  ResultSrcE,
    input  wire        ALUSrcE,
    input  wire [2:0]  ALUControlE,
    input  wire        RegWriteW,
    input  wire [1:0]  ResultSrcW,

    // Memory interfaces
    input  wire [31:0] instrF,
    input  wire [31:0] readdataM,
    output wire [31:0] PCF,
    output wire [31:0] aluresultM,
    output wire [31:0] writedataM,

    // Outputs to Controller & Hazard Unit
    output wire [6:0]  opD,
    output wire [2:0]  funct3D,
    output wire        funct7_5D,
    output wire        ZeroE,
    output wire [4:0]  Rs1D,
    output wire [4:0]  Rs2D,
    output wire [4:0]  Rs1E,
    output wire [4:0]  Rs2E,
    output wire [4:0]  RdE,
    output wire [4:0]  RdM,
    output wire [4:0]  RdW,

    // Latched pointers for Matmul module
    output reg  [31:0] rs1_val,
    output reg  [31:0] rs2_val,
    output reg  [31:0] rd_val
);

    // --- FETCH (IF) STAGE WIRES ---
    wire [31:0] PCNextF;
    wire [31:0] PCPlus4F;

    // --- DECODE (ID) STAGE WIRES ---
    wire [31:0] instrD;
    wire [31:0] PCD;
    wire [31:0] PCPlus4D;
    wire [4:0]  a1D;
    wire [4:0]  a2D;
    wire [4:0]  RdD;
    wire [31:0] rd1D;
    wire [31:0] rd2D;
    wire [31:0] immextD;

    // --- EXECUTE (EX) STAGE WIRES ---
    wire [31:0] rd1E;
    wire [31:0] rd2E;
    wire [31:0] PCE;
    wire [31:0] immextE;
    wire [31:0] PCPlus4E;
    wire [31:0] srcaE;
    wire [31:0] writedataE;
    wire [31:0] srcbE;
    wire [31:0] aluresultE;
    wire [31:0] PCTargetE;

    // --- MEMORY (MEM) STAGE WIRES ---
    wire [31:0] PCPlus4M;

    // --- WRITEBACK (WB) STAGE WIRES ---
    wire [31:0] aluresultW;
    wire [31:0] readdataW;
    wire [31:0] PCPlus4W;
    wire [31:0] ResultW;

    // =========================================================================
    // 1. FETCH (IF) STAGE
    // =========================================================================
    flopenr #(32) pcreg (
        .clk   (clk),
        .reset (reset),
        .en    (~StallPC),
        .d     (PCNextF),
        .q     (PCF)
    );

    adder pcadd4 (
        .a (PCF),
        .b (32'd4),
        .y (PCPlus4F)
    );

    mux2 #(32) pcmux (
        .d0 (PCPlus4F),
        .d1 (PCTargetE),
        .s  (PCSrcE),
        .y  (PCNextF)
    );

    // =========================================================================
    // 2. IF / ID PIPELINE REGISTER
    // =========================================================================
    flopenrc #(96) regID (
        .clk   (clk),
        .reset (reset),
        .en    (~StallID),
        .clear (FlushID),
        .d     ({instrF, PCF, PCPlus4F}),
        .q     ({instrD, PCD, PCPlus4D})
    );

    // Decode instruction fields
    assign opD       = instrD[6:0];
    assign funct3D   = instrD[14:12];
    assign funct7_5D = instrD[30];
    assign Rs1D      = instrD[19:15];
    assign Rs2D      = instrD[24:20];
    assign RdD       = instrD[11:7];

    // Regfile read address multiplexing for matmul (a1D selects rd during cycle 2 of matmul)
    assign a1D = matmul_rd_sel ? RdE : instrD[19:15];
    assign a2D = instrD[24:20];

    regfile rf (
        .clk (clk),
        .we3 (RegWriteW),
        .a1  (a1D),
        .a2  (a2D),
        .a3  (RdW),
        .wd3 (ResultW),
        .rd1 (rd1D),
        .rd2 (rd2D)
    );

    extend ext (
        .instr  (instrD[31:7]),
        .immsrc (ImmSrcD),
        .immext (immextD)
    );

    // Latch matmul base pointers
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rs1_val <= 32'b0;
            rs2_val <= 32'b0;
            rd_val  <= 32'b0;
        end else begin
            if (matmul_latch_rs) begin
                rs1_val <= srcaE;
                rs2_val <= writedataE;
            end
            if (matmul_rd_sel) begin
                rd_val  <= rd1D;
            end
        end
    end

    // =========================================================================
    // 3. ID / EX PIPELINE REGISTER
    // =========================================================================
    flopenrc #(175) regE (
        .clk   (clk),
        .reset (reset),
        .en    (~StallEX),
        .clear (FlushEX),
        .d     ({rd1D, rd2D, PCD, Rs1D, Rs2D, RdD, immextD, PCPlus4D}),
        .q     ({rd1E, rd2E, PCE, Rs1E, Rs2E, RdE, immextE, PCPlus4E})
    );

    // Forwarding Muxes for ALU inputs
    mux3 #(32) forwarda_mux (
        .d0 (rd1E),
        .d1 (ResultW),
        .d2 (aluresultM),
        .s  (ForwardAE),
        .y  (srcaE)
    );

    mux3 #(32) forwardb_mux (
        .d0 (rd2E),
        .d1 (ResultW),
        .d2 (aluresultM),
        .s  (ForwardBE),
        .y  (writedataE)
    );

    mux2 #(32) srcbmux (
        .d0 (writedataE),
        .d1 (immextE),
        .s  (ALUSrcE),
        .y  (srcbE)
    );

    alu alunit (
        .srca       (srcaE),
        .srcb       (srcbE),
        .alucontrol (ALUControlE),
        .aluresult  (aluresultE),
        .zero       (ZeroE)
    );

    adder pcaddbranch (
        .a (PCE),
        .b (immextE),
        .y (PCTargetE)
    );

    // =========================================================================
    // 4. EX / MEM PIPELINE REGISTER
    // =========================================================================
    flopenrc #(101) regM (
        .clk   (clk),
        .reset (reset),
        .en    (1'b1),
        .clear (FlushMEM),
        .d     ({aluresultE, writedataE, RdE, PCPlus4E}),
        .q     ({aluresultM, writedataM, RdM, PCPlus4M})
    );

    // =========================================================================
    // 5. MEM / WB PIPELINE REGISTER
    // =========================================================================
    flopr #(101) regW (
        .clk   (clk),
        .reset (reset),
        .d     ({aluresultM, readdataM, RdM, PCPlus4M}),
        .q     ({aluresultW, readdataW, RdW, PCPlus4W})
    );

    mux3 #(32) resultmux (
        .d0 (aluresultW),
        .d1 (readdataW),
        .d2 (PCPlus4W),
        .s  (ResultSrcW),
        .y  (ResultW)
    );

endmodule
