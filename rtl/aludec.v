module aludec (
    input [1:0] aluop,
    input [2:0] funct3,
    input funct7_5,
    input op_5,
    output reg [2:0] alucontrol
);

    always @* begin
        alucontrol = 3'b000;
        case (aluop)
            2'b00: alucontrol = 3'b000;
            2'b01: alucontrol = 3'b001;
            2'b10: begin
                case (funct3)
                    3'b000: begin
                        if (funct7_5 && op_5)
                            alucontrol = 3'b001;
                        else
                            alucontrol = 3'b000;
                    end
                    3'b010: alucontrol = 3'b101;
                    3'b110: alucontrol = 3'b011;
                    3'b111: alucontrol = 3'b010;
                    default: alucontrol = 3'b000;
                endcase
            end
            default: alucontrol = 3'b000;
        endcase
    end

endmodule
