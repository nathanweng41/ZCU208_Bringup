`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//  
// Nathan Weng 06/2026
// 
//////////////////////////////////////////////////////////////////////////////////


module samples_per_symbol_counter #() (        

	 input wire clk, 
	 
	 input wire rstn,
	 
	 input wire enable,
	 
	 // High only when a valid baseband sample is produced
	 input wire sample_en,
	 
	 input wire valid_en,
	 
	 // Number of valid samples per symbol
	 input wire [15:0] symbol_period,
	 
	 // Current count
	 output reg [15:0] count,
	 
	 // Pulse symbol_advance at that edge when current symbol is finished
	 output reg symbol_advance
   );
   
	 initial begin
		$display("*****************************************************");
		$display("XXXXXX COUNTER_SYMBOL_PERIOD                      = %d", symbol_period);
	 end
	 
	 always @(posedge clk) begin
		if (!rstn) begin	
			count <= {16{1'b0}};
			symbol_advance <= 1'b0;
		end else begin
			// Clear symbol_advance at the start of every clk
			symbol_advance <= 1'b0;
			
			if (!enable) begin
				count <= {16{1'b0}};
				symbol_advance <= 1'b0;
			end else begin	
				// Only count valid samples
				if (sample_en && valid_en) begin
					if (symbol_period <= 1) begin
						count <= {16{1'b0}};
						symbol_advance <= 1'b1;
					end else if (count == symbol_period - 16'd1) begin
						count <= {16{1'b0}};
						symbol_advance <= 1'b1;
					end else begin
						count <= count + 1'b1;
					end
				end
			end
		end
	 end
	
endmodule
			

  
			