module hazard (
    input        clk,
    input        reset,
    input  [4:0] Rs1D,
    input  [4:0] Rs2D,
    input  [4:0] Rs1E,
    input  [4:0] Rs2E,
    input  [4:0] RdE,
    input  [4:0] RdM,
    input  [4:0] RdW,
    input        RegWriteM,
    input        RegWriteW,
    input  [1:0] ResultSrcE,
    input        PCSrcE,
    input        matmul_startD,
    input        matmul_startE,
    input        matmul_busy,
    output reg [1:0] ForwardAE,
    output reg [1:0] ForwardBE,
    output       StallPC,
    output       StallID,
    output       StallEX,
    output       FlushID,
    output       FlushEX,
    output       FlushMEM,
    output       matmul_rd_sel,
    output       matmul_latch_rs
);

    // 1. Data Forwarding Unit (MEM > WB > ID/EX)
    always @* begin
        if ((Rs1E != 5'b0) && (Rs1E == RdM) && RegWriteM)
            ForwardAE = 2'b10;
        else if ((Rs1E != 5'b0) && (Rs1E == RdW) && RegWriteW)
            ForwardAE = 2'b01;
        else
            ForwardAE = 2'b00;
    end

    always @* begin
        if ((Rs2E != 5'b0) && (Rs2E == RdM) && RegWriteM)
            ForwardBE = 2'b10;
        else if ((Rs2E != 5'b0) && (Rs2E == RdW) && RegWriteW)
            ForwardBE = 2'b01;
        else
            ForwardBE = 2'b00;
    end

    // 2. Load-Use Stall Unit
    wire lwstall;
    assign lwstall = ResultSrcE[0] & ((Rs1D == RdE) | (Rs2D == RdE)) & (RdE != 5'b0);

    // 3. Matmul Stall, Freeze & Drain State Machine (EX stage)
    localparam M_IDLE      = 3'd0;
    localparam M_DRAIN1    = 3'd1;
    localparam M_DRAIN2    = 3'd2;
    localparam M_WAIT_BUSY = 3'd3;
    localparam M_RUNNING   = 3'd4;
    localparam M_DONE      = 3'd5;
    
    reg [2:0] m_state;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            m_state <= M_IDLE;
        end else begin
            case (m_state)
                M_IDLE:      if (matmul_startE) m_state <= M_DRAIN1;
                M_DRAIN1:    m_state <= M_DRAIN2;
                M_DRAIN2:    m_state <= M_WAIT_BUSY;
                M_WAIT_BUSY: if (matmul_busy) m_state <= M_RUNNING;
                M_RUNNING:   if (!matmul_busy) m_state <= M_DONE;
                M_DONE:      m_state <= M_IDLE;
                default:     m_state <= M_IDLE;
            endcase
        end
    end

    wire matmul_stall;
    assign matmul_stall = (matmul_startE && m_state != M_DONE) || (m_state != M_IDLE && m_state != M_DONE);
    
    assign matmul_latch_rs = (m_state == M_IDLE && matmul_startE);
    assign matmul_rd_sel   = (m_state == M_DRAIN1);
    
    assign FlushMEM = 1'b0;

    // 4. Combined Stall & Flush Controls
    assign StallPC = lwstall | matmul_stall;
    assign StallID = lwstall | matmul_stall;
    assign StallEX = matmul_stall;

    assign FlushID = (PCSrcE != 1'b0);
    assign FlushEX = lwstall | (PCSrcE != 1'b0);

endmodule
