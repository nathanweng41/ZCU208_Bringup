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
// Dependencies: AXI VIP API
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
    logic axis_0_tready = 1; // assert tready when declared so master can stream out
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
    
    // Declare bin file params
    localparam int MEM_BYTES      = 131072;
    localparam int BYTES_PER_WORD = 64; // 512 bits
    localparam int NUM_WORDS      = MEM_BYTES / BYTES_PER_WORD; // 2048 words
    
    // Total bytes
    byte unsigned bram_image [0:MEM_BYTES-1];
    
    // File I/O for BRAM Image
    integer fd;
    integer nread;
    string bin_path;
    
    // Loading word in main stimulus
    logic [511:0] word;
    int idx;
    
    // Readback for GPIO dbg
    logic [31:0] rd;
    
    // Readback for ptr dbg
    logic [511:0] start_stream_word;
    logic [511:0] stop_stream_word;
    int beat_count;
    bit capture_done;
    bit uram_en;
    
    localparam int LOOP_STOP_ADDR = 32'h00000C00;
    localparam int LOOP_STOP_WORD = LOOP_STOP_ADDR / BYTES_PER_WORD;
    
    // Import AXI VIP Master Packages
    import axi_vip_pkg::*;
    import design_1_axi_vip_0_1_pkg::*; // AXI4
    import design_1_axi_vip_1_0_pkg::*; // AXI-LITE for GPIOs
    
    // Declare <component_name>_mst_t agent
    design_1_axi_vip_0_1_mst_t      axi4_mst_agent;
    design_1_axi_vip_1_0_mst_t      axilite_mst_agent;
    
    //generate transaction
    task automatic axi_write_512(input logic [31:0] addr, input logic [511:0] data);
        axi_transaction wr;
        wr = axi4_mst_agent.wr_driver.create_transaction("512_write");
        
        // ID is not used; can be set to 0
        // Len = 0 means 1 burst (AXI Burst length - 1). We aren't doing AXI Burst here. 
        // Size = log2(bytes_per_transfer). 64 bytes per transfer, so log2(64) = 6
        wr.set_write_cmd(addr,XIL_AXI_BURST_TYPE_INCR,0,0,6);
       
        wr.set_data_block(data);

        axi4_mst_agent.wr_driver.send(wr);

        //Don't wait for resp here, there are some timing issues with send. Just check wr.bresp.
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
        $display("[%0t] AXIL WRITE   addr=0x%08x data=0x%08x resp=%0d", $time, addr, data, resp);
        if ( resp != XIL_AXI_RESP_OKAY ) 
            $display("AXI-Lite WRITE error resp=%0d @%0t", resp, $time);
    endtask
    
    task automatic axi_gpio_read(input logic [31:0] addr, output logic [31:0] data);
        xil_axi_resp_t resp;
        axilite_mst_agent.AXI4LITE_READ_BURST(addr, 0, data, resp);
        $display("[%0t] AXIL READ    addr=0x%08x data=0x%08x resp=%0d", $time, addr, data, resp);
        if ( resp != XIL_AXI_RESP_OKAY ) 
            $display("AXI-Lite READ error resp=%0d @%0t", resp, $time);
        
    endtask
    
    // Prepare AXIS monitor to validate ptr behavior 
    always @(posedge PL_CLK_clk_p[0]) begin
        if(!capture_done && axis_0_tvalid && axis_0_tready && uram_en) begin
            // First word after URAM enable
            if (beat_count == 0) begin
                start_stream_word <= axis_0_tdata;
                $display("[%0t] STREAM START word (beat %0d) = %h", $time, beat_count, axis_0_tdata);
            end
            
            // Word corresponding to stop_ptr
            if (beat_count == LOOP_STOP_WORD) begin
                stop_stream_word <= axis_0_tdata;
                $display("[%0t] STREAM STOP word (beat %0d) = %h", $time, beat_count, axis_0_tdata);
            end
            
            beat_count <= beat_count+1;
            
            if (beat_count == LOOP_STOP_WORD+1) begin
                capture_done <= 1;
                stop_stream_word <= axis_0_tdata;
                $display("[%0t] STREAM STOP+1 word (beat %0d) = %h", $time, beat_count, axis_0_tdata);
            end
        end
    end
    
    // Main Stimulus
    initial begin
    
        // Vars for AXIS monitor
        beat_count = 0;
        capture_done = 0;
        start_stream_word = '0;
        stop_stream_word = '0;
        uram_en = 0;
    
        $display("[%0t] TB entering main stimulus", $time);
        
        //Give clocks time to settle
        #200;
        
        $display("[%0t] After 200 ns, starting masters", $time);
        
        // Declare new agent
        axi4_mst_agent = new("master vip agent (AXI FULL)", dut.design_1_i.axi_vip_0.inst.IF);
        axilite_mst_agent = new("master vip agent (AXILITE)", dut.design_1_i.axi_vip_1.inst.IF);
   
        // Start_master
        axi4_mst_agent.start_master();   
        axilite_mst_agent.start_master();
        
        // Load BRAM image from MATLAB generated bin file. Flatten bin file into array. 
        
        bin_path = "dac_output_bramptr.bin";
        
        fd = $fopen(bin_path, "rb");
        if (fd == 0) begin
            $fatal(1, "Failed to open bin file '%s'", bin_path);
        end
        
        nread = $fread(bram_image, fd);
        $display("Read %0d bytes from %s", nread, bin_path);
        $fclose(fd);
        
        // Program GPIOs to start at 0
        axi_gpio_write(GPIO_DAC_BASE + GPIO_DATA, 32'h0000_0000);
        axi_gpio_read(GPIO_DAC_BASE + GPIO_DATA, rd);
        axi_gpio_write(GPIO_START_BASE + GPIO_DATA, 32'h0000_0000);
        axi_gpio_read(GPIO_START_BASE + GPIO_DATA, rd);
        axi_gpio_write(GPIO_STOP_BASE + GPIO_DATA, 32'h0000_0000);
        axi_gpio_read(GPIO_STOP_BASE + GPIO_DATA, rd);
        
        // Set start/stop ptrs
        axi_gpio_write(GPIO_START_BASE + GPIO_DATA, 32'd0); // Start ptr
        $display("Start PTR Read:");
        axi_gpio_read(GPIO_START_BASE + GPIO_DATA, rd);
        
        axi_gpio_write(GPIO_STOP_BASE + GPIO_DATA, 32'h0000_0C00); // Stop ptr
        $display("Stop PTR Read:");
        axi_gpio_read(GPIO_STOP_BASE + GPIO_DATA, rd);
        
        $display("[%0t] Before BRAM write", $time);
        // Load BRAM 
        // Loop over 2048 words (131,072 bytes)
        for (int w = 0; w < NUM_WORDS; w++) begin
            word = '0;
           
            for (int b = 0; b < BYTES_PER_WORD; b++) begin // 64 bytes per word
                idx = w*BYTES_PER_WORD + b;
                word[8*b +: 8] = bram_image[idx];
            end
            
            //w*BYTES_PER_WORD is increment of 64
            axi_write_512(BRAM_BASE + w*BYTES_PER_WORD, word);
        end
        $display("[%0t] After BRAM write", $time);
        
        // Enable Uram
        axi_gpio_write(GPIO_DAC_BASE + GPIO_DATA, 32'h0000_0001);
        axi_gpio_read(GPIO_DAC_BASE + GPIO_DATA, rd);
    
        // Wait and observe AXIS
        #2000
        
        $display("axis_0_tvalid=%0d axis_0_tdata[31:0]=0x%08x",
                  axis_0_tvalid, axis_0_tdata[31:0]);
    end
    
endmodule
