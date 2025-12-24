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
    
    real freq = 612.5e6;
    real half_period = 1.0 / freq / 2.0; // Seconds
    
    initial begin
        forever begin
            #(half_period * 1e9);
            PL_CLK_clk_p <= ~PL_CLK_clk_p;
            PL_CLK_clk_n <= ~PL_CLK_clk_n;
        end
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
    
    // Declare Address Map
    localparam logic [31:0] BRAM_BASE       = 32'hC000_0000;
    localparam logic [31:0] GPIO_DAC_BASE   = 32'h4000_0000;
    localparam logic [31:0] GPIO_START_BASE = 32'h4001_0000;
    localparam logic [31:0] GPIO_STOP_BASE  = 32'h4002_0000;
    
    // Import AXI VIP Master Packages
    import axi_vip_pkg::*;
    import design_1_axi_vip_0_1_pkg::*;
    
    // declare <component_name>_mst_t agent
    design_1_axi_vip_0_1_pkg_mst_t      mst_agent;
    
    // declare new agent
    mst_agent = new("master vip agent", dut.design_1_i.axi_vip_0.inst.IF);
   
    //start_master
    mst_agent.start_master();
    
    //generate transaction
    task automatic axi_write_512(input logic [31:0] addr, input logic [511:0] data);
        axi_transaction wr;
        wr = mst_agent.wr_driver.create_transaction("512_write");
        // Len = 0 means 1 burst (AXI Burst length - 1). We aren't doing AXI Burst here. 
        // Size = log2(bytes_per_transfer). 64 bytes per transfer, so log2(64) = 6
        wr.set_write_cmd(addr,XIL_AXI_BURST_TYPE_INCR,0,6);
        // Byte mask
        wr.set_strb({64{1'b1}});
        // Set single data beat
        wr.set_data_block(data);
        mst_agent.wr_driver.send(wr);
        mst_agent.wr_driver.wait_rsp(wr);
        
        // Check response
        if (wr.bresp == 2'b00) begin
            $display("Write OK");
        end else begin
            $display("Write failed: %b", wr.bresp);
        end
    endtask
    
    initial begin
        //Give clocks time to settle
        #200;
    end
    
    
    always @(posedge PL_CLK_clk_p) begin
        if (axis_0_tready) begin
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
