`timescale 1ns / 1ps
 
module tb_axis_programmable_phase_aligner;
 
    localparam time CLK_PERIOD = 50ns; //20MHz
 
    logic         axis_aclk;
    logic         axis_aresetn;
 
    logic [127:0] s_axis_tdata;
    logic         s_axis_tvalid;
    wire          s_axis_tready;
 
    wire  [127:0] m_axis_tdata;
    wire          m_axis_tvalid;
    logic         m_axis_tready;
 
    logic [3:0]   gpio_phase;
    logic         gpio_phase_valid;
    logic         gpio_phase_increment;
 
    wire  [3:0]   active_phase_mon;
    wire          phase_initialized_mon;
    wire          phase_update_pending_mon;
    wire  [1:0]   state_mon;
 
    int source_next_sample;
    int expected_output_start;
    int expected_phase;
    int output_count;
    int error_count;
 
    axis_programmable_phase_aligner dut (
        .axis_aclk                 (axis_aclk),
        .axis_aresetn              (axis_aresetn),
        .s_axis_tdata              (s_axis_tdata),
        .s_axis_tvalid             (s_axis_tvalid),
        .s_axis_tready             (s_axis_tready),
        .m_axis_tdata              (m_axis_tdata),
        .m_axis_tvalid             (m_axis_tvalid),
        .m_axis_tready             (m_axis_tready),
        .gpio_phase                (gpio_phase),
        .gpio_phase_valid          (gpio_phase_valid),
        .gpio_phase_increment      (gpio_phase_increment),
        .active_phase_mon          (active_phase_mon),
        .phase_initialized_mon     (phase_initialized_mon),
        .phase_update_pending_mon  (phase_update_pending_mon),
        .state_mon                 (state_mon)
    );
 
    initial begin
        axis_aclk = 1'b0;
        forever #(CLK_PERIOD/2) axis_aclk = ~axis_aclk;
    end
 
    function automatic logic [127:0] make_ramp_beat(input int first_sample);
        logic [127:0] beat;
        int lane;
 
        begin
            beat = '0;
            for (lane = 0; lane < 8; lane++) begin
                beat[lane*16 +: 16] = first_sample + lane;
            end
            return beat;
        end
    endfunction
 
    task automatic send_one_beat;
        begin
            @(negedge axis_aclk);
            s_axis_tdata  = make_ramp_beat(source_next_sample);
            s_axis_tvalid = 1'b1;
 
            // Keep data until accepted downstream.
            do begin
                @(posedge axis_aclk);
            end while (!s_axis_tready);
 
            source_next_sample += 8;
        end
    endtask
 
    task automatic drive_beats(input int count);
        int i;
        begin
            for (i = 0; i < count; i++) begin
                send_one_beat();
            end
 
            @(negedge axis_aclk);
            s_axis_tvalid = 1'b0;
        end
    endtask
 
    task automatic wait_for_outputs(input int target_count);
        int timeout;
        begin
            timeout = 0;
            while ((output_count < target_count) && (timeout < 300)) begin
                @(posedge axis_aclk);
                timeout++;
            end
 
            if (output_count < target_count) begin
                $error("Timeout waiting for %0d outputs; received %0d.",
                       target_count, output_count);
                error_count++;
            end
        end
    endtask
 
    task automatic set_direct_phase(input logic [3:0] new_phase);
        int delta;
        begin
            delta = (new_phase - expected_phase) & 15;
 
            @(negedge axis_aclk);
            gpio_phase = new_phase;
 
            expected_phase = new_phase;
            expected_output_start += delta;
 
            /* Allow the GPIO change to be detected and queued while the
             * source is idle. */
            @(posedge axis_aclk);
        end
    endtask
 
    task automatic increment_phase_once;
        begin
            @(negedge axis_aclk);
            gpio_phase_increment = 1'b1;
 
            expected_phase = (expected_phase + 1) & 15;
            expected_output_start += 1;
 
            @(posedge axis_aclk);
        end
    endtask
 
    task automatic rearm_increment;
        begin
            @(negedge axis_aclk);
            gpio_phase_increment = 1'b0;
            @(posedge axis_aclk);
        end
    endtask
 
    always @(posedge axis_aclk) begin
        int lane;
        int expected_sample;
        int received_sample;
 
        if (axis_aresetn && m_axis_tvalid && m_axis_tready) begin
            for (lane = 0; lane < 8; lane++) begin
                expected_sample = expected_output_start + lane;
                received_sample = $unsigned(m_axis_tdata[lane*16 +: 16]);
 
                if (received_sample !== (expected_sample & 16'hFFFF)) begin
                    $error(
                        "time=%0t output=%0d lane=%0d phase=%0d expected=%0d received=%0d",
                        $time,
                        output_count,
                        lane,
                        active_phase_mon,
                        expected_sample,
                        received_sample
                    );
                    error_count++;
                end
            end
 
            $display(
                "PASS time=%0t output=%0d phase=%0d samples=%0d..%0d",
                $time,
                output_count,
                active_phase_mon,
                expected_output_start,
                expected_output_start + 7
            );
 
            expected_output_start += 8;
            output_count++;
        end
    end
 
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(1);
        axis_aresetn         = 1'b0;
        s_axis_tdata         = '0;
        s_axis_tvalid        = 1'b0;
        m_axis_tready        = 1'b1;
 
        gpio_phase           = 4'd0;
        gpio_phase_valid     = 1'b0;
        gpio_phase_increment = 1'b0;
 
        source_next_sample   = 0;
        expected_output_start = 3;
        expected_phase       = 3;
        output_count         = 0;
        error_count          = 0;
 
        repeat (5) @(posedge axis_aclk);
 
        @(negedge axis_aclk);
        axis_aresetn = 1'b1;
 
        /* Initial direct phase = 3. */
        @(negedge axis_aclk);
        gpio_phase       = 4'd3;
        gpio_phase_valid = 1'b1;
 
        wait (phase_initialized_mon === 1'b1);
        @(posedge axis_aclk);
 
        /* W0 is captured; W1-W3 produce starts 3, 11, 19. */
        drive_beats(4);
        wait_for_outputs(3);
 
        /* Direct 3 -> 10: advance by seven samples.  The next normal start
         * would be 27, so the next aligned start must be 34. */
        set_direct_phase(4'd10);
        drive_beats(3);
        wait_for_outputs(5);
 
        /* Direct 10 -> 2: modulo-16 forward advance of eight samples. */
        set_direct_phase(4'd2);
        drive_beats(3);
        wait_for_outputs(7);
 
        /* Direct 2 -> 1: modulo-16 forward advance of fifteen samples.
         * This exercises the two-word-advance path. */
        set_direct_phase(4'd1);
        drive_beats(4);
        wait_for_outputs(9);
 
        /* Increment 1 -> 2. */
        increment_phase_once();
 
        /* Keep increment high.  It must increment only once. */
        drive_beats(3);
        wait_for_outputs(12);
 
        if (active_phase_mon !== 4'd2) begin
            $error("Expected phase 2 while increment remained high; got %0d.",
                   active_phase_mon);
            error_count++;
        end
 
        rearm_increment();
 
        /* Direct phase can still be used after an increment. */
        set_direct_phase(4'd7);
        drive_beats(3);
        wait_for_outputs(15);
 
        /* Increment boundary 7 -> 8. */
        increment_phase_once();
        drive_beats(3);
        wait_for_outputs(17);
        rearm_increment();
 
        repeat (5) @(posedge axis_aclk);
 
        if (error_count == 0) begin
            $display("");
            $display("========================================");
            $display("TEST PASSED: %0d output beats checked.", output_count);
            $display("========================================");
        end else begin
            $display("");
            $display("========================================");
            $display("TEST FAILED: %0d error(s).", error_count);
            $display("========================================");
        end
 
        $finish;
    end
 
endmodule