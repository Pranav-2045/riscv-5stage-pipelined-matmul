module top (
    input         clk,
    input         reset,
    output [31:0] writedata,
    output [31:0] dataadr,
    output        memwrite
);

    wire [31:0] pc;
    wire [31:0] instr;

    // CPU Data Memory Interface Wires
    wire        mem_we;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [31:0] mem_rdata;

    // Matmul Direct Memory Interface Wires
    wire        matmul_busy;
    wire        matmul_dmem_en;
    wire        matmul_dmem_we;
    wire [31:0] matmul_dmem_addr;
    wire [31:0] matmul_dmem_wdata;
    wire [31:0] matmul_dmem_rdata;

    // Memory Arbiter Multiplexed Wires
    wire        dmem_we;
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [31:0] dmem_rdata;

    // Memory Arbiter Multiplexing
    assign dmem_we            = matmul_busy ? matmul_dmem_we   : mem_we;
    assign dmem_addr          = matmul_busy ? matmul_dmem_addr : mem_addr;
    assign dmem_wdata         = matmul_busy ? matmul_dmem_wdata: mem_wdata;
    assign mem_rdata          = dmem_rdata;
    assign matmul_dmem_rdata  = dmem_rdata;

    // Top Level Outputs for Testbench Monitoring
    assign memwrite  = dmem_we;
    assign dataadr   = dmem_addr;
    assign writedata = dmem_wdata;

    // Instantiate 5-stage Pipelined Core
    riscvpipelined rvpipelined (
        .clk               (clk),
        .reset             (reset),
        .pc                (pc),
        .instr             (instr),
        .mem_we            (mem_we),
        .mem_addr          (mem_addr),
        .mem_wdata         (mem_wdata),
        .mem_rdata         (mem_rdata),
        .matmul_busy       (matmul_busy),
        .matmul_dmem_en    (matmul_dmem_en),
        .matmul_dmem_we    (matmul_dmem_we),
        .matmul_dmem_addr  (matmul_dmem_addr),
        .matmul_dmem_wdata (matmul_dmem_wdata),
        .matmul_dmem_rdata (matmul_dmem_rdata)
    );

    // Instantiate Instruction Memory
    imem imem (
        .a  (pc),
        .rd (instr)
    );

    // Instantiate Data Memory
    dmem dmem (
        .clk (clk),
        .we  (dmem_we),
        .a   (dmem_addr),
        .wd  (dmem_wdata),
        .rd  (dmem_rdata)
    );

endmodule
