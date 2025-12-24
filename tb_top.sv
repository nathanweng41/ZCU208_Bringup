`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Nathan Weng
// 
// Create Date: 12/23/2025 03:46:04 PM
// Design Name: 
// Module Name: tb_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Use for behavioral simulation of pointer 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_top(
    );
    // ---- clocks / resets ----
    logic PL_CLK_clk_p = 0;
    logic PL_CLK_clk_n = 1; 
    
    always #5 begin
        PL_CLK_clk_p <= ~PL_CLK_clk_p;
        PL_CLK_clk_n <= ~PL_CLK_clk_n;
    end
    
    // ---- AXIS ----
    logic axis_0_tready; 
    wire [511:0] axis_0_tdata;
    wire axis_0_tvalid;
    
    // Need to assert tready so master can stream out
    initial begin
        axis_0_tready = 1'b1;
    end
    
    design_1_wrapper dut(
        .PL_CLK_clk_n(PL_CLK_clk_n),
        .PL_CLK_clk_p(PL_CLK_clk_p),
        .axis_0_tdata(axis_0_tdata),
        .axis_0_tready(axis_0_tready),
        .axis_0_tvalid(axis_0_tvalid)
    );
    
    always @(posedge PL_CLK_clk_p) begin
        if (axis_0_tvalid && axis_0_tready) begin
            $display("[%0t] AXIS beat: %h", $time, axis_0_tdata);
           end
    end
    
    initial begin 
        repeat (50) @(posedge PL_CLK_clk_p);
        $display("TB alive.");
        repeat (2000) @(posedge PL_CLK_clk_p);
        $finish;
    end
endmodule
