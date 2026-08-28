`timescale 1ns/1ps

module tb_modulation_v5;

    localparam real CLK_PERIOD_NS = 50.0;
    localparam integer NUM_WORDS = 16;
    localparam integer SYMS_PER_WORD = 128;
    localparam integer NUM_SYMBOLS = NUM_WORDS*SYMS_PER_WORD;
    localparam integer FINAL_SPS = 64;
    localparam integer EXPECTED_OUTPUT_SAMPLES = NUM_SYMBOLS*FINAL_SPS;
    localparam integer EXPECTED_OUTPUT_BEATS = EXPECTED_OUTPUT_SAMPLES/8;

    logic axis_aclk = 1'b0;
    logic axis_aresetn_0 = 1'b0;
    logic enable_0 = 1'b0;
    logic [15:0] gain_q15_0 = 16'h4000;
    logic mod_mode_0 = 1'b1;

    logic [511:0] s_axis_0_tdata = '0;
    logic s_axis_0_tvalid = 1'b0;
    wire s_axis_0_tready;

    wire [255:0] M_AXIS_DATA_0_tdata;
    logic M_AXIS_DATA_0_tready = 1'b1;
    wire M_AXIS_DATA_0_tvalid;

    integer f_iq, f_sym, f_words;
    integer input_words_accepted = 0;
    integer rate_errors = 0;
    time last_output_beat_time = 0;

    integer captured_beats = 0;
    integer captured_samples = 0;
    integer total_beats_seen = 0;
    integer post_beats_seen = 0;

    logic [14:0] prbs_state = 15'h1;

    always #(CLK_PERIOD_NS/2.0) axis_aclk = ~axis_aclk;

    modulation_v5_sim_wrapper dut (
        .M_AXIS_DATA_0_tdata(M_AXIS_DATA_0_tdata),
        .M_AXIS_DATA_0_tready(M_AXIS_DATA_0_tready),
        .M_AXIS_DATA_0_tvalid(M_AXIS_DATA_0_tvalid),
        .axis_aclk(axis_aclk),
        .axis_aresetn_0(axis_aresetn_0),
        .enable_0(enable_0),
        .gain_q15_0(gain_q15_0),
        .mod_mode_0(mod_mode_0),
        .s_axis_0_tdata(s_axis_0_tdata),
        .s_axis_0_tready(s_axis_0_tready),
        .s_axis_0_tvalid(s_axis_0_tvalid)
    );

    task automatic next_prbs_bit(output logic b);
        logic feedback;
        begin
            b = prbs_state[14];
            feedback = prbs_state[14] ^ prbs_state[13];
            prbs_state = {prbs_state[13:0], feedback};
            if (prbs_state == 15'd0) prbs_state = 15'h1;
        end
    endtask

    task automatic build_16qam_word(output logic [511:0] w);
        integer s;
        logic b3,b2,b1,b0;
        logic [3:0] sym;
        begin
            w = '0;
            for (s = 0; s < SYMS_PER_WORD; s = s + 1) begin
                next_prbs_bit(b3); 
                next_prbs_bit(b2);
                next_prbs_bit(b1); 
                next_prbs_bit(b0);
                sym = {b3,b2,b1,b0};
                w[s*4 +: 4] = sym;
                $fwrite(f_sym, "%0d\n", sym);
            end
        end
    endtask

    task automatic axis_send_word(input logic [511:0] w);
        begin
            s_axis_0_tdata  = w;
            s_axis_0_tvalid = 1'b1;
            while (1) begin
                @(posedge axis_aclk);
                if (s_axis_0_tready) break;
            end
            input_words_accepted = input_words_accepted + 1;
            #1 s_axis_0_tvalid = 1'b0;
        end
    endtask

    always @(posedge axis_aclk) begin : capture_output
        integer lane;
        logic signed [15:0] i_lane, q_lane;
        time dt;

        if (M_AXIS_DATA_0_tvalid && M_AXIS_DATA_0_tready) begin
            if (total_beats_seen != 0) begin
                dt = $time - last_output_beat_time;
                if ((total_beats_seen > 16) && (dt != 50ns)) begin
                    $error("Output beat-rate error: dt=%0t expected 50 ns", dt);
                    rate_errors = rate_errors + 1;
                end
            end

            last_output_beat_time = $time;
            total_beats_seen = total_beats_seen + 1;

            if (captured_beats < EXPECTED_OUTPUT_BEATS) begin
                for (lane = 0; lane < 8; lane = lane + 1) begin
                    i_lane = $signed(M_AXIS_DATA_0_tdata[lane*32 +: 16]);
                    q_lane = $signed(M_AXIS_DATA_0_tdata[lane*32 + 16 +: 16]);
                    $fwrite(f_iq, "%0d,%0d,%0d\n", captured_samples, i_lane, q_lane);
                    captured_samples = captured_samples + 1;
                end

                captured_beats = captured_beats + 1;
            end else begin
                post_beats_seen = post_beats_seen + 1;

                if (post_beats_seen <= 20) begin
                    $display(
                        "POST beat %0d : I0=%0d Q0=%0d",
                        post_beats_seen,
                        $signed(M_AXIS_DATA_0_tdata[15:0]),
                        $signed(M_AXIS_DATA_0_tdata[31:16])
                    );
                end
            end
        end
    end

    initial begin : run_test
        integer w;
        logic [511:0] word;

        f_iq    = $fopen("tx_out_iq_16qam.csv", "w");
        f_sym   = $fopen("tx_symbols_16qam.txt", "w");
        f_words = $fopen("tx_input_words_16qam_hex.txt", "w");

        if ((f_iq == 0) || (f_sym == 0) || (f_words == 0))
            $fatal(1, "Could not open output files.");

        $fwrite(f_iq, "sample,I,Q\n");

        repeat (10) @(posedge axis_aclk);

        @(negedge axis_aclk);
        axis_aresetn_0 = 1'b1;

        repeat (4) @(posedge axis_aclk);

        @(negedge axis_aclk);
        enable_0 = 1'b1;

        for (w = 0; w < NUM_WORDS; w = w + 1) begin
            build_16qam_word(word);
            $fwrite(f_words, "%0128h\n", word);
            axis_send_word(word);
        end

        s_axis_0_tvalid = 1'b0;

        while (captured_beats < EXPECTED_OUTPUT_BEATS)
            @(posedge axis_aclk);

        repeat (20) @(posedge axis_aclk);

        $display("Input words accepted         : %0d / %0d", input_words_accepted, NUM_WORDS);
        $display("Captured payload beats       : %0d / %0d", captured_beats, EXPECTED_OUTPUT_BEATS);
        $display("Captured payload samples     : %0d / %0d", captured_samples, EXPECTED_OUTPUT_SAMPLES);
        $display("Total FIR output beats seen  : %0d", total_beats_seen);
        $display("Output rate errors           : %0d", rate_errors);

        $display("Post-payload beats seen      : %0d", post_beats_seen);

        if (input_words_accepted != NUM_WORDS) $fatal(1, "Input count mismatch.");
        if (captured_beats != EXPECTED_OUTPUT_BEATS) $fatal(1, "Payload beat count mismatch.");
        if (captured_samples != EXPECTED_OUTPUT_SAMPLES) $fatal(1, "Payload sample count mismatch.");
        if (rate_errors != 0) $fatal(1, "Output-rate check failed.");

        $display("PASS: 16-QAM full-chain rate/count checks.");

        if (post_beats_seen != 0) $display("NOTE: DUT produced %0d additional valid beats after payload.", post_beats_seen);

        $fclose(f_iq); $fclose(f_sym); $fclose(f_words);
        $finish;
    end

    initial begin
        #2_000_000;
        $fatal(1, "TIMEOUT");
    end

endmodule
