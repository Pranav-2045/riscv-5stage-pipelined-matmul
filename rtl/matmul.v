// Custom 64-Cycle 4x4 32-bit Integer Matrix Multiplication Execution Engine
module matmul (
    input  wire        clk,
    input  wire        reset,
    input  wire        matmul_start,
    input  wire [31:0] rs1_val,
    input  wire [31:0] rs2_val,
    input  wire [31:0] rd_val,
    output wire        matmul_busy,
    output reg         matmul_dmem_en,
    output reg         matmul_dmem_we,
    output reg  [31:0] matmul_dmem_addr,
    output reg  [31:0] matmul_dmem_wdata,
    input  wire [31:0] matmul_dmem_rdata
);

    // State definitions
    localparam IDLE    = 3'b000;
    localparam READ_A  = 3'b001;
    localparam READ_B  = 3'b010;
    localparam COMPUTE = 3'b011;
    localparam WRITE_C = 3'b100;

    reg [2:0] state;
    reg [3:0] counter;

    // Base address registers
    reg [31:0] baseA;
    reg [31:0] baseB;
    reg [31:0] baseC;

    // Internal matrix registers (4x4 = 16 elements each)
    reg [31:0] matA [0:15];
    reg [31:0] matB [0:15];
    reg [31:0] matC [0:15];

    // Helper wires for COMPUTE phase indexing
    wire [1:0] comp_i = counter[3:2];
    wire [1:0] comp_j = counter[1:0];

    // Busy signal is high while processing (not in IDLE)
    assign matmul_busy = (state != IDLE);

    // FSM and Datapath Logic
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state   <= IDLE;
            counter <= 4'd0;
            baseA   <= 32'd0;
            baseB   <= 32'd0;
            baseC   <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (matmul_start) begin
                        $display("[MATMUL_RTL] time=%0t Starting Matmul! rs1_val=%0d (0x%0h), rs2_val=%0d (0x%0h), rd_val=%0d (0x%0h)",
                                 $time, rs1_val, rs1_val, rs2_val, rs2_val, rd_val, rd_val);
                        state   <= READ_A;
                        counter <= 4'd0;
                        baseA   <= rs1_val;
                        baseB   <= rs2_val;
                        baseC   <= rd_val;
                    end
                end

                READ_A: begin
                    matA[counter] <= matmul_dmem_rdata;
                    if (counter == 4'd15) begin
                        state   <= READ_B;
                        counter <= 4'd0;
                    end else begin
                        counter <= counter + 4'd1;
                    end
                end

                READ_B: begin
                    matB[counter] <= matmul_dmem_rdata;
                    if (counter == 4'd15) begin
                        state   <= COMPUTE;
                        counter <= 4'd0;
                    end else begin
                        counter <= counter + 4'd1;
                    end
                end

                COMPUTE: begin
                    matC[counter] <= matA[{comp_i, 2'b00}] * matB[{2'b00, comp_j}]
                                   + matA[{comp_i, 2'b01}] * matB[{2'b01, comp_j}]
                                   + matA[{comp_i, 2'b10}] * matB[{2'b10, comp_j}]
                                   + matA[{comp_i, 2'b11}] * matB[{2'b11, comp_j}];
                    if (counter == 4'd15) begin
                        state   <= WRITE_C;
                        counter <= 4'd0;
                    end else begin
                        counter <= counter + 4'd1;
                    end
                end

                WRITE_C: begin
                    if (counter == 4'd15) begin
                        state   <= IDLE;
                        counter <= 4'd0;
                    end else begin
                        counter <= counter + 4'd1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Combinational Memory Interface Driving
    always @(*) begin
        case (state)
            READ_A: begin
                matmul_dmem_en   = 1'b1;
                matmul_dmem_we   = 1'b0;
                matmul_dmem_addr = baseA + ({28'd0, counter} << 2);
                matmul_dmem_wdata= 32'd0;
            end
            READ_B: begin
                matmul_dmem_en   = 1'b1;
                matmul_dmem_we   = 1'b0;
                matmul_dmem_addr = baseB + ({28'd0, counter} << 2);
                matmul_dmem_wdata= 32'd0;
            end
            WRITE_C: begin
                matmul_dmem_en   = 1'b1;
                matmul_dmem_we   = 1'b1;
                matmul_dmem_addr = baseC + ({28'd0, counter} << 2);
                matmul_dmem_wdata= matC[counter];
            end
            default: begin
                matmul_dmem_en   = 1'b0;
                matmul_dmem_we   = 1'b0;
                matmul_dmem_addr = 32'd0;
                matmul_dmem_wdata= 32'd0;
            end
        endcase
    end

endmodule
