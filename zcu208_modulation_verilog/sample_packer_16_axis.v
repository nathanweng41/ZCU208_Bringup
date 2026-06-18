`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//
// Nathan Weng 06/2026
// 
//////////////////////////////////////////////////////////////////////////////////

module sample_packer_16_axis #(
		   parameter integer SAMPLE_WIDTH = 16,
           parameter integer SAMPLES_PER_WORD = 16,
		   parameter integer OUT_WIDTH = SAMPLE_WIDTH * SAMPLES_PER_WORD
)(        

	 input wire axis_clk, 
	 
	 input wire axis_aresetn,
	 
	 input wire enable,
	 
	 // AXI-stream input: one mapped sample from BPSK/QPSK/QAM mapper
	 input wire [SAMPLE_WIDTH-1:0]		s_axis_tdata,
	 input wire				   	   		s_axis_tvalid,
	 output wire			   			s_axis_tready,
	 
	 // High only when this clock should produce a valid DAC sample
	 input wire sample_en,
	 
	 // AXI-stream output: packed samples to RFDC
	 output reg [OUT_WIDTH-1:0]			m_axis_tdata,
	 output reg						  	m_axis_tvalid,
	 input wire						  	m_axis_tready,
	
	 output reg [3:0] 					sample_count,
	 
	 // If overflow is set to 1, RFDC can't react fast enough, need buffer
	 output reg 						overflow
   );
   
   // Packer is sample-timed. 
   // Upstream mapper should see ready high all the time
   assign s_axis_tready = 1'b1;
   
   wire valid_sample;
   assign valid_sample = enable && sample_en && s_axis_tvalid;
   
   reg [OUT_WIDTH-1:0] packed_reg;
   
   initial begin
		$display("*****************************************************");
		$display("XXXXXX SAMPLE_PACKER SAMPLE_WIDTH                     = %d", SAMPLE_WIDTH);
		$display("XXXXXX SAMPLE_PACKER SAMPLES_PER_WORD                 = %d", SAMPLES_PER_WORD);
		$display("XXXXXX SAMPLE_PACKER OUT_WIDTH                        = %d", OUT_WIDTH);
   end

always @(posedge axis_clk) begin
	if (!axis_aresetn) begin
		packed_reg 	 	<= {OUT_WIDTH{1'b0}};
		m_axis_tdata 	<= {OUT_WIDTH{1'b0}};
		m_axis_tvalid	<= 0;
		sample_count	<= 4'd0;
		overflow		<= 0;
	end else begin
		if (!enable) begin
			packed_reg 	 	<= {OUT_WIDTH{1'b0}};
			m_axis_tdata 	<= {OUT_WIDTH{1'b0}};
			m_axis_tvalid	<= 0;
			sample_count	<= 4'd0;
			overflow		<= 0;
		end else begin
			// If RFDC accepts the packed word, clear valid. If a new word is completed in this same clock, set m_axis_tvalid back to 1
			if (m_axis_tvalid && m_axis_tready) begin
				m_axis_tvalid	<= 0;
			end
			// Only collect samples on sample_en cycles
			if (valid_sample) begin
			
				if (sample_count == 4'd15) begin
					
					if (m_axis_tvalid && !m_axis_tready) begin
						overflow <= 1;
					end else begin
						m_axis_tdata	<= {s_axis_tdata, packed_reg[239:0]}; // Put s_axis_tdata in [255:240]
						m_axis_tvalid	<= 1'b1;
					end
					
					sample_count <= 4'd0;
					packed_reg <= {OUT_WIDTH{1'b0}};
					
				end else begin
					packed_reg[sample_count*SAMPLE_WIDTH +: SAMPLE_WIDTH] <= s_axis_tdata;
					sample_count <= sample_count + 1'b1;
				end
			end
		end
	end
end

endmodule