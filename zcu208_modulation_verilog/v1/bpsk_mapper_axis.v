`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//  
// Nathan Weng 06/2026
// 
//////////////////////////////////////////////////////////////////////////////////


module bpsk_mapper_axis ( 
     (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 axis_aclk CLK" *)
     (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axis:m_axis, FREQ_HZ 306250000" *)
     input wire axis_aclk,
     
	 input wire [7:0] s_axis_tdata,
	 input wire 	  s_axis_tvalid,
	 output wire      s_axis_tready,
	 
	 output wire signed [15:0] m_axis_tdata,
	 output wire			   m_axis_tvalid,
	 input wire 			   m_axis_tready
   );
   
     localparam signed [15:0] AMPLITUDE_FIXED = 16'sd16000;
     
     initial begin
        $display("*****************************************************");
        $display("XXXXX BPSK_MAPPER AMPLITUDE   = %0d / 0x%04h", AMPLITUDE_FIXED, AMPLITUDE_FIXED[15:0]);
        $display("XXXXX BPSK_MAPPER -AMPLITUDE  = %0d / 0x%04h", -AMPLITUDE_FIXED, (-AMPLITUDE_FIXED) & 16'hFFFF);
     end
	 
	 assign s_axis_tready = m_axis_tready;
	 assign m_axis_tvalid = s_axis_tvalid;
	 
	 // BPSK mapping:
	 // bit 1 -> +AMPLITUDE
	 // bit 0 -> -AMPLITUDE
	 assign m_axis_tdata = s_axis_tdata[0]? AMPLITUDE_FIXED : -AMPLITUDE_FIXED;
	 
endmodule
			

  
			