module alu (
    input  [31:0] srca,
    input  [31:0] srcb,
    input  [2:0]  alucontrol,
    output reg [31:0] aluresult,
    output        zero
);

    always @(*) begin
        case (alucontrol)
            3'b000:  aluresult = srca + srcb;
            3'b001:  aluresult = srca - srcb;
            3'b010:  aluresult = srca & srcb;
            3'b011:  aluresult = srca | srcb;
            3'b101:  aluresult = ($signed(srca) < $signed(srcb)) ? 32'b1 : 32'b0;
            default: aluresult = 32'b0;
        endcase
    end

    assign zero = (aluresult == 32'b0);

endmodule
