`timescale 1ns / 1ps

module tb_full_modulation_word_boundary;

    logic [0:0] PL_CLK_clk_p = 1'b0;
    logic [0:0] PL_CLK_clk_n = 1'b1;

    // 612.5 MHz input clock
    always begin
        #816.326ps;
        PL_CLK_clk_p[0] = ~PL_CLK_clk_p[0];
        PL_CLK_clk_n[0] = ~PL_CLK_clk_n[0];
    end

    // Exported output from sample_packer_16_axis
    wire [255:0] m_axis_0_tdata;
    wire         m_axis_0_tvalid;
    logic        m_axis_0_tready = 1'b1;

    full_baseband_sim_wrapper dut (
        .PL_CLK_clk_n(PL_CLK_clk_n),
        .PL_CLK_clk_p(PL_CLK_clk_p),

        .m_axis_0_tdata(m_axis_0_tdata),
        .m_axis_0_tvalid(m_axis_0_tvalid),
        .m_axis_0_tready(m_axis_0_tready)
    );

    // ------------------------------------------------------------
    // Internal monitor signals
    // ------------------------------------------------------------

    wire axis_clk;
    assign axis_clk = dut.full_baseband_sim_i.sample_packer_16_axis_0.axis_clk;

    wire sample_en;
    assign sample_en = dut.full_baseband_sim_i.sample_enable_counter_0.sample_en;

    wire symbol_advance;
    assign symbol_advance = dut.full_baseband_sim_i.samples_per_symbol_c_0.symbol_advance;

    wire [15:0] symbol_count;
    assign symbol_count = dut.full_baseband_sim_i.samples_per_symbol_c_0.count;

    wire [7:0] unpacker_symbol;
    assign unpacker_symbol = dut.full_baseband_sim_i.symbol_unpacker_axis_0.m_axis_tdata;

    wire unpacker_valid;
    assign unpacker_valid = dut.full_baseband_sim_i.symbol_unpacker_axis_0.m_axis_tvalid;
    
    wire symbol_unpacker_tready;
    assign symbol_unpacker_tready = dut.full_baseband_sim_i.symbol_unpacker_axis_0.s_axis_tready;

    wire [8:0] symbol_idx;
    assign symbol_idx = dut.full_baseband_sim_i.symbol_unpacker_axis_0.symbol_idx;

    wire word_loaded;
    assign word_loaded = dut.full_baseband_sim_i.symbol_unpacker_axis_0.word_loaded;

    wire signed [15:0] mapped_sample;
    assign mapped_sample = dut.full_baseband_sim_i.bpsk_mapper_axis_0.m_axis_tdata;

    wire [3:0] packer_sample_count;
    assign packer_sample_count = dut.full_baseband_sim_i.sample_packer_16_axis_0.sample_count;

    wire uram_play_tvalid;
    assign uram_play_tvalid = dut.full_baseband_sim_i.uram_play_modulation_0.axis_tvalid;

    wire uram_play_tready;
    assign uram_play_tready = dut.full_baseband_sim_i.uram_play_modulation_0.axis_tready;

    wire [511:0] uram_play_tdata;
    assign uram_play_tdata = dut.full_baseband_sim_i.uram_play_modulation_0.axis_tdata;

    wire uram_fire;
    assign uram_fire = uram_play_tvalid && uram_play_tready;

    wire [31:0] uram_addr;
    assign uram_addr = dut.full_baseband_sim_i.uram_play_modulation_0.portAcpu_addr;

    wire uram_port_en;
    assign uram_port_en = dut.full_baseband_sim_i.uram_play_modulation_0.portA_en;

    // ------------------------------------------------------------
    // Address map
    // ------------------------------------------------------------

    localparam logic [31:0] BRAM_BASE        = 32'hC000_0000;
    localparam logic [31:0] GPIO_START_BASE  = 32'h4000_0000;
    localparam logic [31:0] GPIO_STOP_BASE   = 32'h4001_0000;
    localparam logic [31:0] GPIO_PERIOD_BASE = 32'h4002_0000;
    localparam logic [31:0] GPIO_ENABLE_BASE = 32'h4003_0000;

    localparam int BYTES_PER_WORD = 64;
    localparam int TEST_WORDS     = 4;
    localparam int STOP_ADDR      = (TEST_WORDS - 1) * BYTES_PER_WORD;

    // IMPORTANT:
    // This is a boundary-demo symbol period, not the final 1 MSym/s value.
    // SYMBOL_PERIOD = 4 makes the word boundary appear quickly and cleanly.
    // 512 symbols/word * 4 valid samples/symbol = 2048 valid samples.
    // At 245 MS/s, first boundary appears after about 8.36 us.
    localparam int SYMBOL_PERIOD = 4;

    localparam signed [15:0] AMP_POS = 16'sd16000;
    localparam signed [15:0] AMP_NEG = -16'sd16000;

    import axi_vip_pkg::*;
    import full_baseband_sim_axi_vip_0_0_pkg::*;
    import full_baseband_sim_axi_vip_1_0_pkg::*;

    full_baseband_sim_axi_vip_0_0_mst_t axi4_mst_agent;
    full_baseband_sim_axi_vip_1_0_mst_t axilite_mst_agent;

    // ------------------------------------------------------------
    // AXI helper tasks
    // ------------------------------------------------------------

    task automatic axi_write_512(input logic [31:0] addr, input logic [511:0] data);
        axi_transaction wr;
        begin
            wr = axi4_mst_agent.wr_driver.create_transaction("512_write");

            // One 64-byte beat
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

            $display("[%0t] AXIL WRITE addr=0x%08x data=0x%08x resp=%0d",
                     $time, addr, data, resp);

            if (resp != XIL_AXI_RESP_OKAY) begin
                $fatal("AXI-Lite WRITE failed addr=0x%08x resp=%0d", addr, resp);
            end
        end
    endtask

    task automatic axi_gpio_read(input logic [31:0] addr, output logic [31:0] data);
        xil_axi_resp_t resp;
        begin
            axilite_mst_agent.AXI4LITE_READ_BURST(addr, 0, data, resp);

            $display("[%0t] AXIL READ  addr=0x%08x data=0x%08x resp=%0d",
                     $time, addr, data, resp);

            if (resp != XIL_AXI_RESP_OKAY) begin
                $fatal("AXI-Lite READ failed addr=0x%08x resp=%0d", addr, resp);
            end
        end
    endtask

    // ------------------------------------------------------------
    // Boundary-specific BRAM data - AI generated
    // ------------------------------------------------------------
    // word0 = all 0 -> -16000
    // word1 = all 1 -> +16000
    // word2 = all 0 -> -16000
    // word3 = all 1 -> +16000
    //
    // This makes the word boundary obvious:
    // end of word0: -16000
    // start word1:  +16000
    // no gap should appear between them.

    function automatic logic [511:0] make_boundary_word(input int word_index);
        logic [511:0] w;
        begin
            if (word_index % 2 == 0) begin
                w = {512{1'b0}};
            end else begin
                w = {512{1'b1}};
            end

            return w;
        end
    endfunction

    // ------------------------------------------------------------
    // Counters / monitor variables
    // ------------------------------------------------------------

    int sample_en_count;
    int symbol_advance_count;
    int packer_word_count;
    int word_boundary_count;
    int uram_fire_count;

    realtime last_packer_word_time;
    realtime dt_packer;

    bit got_first_packer_word;

    bit last_uram_tready;
    bit last_uram_tvalid;
    bit last_word_loaded;
    bit last_unpacker_valid;

    // ------------------------------------------------------------
    // Basic sample_en count
    // ------------------------------------------------------------

    always @(posedge axis_clk) begin
        #1ps;
        if (sample_en) begin
            sample_en_count++;
        end
    end

    // ------------------------------------------------------------
    // URAM handshake edge monitor
    // This shows tvalid/tready behavior.
    // ------------------------------------------------------------

    always @(posedge axis_clk) begin
        #1ps;

        if (uram_play_tvalid !== last_uram_tvalid) begin
            $display("[%0t] URAM tvalid changed -> %0b  addr=0x%08x tready=%0b fire=%0b",
                     $time, uram_play_tvalid, uram_addr, uram_play_tready, uram_fire);
            last_uram_tvalid = uram_play_tvalid;
        end

        if (uram_play_tready !== last_uram_tready) begin
            $display("[%0t] URAM tready changed -> %0b  tvalid=%0b fire=%0b symbol_idx=%0d symbol_advance=%0b",
                     $time, uram_play_tready, uram_play_tvalid, uram_fire, symbol_idx, symbol_advance);
            last_uram_tready = uram_play_tready;
        end

        if (uram_fire) begin
            uram_fire_count++;
            $display("[%0t] URAM FIRE #%0d: loaded AXIS word, tdata[31:0]=0x%08h addr=0x%08x",
                     $time, uram_fire_count, uram_play_tdata[31:0], uram_addr);
        end
    end

    // ------------------------------------------------------------
    // Unpacker valid/word_loaded edge monitor
    // ------------------------------------------------------------

    always @(posedge axis_clk) begin
        #1ps;

        if (word_loaded !== last_word_loaded) begin
            $display("[%0t] word_loaded changed -> %0b  symbol_idx=%0d unpacker_valid=%0b symbol=0x%0h mapped=%0d",
                     $time, word_loaded, symbol_idx, unpacker_valid, unpacker_symbol, mapped_sample);
            last_word_loaded = word_loaded;
        end

        if (unpacker_valid !== last_unpacker_valid) begin
            $display("[%0t] unpacker_valid changed -> %0b  word_loaded=%0b symbol_idx=%0d symbol=0x%0h mapped=%0d",
                     $time, unpacker_valid, word_loaded, symbol_idx, unpacker_symbol, mapped_sample);
            last_unpacker_valid = unpacker_valid;
        end
    end

    // ------------------------------------------------------------
    // Symbol advance monitor
    // ------------------------------------------------------------

    always @(posedge axis_clk) begin
        #1ps;

        if (symbol_advance) begin
            symbol_advance_count++;

            // Only print near boundary to avoid massive spam
            if ((symbol_idx >= 9'd508) || (symbol_idx <= 9'd3)) begin
                $display("[%0t] symbol_advance #%0d near boundary: idx=%0d symbol=0x%0h mapped=%0d sample_en=%0b",
                         $time, symbol_advance_count, symbol_idx, unpacker_symbol, mapped_sample, sample_en);
            end
        end
    end

    // ------------------------------------------------------------
    // Word boundary monitor
    //
    // Important timing:
    // When symbol_advance=1 and symbol_idx=511, the unpacker is ready
    // to accept the next 512-bit word. During that cycle, uram_tready
    // should go high. On the next posedge, symbol_idx should wrap to 0
    // and unpacker_valid/word_loaded should stay high.
    // ------------------------------------------------------------

    always @(posedge axis_clk) begin
        #1ps;

        if (symbol_advance && word_loaded && (symbol_idx == 9'd511)) begin
            automatic int next_word_index;
            automatic bit expected_next_symbol;

            word_boundary_count++;
            next_word_index = word_boundary_count % TEST_WORDS;
            expected_next_symbol = next_word_index[0];

            $display("");
            $display("==================================================");
            $display("[%0t] WORD BOUNDARY #%0d ARMED", $time, word_boundary_count);
            $display("  This is the cycle before the next word becomes active.");
            $display("  Current symbol_idx       = %0d", symbol_idx);
            $display("  Current unpacker_symbol  = 0x%0h", unpacker_symbol);
            $display("  Current mapped_sample    = %0d", mapped_sample);
            $display("  symbol_advance           = %0b", symbol_advance);
            $display("  uram_tvalid              = %0b", uram_play_tvalid);
            $display("  uram_tready              = %0b", uram_play_tready);
            $display("  uram_fire                = %0b", uram_fire);
            $display("  word_loaded              = %0b", word_loaded);
            $display("  unpacker_valid           = %0b", unpacker_valid);
            $display("  uram_tdata[31:0]         = 0x%08h", uram_play_tdata[31:0]);
            $display("  Expected next word index = %0d", next_word_index);
            $display("  Expected next symbol bit = %0d", expected_next_symbol);

            // These are the key no-gap checks during the boundary-ready cycle.
            if (!uram_play_tvalid) begin
                $fatal("[%0t] ERROR: URAM tvalid is not high before word boundary", $time);
            end

            if (!uram_play_tready) begin
                $fatal("[%0t] ERROR: URAM tready did not assert at word boundary", $time);
            end

            if (!uram_fire) begin
                $fatal("[%0t] ERROR: URAM fire did not occur at word boundary", $time);
            end

            if (!word_loaded) begin
                $fatal("[%0t] ERROR: word_loaded dropped before boundary", $time);
            end

            if (!unpacker_valid) begin
                $fatal("[%0t] ERROR: unpacker_valid dropped before boundary", $time);
            end

            // Wait one clock. After this edge, the new word should be active.
            @(posedge axis_clk);
            #1ps;

            $display("[%0t] WORD BOUNDARY #%0d AFTER LOAD", $time, word_boundary_count);
            $display("  New symbol_idx           = %0d", symbol_idx);
            $display("  New unpacker_symbol      = 0x%0h", unpacker_symbol);
            $display("  New mapped_sample        = %0d", mapped_sample);
            $display("  symbol_advance           = %0b", symbol_advance);
            $display("  uram_tvalid              = %0b", uram_play_tvalid);
            $display("  uram_tready              = %0b", uram_play_tready);
            $display("  uram_fire                = %0b", uram_fire);
            $display("  word_loaded              = %0b", word_loaded);
            $display("  unpacker_valid           = %0b", unpacker_valid);
            $display("==================================================");
            $display("");

            // Key after-boundary no-gap checks.
            if (!word_loaded) begin
                $fatal("[%0t] ERROR: word_loaded dropped after word boundary", $time);
            end

            if (!unpacker_valid) begin
                $fatal("[%0t] ERROR: unpacker_valid dropped after word boundary", $time);
            end

            if (symbol_idx != 9'd0) begin
                $fatal("[%0t] ERROR: symbol_idx did not wrap to 0 after word boundary. Got %0d",
                       $time, symbol_idx);
            end

            if (unpacker_symbol[0] !== expected_next_symbol) begin
                $fatal("[%0t] ERROR: new word first symbol wrong. Got %0d expected %0d",
                       $time, unpacker_symbol[0], expected_next_symbol);
            end

            if (expected_next_symbol && (mapped_sample !== AMP_POS)) begin
                $fatal("[%0t] ERROR: expected +16000 after boundary, got %0d",
                       $time, mapped_sample);
            end

            if (!expected_next_symbol && (mapped_sample !== AMP_NEG)) begin
                $fatal("[%0t] ERROR: expected -16000 after boundary, got %0d",
                       $time, mapped_sample);
            end
        end
    end

    // ------------------------------------------------------------
    // Packer output monitor
    // ------------------------------------------------------------

    always @(posedge axis_clk) begin
        #1ps;

        if (m_axis_0_tvalid && m_axis_0_tready) begin
            packer_word_count++;

            if (!got_first_packer_word) begin
                got_first_packer_word = 1'b1;
                last_packer_word_time = $realtime;

                $display("[%0t] first packer word", $time);
            end else begin
                dt_packer = $realtime - last_packer_word_time;
                last_packer_word_time = $realtime;

                if (packer_word_count <= 20) begin
                    $display("[%0t] packer word #%0d dt=%0.3f ns",
                             $time, packer_word_count, dt_packer);
                end

                // 16 valid samples * 5 clocks / 4 valid samples = 20 fabric clocks
                // 20 / 306.25 MHz = 65.306 ns
                if ((dt_packer < 60.0) || (dt_packer > 70.0)) begin
                    $fatal("Packer output word period wrong: dt=%0.3f ns expected about 65 ns",
                           dt_packer);
                end
            end

            // All lanes should be valid BPSK amplitudes.
            for (int lane = 0; lane < 16; lane++) begin
                automatic logic signed [15:0] samp;
                samp = m_axis_0_tdata[lane*16 +: 16];

                if (!((samp == AMP_POS) || (samp == AMP_NEG))) begin
                    $fatal("Invalid BPSK sample word=%0d lane=%0d value=%0d hex=%04h",
                           packer_word_count, lane, samp, m_axis_0_tdata[lane*16 +: 16]);
                end
            end

            // Print first few packed words so you can see -16000 or +16000 lanes.
            if (packer_word_count <= 8) begin
                $write("    lanes:");
                for (int lane = 0; lane < 16; lane++) begin
                    automatic logic signed [15:0] samp;
                    samp = m_axis_0_tdata[lane*16 +: 16];
                    $write(" %0d", samp);
                end
                $write("\n");
            end
        end
    end

    // ------------------------------------------------------------
    // Main stimulus
    // ------------------------------------------------------------

    logic [511:0] word;
    logic [31:0] rd;

    initial begin
        $display("[%0t] TB WORD BOUNDARY DEMO START", $time);

        sample_en_count          = 0;
        symbol_advance_count     = 0;
        packer_word_count        = 0;
        word_boundary_count      = 0;
        uram_fire_count          = 0;
        got_first_packer_word    = 0;
        last_packer_word_time    = 0.0;

        last_uram_tready         = 1'bx;
        last_uram_tvalid         = 1'bx;
        last_word_loaded         = 1'bx;
        last_unpacker_valid      = 1'bx;

        #200ns;

        // Start VIP agents
        axi4_mst_agent    = new("AXI FULL master", dut.full_baseband_sim_i.axi_vip_0.inst.IF);
        axilite_mst_agent = new("AXI-LITE master", dut.full_baseband_sim_i.axi_vip_1.inst.IF);

        axi4_mst_agent.start_master();
        axilite_mst_agent.start_master();

        // Disable stream while programming BRAM/control registers.
        axi_gpio_write(GPIO_ENABLE_BASE, 32'd0);

        // Give the disable time to propagate.
        repeat (10) @(posedge axis_clk);

        // Program pointers and symbol period.
        axi_gpio_write(GPIO_START_BASE,  32'd0);
        axi_gpio_write(GPIO_STOP_BASE,   STOP_ADDR);
        axi_gpio_write(GPIO_PERIOD_BASE, SYMBOL_PERIOD);

        axi_gpio_read(GPIO_START_BASE,  rd);
        axi_gpio_read(GPIO_STOP_BASE,   rd);
        axi_gpio_read(GPIO_PERIOD_BASE, rd);
        axi_gpio_read(GPIO_ENABLE_BASE, rd);

        $display("[%0t] Writing BRAM boundary test pattern", $time);

        for (int w = 0; w < TEST_WORDS; w++) begin
            word = make_boundary_word(w);
            axi_write_512(BRAM_BASE + w*BYTES_PER_WORD, word);

            $display("[%0t] Wrote BRAM word %0d addr=0x%08x word[31:0]=0x%08x",
                     $time, w, BRAM_BASE + w*BYTES_PER_WORD, word[31:0]);
        end
        
        // Let AXI BRAM writes fully settle before enabling stream.
        repeat (100) @(posedge axis_clk);

        $display("[%0t] Enabling stream", $time);

        #1ns;

        axi_gpio_write(GPIO_ENABLE_BASE, 32'd1);
        axi_gpio_read(GPIO_ENABLE_BASE, rd);

        // Run long enough to hit several 512-symbol word boundaries.
        // With SYMBOL_PERIOD=4, one word lasts about 8.36 us.
        #35us;

        $display("--------------------------------------------------");
        $display("RESULTS");
        $display("sample_en_count       = %0d", sample_en_count);
        $display("symbol_advance_count  = %0d", symbol_advance_count);
        $display("packer_word_count     = %0d", packer_word_count);
        $display("word_boundary_count   = %0d", word_boundary_count);
        $display("uram_fire_count       = %0d", uram_fire_count);
        $display("--------------------------------------------------");

        if (word_boundary_count < 2) begin
            $fatal("Too few word boundaries observed. Increase sim time or reduce SYMBOL_PERIOD.");
        end

        if (uram_fire_count < 3) begin
            $fatal("Too few URAM AXIS transfers observed");
        end

        if (packer_word_count < 100) begin
            $fatal("Too few packer output words");
        end

        $display("==== TB WORD BOUNDARY DEMO PASS ====");
        $finish;
    end

endmodule