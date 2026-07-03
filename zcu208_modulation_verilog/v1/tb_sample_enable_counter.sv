`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Nathan Weng
// 
// Create Date: 06/17/2026 11:46:59 PM
// Design Name: 
// Module Name: tb_sample_enable_counter
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Behavioral simulation of sample_enable_counter.v
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_sample_enable_counter(
    );
    
    localparam int PERIOD = 5;
    
    // ---- clocks / resets ----
    logic clk = 0;
    logic rstn = 0;
    logic enable = 0;
    
    wire [2:0] count;
    wire sample_en;
    
    always #5 clk = ~clk;

    design_2_wrapper #(.PERIOD(5)) dut(
        .clk_0(clk),
        .rstn_0(rstn),
        .enable_0(enable),
        .count_0(count),
        .sample_en_0(sample_en)
     );
     
     int cyc;
     logic expected_sample_en;
     
     initial begin
        $display("==== TB sample_enable_counter START =====");
        
        repeat (2) @(posedge clk);
        
        @(negedge clk);
        rstn   <= 1;
        enable <= 1;
        
        cyc = 0;
        
        repeat (30) begin
            @(posedge clk);
            #1;
            
            expected_sample_en = enable && (count != PERIOD-1);

            assert(sample_en == expected_sample_en)
                else $fatal("FAIL: cycle=%0d count=%d expected sample_en=0 got=%0b", cyc, count, expected_sample_en, sample_en);
                
            $display("cycle=%0d count=%0d sample_en=%0b PASS", cyc, count, sample_en);
            cyc++;
        end
      
        $display("==== TB sample_enable_counter PASS ====");
        $finish;
    end
endmodule
 