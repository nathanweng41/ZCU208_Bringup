`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//  
// Nathan Weng 08/2026
// QAM Mapper AXIS
//
// Input:
//  s_axis_tdata[3:0] = 4-bit QAM symbol
//
// Output:
//  m_axis_tdata[15:0] = I sample, signed int16
//  m_axis_tdata[31:16] = Q sample, signed int16
//
// Gray mapping: 
//  00 -> +MAX_AMPLITUDE
//  01 -> +INNER_AMPLITUDE
//  11 -> -INNER_AMPLITUDE
//  10 -> -MAX_AMPLITUDE
//
//////////////////////////////////////////////////////////////////////////////////



module qam_mapper_axis ( 
     (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 axis_aclk CLK" *)
     (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axis:m_axis, FREQ_HZ 160000000" *)
     input wire axis_aclk,
     
	 input wire [7:0] s_axis_tdata,
	 input wire 	  s_axis_tvalid,
	 output wire      s_axis_tready,
	 
	 output wire [31:0]        m_axis_tdata,
	 output wire			   m_axis_tvalid,
	 input wire 			   m_axis_tready
   );
   
     parameter signed [15:0] MAX_AMPLITUDE = 16'sd22000;
     localparam signed [15:0] INNER_AMPLITUDE = MAX_AMPLITUDE / 3; // 7333 truncated down

     wire [3:0] sym;
     wire signed [15:0] i_sample;
     wire signed [15:0] q_sample;

     assign sym = s_axis_tdata[3:0];

     function signed [15:0] map_symbol;
         input [1:0] bits;
         begin
             case (bits)
                 2'b00: map_symbol = MAX_AMPLITUDE;
                 2'b01: map_symbol = INNER_AMPLITUDE;
                 2'b11: map_symbol = -INNER_AMPLITUDE;
                 2'b10: map_symbol = -MAX_AMPLITUDE;
                 default: map_symbol = 16'sd0; // Should not happen
             endcase
         end
     endfunction

     initial begin
        $display("*****************************************************");
        $display("XXXXX QAM_MAPPER AMPLITUDE   = %0d / 0x%04h", MAX_AMPLITUDE, MAX_AMPLITUDE[15:0]);
        $display("XXXXX QAM_MAPPER INNER AMPLITUDE  = %0d / 0x%04h", INNER_AMPLITUDE, INNER_AMPLITUDE[15:0]);
        $display("XXXXX QAM_MAPPER mapping: ");
        $display("XXXXX 00 -> +MAX_AMPLITUDE");
        $display("XXXXX 01 -> +INNER_AMPLITUDE");
        $display("XXXXX 11 -> -INNER_AMPLITUDE");
        $display("XXXXX 10 -> -MAX_AMPLITUDE");
     end
	 
     // AXIS passthrough
	 assign s_axis_tready = m_axis_tready;
	 assign m_axis_tvalid = s_axis_tvalid;

     assign q_sample = map_symbol(sym[3:2]);
	 assign i_sample = map_symbol(sym[1:0]);
	 assign m_axis_tdata = {q_sample, i_sample};
	 
endmodule
