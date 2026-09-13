module flopenr #(
    parameter WIDTH = 32
) (
    input                  clk,
    input                  reset,
    input                  en,
    input      [WIDTH-1:0] d,
    output reg [WIDTH-1:0] q
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            q <= 0;
        end else if (en) begin
            q <= d;
        end
    end

endmodule
