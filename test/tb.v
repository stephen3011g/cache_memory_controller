`default_nettype none
`timescale 1ns / 1ps

module tb ();

  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
    #1;
  end

  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;


  tt_um_cache user_project (
      .ui_in  (ui_in),    
      .uo_out (uo_out),   
      .uio_in (uio_in),   
      .uio_out(uio_out),  
      .uio_oe (uio_oe),   
      .ena    (ena),      
      .clk    (clk),      
      .rst_n  (rst_n)     
  );


  initial begin
    clk = 0;
    forever #5 clk = ~clk; 
  end

  initial begin
    rst_n = 0;
    ena   = 0;
    ui_in = 0;
    uio_in = 0;

    #20 rst_n = 1;
    ena   = 1;

    ui_in = 8'b001011;  
    #10 ui_in = 0;


    #20 ui_in = 8'b000010;  
    #10 ui_in = 0;

    #40;
    $finish;
  end

endmodule

