`timescale 1ns / 1ps

module tb_full_modulation_path;

	logic [0:0] PL_CLK_clk_p = 1'b0;
	logic [0:0] PL_CLK_clk_n = 1'b1;

	always begin
		#(816.326ps);
		PL_CLK_clk_p[0] = ~PL_CLK_clk_p[0];
		PL_CLK_clk_n[0] = ~PL_CLK_clk_n[0];
	end
	
	// Exported output from sample_packer_16_axis
	wire [255:0] m_axis_0_tdata;
	wire 		 m_axis_0_tvalid;
	// Will add FIFO here so it doesn't really matter
	logic m_axis_0_tready = 1'b1;
	
	full_baseband_sim_wrapper dut (
		.PL_CLK_clk_n(PL_CLK_clk_n),
		.PL_CLK_clk_p(PL_CLK_clk_p),
		
		.m_axis_0_tdata(m_axis_0_tdata),
		.m_axis_0_tvalid(m_axis_0_tvalid),
		.m_axis_0_tready(m_axis_0_tready)
	);
	
	// Internal monitor signals
	wire axis_clk;
	assign axis_clk = dut.full_baseband_sim_i.sample_packer_16_axis_0.axis_clk;
	
	wire sample_en;
	assign sample_en = dut.full_baseband_sim_i.sample_enable_counter_0.sample_en;
	
	wire symbol_advance; 
	assign symbol_advance = dut.full_baseband_sim_i.samples_per_symbol_c_0.symbol_advance;
	
	wire [7:0] unpacker_symbol;
	assign unpacker_symbol = dut.full_baseband_sim_i.symbol_unpacker_axis_0.m_axis_tdata;
	
	wire unpacker_valid;
	assign unpacker_valid = dut.full_baseband_sim_i.symbol_unpacker_axis_0.m_axis_tvalid;
	
	wire [8:0] symbol_idx;
	assign symbol_idx = dut.full_baseband_sim_i.symbol_unpacker_axis_0.symbol_idx;
	
	wire signed [15:0] mapped_sample;
	assign mapped_sample = dut.full_baseband_sim_i.bpsk_mapper_axis_0.m_axis_tdata;
	
	wire [3:0] packer_sample_count;
	assign packer_sample_count = dut.full_baseband_sim_i.sample_packer_16_axis_0.sample_count;
	
	wire packer_overflow;
	assign packer_overflow = dut.full_baseband_sim_i.sample_packer_16_axis_0.overflow;
	
	wire word_loaded;
	assign word_loaded = dut.full_baseband_sim_i.symbol_unpacker_axis_0.word_loaded;
	
	wire uram_play_tvalid;
	assign uram_play_tvalid = dut.full_baseband_sim_i.uram_play_modulation_0.axis_tvalid;
	
    wire uram_play_tready;
	assign uram_play_tready = dut.full_baseband_sim_i.uram_play_modulation_0.axis_tready;
	
	
	
	localparam logic [31:0] BRAM_BASE		 = 32'hC000_0000;
	localparam logic [31:0] GPIO_START_BASE  = 32'h4000_0000;
	localparam logic [31:0] GPIO_STOP_BASE   = 32'h4001_0000;
	localparam logic [31:0] GPIO_PERIOD_BASE = 32'h4002_0000;
	localparam logic [31:0] GPIO_ENABLE_BASE = 32'h4003_0000;
	
	localparam logic [31:0] GPIO_DATA = 32'h0;
	
	localparam int BYTES_PER_WORD = 64;
	localparam int TEST_WORDS	  = 8;
	localparam int STOP_ADDR	  = (TEST_WORDS-1) * BYTES_PER_WORD;
	
	localparam int SYMBOL_PERIOD = 244;
	
	localparam signed [15:0] AMP_POS = 16'sd16000;
	localparam signed [15:0] AMP_NEG = -16'sd16000;
	
	import axi_vip_pkg::*;
	import full_baseband_sim_axi_vip_0_0_pkg::*;
	import full_baseband_sim_axi_vip_1_0_pkg::*;
	
	full_baseband_sim_axi_vip_0_0_mst_t axi4_mst_agent;
	full_baseband_sim_axi_vip_1_0_mst_t axilite_mst_agent;

	// AXI helper tasks from previous testbench
	task automatic axi_write_512(input logic [31:0] addr, input logic [511:0] data);
        axi_transaction wr;
        begin
            wr = axi4_mst_agent.wr_driver.create_transaction("512_write");

            // one 64-byte beat
            wr.set_write_cmd(addr, XIL_AXI_BURST_TYPE_INCR, 0, 0, 6);
            wr.set_data_block(data);
			
            axi4_mst_agent.wr_driver.send(wr);

            if (wr.bresp != 2'b00) begin
                $fatal("AXI FULL WRITE failed addr=0x%08x bresp=%0b", addr, wr.bresp);
            end
        end
    endtask
	
    task automatic axi_gpio_write(input logic [31:0] addr, input logic [31:0] data);
        xil_axi_resp_t resp;
        begin
            axilite_mst_agent.AXI4LITE_WRITE_BURST(addr, 0, data, resp);

            $display("[%0t] AXIL WRITE addr=0x%08x data=0x%08x resp=%0d", $time, addr, data, resp);

            if (resp != XIL_AXI_RESP_OKAY) begin
                $fatal("AXI-Lite WRITE failed addr=0x%08x resp=%0d", addr, resp);
            end
        end
    endtask

    task automatic axi_gpio_read(input logic [31:0] addr, output logic [31:0] data);
        xil_axi_resp_t resp;
        begin
            axilite_mst_agent.AXI4LITE_READ_BURST(addr, 0, data, resp);

            $display("[%0t] AXIL READ  addr=0x%08x data=0x%08x resp=%0d", $time, addr, data, resp);

            if (resp != XIL_AXI_RESP_OKAY) begin
                $fatal("AXI-Lite READ failed addr=0x%08x resp=%0d", addr, resp);
            end
        end
    endtask	
	
	// Packed BPSK test data
	// word=010101... from bit 0 upward
	
	function automatic logic [511:0] make_bpsk_word(input bit invert);
		logic [511:0] w;
		begin
			for (int i = 0; i < 512; i++) begin
				if (!invert)
					w[i] = (i%2); //bit sequence 0, 1, 0, 1,...
				else
					w[i] = ~(i%2); //bit sequence 1, 0, 1, 0,...
			end
			return w;
		end
	endfunction
	
	// Physical monitor variables
	int sample_en_count;
	int symbol_advance_count;
	int packer_word_count;
	
	time last_symbol_advance_time;
	time last_packer_word_time;
	time last_axis_clk_time;
	
	time dt_symbol;
	time dt_packer;
	time axis_clk_period;
	
	bit got_first_symbol_advance;
	bit got_first_packer_word;
	bit got_first_axis_clk;
	
	/* CLK DEBUG, seems okay so far so commenting it out
	
	always @(posedge axis_clk) begin
		if (!got_first_axis_clk) begin
			got_first_axis_clk = 1'b1;
			last_axis_clk_time = $time;
		end else begin
			axis_clk_period = $time - last_axis_clk_time;
			last_axis_clk_time = $time;
			
			if (packer_word_count < 3) begin
				$display("[%0t] axis_clk period = %0t", $time, axis_clk_period);
			end
		end
	end

	*/
	
	// Count sample_en
	always @(posedge axis_clk) begin
		if (sample_en) begin
			sample_en_count++;
		end
	end
	
	// Symbol rate monitor
	always @(posedge axis_clk) begin
		if (symbol_advance) begin
			symbol_advance_count++;
		
			if (!got_first_symbol_advance) begin
				got_first_symbol_advance = 1'b1;
				last_symbol_advance_time = $time;
				$display("[%0t] first symbol advance", $time);
			end else begin
				dt_symbol = $time - last_symbol_advance_time;
				last_symbol_advance_time = $time;
				
				$display("[%0t] symbol_advance #%0d dt=%0t symbol_idx=%0d symbol=%0h", $time, symbol_advance_count, dt_symbol, symbol_idx, unpacker_symbol);
				
				if ((dt_symbol < 950ns) || (dt_symbol > 1050ns)) begin
					// 1MSPS
					$fatal("Symbol period wrong: dt=%0t expected about 1000ns", dt_symbol);
				end
			end
		end
	end
	
	// Packer output monitor
	always @(posedge axis_clk) begin
		if (m_axis_0_tvalid && m_axis_0_tready) begin
			packer_word_count++;
			
			if (!got_first_packer_word) begin
				got_first_packer_word = 1'b1;
				last_packer_word_time = $time;
				
				$display("[%0t] first packer word", $time);
			end else begin
				dt_packer = $time - last_packer_word_time;
				last_packer_word_time = $time;
				
				$display("[%0t] packer word #%0d dt=%0t", $time, packer_word_count, dt_packer);
				
	
				// 16 valid samples * 5 clocks / 4 valid samples = 20 fabric clocks
				// One packed word every 20 fabric clocks, should be around 3.265 ns
				// 20 / 306.25 MHz ~ 65.306ns
				if ((dt_packer < 60ns) || (dt_packer > 70ns)) begin
					$fatal("Packer output word period wrong: dt=%0t expected about 65 ns", dt_packer);
				end
			end
			
			// Do all lanes have valid BPSK amplitudes? 
			for (int lane = 0; lane < 16; lane++) begin
				automatic logic signed [15:0] samp;
				samp = m_axis_0_tdata[lane*16 +: 16];
				
				if(!((samp == AMP_POS) || (samp == AMP_NEG))) begin	
					$fatal("Invalid BPSK sample word=%0d lane=%0d value=%0d hex=%04h", packer_word_count, lane, samp, m_axis_0_tdata[lane*16 +: 16]);
				end
			end
			
			if (packer_word_count <= 8) begin
				$write("	lanes:");
				for (int lane = 0; lane < 16; lane++) begin
					automatic logic signed [15:0] samp;
					samp = m_axis_0_tdata[lane*16 +: 16];
					$write(" %0d", samp);
				end
				$write("\n");
			end
		end			
	end
	
	// Overflow should never be asserted
	always @(posedge axis_clk) begin
		if (packer_overflow) begin
			$fatal("[%0t] sample_packer_overflow asserted", $time);
		end
	end
	
	// Main stimulus
	logic [511:0] word;
	// Not really used, just filler for return
	logic [31:0] rd;
	
	initial begin
		$display("[%0t] TB full modulation path START", $time);
		
		sample_en_count				= 0;
		symbol_advance_count		= 0;
		packer_word_count			= 0;
		got_first_symbol_advance	= 0;
		got_first_packer_word		= 0;
		last_symbol_advance_time	= 0;
		last_packer_word_time		= 0;
		
		#200ns;
		
		// Start VIP agents
		axi4_mst_agent    = new("AXI FULL master", dut.full_baseband_sim_i.axi_vip_0.inst.IF);
        axilite_mst_agent = new("AXI-LITE master", dut.full_baseband_sim_i.axi_vip_1.inst.IF);
		
		axi4_mst_agent.start_master();
		axilite_mst_agent.start_master();
		
		// Program pointers and symbol period.
		// Disable stream while loading data
		axi_gpio_write(GPIO_ENABLE_BASE, 32'd0);
		
		// Make sure uram_play_modulation sees 0
		repeat (1) @(posedge axis_clk);
		
		axi_gpio_write(GPIO_START_BASE, 32'd0);
		axi_gpio_write(GPIO_STOP_BASE, STOP_ADDR);
		axi_gpio_write(GPIO_PERIOD_BASE, SYMBOL_PERIOD);
		
		axi_gpio_read(GPIO_START_BASE,  rd);
		axi_gpio_read(GPIO_STOP_BASE,   rd);
		axi_gpio_read(GPIO_PERIOD_BASE, rd);
		axi_gpio_read(GPIO_ENABLE_BASE, rd);
		
		$display("[%0t] Writing BRAM test pattern", $time);
		
		for (int w = 0; w < TEST_WORDS; w++) begin
			word = make_bpsk_word(w[0]);
			axi_write_512(BRAM_BASE + w*BYTES_PER_WORD, word);
			
			$display("[%0t] Wrote BRAM word %0d addr=0x%08x word[31:0]=0x%08x", $time, w, BRAM_BASE + w*BYTES_PER_WORD, word[31:0]);
		end
		
		// Start stream after BRAM programming is complete
		
		$display("[%0t] Enabling stream", $time);
		
		#1ns;
		
		axi_gpio_write(GPIO_ENABLE_BASE, 32'd1);
		axi_gpio_read(GPIO_ENABLE_BASE, rd);
		
		#40us;
		
		$display("--------------------------------------------------");
        $display("RESULTS");
        $display("sample_en_count       = %0d", sample_en_count);
        $display("symbol_advance_count  = %0d", symbol_advance_count);
        $display("packer_word_count     = %0d", packer_word_count);
        $display("packer_overflow       = %0b", packer_overflow);
        $display("--------------------------------------------------");

        // Expected rough counts over 20 us:
        // sample_en_count ~ 245e6 * 20e-6 = 4900
        // symbol_advance_count ~ 20
        // packer_word_count ~ 4900/16 = 306
        if (symbol_advance_count < 15) begin
            $fatal("Too few symbol_advance pulses");
        end

        if (packer_word_count < 250) begin
            $fatal("Too few packer output words");
        end

        if (packer_overflow) begin
            $fatal("Packer overflow");
        end

        $display("==== TB full modulation path PASS ====");
        $finish;
    end

endmodule
		
		
		
		
		
	
	
				
	
	
	
		