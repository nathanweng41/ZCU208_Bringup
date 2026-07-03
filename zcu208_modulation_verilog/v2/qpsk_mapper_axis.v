`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//  
// Nathan Weng 07/2026
// QPSK Mapper AXIS
//
// Input:
//  s_axis_tdata[1:0] = 2-bit QPSK symbol
//
// Output:
//  m_axis_tdata[15:0] = I sample, signed int16
//  m_axis_tdata[31:16] = Q sample, signed int16
//
// Gray mapping: 
//
//  00 -> (+AMPLITUDE, +AMPLITUDE)
//  01 -> (-AMPLITUDE, +AMPLITUDE)
//  11 -> (-AMPLITUDE, -AMPLITUDE)
//  10 -> (+AMPLITUDE, -AMPLITUDE)
//
//////////////////////////////////////////////////////////////////////////////////


module qpsk_mapper_axis ( 
     (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 axis_aclk CLK" *)
     (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axis:m_axis, FREQ_HZ 160000000" *)
     input wire axis_aclk,
     
	 input wire [7:0] s_axis_tdata,
	 input wire 	  s_axis_tvalid,
	 output wire      s_axis_tready,
	 
	 output wire signed [31:0] m_axis_tdata,
	 output wire			   m_axis_tvalid,
	 input wire 			   m_axis_tready
   );
   
     localparam signed [15:0] AMPLITUDE_FIXED = 16'sd10000;

     wire [1:0] sym;
     reg signed [15:0] i_sample;
     reg signed [15:0] q_sample;

     assign sym = s_axis_tdata[1:0];

     initial begin
        $display("*****************************************************");
        $display("XXXXX QPSK_MAPPER AMPLITUDE   = %0d / 0x%04h", AMPLITUDE_FIXED, AMPLITUDE_FIXED[15:0]);
        $display("XXXXX QPSK_MAPPER -AMPLITUDE  = %0d / 0x%04h", -AMPLITUDE_FIXED, (-AMPLITUDE_FIXED) & 16'hFFFF);
        $display("XXXXX QPSK_MAPPER mapping: ");
        $display("XXXXX 00 -> +I  +Q ");
        $display("XXXXX 01 -> -I  +Q ");
        $display("XXXXX 11 -> -I  -Q ");
        $display("XXXXX 10 -> +I  -Q ");
     end
	 
     // AXIS passthrough
	 assign s_axis_tready = m_axis_tready;
	 assign m_axis_tvalid = s_axis_tvalid;
	 
	 always @(*) begin
        case (sym)
            2'b00: begin
                i_sample = AMPLITUDE_FIXED;
                q_sample = AMPLITUDE_FIXED;
            end
            2'b01: begin
                i_sample = -AMPLITUDE_FIXED;
                q_sample = AMPLITUDE_FIXED;
            end
            2'b11: begin
                i_sample = -AMPLITUDE_FIXED;
                q_sample = -AMPLITUDE_FIXED;
            end
            2'b10: begin
                i_sample = AMPLITUDE_FIXED;
                q_sample = -AMPLITUDE_FIXED;
            end
            
            default: begin
                i_sample = 16'sd0;
                q_sample = 16'sd0;
            end
        endcase
     end
     
	 assign m_axis_tdata = {q_sample, i_sample};
	 
endmodule
			

  
			