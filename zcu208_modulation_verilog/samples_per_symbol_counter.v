`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//  
// Nathan Weng 08/2026
// Revised version from v1/samples_per_symbol_counter.v, no more fractional sample_en
// Further revised from v2/samples_per_symbol_counter.v, found issue where it's one clock late.
// symbol_period = # of complex samples per modulation symbol
// Examples:
//  symbol_period = 1 -> 160 MSym/s
//  symbol_period = 8 -> 20 MSym/s
// 
//////////////////////////////////////////////////////////////////////////////////


module samples_per_symbol_counter (        

	 input wire clk, 
	 
	 input wire rstn,
	 
	 input wire enable,

	 // Pulses high for a cycle in which one sample is accepted
	 input wire sample_fire, 
	 
	 // Number of valid samples per symbol
	 input wire [15:0] symbol_period,
	 
	 // Current count
	 output reg [15:0] count,
	 
	 // Combinational: high during the cycle containing the final accepted sample of the current symbol
	 output wire symbol_advance
   );
   
     wire period_done;

	 assign period_done = (symbol_period <= 16'd1) || (count == symbol_period - 16'd1);

	 assign symbol_advance = enable && sample_fire && period_done;

	 initial begin
		$display("*****************************************************");
		$display("XXXXXX SAMPLES_PER_SYMBOL_COUNTER loaded");
	 end

	 always @(posedge clk) begin
		if (!rstn) begin	
			count          <= 16'd0;
		
		end else if (!enable) begin
			count <= 16'd0;
		
		end else if (sample_fire) begin
				if (period_done) begin
					count <= 16'd0;
				end else begin
					count <= count + 16'd1;
				end
		end
	 end
endmodule
			

  
			