module dmem (
    input clk,
    input we,
    input [31:0] a,
    input [31:0] wd,
    output [31:0] rd
);

    reg [31:0] RAM [0:255];

    assign rd = RAM[a[31:2]];

    always @(posedge clk) begin
        if (we) begin
            RAM[a[31:2]] <= wd;
        end
    end

endmodule
