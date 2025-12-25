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
    logic [0:0] PL_CLK_clk_p = 1'b0;
    logic [0:0] PL_CLK_clk_n = 1'b1; 
    
    time half_period_t = 816ps; // ~612.5 MHz diff clock
    
    always begin
            #(half_period_t);
            PL_CLK_clk_p[0] = ~PL_CLK_clk_p[0];
            PL_CLK_clk_n[0] = ~PL_CLK_clk_n[0];
    end
    
    // ---- AXIS ----
    logic axis_0_tready = 1'b1; // assert tready when declared so master can stream out
    wire [511:0] axis_0_tdata;
    wire axis_0_tvalid;
    
    design_1_wrapper dut(
        .PL_CLK_clk_n(PL_CLK_clk_n),
        .PL_CLK_clk_p(PL_CLK_clk_p),
        .axis_0_tdata(axis_0_tdata),
        .axis_0_tready(axis_0_tready),
        .axis_0_tvalid(axis_0_tvalid)
    );
    
    // Declare address map
    localparam logic [31:0] BRAM_BASE       = 32'hC000_0000;
    localparam logic [31:0] GPIO_DAC_BASE   = 32'h4000_0000;
    localparam logic [31:0] GPIO_START_BASE = 32'h4001_0000;
    localparam logic [31:0] GPIO_STOP_BASE  = 32'h4002_0000;
    
    // For GPIO channel 1
    localparam logic [31:0] GPIO_DATA = 32'h0;
    localparam logic [31:0] GPIO_TRI  = 32'h4;
    
    // Import AXI VIP Master Packages
    import axi_vip_pkg::*;
    import design_1_axi_vip_0_1_pkg::*; // AXI4
    import design_1_axi_vip_1_0_pkg::*; // AXI-LITE for GPIOs
    
    // declare <component_name>_mst_t agent
    design_1_axi_vip_0_1_mst_t      axi4_mst_agent;
    design_1_axi_vip_1_0_mst_t      axilite_mst_agent;
    
    //generate transaction
    task automatic axi_write_512(input logic [31:0] addr, input logic [511:0] data);
        axi_transaction wr;
        wr = axi4_mst_agent.wr_driver.create_transaction("512_write");
        // Len = 0 means 1 burst (AXI Burst length - 1). We aren't doing AXI Burst here. 
        // Size = log2(bytes_per_transfer). 64 bytes per transfer, so log2(64) = 6
        wr.set_write_cmd(addr,XIL_AXI_BURST_TYPE_INCR,0,6);
        // Set Beat 0 data
        wr.set_data_beat(0, data);
        // Set Beat 0 strobe
        wr.set_strb_beat(0, {64{1'b1}});
        // Set single data beat
        //wr.set_data_block(data);
        axi4_mst_agent.wr_driver.send(wr);
        axi4_mst_agent.wr_driver.wait_rsp(wr);
        
        // Check response
        if (wr.bresp == 2'b00) begin
            $display("Write OK");
        end else begin
            $display("Write failed: %b", wr.bresp);
        end
    endtask
    
    task automatic axi_gpio_write(input logic [31:0] addr, input logic [31:0] data);
        xil_axi_resp_t resp;
        axilite_mst_agent.AXI4LITE_WRITE_BURST(addr, 0, data, resp);
        if ( resp != XIL_AXI_RESP_OKAY ) 
            $display("AXI-Lite WRITE error resp=%0d @%0t", resp, $time);
    endtask
    
    task automatic axi_gpio_read(input logic [31:0] addr, output logic [31:0] data);
        xil_axi_resp_t resp;
        axilite_mst_agent.AXI4LITE_READ_BURST(addr, 0, data, resp);
        if ( resp != XIL_AXI_RESP_OKAY ) 
            $display("AXI-Lite READ error resp=%0d @%0t", resp, $time);
        
    endtask
    
    // Main Stimulus
    initial begin
    
        $display("[%0t] TB entering main stimulus", $time);
        
        //Give clocks time to settle
        #200;
        
        // declare new agent
        axi4_mst_agent = new("master vip agent (AXI FULL)", dut.design_1_i.axi_vip_0.inst.IF);
        axilite_mst_agent = new("master vip agent (AXILITE)", dut.design_1_i.axi_vip_1.inst.IF);
   
        //start_master
        axi4_mst_agent.start_master();   
        axilite_mst_agent.start_master();
       
        // Program TRIs to output 1
        axi_gpio_write(GPIO_DAC_BASE + GPIO_TRI, 32'h0000_0000);
        axi_gpio_write(GPIO_START_BASE + GPIO_TRI, 32'h0000_0000);
        axi_gpio_write(GPIO_STOP_BASE + GPIO_TRI, 32'h0000_0000);
        
        // Program GPIOs to start at 0
        axi_gpio_write(GPIO_DAC_BASE + GPIO_DATA, 32'h0000_0000);
        axi_gpio_write(GPIO_START_BASE + GPIO_DATA, 32'h0000_0000);
        axi_gpio_write(GPIO_STOP_BASE + GPIO_DATA, 32'h0000_0000);
        
        // Load BRAM (2 words)
        axi_write_512(BRAM_BASE, 512'h0001_0002_0003_0004_0005_0006_0007_0008_0009_000A_000B_000C_000D_000E_000F_0010_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000);
        axi_write_512(BRAM_BASE + 32'h0000_0040, 512'h1111_2222_3333_4444_5555_6666_7777_8888_9999_AAAA_BBBB_CCCC_DDDD_EEEE_FFFF_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000);
        
        // Set start/stop ptrs
        axi_gpio_write(GPIO_START_BASE + GPIO_DATA, 32'd0); // Start ptr
        axi_gpio_write(GPIO_STOP_BASE + GPIO_DATA, 32'h0000_0C00); // Stop ptr
        
        // Enable Uram
        axi_gpio_write(GPIO_DAC_BASE + GPIO_DATA, 32'h0000_0001);
    
        // Wait and observe AXIS
        #2000
        
        $display("axis_0_tvalid=%0d axis_0_tdata[31:0]=0x%08x",
                  axis_0_tvalid, axis_0_tdata[31:0]);
    
        $finish;
    end
endmodule
