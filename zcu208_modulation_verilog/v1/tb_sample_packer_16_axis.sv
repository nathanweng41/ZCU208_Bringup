`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Nathan Weng
// 
// Create Date: 06/18/2026 04:22:53 PM
// Design Name: 
// Module Name: tb_sample_packer_16_axis
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


module tb_sample_packer_16_axis;
	
	// Use smaller width for simulation waveforms
	localparam int SAMPLE_WIDTH     = 16; // int16
	localparam int SAMPLES_PER_WORD = 16; // rfsoc param
	localparam int OUT_WIDTH	    = SAMPLE_WIDTH * SAMPLES_PER_WORD; // 256
	
	// ---- clocks / resets ----
	logic axis_clk	    = 1'b0;
	logic axis_aresetn  = 1'b0;
	logic enable 		= 1'b0;
	
	always #5 axis_clk = ~axis_clk;
	
	// ---- axis input ----
	logic [SAMPLE_WIDTH-1:0] s_axis_tdata;
	logic 				 s_axis_tvalid;
	wire				 s_axis_tready;
	
	logic sample_en;
	
	// ---- output symbol stream ----
	wire [OUT_WIDTH-1:0] m_axis_tdata;
	wire	   			 m_axis_tvalid;
	logic	  			 m_axis_tready;
	
	// Debug outputs
	wire [3:0] sample_count;
	wire 	   overflow;
	
    sample_packer_16_axis #(
        .SAMPLE_WIDTH(SAMPLE_WIDTH),
		.SAMPLES_PER_WORD(SAMPLES_PER_WORD),
		.OUT_WIDTH(OUT_WIDTH)
     ) dut (
		.axis_clk(axis_clk),
		.axis_aresetn(axis_aresetn),
		.enable(enable),
		.s_axis_tdata(s_axis_tdata),
		.s_axis_tvalid(s_axis_tvalid),
		.s_axis_tready(s_axis_tready),
		.sample_en(sample_en),
		.m_axis_tdata(m_axis_tdata),
		.m_axis_tvalid(m_axis_tvalid),
		.m_axis_tready(m_axis_tready),
		.sample_count(sample_count),
		.overflow(overflow)
	 );
	
	task automatic send_valid_sample(input logic [15:0] sample);
		begin
			@(negedge axis_clk);
			s_axis_tdata  = sample;
			s_axis_tvalid = 1'b1;
			sample_en = 1;
			
			@(posedge axis_clk);
			#1;
			
			$display("[%0t] sent valid sample = 0x%04h sample_count=%0d m_valid=%0b", $time, sample, sample_count, m_axis_tvalid);
		end
	endtask
	
	task automatic send_gap(input logic [15:0] sample);
		begin
			@(negedge axis_clk);
			s_axis_tdata = sample;
			s_axis_tvalid = 1'b1;
			sample_en = 0;
			
			@(posedge axis_clk);
			#1;
			
		    $display("[%0t] gap cycle sample_en=0 sample=0x%04h sample_count=%0d", $time, sample, sample_count);
			
		end
	endtask
	
	// Check packed output lanes
	task automatic check_packed_word_0_to_15();
		begin
			assert(m_axis_tvalid == 1'b1)
				else $fatal("FAIL: m_axis_tvalid should be high after 16 valid samples");
			assert(overflow == 1'b0)
				else $fatal("FAIL: overflow should be 0");
			for (int i = 0; i < 16; i++) begin
				assert(m_axis_tdata[i*16 +: 16] == i[15:0])
					else $fatal("FAIL: lane %0d got=0x%04h expected=0x%04h",i, m_axis_tdata[i*16 +: 16], i[15:0]);
				
				$display("PASS lane %0d = 0x%04h", i, m_axis_tdata[i*16 +: 16]);
			end
		end
	endtask
	
	initial begin	
		$display(" ==== TB sample_packer_16_axis START ==== ");
		
		// initial values
		s_axis_tdata   = 0;
		s_axis_tvalid  = 0;
		sample_en 	   = 0;
		m_axis_tready  = 1;
		
		// reset
		repeat (3) @(posedge axis_clk);
		
		@(negedge axis_clk);
		axis_aresetn = 1;
		enable = 1;
		
		@(posedge axis_clk);
		#1;
		
		assert(s_axis_tready == 1)
			else $fatal("FAIL: s_axis_tready should always be 1");
		
		// test 1 - invalid samples should not increment sample_count
		send_gap(16'hAAAA);
		assert(sample_count == 4'd0)
			else $fatal("FAIL: sample_count changed during sample_en=0 gap");
		
		send_gap(16'hBBBB);
		assert(sample_count == 4'd0)
			else $fatal("FAIL: sample_count changed during sample_en=0 gap");

		$display("PASS: sample_en=0 gaps ignored");
		
        // test 2 -  send 16 valid samples: 0,1,2,...,15
        for (int i = 0; i < 16; i++) begin
            send_valid_sample(i[15:0]);

            if (i < 15) begin
                assert(m_axis_tvalid == 1'b0)
                    else $fatal("FAIL: m_axis_tvalid asserted too early at i=%0d", i);
            end
        end

        // After 16th valid sample, output should be ready
        check_packed_word_0_to_15();
        
        @(negedge axis_clk);
        sample_en = 1'b0;
        s_axis_tvalid = 0;

        // test 3 - output accepted by downstream
        @(posedge axis_clk);
        #1;

        assert(m_axis_tvalid == 1'b0)
            else $fatal("FAIL: m_axis_tvalid should clear after m_axis_tready accepts word");

        assert(sample_count == 4'd0)
            else $fatal("FAIL: sample_count should reset after packed word");

        $display("PASS: output accepted and valid cleared");

        $display("==== TB sample_packer_16_axis PASS ====");
        $finish;	
	end
	
	
endmodule