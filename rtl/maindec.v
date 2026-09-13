module maindec (
    input  [6:0] op,
    output reg   regwrite,
    output reg [2:0] immsrc,
    output reg   alusrc,
    output reg   memwrite,
    output reg [1:0] resultsrc,
    output reg   branch,
    output reg   jump,
    output reg   jalr,
    output reg [1:0] aluop,
    output reg   matmul_start
);

    always @* begin
        // Comprehensive default assignment to prevent latches
        regwrite     = 1'b0;
        immsrc       = 3'b000;
        alusrc       = 1'b0;
        memwrite     = 1'b0;
        resultsrc    = 2'b00;
        branch       = 1'b0;
        jump         = 1'b0;
        jalr         = 1'b0;
        aluop        = 2'b00;
        matmul_start = 1'b0;

        case (op)
            7'b0000011: {regwrite, immsrc, alusrc, memwrite, resultsrc, branch, jump, jalr, aluop, matmul_start} = 14'b1_000_1_0_01_0_0_0_00_0; // lw
            7'b0100011: {regwrite, immsrc, alusrc, memwrite, resultsrc, branch, jump, jalr, aluop, matmul_start} = 14'b0_001_1_1_00_0_0_0_00_0; // sw
            7'b0110011: {regwrite, immsrc, alusrc, memwrite, resultsrc, branch, jump, jalr, aluop, matmul_start} = 14'b1_000_0_0_00_0_0_0_10_0; // R-type
            7'b1100011: {regwrite, immsrc, alusrc, memwrite, resultsrc, branch, jump, jalr, aluop, matmul_start} = 14'b0_010_0_0_00_1_0_0_01_0; // beq
            7'b0010011: {regwrite, immsrc, alusrc, memwrite, resultsrc, branch, jump, jalr, aluop, matmul_start} = 14'b1_000_1_0_00_0_0_0_10_0; // I-type
            7'b1101111: {regwrite, immsrc, alusrc, memwrite, resultsrc, branch, jump, jalr, aluop, matmul_start} = 14'b1_011_0_0_10_0_1_0_00_0; // jal
            7'b1100111: {regwrite, immsrc, alusrc, memwrite, resultsrc, branch, jump, jalr, aluop, matmul_start} = 14'b1_000_1_0_10_0_0_1_00_0; // jalr
            7'b0110111: {regwrite, immsrc, alusrc, memwrite, resultsrc, branch, jump, jalr, aluop, matmul_start} = 14'b1_100_1_0_00_0_0_0_00_0; // lui
            7'b0001011: {regwrite, immsrc, alusrc, memwrite, resultsrc, branch, jump, jalr, aluop, matmul_start} = 14'b0_000_0_0_00_0_0_0_00_1; // matmul
            default:    {regwrite, immsrc, alusrc, memwrite, resultsrc, branch, jump, jalr, aluop, matmul_start} = 14'b0_000_0_0_00_0_0_0_00_0;
        endcase
    end

endmodule
