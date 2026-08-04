`timescale 1ns / 1ps

module axis_programmable_offset #(
    parameter integer MAX_OFFSET_SAMPLES = 4095,

    // stores the offset in individual 16 bit samples
    parameter integer OFFSET_WIDTH = (MAX_OFFSET_SAMPLES < 1) ? 1 : $clog2(MAX_OFFSET_SAMPLES + 1),

    // stores the number of complete 128-bit AXI words that must be skipped
    parameter integer SKIP_COUNT_WIDTH = ((MAX_OFFSET_SAMPLES / 8) < 1) ? 1 : $clog2((MAX_OFFSET_SAMPLES / 8 ) + 1)
) (
    input  wire                     axis_aclk,
    input  wire                     axis_aresetn,

    // Input AXI stream interface: 128 bits = 8 samples x 16 bits/sample
    input  wire [127:0]             s_axis_tdata,
    input  wire                     s_axis_tvalid,
    output wire                     s_axis_tready,

    // Output AXI stream interface
    output reg [127:0]              m_axis_tdata,
    output reg                      m_axis_tvalid,
    input  wire                     m_axis_tready,

    /* Static startup offset
     *
     * Pulse intial_offset_load for one clock to load initial_offset_samples
     *
     * Examples:
     *   0 -> output starts at s0
     *   1 -> output starts at s1
     *  10 -> output starts at s10
     */

    input wire [OFFSET_WIDTH-1:0]   initial_offset_samples,
    input wire                      initial_offset_load,

    // for calibration (increase k by 1). Hold step_valid high until step_ready is high. Correction is applied after the current output word is accepted
    input wire                      step_valid,
    output wire                     step_ready,

    /* 
     * Monitor signals
     */

    output wire [OFFSET_WIDTH-1:0]   active_offset_mon,
    output wire [2:0]                active_lane_mon,
    output wire                      step_pending_mon,
    output wire                      initialized_mon
);
    /*
     * State definitions
     */

    localparam [1:0] STATE_SKIP_WORDS = 2'd0;
    localparam [1:0] STATE_GET_FIRST  = 2'd1;
    localparam [1:0] STATE_GET_SECOND = 2'd2;
    localparam [1:0] STATE_STREAM     = 2'd3;

    reg [1:0] state;

    /* 
    * Previous complete 128-bit AXI word
    */
     reg [127:0] previous_word;

    /*
     * Current offset inside an AXI beat:
     *
     * lane 0 -> start at sample 0
     * lane 1 -> start at sample 1
     * lane 2 -> start at sample 2
     * ... lane 7 -> start at sample 7
     *
     */

    reg [2:0] active_lane;

    // Total logical offset for monitoring
    reg [OFFSET_WIDTH-1:0] active_offset;

    reg [SKIP_COUNT_WIDTH-1:0] skip_words_remaining;

    reg step_pending;

    wire [SKIP_COUNT_WIDTH-1:0] initial_word_skip;


    wire input_transfer;
    wire output_transfer;
    wire output_slot_available;

    /*
     * Words to skip = floor (offset / 8)
     */
    assign initial_word_skip = initial_offset_samples >> 3;

    // Output transfer when m_axis_tvalid is high and m_axis_tready is high (handshake), similar for input transfer
    assign output_transfer = m_axis_tvalid && m_axis_tready;
    assign input_transfer = s_axis_tvalid && s_axis_tready;

    // Input only advances when there is no pending output or the pending output is being accepted this clock
    assign output_slot_available = !m_axis_tvalid || m_axis_tready;

    // Tells upstream to send data when the output slot is available and the block is not being reset or reloaded
    assign s_axis_tready = axis_aresetn && !initial_offset_load && ( (state != STATE_STREAM) || output_slot_available );

    assign step_ready = axis_aresetn && (state == STATE_STREAM) && !step_pending && (active_offset < MAX_OFFSET_SAMPLES);

    // Initialize monitor signals
    assign active_offset_mon = active_offset;
    assign active_lane_mon = active_lane;
    assign step_pending_mon = step_pending;
    assign initialized_mon = (state == STATE_STREAM);

    /* 
     * This function builds an output word beginning at the selected sample lane
     *
     * Example:
     * 
     * older = s0 through s7
     * newer = s8 through s15
     *
     * lane 0 -> s0 through s7
     * lane 1 -> s1 through s8
     * ...
     * lane 7 -> s7 through s14
     *
     * Each lane is 8 samples --> total of 128 bits
     *
     */

    function [127:0] align_words;

        input [127:0] older;
        input [127:0] newer;
        input [2:0] lane;

        reg [255:0] combined_words;
        integer shift_bits;

        begin
            combined_words = {newer, older};
            shift_bits = lane * 16; // Each sample is 16 bits
            
            // Shift out samples from the older_word and assignment to 128 bits retains the lower 128 bits
            align_words = combined_words >> shift_bits;
        end

    
    /*
     * Before the shift register update:
     * 
     * delay_line[0] = x[n-1]
     * delay_line[1] = x[n-2]
     * ...
     * Therefore, for delay k:
     * 
     * k = 0: current s_axis_tdata
     * k = 1: delay_line[0]
     * k = 2: delay_line[1]
     * ...
     */
    
    // Select the data to output based on the active delay
    always @(*) begin
        if (active_delay == 0) begin
            selected_data = s_axis_tdata;
        end else begin
            selected_data = delay_line[active_delay - 1];
        end
    end

    always @(posedge axis_aclk) begin
        if (!axis_aresetn) begin
            active_delay <= 0;
            history_count <= 0;

            m_axis_tdata <= 0;
            m_axis_tvalid <= 0;

            for (i = 0; i < MAX_DELAY; i = i + 1) begin
                delay_line[i] <= 0;
            end
        end else if (delay_load) begin
            // Load the new delay value and reset everything
            if (delay_value < MAX_DELAY) begin
                active_delay <= delay_value;
            end else begin
                active_delay <= MAX_DELAY;
            end

            history_count <= 0;
            m_axis_tdata <= 0;
            m_axis_tvalid <= 0;

            for (i = 0; i < MAX_DELAY; i = i + 1) begin
                delay_line[i] <= 0;
            end
        end else begin
            // Remove an accepted output
            if (output_transfer) begin
                // Output transfer accepted, advance history count
                m_axis_tvalid <= 1'b0;
            end

            if (input_transfer) begin
                // Update delay line history (shift register)
                for (i = MAX_DELAY-1; i > 0; i = i - 1) begin
                    delay_line[i] <= delay_line[i-1];
                end

                delay_line[0] <= s_axis_tdata;

                if (history_count < MAX_DELAY) begin
                    history_count <= history_count + 1;
                end

                // Suppress the output during delay-line startup
                if (history_valid) begin
                    m_axis_tdata <= selected_data;
                    m_axis_tvalid <= 1'b1;
                end
            end
        end
    end

endmodule