`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//
// Nathan Weng 07/2026
// QPSK IQ Sample Packer AXIS
// 
// Input @ 160 MHz:
//  s_axis_tdata[15:0] = I sample, signed int16
//  s_axis_tdata[31:16] = Q sample, signed int16
//
// Output:
//  m_axis_tdata[255:0] = 8 accepted complex samples
//
// Internal packing convention:
//  complex sample 0 -> m_axis_tdata[31:0]
//      [15:0]  = I0
//      [31:16] = Q0
//  complex sample 1 -> m_axis_tdata[63:32]
//      [47:32] = I1
//      [63:48] = Q1
//
//  ...
//
//  complex sample 7 -> m_axis_tdata[255:224]
//      [239:224] = I7
//      [255:240] = Q7
//
//  Verify this against RFDC Guide for DAC data packing convention.
//
//////////////////////////////////////////////////////////////////////////////////

module sample_packer_16_axis #(
		   parameter integer SAMPLE_WIDTH = 16,
           parameter integer COMPLEX_WIDTH = 32,
           parameter integer COMPLEX_SAMPLES_PER_WORD = 8,
		   parameter integer OUT_WIDTH = COMPLEX_WIDTH * COMPLEX_SAMPLES_PER_WORD;
)(        

	 input wire axis_clk, 
	 
	 input wire axis_aresetn,
	 
	 input wire enable,
	 
	 // AXI-stream input: one complex I/Q sample from FIR or mapper
     // [15:0] = I sample, signed int16
     // [31:16] = Q sample, signed int16
	 input wire [COMPLEX_WIDTH-1:0]		s_axis_tdata,
	 input wire				   	   		s_axis_tvalid,
	 output wire			   			s_axis_tready,
	 
	 // AXI-stream output: packed 8 complex samples
	 output reg [OUT_WIDTH-1:0]			m_axis_tdata,
	 output reg						  	m_axis_tvalid,
	 input wire						  	m_axis_tready,
	
	 output reg [2:0] 					sample_count,
	 
	 // If overflow is set to 1, output was not acccepted when a new packed word was ready
	 output reg 						overflow
   );
   
   localparam integer COUNT_WIDTH = 3;

   reg [OUT_WIDTH-1:0] packed_reg;

   assign in_fire = s_axis_tvalid && s_axis_tready;
   assign out_fire = m_axis_tvalid && m_axis_tready;
   
   // If a packed output word is waiting and downstream is not ready, stop accepting new input samples.
   assign s_axis_tready = enable && (!m_axis_tvalid || m_axis_tready);
   // In reality, FIFO should take care of above, may not work need to verify in simulation.
   
   initial begin
		$display("*****************************************************");
		$display("XXXXXX QPSK_SAMPLE_PACKER SAMPLE_WIDTH                     = %d", SAMPLE_WIDTH);
        $display("XXXXXX QPSK_SAMPLE_PACKER COMPLEX_WIDTH                    = %d", COMPLEX_WIDTH);
        $display("XXXXXX QPSK_SAMPLE_PACKER COMPLEX_SAMPLES_PER_WORD        = %d", COMPLEX_SAMPLES_PER_WORD);
		$display("XXXXXX QPSK_SAMPLE_PACKER OUT_WIDTH                        = %d", OUT_WIDTH);
   end

always @(posedge axis_clk) begin
	if (!axis_aresetn) begin
		packed_reg 	 	<= {OUT_WIDTH{1'b0}};
		m_axis_tdata 	<= {OUT_WIDTH{1'b0}};
		m_axis_tvalid	<= 1'b0;
		sample_count	<= 3'd0;
		overflow		<= 1'b0;
	end else begin
		if (!enable) begin
			packed_reg 	 	<= {OUT_WIDTH{1'b0}};
			m_axis_tdata 	<= {OUT_WIDTH{1'b0}};
			m_axis_tvalid	<= 1'b0;
			sample_count	<= 3'd0;
			overflow		<= 1'b0;
		end else begin
			// If RFDC accepts the packed word, clear valid. If a new word is completed in this same clock, set m_axis_tvalid back to 1
			if (out_fire) begin
				m_axis_tvalid	<= 1'b0;
			end
			// Only collect samples on sample_en cycles
			if (in_fire) begin
			
				if (sample_count == 3'd7) begin
					
					if (m_axis_tvalid && !m_axis_tready) begin
						overflow <= 1;
					end else begin
						m_axis_tdata	<= {s_axis_tdata, packed_reg[223:0]}; // Put s_axis_tdata in [255:224]
						m_axis_tvalid	<= 1'b1;
					end
					
					sample_count <= 3'd0;
					packed_reg <= {OUT_WIDTH{1'b0}};
					
				end else begin
					packed_reg[sample_count*COMPLEX_WIDTH +: COMPLEX_WIDTH] <= s_axis_tdata;
					sample_count <= sample_count + 3'd1;
				end
			end
		end
	end
end

endmodule