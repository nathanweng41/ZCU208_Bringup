`timescale 1ns / 1ps

module tb_qam_qpsk_symbol_unpacker_axis_2_5;

    localparam real CLK_PERIOD_NS = 50.0; // 20 MHz
    localparam time SYMBOL_PERIOD_NS = 400ns;

    logic       axis_clk     = 1'b0;
    logic       axis_aresetn = 1'b0;
    logic       enable       = 1'b0;

    logic [511:0] s_axis_tdata = 0;
    logic        s_axis_tvalid = 0;
    logic        s_axis_tready;

    wire [7:0]   m_axis_tdata;
    wire         m_axis_tvalid;
    wire         m_axis_tready = 1'b1;

    logic        mod_mode = 1'b0;

    wire         sample_fire;
    wire [7:0]   symbol_idx;
    wire         word_loaded;
    wire [2:0]   rate_count;

    logic [3:0]   expected [0:511];
    logic [511:0] qpsk_words [0:1];
    logic [511:0] qam_word;

    integer errors = 0;

    always #(CLK_PERIOD_NS/2.0) axis_clk = ~axis_clk;

    qam_qpsk_symbol_unpacker_axis_2_5 dut (
        .axis_clk        (axis_clk),
        .axis_aresetn    (axis_aresetn),
        .enable          (enable),

        .s_axis_tdata    (s_axis_tdata),
        .s_axis_tvalid   (s_axis_tvalid),
        .s_axis_tready   (s_axis_tready),

        .m_axis_tdata    (m_axis_tdata),
        .m_axis_tvalid   (m_axis_tvalid),
        .m_axis_tready   (m_axis_tready),

        .mod_mode        (mod_mode),

        .sample_fire     (sample_fire),
        .symbol_idx      (symbol_idx),
        .word_loaded     (word_loaded),
        .rate_count      (rate_count)
    );

    function automatic [3:0] qpsk_expected(input logic [1:0] s);
        case (s)
            2'b00: qpsk_expected = 4'b0000;
            2'b01: qpsk_expected = 4'b0010;
            2'b11: qpsk_expected = 4'b1010;
            2'b10: qpsk_expected = 4'b1000;
            default: qpsk_expected = 4'b0000;
        endcase
    endfunction

    task automatic axis_send_word(input logic [511:0] w);
        begin
            s_axis_tdata  = w;
            s_axis_tvalid = 1'b1;

            // AXIS master behavior: hold TVALID/TDATA until accepted.
            while (1) begin
                @(posedge axis_clk);
                if (s_axis_tready)
                    break;
            end

            #1;
            s_axis_tvalid = 1'b0;
        end
    endtask

    task automatic check_output_symbols(input integer count);
        integer i;
        time last_fire_time;
        time dt;
        begin
            last_fire_time = 0;

            for (i = 0; i < count; i = i + 1) begin
                while (1) begin
                    @(posedge axis_clk);
                    if (sample_fire)
                        break;
                end

                if (m_axis_tdata[3:0] !== expected[i]) begin
                    $error("Symbol mismatch at index %0d: got 0x%0h expected 0x%0h", i, m_axis_tdata[3:0], expected[i]);
                    errors = errors + 1;
                end

                if (m_axis_tdata[7:4] !== 4'h0) begin
                    $error("Upper nibble is non-zero at symbol %0d: 0x%0h",i, m_axis_tdata[7:4]);
                    errors = errors + 1;
                end

                if (i != 0) begin
                    dt = $time - last_fire_time;
                    if (dt != SYMBOL_PERIOD_NS) begin
                        $error("Symbol-rate error at symbol %0d: dt=%0t, expected=%0t",
                               i, dt, SYMBOL_PERIOD_NS);
                        errors = errors + 1;
                    end
                end

                last_fire_time = $time;
            end
        end
    endtask

    initial begin : build_vectors
        integer w, s;
        logic [1:0] qsym;
        logic [3:0] qamsym;
        integer idx;

        qpsk_words[0] = 0;
        qpsk_words[1] = 0;

        // QPSK test pattern: 00,01,11,10 repeated.
        idx = 0;
        for (w = 0; w < 2; w = w + 1) begin
            for (s = 0; s < 256; s = s + 1) begin
                case (s % 4)
                    0: qsym = 2'b00;
                    1: qsym = 2'b01;
                    2: qsym = 2'b11;
                    3: qsym = 2'b10;
                endcase

                qpsk_words[w][s*2 +: 2] = qsym;
                expected[idx] = qpsk_expected(qsym);
                idx = idx + 1;
            end
        end

        // 16-QAM test pattern: 0..F repeated.
        qam_word = 0;
        for (s = 0; s < 128; s = s + 1) begin
            qamsym = s[3:0];
            qam_word[s*4 +: 4] = qamsym;
        end
    end

    initial begin : test_sequence
        integer s;

        $display("============================================================");
        $display("Unit test: qam_qpsk_symbol_unpacker_axis_2_5");
        $display("Clock = 20 MHz, expected symbol rate = 2.5 MSym/s");
        $display("============================================================");

        repeat (6) @(posedge axis_clk);
        axis_aresetn = 1'b1;
        repeat (2) @(posedge axis_clk);

        // QPSK: two complete packed words, including seamless boundary.
        mod_mode = 1'b0;
        enable   = 1'b1;

        fork
            begin
                axis_send_word(qpsk_words[0]);
                axis_send_word(qpsk_words[1]);
            end
            begin
                check_output_symbols(512);
            end
        join

        $display("QPSK unpacking + 2.5 MSym/s timing check complete.");

        // Explicitly check enable-low reset behavior.
        enable = 1'b0;
        repeat (2) @(posedge axis_clk);
        #1;

        if (rate_count !== 3'd0) begin
            $error("rate_count did not reset to zero when enable=0.");
            errors = errors + 1;
        end

        if (word_loaded !== 1'b0) begin
            $error("word_loaded did not clear when enable=0.");
            errors = errors + 1;
        end

        if (m_axis_tvalid !== 1'b0) begin
            $error("m_axis_tvalid did not clear when enable=0.");
            errors = errors + 1;
        end

        // 16-QAM: verify nibbles pass through unchanged.
        for (s = 0; s < 128; s = s + 1)
            expected[s] = s[3:0];

        mod_mode = 1'b1;
        enable   = 1'b1;

        fork
            begin
                axis_send_word(qam_word);
            end
            begin
                check_output_symbols(128);
            end
        join

        $display("16-QAM unpacking + 2.5 MSym/s timing check complete.");

        if (errors == 0) begin
            $display("============================================================");
            $display("PASS: unpacker logic, symbol mapping, rate, and enable reset.");
            $display("============================================================");
        end else begin
            $fatal(1, "FAIL: unpacker unit test found %0d error(s).", errors);
        end

        #100;
        $finish;
    end

    initial begin : timeout
        #1_000_000;
        $fatal(1, "TIMEOUT in unpacker unit test.");
    end

endmodule

