// 5-Stage Pipelined RISC-V RV32I Processor Core with Custom Matmul Engine
module riscvpipelined (
    input  wire        clk,
    input  wire        reset,
    output wire [31:0] pc,
    input  wire [31:0] instr,
    output wire        mem_we,
    output wire [31:0] mem_addr,
    output wire [31:0] mem_wdata,
    input  wire [31:0] mem_rdata,
    output wire        matmul_busy,
    output wire        matmul_dmem_en,
    output wire        matmul_dmem_we,
    output wire [31:0] matmul_dmem_addr,
    output wire [31:0] matmul_dmem_wdata,
    input  wire [31:0] matmul_dmem_rdata
);

    // Controller <-> Datapath & Hazard wires
    wire [2:0] ImmSrcD;
    wire       matmul_startD;
    wire       PCSrcE;
    wire [1:0] ResultSrcE;
    wire       ALUSrcE;
    wire [2:0] ALUControlE;
    wire       matmul_startE;
    wire       RegWriteM;
    wire       MemWriteM;
    wire [1:0] ResultSrcM;
    wire       RegWriteW;
    wire [1:0] ResultSrcW;

    // Datapath -> Controller & Hazard wires
    wire [6:0] opD;
    wire [2:0] funct3D;
    wire       funct7_5D;
    wire       ZeroE;
    wire [4:0] Rs1D, Rs2D, Rs1E, Rs2E, RdE, RdM, RdW;
    wire [31:0] rs1_val, rs2_val, rd_val;

    // Hazard -> Datapath & Controller wires
    wire [1:0] ForwardAE, ForwardBE;
    wire       StallPC, StallID, StallEX;
    wire       FlushID, FlushEX, FlushMEM;
    wire       matmul_rd_sel, matmul_latch_rs;

    // Matmul start pulse generation
    reg matmul_start_reg;
    always @(posedge clk or posedge reset) begin
        if (reset)
            matmul_start_reg <= 1'b0;
        else
            matmul_start_reg <= matmul_rd_sel;
    end

    // Assign CPU memory outputs
    assign mem_we   = MemWriteM;
    assign mem_addr = mem_addr_internal;
    assign mem_wdata= mem_wdata_internal;
    assign pc       = pc_internal;

    wire [31:0] pc_internal;
    wire [31:0] mem_addr_internal;
    wire [31:0] mem_wdata_internal;

    // Controller Unit
    controller c (
        .clk           (clk),
        .reset         (reset),
        .op            (opD),
        .funct3        (funct3D),
        .funct7_5      (funct7_5D),
        .ZeroE         (ZeroE),
        .StallE        (StallEX),
        .FlushE        (FlushEX),
        .FlushM        (FlushMEM),
        .ImmSrcD       (ImmSrcD),
        .matmul_startD (matmul_startD),
        .PCSrcE        (PCSrcE),
        .ResultSrcE    (ResultSrcE),
        .ALUSrcE       (ALUSrcE),
        .ALUControlE   (ALUControlE),
        .matmul_startE (matmul_startE),
        .RegWriteM     (RegWriteM),
        .MemWriteM     (MemWriteM),
        .ResultSrcM    (ResultSrcM),
        .RegWriteW     (RegWriteW),
        .ResultSrcW    (ResultSrcW)
    );

    // Datapath Unit
    datapath dp (
        .clk           (clk),
        .reset         (reset),
        .StallPC       (StallPC),
        .StallID       (StallID),
        .StallEX       (StallEX),
        .FlushID       (FlushID),
        .FlushEX       (FlushEX),
        .FlushMEM      (FlushMEM),
        .ForwardAE     (ForwardAE),
        .ForwardBE     (ForwardBE),
        .matmul_rd_sel (matmul_rd_sel),
        .matmul_latch_rs (matmul_latch_rs),
        .ImmSrcD       (ImmSrcD),
        .matmul_startD (matmul_startD),
        .PCSrcE        (PCSrcE),
        .ResultSrcE    (ResultSrcE),
        .ALUSrcE       (ALUSrcE),
        .ALUControlE   (ALUControlE),
        .RegWriteW     (RegWriteW),
        .ResultSrcW    (ResultSrcW),
        .instrF        (instr),
        .readdataM     (mem_rdata),
        .PCF           (pc_internal),
        .aluresultM    (mem_addr_internal),
        .writedataM    (mem_wdata_internal),
        .opD           (opD),
        .funct3D       (funct3D),
        .funct7_5D     (funct7_5D),
        .ZeroE         (ZeroE),
        .Rs1D          (Rs1D),
        .Rs2D          (Rs2D),
        .Rs1E          (Rs1E),
        .Rs2E          (Rs2E),
        .RdE           (RdE),
        .RdM           (RdM),
        .RdW           (RdW),
        .rs1_val       (rs1_val),
        .rs2_val       (rs2_val),
        .rd_val        (rd_val)
    );

    // Hazard Unit
    hazard hz (
        .clk           (clk),
        .reset         (reset),
        .Rs1D          (Rs1D),
        .Rs2D          (Rs2D),
        .Rs1E          (Rs1E),
        .Rs2E          (Rs2E),
        .RdE           (RdE),
        .RdM           (RdM),
        .RdW           (RdW),
        .RegWriteM     (RegWriteM),
        .RegWriteW     (RegWriteW),
        .ResultSrcE    (ResultSrcE),
        .PCSrcE        (PCSrcE),
        .matmul_startD (matmul_startD),
        .matmul_startE (matmul_startE),
        .matmul_busy   (matmul_busy),
        .ForwardAE     (ForwardAE),
        .ForwardBE     (ForwardBE),
        .StallPC       (StallPC),
        .StallID       (StallID),
        .StallEX       (StallEX),
        .FlushID       (FlushID),
        .FlushEX       (FlushEX),
        .FlushMEM      (FlushMEM),
        .matmul_rd_sel (matmul_rd_sel),
        .matmul_latch_rs (matmul_latch_rs)
    );

    // Matmul Accelerator Engine
    matmul mm (
        .clk               (clk),
        .reset             (reset),
        .matmul_start      (matmul_start_reg),
        .rs1_val           (rs1_val),
        .rs2_val           (rs2_val),
        .rd_val            (rd_val),
        .matmul_busy       (matmul_busy),
        .matmul_dmem_en    (matmul_dmem_en),
        .matmul_dmem_we    (matmul_dmem_we),
        .matmul_dmem_addr  (matmul_dmem_addr),
        .matmul_dmem_wdata (matmul_dmem_wdata),
        .matmul_dmem_rdata (matmul_dmem_rdata)
    );

endmodule
