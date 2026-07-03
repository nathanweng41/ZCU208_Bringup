`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Nathan Weng
// 
// Create Date: 06/18/2026 11:29:53 AM
// Design Name: 
// Module Name: tb_samples_per_symbol_counter
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_samples_per_symbol_counter;
	// ---- clocks / resets ----
	logic clk	 = 1'b0;
	logic rstn   = 1'b0;
	logic enable = 1'b0;
	
	always #5 clk = ~clk;
	
	// ---- DUT inputs ----
	logic sample_en;
	logic [15:0] symbol_period;
	
	// ---- DUT outputs ----
	wire [15:0] count;
	wire symbol_advance;
	
    design_3_wrapper dut(
        .clk_0(clk),
        .rstn_0(rstn),
        .enable_0(enable),
        .count_0(count),
        .sample_en_0(sample_en),
		.symbol_period_0(symbol_period),
		.symbol_advance_0(symbol_advance)
     );
	 
	int clk_cyc;
	int valid_sample_count;
	logic expected_symbol_advance;
	
	initial begin
		$display(" ===== TB samples_per_symbol_counter START ===== ");
		
		// Initial values
		sample_en 			= 1'b0;
		symbol_period		= 16'd4;
		clk_cyc 			= 0;
		valid_sample_count  = 0;
		
		repeat (3) @(posedge clk);
		
		// Release reset and start enable
		@(negedge clk);
		rstn 	= 1'b1;
		enable  = 1'b1;
		
		// Main test: 1, 1, 1, 1, 0 repeating, symbol_period=4
		repeat (40) begin
			
			@(negedge clk);
			sample_en = ((clk_cyc % 5) != 4);
			
			@(posedge clk);
			#1;
			
			expected_symbol_advance = 1'b0;
			
			if (sample_en) begin
				if (valid_sample_count == symbol_period - 1) begin
					expected_symbol_advance = 1'b1;
					valid_sample_count = 0;
				end else begin
					expected_symbol_advance = 1'b0;
					valid_sample_count++;
				end
			end else begin
				expected_symbol_advance = 1'b0;
			end
			
			assert(symbol_advance == expected_symbol_advance)
				else $fatal("FAIL cycle=%0d sample_en=%0b count=%0d expected symbol_advance=%0b got=%0b", clk_cyc, sample_en, count, expected_symbol_advance, symbol_advance);
			$display("cycle=%0d sample_en=%0b count=%0d symbol_advance=%0b PASS", clk_cyc, sample_en, count, symbol_advance);
			
			clk_cyc++;
		end

		$display(" ==== TB samples_per_symbol_counter PASS ====");
		$finish;
		
	end	
	
endmodule
