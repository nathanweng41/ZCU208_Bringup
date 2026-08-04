`timescale 1ns / 1ps

module axis_phase_downsampler_16 (
    input wire                          axis_aclk,
    input wire                          axis_aresetn,

    input wire [255:0]                  s_axis_tdata,
    input wire                          s_axis_tvalid,
    output wire                         s_axis_tready,

    // Output is 16 bits wide, representing the downsampled phase information
    output reg [15:0]                   m_axis_tdata,
    output reg                          m_axis_tvalid,
    input wire                          m_axis_tready,

    /* 
     * Direct phase setting from AXI GPIO
     * 
     * gpio_phase_valid may remain high indefinitely, changing gpio_phase will load the new phase
     */
    input wire [3:0]                    gpio_phase,
    input wire                          gpio_phase_valid,

    /*
     * Increment control from AXI GPIO
     * 
     * A 0-1 transition on gpio_phase_increment increments the active phase once. Holding this signal high does not repeatedly increment. Must return to zero 
     * before another increment can be triggered.
     */
    input wire                          gpio_phase_increment,

    // Output monitors
    output wire [3:0]                   active_phase_mon,
    output wire                         phase_initialized_mon
);
    // Current phase being selected
    reg [3:0] active_phase;
    reg phase_initialized;

    // Stores the last phase value received through gpio_phase
    reg [3:0] gpio_phase_seen;

    // Delayed copy of increment signal, used for edge detection
    reg gpio_phase_increment_d;

    wire output_transfer;
    wire output_slot_available;
    wire input_transfer;

    wire gpio_phase_changed;
    wire increment_rising_edge;

    wire phase_update;
    wire [3:0] updated_phase;
    wire [3:0] phase_input;

    assign output_transfer = m_axis_tvalid && m_axis_tready;
    // New output may be generated when the output register is empty or the existing output is being accepted
    assign output_slot_available = !m_axis_tvalid || m_axis_tready;

    // Do not accept new input until the initial phase has been received from AXI GPIO
    assign s_axis_tready = axis_aresetn && output_slot_available && phase_initialized;

    assign input_transfer = s_axis_tvalid && s_axis_tready;

    /* Detect changes made directly to gpio_phase
     * Compare against the last phase value seen to avoid repeated updates when gpio_phase_valid remains high
     */
    assign gpio_phase_changed = phase_initialized && gpio_phase_valid && (gpio_phase_seen != gpio_phase);

    // Detect only a 0-1 transition for k calibration
    assign increment_rising_edge = gpio_phase_increment && !gpio_phase_increment_d && phase_initialized;

    /* 
     * Phase update logic
     * 
     * The active phase is updated when either a new phase is received from AXI GPIO or a rising edge is detected on gpio_phase_increment.
     * Direct GPIO phase updates take precedence over incrementing the phase. Four bit addition naturally wraps
     */
    assign updated_phase = gpio_phase_changed ? gpio_phase : active_phase + 1'b1;

    // Determines whether to change the active phase this cycle
    assign phase_update = gpio_phase_changed || increment_rising_edge;

    assign phase_input = phase_update ? updated_phase : active_phase;

    // Monitors
    assign active_phase_mon = active_phase;
    assign phase_initialized_mon = phase_initialized;

    /*
     * Select one of the sixteen 16-bit samples. 
     */
     function [15:0] select_phase_sample;
     input [255:0] data;
     input [3:0] phase;
         begin
            select_phase_sample = data[(phase*16) +: 16];
         end
     endfunction

     always @(posedge axis_aclk) begin
        if (!axis_aresetn) begin
            active_phase <= 4'd0;
            phase_initialized <= 1'b0;
            gpio_phase_seen <= 4'd0;
            gpio_phase_increment_d <= 1'b0;

            m_axis_tdata <= 16'd0;
            m_axis_tvalid <= 1'b0;
        end else begin
            // Save the current increment GPIO state for edge detection on the next clock
            gpio_phase_increment_d <= gpio_phase_increment;

            if (output_transfer) begin
                // Clear valid once the output has been accepted, a new output may replace it later in this same clock
                m_axis_tvalid <= 1'b0;
            end

            if (!phase_initialized) begin
                m_axis_tvalid <= 1'b0;
                if (gpio_phase_valid) begin
                    active_phase <= gpio_phase;
                    gpio_phase_seen <= gpio_phase;
                    phase_initialized <= 1'b1;
                end
            end else begin
                /* Direct phase change from Vitis
                 * This takes precedence over incrementing the phase
                 */
                 if (gpio_phase_changed) begin
                    active_phase <= gpio_phase;
                    gpio_phase_seen <= gpio_phase;
                 end else if (increment_rising_edge) begin
                    active_phase <= active_phase + 1;
                 end

                 if(input_transfer) begin
                    m_axis_tdata <= select_phase_sample(s_axis_tdata, phase_input);
                    m_axis_tvalid <= 1;
                 end
            end
        end
     end

endmodule
