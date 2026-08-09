`timescale 1ns / 1ps

module tb_fir_compiler;

    // Clock
    localparam CLK_PERIOD = 50; // 20 MHz for PL

    reg aclk = 1'b0;

    always #(CLK_PERIOD/2) aclk = ~aclk;

    // FIR input
    reg [127:0] s_axis_data_tdata;
    reg         s_axis_data_tvalid;
    wire         s_axis_data_tready;

    // FIR output
    wire [127:0] m_axis_data_tdata;
    wire         m_axis_data_tvalid;
    reg          m_axis_data_tready;

    // Variables
    integer i;
    integer fout;
    integer lane;

    // DUT
    fir_compiler_test_wrapper dut(
        .aclk_0(aclk),
        .S_AXIS_DATA_0_tdata(s_axis_data_tdata),
        .S_AXIS_DATA_0_tvalid(s_axis_data_tvalid),
        .S_AXIS_DATA_0_tready(s_axis_data_tready),
        .m_axis_0_tdata(m_axis_data_tdata),
        .m_axis_0_tvalid(m_axis_data_tvalid),
        .m_axis_0_tready(m_axis_data_tready)
    );

    always @(posedge aclk) begin

        if (m_axis_data_tvalid && m_axis_data_tready) begin

            for (lane = 0; lane < 8; lane = lane + 1) begin
                $fwrite(
                    fout,
                    "%0d\n",
                    $signed(m_axis_data_tdata[lane*16 +: 16])
                );
            end

        end
    end

    initial begin

        fout = $fopen("fir_output.txt", "w");

        s_axis_data_tdata = 128'd0;
        s_axis_data_tvalid = 1'b0;
        m_axis_data_tready = 1'b1;

        repeat(10)
            @(posedge aclk);

        @(negedge aclk);
        s_axis_data_tvalid = 1'b1;
        s_axis_data_tdata = {16'sd0, 16'sd0, 16'sd0, 16'sd0, 16'sd0, 16'sd0, 16'sd0, 16'sd32767}; // Input data

        do begin
            @(posedge aclk);
        end while (!s_axis_data_tready);

        // Following beats are all zeros
        @(negedge aclk);
        s_axis_data_tdata = 128'd0;

        for (i = 0; i < 200; i = i + 1) begin

            @(posedge aclk);

            // Nothing needs to change.
            // TVALID stays high and data stays zero.
            //
            // If TREADY drops, AXI automatically holds this
            // zero beat until it is accepted.

        end

        // Stop input stream
        @(negedge aclk);

        s_axis_data_tvalid = 1'b0;

        repeat(5)
            @(posedge aclk);

        $fclose(fout);
        $display("Simulation finished.");
        $finish;

    end

endmodule
