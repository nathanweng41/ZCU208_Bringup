`timescale 1ns / 1ps
 
module tb_axis_phase_chain_sine;
 
    localparam integer CLK_PERIOD_NS = 50;     // 20 MHz
    localparam integer NUM_SAMPLES   = 64000;  // Must match MATLAB
    localparam integer NUM_BEATS     = NUM_SAMPLES / 8;
    localparam integer NUM_FRAMES    = NUM_SAMPLES / 16; // 4K
    localparam [3:0]   TEST_PHASE    = 4'd15;
 
    reg          axis_aclk;
    reg          axis_aresetn;
 
    reg  [127:0] adc_tdata;
    reg          adc_tvalid;
    wire         adc_tready;
 
    wire [255:0] packed_tdata;
    wire         packed_tvalid;
    wire         packed_tready;
 
    wire [15:0]  decim_tdata;
    wire         decim_tvalid;
    reg          decim_tready;
 
    reg  [3:0]   gpio_phase;
    reg          gpio_phase_valid;
    reg          gpio_phase_increment;
 
    wire [3:0]   active_phase_mon;
    wire         phase_initialized_mon;
 
    reg [15:0] sample_memory [0:NUM_SAMPLES-1];
 
    integer output_file;
    integer output_count;
    integer sample_index;
    integer beat_index;
    integer lane;
    integer timeout_count;
 
    reg [127:0] beat_word;
 
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
        axis_aclk = 1'b0;
        forever #(CLK_PERIOD_NS/2) axis_aclk = ~axis_aclk;
    end
 
    /*
     * Record each accepted 16-bit downsampled output as signed decimal.
     */
    always @(posedge axis_aclk) begin
        if (axis_aresetn && decim_tvalid && decim_tready) begin
            $fwrite(output_file, "%0d\n", $signed(decim_tdata));
            output_count = output_count + 1;
        end
    end
 
    initial begin
        /*
         * One 16-bit two's-complement sample per line. Load everything into sample_memory
         */
        $readmemh("input_samples.hex", sample_memory);
 
        output_file = $fopen("downsampled_samples.txt", "w");
 
        if (output_file == 0) begin
            $display("ERROR: Could not open downsampled_samples.txt");
            $finish;
        end
 
        axis_aresetn         = 1'b0;
 
        adc_tdata            = 128'd0;
        adc_tvalid           = 1'b0;
 
        decim_tready         = 1'b1;
 
        gpio_phase           = 4'd0;
        gpio_phase_valid     = 1'b0;
        gpio_phase_increment = 1'b0;
 
        output_count         = 0;
        sample_index         = 0;
 
        repeat (5) @(posedge axis_aclk);
 
        @(negedge axis_aclk);
        axis_aresetn = 1'b1;
 
        /*
         * Simulate Vitis writing the initial GPIO phase and leaving
         * gpio_phase_valid high.
         */
        @(negedge axis_aclk);
        gpio_phase       = TEST_PHASE;
        gpio_phase_valid = 1'b1;
 
        wait (phase_initialized_mon == 1'b1);
        @(posedge axis_aclk);
 
        /*
         * Drive the complete MATLAB-generated sample stream.
         */
        for (beat_index = 0; beat_index < NUM_BEATS; beat_index = beat_index + 1) begin
 
            beat_word = 128'd0;
 
            for (lane = 0; lane < 8; lane = lane + 1) begin
                beat_word[lane*16 +: 16] = sample_memory[sample_index + lane];
            end
 
            @(negedge axis_aclk);
            adc_tdata  = beat_word;
            adc_tvalid = 1'b1;
 
            begin : wait_for_input_handshake
                while (1) begin
                    @(posedge axis_aclk);
 
                    // Wait for adc_tready before incrementing sample_index and moving to the next beat. 
                    if (adc_tready) begin
                        sample_index = sample_index + 8;
                        disable wait_for_input_handshake;
                    end
                end
            end
        end
 
        @(negedge axis_aclk);
        adc_tvalid = 1'b0;
 
        /*
         * Allow the final packed frame and selected sample to leave
         * the two-block pipeline.
         */
        timeout_count = 0;
 
        while ((output_count < NUM_FRAMES) &&
               (timeout_count < 200)) begin
            @(posedge axis_aclk);
            timeout_count = timeout_count + 1;
        end
 
        $fclose(output_file);
 
        if (output_count == NUM_FRAMES) begin
            $display(
                "SINE TEST COMPLETE: wrote %0d samples using phase %0d.",
                output_count,
                TEST_PHASE
            );
        end else begin
            $display(
                "ERROR: expected %0d output samples, received %0d.",
                NUM_FRAMES,
                output_count
            );
        end
 
        $finish;
    end
 
endmodule