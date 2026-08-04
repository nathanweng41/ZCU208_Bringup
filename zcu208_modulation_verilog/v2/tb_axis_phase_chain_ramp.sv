`timescale 1ns / 1ps

module tb_axis_phase_chain_ramp;

    localparam time CLK_PERIOD = 50ns; // 20 MHz

    logic         axis_aclk;
    logic         axis_aresetn;

    // Simulate ADC input
    logic [127:0] adc_tdata;
    logic         adc_tvalid;
    wire          adc_tready;

    // After 128-256 bit AXIS packer
    wire [255:0]  packed_tdata;
    wire          packed_tvalid;
    wire          packed_tready;

    // After downsampler
    wire  [15:0]  decim_tdata;
    wire          decim_tvalid;
    logic         decim_tready;

    logic [3:0]   gpio_phase;
    logic         gpio_phase_valid;
    logic         gpio_phase_increment;

    wire  [3:0]   active_phase_mon;
    wire          phase_initialized_mon;

    int output_count;
    int frames_sent;
    int error_count;
    int next_input_sample;
    int expected_phase;
    int expected_value;

    // Declarations
    axis_packer_128_to_256 packer_inst (
        .axis_aclk      (axis_aclk),
        .axis_aresetn   (axis_aresetn),
        .s_axis_tdata   (adc_tdata),
        .s_axis_tvalid  (adc_tvalid),
        .s_axis_tready  (adc_tready),
        .m_axis_tdata   (packed_tdata),
        .m_axis_tvalid  (packed_tvalid),
        .m_axis_tready  (packed_tready)
    );

    axis_phase_downsampler_16 downsampler_inst (
        .axis_aclk               (axis_aclk),
        .axis_aresetn            (axis_aresetn),
        .s_axis_tdata            (packed_tdata),
        .s_axis_tvalid           (packed_tvalid),
        .s_axis_tready           (packed_tready),
        .m_axis_tdata            (decim_tdata),
        .m_axis_tvalid           (decim_tvalid),
        .m_axis_tready           (decim_tready),
        .gpio_phase              (gpio_phase),
        .gpio_phase_valid        (gpio_phase_valid),
        .gpio_phase_increment    (gpio_phase_increment),
        .active_phase_mon        (active_phase_mon),
        .phase_initialized_mon   (phase_initialized_mon)
);

    initial begin
        axis_clk = 1'b0;
        forever #(CLK_PERIOD/2) axis_clk = ~axis_clk
    end

    function automatic logic [127:0] make_ramp_beat(
        input int first_sample
    );
        logic [127:0] beat;
        int lane;

        begin
            beat = 0;
            for (lane = 0; lane < 8; lane++) begin
                beat[lane*16 +: 16] = first_sample + lane;
            end

            return beat;
        end
    endfunction


    always @(posedge axis_aclk) begin
        if (!axis_aresetn) begin
            output_count = 0;
        // Output is ON
        end else if (decim_tvalid && decim_tready) begin
            expected_value = output_count * 16 + expected_phase;
            if (decim_tdata != expected_value[15:0]) begin
                $error("frame=%0d phase=%0d expected=%0d received=%0d", output_count, expected_phase, expected_value, $unsigned(decim_tdata));
                error_count++;
            end else begin
                $display("PASS time=%0t frame=%0d phase=%0d sample=%0d", $time, output_count, expected_phase, $unsigned(decim_tdata));
            end

            output_count++;
        end
    end

    task automatic drive_frames(input int number_of_frames);
        int total_beats;
        int beat_index;

        begin
            total_beats = number_of_frames * 2;
            frames_sent += number_of_frames;

            for (beat_index = 0; beat_index < total_beats; beat_index++) begin
                @(negedge axis_aclk);
                adc_tdata  = make_ramp_beat(next_input_sample);
                adc_tvalid = 1'b1;

                do begin
                    @(posedge axis_aclk);
                end while (!adc_tready);

                next_input_sample += 8;
            end

            @(negedge axis_aclk);
            adc_tvalid = 1'b0;
        end
    endtask

    task automatic wait_for_outputs(input int target_count);
        int timeout_count;

        begin
            timeout_count = 0;

            while ((output_count < target_count) &&
                   (timeout_count < 200)) begin
                @(posedge axis_aclk);
                timeout_count++;
            end

            if (output_count < target_count) begin
                $error(
                    "Timed out waiting for %0d outputs; received %0d.",
                    target_count,
                    output_count
                );
                error_count++;
            end
        end
    endtask     