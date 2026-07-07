`timescale 1ns / 1ps

module tb_full_qpsk_modulation_path;

	logic [0:0] PL_CLK_clk_p = 1'b0;
	logic [0:0] PL_CLK_clk_n = 1'b1;

	always begin
		#(816.326ps);
		PL_CLK_clk_p[0] = ~PL_CLK_clk_p[0];
		PL_CLK_clk_n[0] = ~PL_CLK_clk_n[0];
	end
	
	// Exported output from sample_packer_8_axis
	wire [255:0] m_axis_0_tdata;
	wire 		 m_axis_0_tvalid;
	// For testbench, assume downstream is always ready to accept data
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
	assign axis_clk = dut.full_baseband_sim_i.qpsk_sample_packer_8_0.axis_clk;

	wire clk_wiz_locked;
	assign clk_wiz_locked = dut.full_baseband_sim_i.clk_wiz_0.locked;
	
	wire symbol_advance; 
	assign symbol_advance = dut.full_baseband_sim_i.samples_per_symbol_c_0.symbol_advance;

    wire [15:0] sps_count;
    assign sps_count = dut.full_baseband_sim_i.samples_per_symbol_c_0.count;
	
	wire [7:0] unpacker_symbol;
	assign unpacker_symbol = dut.full_baseband_sim_i.qpsk_symbol_unpacker_0.m_axis_tdata;
	
	wire unpacker_valid;
	assign unpacker_valid = dut.full_baseband_sim_i.qpsk_symbol_unpacker_0.m_axis_tvalid;
	
	wire [7:0] symbol_idx;
	assign symbol_idx = dut.full_baseband_sim_i.qpsk_symbol_unpacker_0.symbol_idx;

    wire word_loaded;
	assign word_loaded = dut.full_baseband_sim_i.qpsk_symbol_unpacker_0.word_loaded;
	
	wire [31:0] mapped_iq;
	assign mapped_iq = dut.full_baseband_sim_i.qpsk_mapper_axis_0.m_axis_tdata;

    wire signed [15:0] mapped_i;
    assign mapped_i = mapped_iq[15:0];
    
	wire signed [15:0] mapped_q;
	assign mapped_q = mapped_iq[31:16];

	wire [2:0] packer_sample_count;
	assign packer_sample_count = dut.full_baseband_sim_i.qpsk_sample_packer_8_0.sample_count;
	
    // No need to look at this in simulation...
	wire packer_overflow;
	assign packer_overflow = dut.full_baseband_sim_i.qpsk_sample_packer_8_0.overflow;
	
	wire uram_play_tvalid;
	assign uram_play_tvalid = dut.full_baseband_sim_i.uram_play_modulation_0.axis_tvalid;
	
    wire uram_play_tready;
	assign uram_play_tready = dut.full_baseband_sim_i.uram_play_modulation_0.axis_tready;
	
    // AXI address map
	localparam logic [31:0] BRAM_BASE		 = 32'hC000_0000;
	localparam logic [31:0] GPIO_START_BASE  = 32'h4000_0000;
	localparam logic [31:0] GPIO_STOP_BASE   = 32'h4001_0000;
	localparam logic [31:0] GPIO_PERIOD_BASE = 32'h4002_0000;
	localparam logic [31:0] GPIO_ENABLE_BASE = 32'h4003_0000;
	
	localparam logic [31:0] GPIO_DATA = 32'h0;
	
	localparam int BYTES_PER_WORD = 64;
	localparam int TEST_WORDS	  = 8;

    // Stop address is last valid 512-bit word address
	localparam int STOP_ADDR	  = (TEST_WORDS-1) * BYTES_PER_WORD;
	
    // 2 complex samples per QPSK symbol
    // Baseband sample rate = 160 MHz
    // Symbol rate = 160 MHz / 2 = 80 MSym/s
	localparam int SYMBOL_PERIOD = 2;
	
	localparam signed [15:0] AMP_POS = 16'sd10000;
	localparam signed [15:0] AMP_NEG = -16'sd10000;
	
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
	
	// QPSK test word generator
    //
    // Packing convention:
    //
    // symbol 0 = word[1:0]
    // symbol 1 = word[3:2]
    // ...
    // symbol 255 = word[511:510]
    //
    // Symbol mapping expected by QPSK mapper:
    // 00 -> +I + Q
    // 01 -> -I + Q
    // 11 -> -I - Q
    // 10 -> +I - Q
	// 

    function automatic logic [1:0] qpsk_sym_pattern(input int sym_idx, input bit invert);
        logic [1:0] sym;
        begin
           case (sym_idx % 4)
                0: sym = 2'b00;
                1: sym = 2'b01;
                2: sym = 2'b11;
                3: sym = 2'b10;
                default: sym=2'b00;
            endcase

            if (invert) begin
                case (sym)
                    2'b00: sym = 2'b11;
                    2'b01: sym = 2'b10;
                    2'b11: sym = 2'b00;
                    2'b10: sym = 2'b01;
                    default: sym=2'b00;
                endcase
            end

            return sym;
        end
    endfunction

	function automatic logic [511:0] make_qpsk_word(input bit invert);
		logic [511:0] w;
        logic [1:0] sym;
		begin
            // One word is 512 bits, 256 symbols, 2 bits per symbol
            w = 512'd0;
            
			for (int i = 0; i < 256; i++) begin
				sym = qpsk_sym_pattern(i, invert);
                w[i*2 +: 2] = sym;
			end

			return w;
		end
	endfunction
	
    // Returns expected I/Q amplitudes for a given QPSK symbol
    function automatic void expected_iq_from_sym(input logic [1:0] sym, output logic signed [15:0] exp_i, output logic signed [15:0] exp_q);
        begin
            case (sym)
                2'b00: begin 
                    exp_i = AMP_POS; 
                    exp_q = AMP_POS; 
                end
                2'b01: begin 
                    exp_i = AMP_NEG; 
                    exp_q = AMP_POS; end
                2'b11: begin 
                    exp_i = AMP_NEG; 
                    exp_q = AMP_NEG; end
                2'b10: begin 
                    exp_i = AMP_POS; 
                    exp_q = AMP_NEG; end
                default: begin 
                    exp_i = 0; 
                    exp_q = 0; 
                    end
            endcase
        end
    endfunction

	// Physical monitor variables
	int symbol_advance_count;
	int packer_word_count;
    int axis_clk_count;

	int last_symbol_advance_cycle;
	int symbol_advance_cycle_delta;
	int last_packer_word_cycle;
	int packer_cycle_delta;
	
	realtime last_symbol_advance_time;
	realtime last_packer_word_time;
	realtime last_axis_clk_time;
	
	realtime dt_symbol;
	realtime dt_packer;
	realtime axis_clk_period;
	
	bit got_first_symbol_advance;
	bit got_first_packer_word;
	bit got_first_axis_clk;

	bit got_first_symbol_advance_cycle;
	bit got_first_packer_word_cycle;
	

    // Clk debug, use for first validation test, then comment out to reduce simulation output
	// Clk wizard may show 6ns/7ns style edge spacing.
	
	always @(posedge axis_clk) begin
		if (!clk_wiz_locked) begin
			axis_clk_count <= 0;
			got_first_axis_clk <= 0;
			last_axis_clk_time <= 0.0;
		end else begin
			axis_clk_count <= axis_clk_count + 1;

			if (!got_first_axis_clk) begin
				got_first_axis_clk <= 1'b1;
				last_axis_clk_time <= $realtime;
			end else begin
				axis_clk_period = $realtime - last_axis_clk_time;
				last_axis_clk_time <= $realtime;
				
				if (axis_clk_count <= 10) begin
					$display("[%.3f ns] axis_clk period = %.3f ns", $realtime, axis_clk_period);
				end

				// Widen range, loose check only
				if ((axis_clk_period < 5.5) || (axis_clk_period > 7.5)) begin
					$display("ERROR: axis_clk period VERY wrong: dt=%.3f expected about 6.25ns for 160 MHz", axis_clk_period);
					$finish(1);
				end
			end
		end
	end
	
	// Symbol rate monitor
    // For SYMBOL_PERIOD = 2, we expect a symbol advance every 2 axis_clk cycles, or every 12.5 ns
	always @(posedge axis_clk) begin
		if (symbol_advance && clk_wiz_locked) begin
			symbol_advance_count++;
		
			if (!got_first_symbol_advance) begin
				got_first_symbol_advance = 1'b1;
				last_symbol_advance_time = $realtime;
				$display("[%0d] first symbol advance symbol_idx=%0d symbol=0x%0h word_loaded=%0b", $realtime, symbol_idx, unpacker_symbol, word_loaded);
			end else begin
				dt_symbol = $realtime - last_symbol_advance_time;
				last_symbol_advance_time = $realtime;

                if (symbol_advance_count <= 32) begin
                    $display("[%.3f ns] symbol_advance #%0d dt=%0t sps_count=%0d symbol_idx=%0d symbol=0x%0h I=%0d Q=%0d", $realtime, symbol_advance_count, dt_symbol, sps_count, symbol_idx, unpacker_symbol, mapped_i, mapped_q);
                end
				
				if (!got_first_symbol_advance_cycle) begin
					got_first_symbol_advance_cycle = 1'b1;
					last_symbol_advance_cycle = axis_clk_count;
				end else begin
					symbol_advance_cycle_delta = axis_clk_count - last_symbol_advance_cycle;
					last_symbol_advance_cycle = axis_clk_count;

					if (symbol_advance_cycle_delta != SYMBOL_PERIOD) begin
						$fatal("Symbol advance spacing wrong: got %0d cycles, expected %0d", symbol_advance_cycle_delta, SYMBOL_PERIOD);
					end
				end
			end
		end
	end
	
	// Packer output monitor
	always @(posedge axis_clk) begin
		if (m_axis_0_tvalid && m_axis_0_tready && clk_wiz_locked) begin
			packer_word_count++;
			
			if (!got_first_packer_word) begin
				got_first_packer_word = 1'b1;
				last_packer_word_time = $realtime;
				
				$display("[%.3f ns] first packer word", $realtime);
			end else begin
				dt_packer = $realtime - last_packer_word_time;
				last_packer_word_time = $realtime;
				
                if (packer_word_count <= 32) begin
                    $display("[%.3f ns] packer word #%0d dt=%0t", $realtime, packer_word_count, dt_packer);
                end
	
				// Packer outputs one 256-bit word every 8 complex samples
				if (!got_first_packer_word_cycle) begin
					got_first_packer_word_cycle = 1'b1;
					last_packer_word_cycle = axis_clk_count;
				end else begin
					packer_cycle_delta = axis_clk_count - last_packer_word_cycle;
					last_packer_word_cycle = axis_clk_count;

					if (packer_cycle_delta != 8) begin
						$fatal("Packer output spacing wrong: got %0d cycles, expected 8", packer_cycle_delta);
					end
				end
			end
			
			// Do all lanes have valid QPSK amplitudes?
            // 8 complex samples, 1 each lane 
			for (int lane = 0; lane < 8; lane++) begin
                automatic logic signed [15:0] lane_i;
                automatic logic signed [15:0] lane_q;

                lane_i = m_axis_0_tdata[lane*32 +: 16];
				lane_q = m_axis_0_tdata[lane*32 + 16 +: 16];

                if (!((lane_i == AMP_POS) || (lane_i == AMP_NEG))) begin
                    $fatal("Invalid QPSK I sample word=%0d lane=%0d I_value=%0d hex=%04h", packer_word_count, lane, lane_i, m_axis_0_tdata[lane*32 +: 16]);
                end

                if (!((lane_q == AMP_POS) || (lane_q == AMP_NEG))) begin
                    $fatal("Invalid QPSK Q sample word=%0d lane=%0d Q_value=%0d hex=%04h", packer_word_count, lane, lane_q, m_axis_0_tdata[lane*32 + 16 +: 16]);
                end
			end
			
			if (packer_word_count <= 8) begin
				$write("	IQ lanes:");
				for (int lane = 0; lane < 8; lane++) begin
					automatic logic signed [15:0] lane_i;
                    automatic logic signed [15:0] lane_q;

                    lane_i = m_axis_0_tdata[lane*32 +: 16];
                    lane_q = m_axis_0_tdata[lane*32 + 16 +: 16];
					$write(" (%0d,%0d)", lane_i, lane_q);
				end
				$write("\n");
			end
		end			
	end
	
	// Overflow should never be asserted
	always @(posedge axis_clk) begin
		if (packer_overflow && clk_wiz_locked) begin
			$display("[%0t] ERROR: qpsk_sample_packer overflow asserted", $realtime);
            $finish(1);
		end
	end
    
    // Backpressure test from AI
        /*
    initial begin
        m_axis_0_tready = 1'b1;

        #5us;
        repeat (4) begin
            @(posedge axis_clk);
            m_axis_0_tready = 1'b0;
            repeat (3) @(posedge axis_clk);
            m_axis_0_tready = 1'b1;
            repeat (20) @(posedge axis_clk);
        end
    end
    */
	
	// Main stimulus
	logic [511:0] word;
	// Not really used, just filler for return
	logic [31:0] rd;
	
	initial begin
		$display("[%.3f ns] TB full QPSK modulation path START", $realtime);
		
		symbol_advance_count		= 0;
		packer_word_count			= 0;
        axis_clk_count              <= 0;
		symbol_advance_cycle_delta	= 0;
		packer_cycle_delta			= 0;

		got_first_symbol_advance		= 0;
		got_first_packer_word			= 0;
		got_first_axis_clk          	<= 0;
		got_first_symbol_advance_cycle	= 0;
		got_first_packer_word_cycle		= 0;
        
        last_symbol_advance_time	= 0;
		last_packer_word_time		= 0;
        last_axis_clk_time          <= 0.0;
		last_symbol_advance_cycle	= 0;
		last_packer_word_cycle		= 0;
		
		#200ns;
		
		$display("[%0t] Waiting for clk_wiz locked", $time);
		wait(clk_wiz_locked == 1);
		$display("[%0t] clk_wiz locked", $time);

		// Wait for a few cycles after lock
		repeat (20) @(posedge axis_clk);

		symbol_advance_count		= 0;
		packer_word_count			= 0;
        axis_clk_count              <= 0;
		symbol_advance_cycle_delta	= 0;
		packer_cycle_delta			= 0;

		got_first_symbol_advance        = 1'b0;
		got_first_packer_word           = 1'b0;
		got_first_axis_clk              <= 1'b0;
		got_first_symbol_advance_cycle  = 1'b0;
		got_first_packer_word_cycle     = 1'b0;

        last_symbol_advance_time	= 0;
		last_packer_word_time		= 0;
        last_axis_clk_time          <= 0;
		last_symbol_advance_cycle	= 0;
		last_packer_word_cycle		= 0;

		// Start VIP agents
		axi4_mst_agent    = new("AXI FULL master", dut.full_baseband_sim_i.axi_vip_0.inst.IF);
        axilite_mst_agent = new("AXI-LITE master", dut.full_baseband_sim_i.axi_vip_1.inst.IF);
		
		axi4_mst_agent.start_master();
		axilite_mst_agent.start_master();
		
		// Program pointers and symbol period.
		// Disable stream while loading data
		axi_gpio_write(GPIO_ENABLE_BASE, 32'd0);
		
		// Make sure uram_play_modulation sees 0
		repeat (2) @(posedge axis_clk);
		
		axi_gpio_write(GPIO_START_BASE, 32'd0);
		axi_gpio_write(GPIO_STOP_BASE, STOP_ADDR);
		axi_gpio_write(GPIO_PERIOD_BASE, SYMBOL_PERIOD);
		
		axi_gpio_read(GPIO_START_BASE,  rd);
		axi_gpio_read(GPIO_STOP_BASE,   rd);
		axi_gpio_read(GPIO_PERIOD_BASE, rd);
		axi_gpio_read(GPIO_ENABLE_BASE, rd);
		
		$display("[%.3f ns] Writing BRAM QPSK test pattern", $realtime);
		
		for (int w = 0; w < TEST_WORDS; w++) begin
			word = make_qpsk_word(w[0]);

			axi_write_512(BRAM_BASE + w*BYTES_PER_WORD, word);
			
			$display("[%.3f ns] Wrote BRAM word %0d addr=0x%08x word[31:0] (first 32 bits of word)=0x%08x", $realtime, w, BRAM_BASE + w*BYTES_PER_WORD, word[31:0]);
		end
		
		// Start stream after BRAM programming is complete
		
		$display("[%.3f ns] Enabling stream", $realtime);
		
		#1ns;
		
		axi_gpio_write(GPIO_ENABLE_BASE, 32'd1);
		axi_gpio_read(GPIO_ENABLE_BASE, rd);
		
		#5us;
		
		$display("--------------------------------------------------");
        $display("RESULTS");
        $display("axis_clk_count        = %0d", axis_clk_count);
        $display("symbol_advance_count  = %0d", symbol_advance_count);
        $display("packer_word_count     = %0d", packer_word_count);
        $display("packer_overflow       = %0b", packer_overflow);
        $display("last_unpacker_symbol  = 0x%0h", unpacker_symbol);
        $display("last_symbol_idx       = %0d", symbol_idx);
        $display("last_mapped_IQ        = %0d, %0d", mapped_i, mapped_q);
        $display("--------------------------------------------------");

        // Expected rough counts over 5 us:
        // 160 MHz sample clock --> about 800 complex samples
        // symbol_period = 2 --> about 400 symbol_advance pulses
        // packer output = 800 / 8 ~ 100 packed words
        
        if (symbol_advance_count < 300) begin
            $fatal("Too few symbol_advance pulses");
        end

        if (packer_word_count < 80) begin
            $fatal("Too few packer output words");
        end

        if (packer_overflow) begin
            $fatal("Packer overflow");
        end

        $display("==== TB full modulation path PASS ====");
        $finish;
    end

endmodule
