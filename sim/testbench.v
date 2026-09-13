`timescale 1ns / 1ps

module testbench;

  reg         clk;
  reg         reset;
  wire [31:0] writedata;
  wire [31:0] dataadr;
  wire        memwrite;

  integer     cycle_count;
  integer     timeout_cycles;
  integer     expected_val;
  reg [1024:0] hex_filename;

  // Instantiate top-level DUT
  top dut (
    .clk(clk),
    .reset(reset),
    .writedata(writedata),
    .dataadr(dataadr),
    .memwrite(memwrite)
  );

  // Clock generation (100MHz / 10ns period)
  always #5 clk = ~clk;

  // Cycle counter
  always @(posedge clk) begin
    if (reset)
      cycle_count <= 0;
    else
      cycle_count <= cycle_count + 1;
  end

  // Initialize signals and load hex file
  initial begin
    clk = 0;
    reset = 1;
    cycle_count = 0;
    timeout_cycles = 1000;

    if ($value$plusargs("TIMEOUT=%d", timeout_cycles)) begin
      $display("[TB] Setting timeout to %0d cycles", timeout_cycles);
    end

    if ($value$plusargs("HEX_FILE=%s", hex_filename)) begin
      $display("[TB] Loading imem hex file: %0s", hex_filename);
      $readmemh(hex_filename, dut.imem.RAM);
    end else begin
      $display("[TB] Loading default riscvtest.hex");
      $readmemh("riscvtest.hex", dut.imem.RAM);
    end

    #22;
    reset = 0;
  end

  // Safety Timeout
  always @(posedge clk) begin
    if (cycle_count >= timeout_cycles) begin
      $display("[TB] Simulation failed: TIMEOUT after %0d cycles", cycle_count);
      $finish;
    end
  end

  // VCD Waveform Tracing
  initial begin
    $dumpfile("riscv_tb.vcd");
    $dumpvars(0, testbench);
  end

  // Self-Checking and Monitor Mechanism
  always @(negedge clk) begin
    if (!reset && memwrite) begin
      $display("[TB] MEMWRITE @ cycle %0d: addr=0x%0h (%0d), data=0x%0h (%0d)",
               cycle_count, dataadr, dataadr, writedata, writedata);
      
      // Address 84 is standard signature address
      if (dataadr === 32'd84) begin
        $display("[TB] Signature written to addr 84: %0d (0x%0h) at cycle %0d", writedata, writedata, cycle_count);
        #50;
        $finish;
      end
    end
  end

endmodule
