module imem (
    input [31:0] a,
    output [31:0] rd
);

    reg [31:0] RAM [0:255];

    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            RAM[i] = 32'h00000013; // NOP instruction (addi x0, x0, 0)
        end
    end

    assign rd = RAM[a[31:2]];

endmodule
