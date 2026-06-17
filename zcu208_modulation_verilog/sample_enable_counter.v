`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//  
// Nathan Weng 06/2026
// 
//////////////////////////////////////////////////////////////////////////////////


module sample_enable_counter #(
	 parameter integer PERIOD = 5
) (        

	 input wire clk, 
	 
	 input wire rstn,
	 
	 input wire enable,
	 
	 // Debug for simulation
	 output reg [$clog2(PERIOD)-1:0] count,
	 
	 // High only when a valid baseband sample is produced
	 output reg sample_en
   );
   
	 initial begin
		$display("*****************************************************");
		$display("XXXXXX COUNTER_PERIOD                      = %d", PERIOD);
	 end
	 
	 always @(posedge clk) begin
		if (!rstn) begin	
			count <= 0;
			sample_en <= 1'b0;
		end else begin
			if (!enable) begin
				count <= 0;
				sample_en <= 1'b0;
			end else begin
				// sample_en will be 0 on the last count and then we reset
				if (count == PERIOD-1) begin
					sample_en <= 1'b0;
					count <= 0;
				end else begin
					sample_en <= 1'b1;
					count <= count + 1'b1;
				end
			end
		end
	 end
	
endmodule
			

  
			