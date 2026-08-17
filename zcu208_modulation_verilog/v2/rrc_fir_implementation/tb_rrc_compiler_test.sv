`timescale 1ps / 1ps

// Gray mapping: 
//
//  00 -> (+AMPLITUDE, +AMPLITUDE)
//  01 -> (-AMPLITUDE, +AMPLITUDE)
//  11 -> (-AMPLITUDE, -AMPLITUDE)
//  10 -> (+AMPLITUDE, -AMPLITUDE)

module tb_rrc_compiler_test;

  // DAC PL clk
  localparam time CLK_PERIOD_PS = 6250ps; // 160 MHz clock period in picoseconds

  localparam int SPS = 8;

  localparam int NUM_QPSK_SYMBOLS = 8192;
  localparam int NUM_FLUSH_SYMBOLS = 16;

  localparam logic signed [15:0] AMP = 16'sd10000; // Amplitude for QPSK symbols

  // Clock
  logic aclk_0 = 1'b0;

  always #(CLK_PERIOD_PS/2) aclk_0 = ~aclk_0;

  // AXI input, Path0 / [15:0]  = I
  // AXI input, Path1 / [31:16] = Q

  logic [31:0] S_AXIS_DATA_0_tdata;
  logic        S_AXIS_DATA_0_tvalid;
  logic        S_AXIS_DATA_0_tready;

   // AXI output
   logic [31:0] M_AXIS_DATA_0_tdata;
   logic        M_AXIS_DATA_0_tvalid;
   logic        M_AXIS_DATA_0_tready;

   // DUT

   rrc_compiler_test_wrapper dut (
        .M_AXIS_DATA_0_tdata(M_AXIS_DATA_0_tdata),
        .M_AXIS_DATA_0_tready(M_AXIS_DATA_0_tready),
        .M_AXIS_DATA_0_tvalid(M_AXIS_DATA_0_tvalid),
        
        .S_AXIS_DATA_0_tdata(S_AXIS_DATA_0_tdata),
        .S_AXIS_DATA_0_tready(S_AXIS_DATA_0_tready),
        .S_AXIS_DATA_0_tvalid(S_AXIS_DATA_0_tvalid),

        .aclk_0(aclk_0)
   )
   
   // Output I/Q

   logic signed [15:0] out_i;
   logic signed [15:0] out_q;

   assign out_i = $signed(M_AXIS_DATA_0_tdata[15:0]);
   assign out_q = $signed(M_AXIS_DATA_0_tdata[31:16]);

   // Test mode
   typedef enum {
     TEST_IDLE,
     TEST_IMPULSE,
     TEST_QPSK
   } test_mode_t;

   test_mode_t test_mode;

   // Files
   integer f_impulse;
   integer f_qpsk;
   integer f_symbols;
   integer f_timing;

   // Counters

   int impulse_output_index;
   int qpsk_output_index;

   int input_transfer_index;

   int clock_counter;
   int previous_input_clock;

   int output_clock_counter;
   int previous_output_clock;

   // Output capture
   always @(posedge aclk_0) begin
     if (M_AXIS_DATA_0_tvalid && M_AXIS_DATA_0_tready) begin
       case (test_mode)
         TEST_IMPULSE: begin
           $fwrite(f_impulse, "%d %d\n", out_i, out_q);
           impulse_output_index++;
         end
         TEST_QPSK: begin
           $fwrite(f_qpsk, "%d %d\n", out_i, out_q);
           qpsk_output_index++;
         end
         default: ;
       endcase
     end
   end
