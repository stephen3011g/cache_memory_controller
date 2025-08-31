`default_nettype none
`timescale 1ns / 1ps

module tb ();

  // Dump the signals to a VCD file. You can view it with gtkwave.
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
    #1;
  end

  // Inputs and outputs:
  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  // Instantiate your project
  tt_um_cache user_project (
      .ui_in  (ui_in),    // Dedicated inputs
      .uo_out (uo_out),   // Dedicated outputs
      .uio_in (uio_in),   // IOs: Input path
      .uio_out(uio_out),  // IOs: Output path
      .uio_oe (uio_oe),   // IOs: Enable path
      .ena    (ena),      // enable
      .clk    (clk),      // clock
      .rst_n  (rst_n)     // reset (active low)
  );

  // Generate clock
  initial begin
    clk = 0;
    forever #5 clk = ~clk;  // 100 MHz
  end

  // Stimulus
  initial begin
    rst_n = 0;
    ena   = 0;
    ui_in = 0;
    uio_in = 0;

    #20 rst_n = 1;
    ena   = 1;

    // Example: write addr=2, data=3
    ui_in = 8'b001011;  // valid=1, rw=1, addr=2, data=3
    #10 ui_in = 0;

    // Example: read addr=2
    #20 ui_in = 8'b000010;  // valid=1, rw=0, addr=2
    #10 ui_in = 0;

    #40;
    $finish;
  end

endmodule

