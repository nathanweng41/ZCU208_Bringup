`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//  
// Nathan Weng 06/2026
// 
//////////////////////////////////////////////////////////////////////////////////


module bpsk_mapper_axis #(
	 parameter signed [15:0] AMPLITUDE = 16'sd16000
) ( 
	 input wire [0:0] s_axis_tdata,
	 input wire 	  s_axis_tvalid,
	 output wire      s_axis_tready,
	 
	 output wire signed [15:0] m_axis_tdata,
	 output wire			   m_axis_tvalid,
	 input wire 			   m_axis_tready
   );
	 
	 assign s_axis_tready = m_axis_tready;
	 assign m_axis_tvalid = s_axis_tvalid;
	 
	 // BPSK mapping:
	 // bit 1 -> +AMPLITUDE
	 // bit 0 -> -AMPLITUDE
	 assign m_axis_tdata = s_axis_tdata[0]? AMPLITUDE : -AMPLITUDE;
	 
endmodule
			

  
			