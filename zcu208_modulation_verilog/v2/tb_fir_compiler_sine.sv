`timescale 1ns / 1ps

module tb_fir_compiler_sine;
    localparam CLK_PERIOD = 50;  // 20 MHz
    localparam NUM_SAMPLES = 64000; 
    localparam NUM_BEATS = NUM_SAMPLES / 8;

    reg aclk = 1'b0;

    always #(CLK_PERIOD/2) aclk = ~aclk;

    reg [15:0] sample_mem [0:NUM_SAMPLES-1];

    // DUT input

    reg [127:0] s_axis_data_tdata;
    reg         s_axis_data_tvalid;
    wire        s_axis_data_tready;

    // DUT output

    wire [127:0] m_axis_data_tdata;
    wire         m_axis_data_tvalid;
    reg          m_axis_data_tready;

    integer beat;
    integer lane;
    integer fout;
    integer output_sample_count;

    fir_compiler_test_wrapper dut (
    .aclk_0               (aclk),

    .S_AXIS_DATA_0_tdata  (s_axis_data_tdata),
    .S_AXIS_DATA_0_tvalid (s_axis_data_tvalid),
    .S_AXIS_DATA_0_tready (s_axis_data_tready),

    .m_axis_0_tdata         (m_axis_data_tdata),
    .m_axis_0_tvalid        (m_axis_data_tvalid),
    .m_axis_0_tready        (m_axis_data_tready)
    );

    always @(posedge aclk) begin
        if (m_axis_data_tvalid && m_axis_data_tready) begin
            for (lane = 0; lane < 8; lane = lane + 1) begin
                $fwrite(fout, "%0d\n", $signed(m_axis_data_tdata[16*lane +: 16]));
            end

            output_sample_count = output_sample_count + 8;
        end
    end

    initial begin
        $readmemh("input_samples.hex", sample_mem);

        fout = $fopen("fir_saturated_output.txt", "w");

        if (fout == 0) begin
            $display("Error: could not open output file for writing.");
            $finish;
        end

        s_axis_data_tdata = 128'd0;
        s_axis_data_tvalid = 1'b0;
        m_axis_data_tready = 1'b1;

        output_sample_count = 0;

        repeat(10)
            @(posedge aclk);
        
        @(negedge aclk);
        s_axis_data_tvalid = 1'b1;

        for (beat = 0; beat < NUM_BEATS; beat = beat + 1) begin

            // Pack next 8 samples
            for (lane = 0; lane < 8; lane = lane + 1) begin

                s_axis_data_tdata[lane*16 +: 16] = sample_mem[beat*8 + lane];
            end

            @(posedge aclk);

            while (!s_axis_data_tready) begin
                @(posedge aclk);
            end

            @(negedge aclk);

        end

        s_axis_data_tvalid = 1'b0;
        s_axis_data_tdata = 128'd0;

        wait (output_sample_count >= NUM_SAMPLES);

        repeat (10)
            @(posedge aclk);

        $display("");
        $display("======================================");
        $display("Simulation finished");
        $display("Input samples  = %0d", NUM_SAMPLES);
        $display("Output samples = %0d", output_sample_count);
        $display("======================================");

        $fclose(fout);

        $finish;
    end

endmodule