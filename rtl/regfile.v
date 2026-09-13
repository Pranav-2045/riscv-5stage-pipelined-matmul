module regfile (
    input clk,
    input we3,
    input [4:0] a1,
    input [4:0] a2,
    input [4:0] a3,
    input [31:0] wd3,
    output [31:0] rd1,
    output [31:0] rd2
);

  reg [31:0] rf [0:31];

  // Asynchronous reads with internal write-through for simultaneous WB write and ID read
  assign rd1 = (a1 != 5'b0) ? ((a1 == a3 && we3) ? wd3 : rf[a1]) : 32'b0;
  assign rd2 = (a2 != 5'b0) ? ((a2 == a3 && we3) ? wd3 : rf[a2]) : 32'b0;

  // Synchronous write on positive edge of clock
  always @(posedge clk) begin
    if (we3 && (a3 != 5'b0)) begin
      rf[a3] <= wd3;
    end
  end

endmodule
