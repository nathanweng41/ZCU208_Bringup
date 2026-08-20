`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//  
// Nathan Weng 08/2026
// Gain Ctrl AXIS
//
// Input:
//      s_axis_tdata[15:0] = I sample, signed int16
//      s_axis_tdata[31:16] = Q sample, signed int16
//
// Gain:
//      gain_q15[15:0] = unsigned Q1.15
//
//      0x0000 = 0.0
//      0x4000 = 0.5
//      0x8000 = 1.0
//
// Output:
//  m_axis_tdata[15:0] = I sample scaled, signed int16
//  m_axis_tdata[31:16] = Q sample scaled, signed int16
//
//
//////////////////////////////////////////////////////////////////////////////////



module gain_ctrl ( 
     (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 axis_aclk CLK" *)
     (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axis:m_axis, FREQ_HZ 160000000" *)
     input wire axis_aclk,
     
	 input wire [31:0]         s_axis_tdata,
	 input wire 	           s_axis_tvalid,
	 output wire               s_axis_tready,
	 
	 output wire [31:0]        m_axis_tdata,
	 output wire			   m_axis_tvalid,
	 input wire 			   m_axis_tready,

     input wire [15:0]         gain_q15
   );

    localparam signed [32:0] ROUND_POS = 33'sd16384; // 2^14
    localparam signed [32:0] ROUND_NEG = 33'sd16383; // 2^14-1

    // Extract signed I/Q samples
    wire signed [15:0] i_sample;
    wire signed [15:0] q_sample;

    // Gain must be extended to 17 bits so 0x8000 is +32768, not -32768. 
    wire signed [16:0] gain_signed;

    // 16+17 = 33-bit signed product
    wire signed [32:0] product_i;
    wire signed [32:0] product_q;

    // Rounded results 
    wire signed [32:0] rounded_i_wide;
    wire signed [32:0] rounded_q_wide;

    wire signed [15:0] scaled_i;
    wire signed [15:0] scaled_q;

    // Gain limit
    wire [15:0] gain_limited;

    assign gain_limited = (gain_q15 > 16'h8000) ? 16'h8000 : gain_q15;

    assign i_sample = $signed(s_axis_tdata[15:0]);
    assign q_sample = $signed(s_axis_tdata[31:16]);	

    assign gain_signed = $signed({1'b0, gain_limited}); // Extend to 17 bits

    assign product_i = i_sample * gain_signed;
    assign product_q = q_sample * gain_signed;

    // Round to nearest integer
    assign rounded_i_wide = (product_i >= 0) ? ((product_i + ROUND_POS) >>> 15) : ((product_i + ROUND_NEG) >>> 15);
    assign rounded_q_wide = (product_q >= 0) ? ((product_q + ROUND_POS) >>> 15) : ((product_q + ROUND_NEG) >>> 15);

    assign scaled_i = rounded_i_wide[15:0];
    assign scaled_q = rounded_q_wide[15:0];

    assign m_axis_tdata = {scaled_q, scaled_i};

     // AXIS passthrough
    assign s_axis_tready = m_axis_tready;
    assign m_axis_tvalid = s_axis_tvalid;
	 
endmodule
