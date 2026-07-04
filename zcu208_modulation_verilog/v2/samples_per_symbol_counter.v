`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//  
// Nathan Weng 07/2026
// Revised version from v1/samples_per_symbol_counter.v, no more fractional sample_en
// symbol_period = samples per QPSK symbol
// Examples:
//  symbol_period = 1 -> 160 MSym/s
//  symbol_period = 8 -> 20 MSym/s
// 
//////////////////////////////////////////////////////////////////////////////////


module samples_per_symbol_counter #() (        

	 input wire clk, 
	 
	 input wire rstn,
	 
	 input wire enable,
	 
	 // Number of valid samples per symbol
	 input wire [15:0] symbol_period,
	 
	 // Current count
	 output reg [15:0] count,
	 
	 // Pulse symbol_advance at that edge when current symbol is finished
	 output reg symbol_advance
   );
   
	 initial begin
		$display("*****************************************************");
		$display("XXXXXX SAMPLES_PER_SYMBOL_COUNTER loaded");
	 end
	 
	 always @(posedge clk) begin
		if (!rstn) begin	
			count          <= 16'd0;
			symbol_advance <= 1'b0;
		end else begin
			// Clear symbol_advance at the start of every clk
			symbol_advance <= 1'b0;
			
			if (!enable) begin
				count          <= 16'd0;
				symbol_advance <= 1'b0;
            end else begin
                // min symbol_period = 1, which means symbol_advance is always high
				if (symbol_period <= 16'd1) begin
					count          <= 16'd0;
					symbol_advance <= 1'b1;
				end else if (count == symbol_period - 16'd1) begin
					count          <= 16'd0;
					symbol_advance <= 1'b1;
				end else begin
					count <= count + 16'd1;
				end
			end
		end
	end
end
	
endmodule
			

  
			