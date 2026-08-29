`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//  
// Nathan Weng 08/2026
// QAM Mapper AXIS
//
// Input:
//  s_axis_tdata[3:0] = 4-bit QAM symbol
//
// Internal QAM samples: signed 14-bit
//
// AXIS Output:
//  m_axis_tdata[15:0] = I sample, 14-bit signed value sign-extended to 16 bits
//  m_axis_tdata[31:16] = Q sample, 14-bit signed value sign-extended to 16 bits
//
// FIR Compiler configured for 14-bit input will use:
//  PATH_0 = m_axis_tdata[13:0] = I sample
//  PATH_1 = m_axis_tdata[29:16] = Q sample
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
     (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axis:m_axis, FREQ_HZ 20000000" *)
     input wire axis_aclk,
     
	 input wire [7:0] s_axis_tdata,
	 input wire 	  s_axis_tvalid,
	 output wire      s_axis_tready,
	 
	 output wire [31:0]        m_axis_tdata,
	 output wire			   m_axis_tvalid,
	 input wire 			   m_axis_tready
   );
   
     localparam signed [13:0] MAX_AMPLITUDE = 14'sd5500;
     localparam signed [13:0] INNER_AMPLITUDE = MAX_AMPLITUDE / 3; // 1833 truncated down
     localparam integer EQUIV_16BIT_AMPLITUDE = 5500 * 4;

     wire [3:0] sym;
     wire signed [13:0] i_sample;
     wire signed [13:0] q_sample;

     wire signed [15:0] i_axis;
     wire signed [15:0] q_axis;

     assign sym = s_axis_tdata[3:0];

     function signed [13:0] map_symbol;
         input [1:0] bits;
         begin
             case (bits)
                 2'b00: map_symbol = MAX_AMPLITUDE;
                 2'b01: map_symbol = INNER_AMPLITUDE;
                 2'b11: map_symbol = -INNER_AMPLITUDE;
                 2'b10: map_symbol = -MAX_AMPLITUDE;
                 default: map_symbol = 14'sd0; // Should not happen
             endcase
         end
     endfunction

     initial begin
        $display("*****************************************************");
        $display("XXXXX QAM_MAPPER 14-BIT AMPLITUDE            = %0d", MAX_AMPLITUDE);
        $display("XXXXX QAM_MAPPER 14-BIT INNER AMPLITUDE      = %0d", INNER_AMPLITUDE);
        $display("XXXXX QAM_MAPPER EQUIVALENT 16-BIT AMPLITUDE = %0d", EQUIV_16BIT_AMPLITUDE);
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

     assign i_axis = {{2{i_sample[13]}}, i_sample}; // Sign-extend to 16 bits
     assign q_axis = {{2{q_sample[13]}}, q_sample}; // Sign-extend to 16 bits

	 assign m_axis_tdata = {q_axis, i_axis};
	 
endmodule
