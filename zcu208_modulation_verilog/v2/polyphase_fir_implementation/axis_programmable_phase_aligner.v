`timescale 1ns / 1ps
 
module axis_programmable_phase_aligner (
    input  wire         axis_aclk,
    input  wire         axis_aresetn,
 
    input  wire [127:0] s_axis_tdata,
    input  wire         s_axis_tvalid,
    output wire         s_axis_tready,
 
    output reg  [127:0] m_axis_tdata,
    output reg          m_axis_tvalid,
    input  wire         m_axis_tready,
 
    /*
     * Direct phase value from AXI GPIO.
     *
     * gpio_phase_valid may stay high continuously.  During startup the
     * first valid value initializes the block.  While streaming, changing
     * gpio_phase requests a new phase directly.
     */
    input  wire [3:0]   gpio_phase,
    input  wire         gpio_phase_valid,
 
    /*
     * Optional +1 request from AXI GPIO.
     * A rising edge increments once.  Holding the signal high does not
     * repeatedly increment; it must return low before another increment.
     */
    input  wire         gpio_phase_increment,
 
    output wire [3:0]   active_phase_mon,
    output wire         phase_initialized_mon,
    output wire         phase_update_pending_mon,
    output wire [1:0]   state_mon
);
 
    localparam [1:0] STATE_WAIT_PHASE    = 2'd0;
    localparam [1:0] STATE_SKIP_WORD     = 2'd1;
    localparam [1:0] STATE_CAPTURE_FIRST = 2'd2;
    localparam [1:0] STATE_STREAM        = 2'd3;
 
    reg [1:0] state;
 
    reg [127:0] previous_word;
 
    reg [3:0] active_phase;
    reg       phase_initialized;
 
    /* Last value explicitly observed on gpio_phase. */
    reg [3:0] gpio_phase_seen;
 
    /* Rising-edge detector for gpio_phase_increment. */
    reg gpio_phase_increment_d;
 
    /* One pending phase request. */
    reg       phase_update_pending;
    reg [3:0] pending_phase;
 
    wire output_transfer;
    wire output_slot_available;
    wire input_transfer;
 
    wire direct_phase_change;
    wire increment_rising_edge;
    wire phase_request_new;
 
    wire [3:0] increment_base_phase;
    wire [3:0] requested_phase_now;
    wire       phase_update_available;
    wire [3:0] phase_to_apply;
 
    wire [3:0] phase_delta;
    wire [4:0] lane_plus_delta;
    wire [1:0] whole_word_advance;
    wire [2:0] updated_lane;
 
    assign output_transfer = m_axis_tvalid && m_axis_tready;
    assign output_slot_available = !m_axis_tvalid || m_axis_tready;
 
    assign s_axis_tready =
        axis_aresetn &&
        phase_initialized &&
        (
            (state == STATE_SKIP_WORD) ||
            (state == STATE_CAPTURE_FIRST) ||
            ((state == STATE_STREAM) && output_slot_available)
        );
 
    assign input_transfer = s_axis_tvalid && s_axis_tready;
 
    /* Compare against gpio_phase_seen, not active_phase.  This prevents an
     * incremented active phase from being overwritten by an unchanged GPIO
     * phase value. */
    assign direct_phase_change = phase_initialized && gpio_phase_valid && (gpio_phase != gpio_phase_seen);
 
    assign increment_rising_edge = phase_initialized && gpio_phase_increment && !gpio_phase_increment_d;
 
    assign phase_request_new = direct_phase_change || increment_rising_edge;
 
    /* If an increment arrives while another update is pending, increment the
     * pending target.  A direct GPIO phase change has priority. */
    assign increment_base_phase = phase_update_pending ? pending_phase : active_phase;
 
    // What phase is being requested right now? gpio_phase or pending_phase + 1 or active_phase + 1?
    assign requested_phase_now = direct_phase_change ? gpio_phase : (increment_base_phase + 4'd1);
 
    // Is there any phase update that still needs to be applied? Either a new request just arrived, or a previous request is still pending.
    assign phase_update_available = phase_request_new || phase_update_pending;
 
    // Newest request wins
    assign phase_to_apply = phase_request_new ? requested_phase_now : pending_phase;
 
    /* Direct phase changes are interpreted exactly like changing the phase of
     * the previous 1-of-16 selector: the stream moves forward by
     * (new_phase-old_phase) modulo 16 samples. */
    assign phase_delta = phase_to_apply - active_phase;
 
    /* How many words were crossed
       active_phase[2:0] is the lane number of the first sample in the current output word.
       phase_delta is the number of samples to advance.
     */
    assign lane_plus_delta = {2'b00, active_phase[2:0]} + {1'b0, phase_delta};
 
    assign whole_word_advance = lane_plus_delta[4:3];
 
    // New lane number within a word
    assign updated_lane       = lane_plus_delta[2:0];
 
    assign active_phase_mon         = active_phase;
    assign phase_initialized_mon    = phase_initialized;
    assign phase_update_pending_mon = phase_update_pending;
    assign state_mon                = state;
 
    function [127:0] align_words;
        input [127:0] older_word;
        input [127:0] newer_word;
        input [2:0]   lane;
 
        reg [255:0] combined_words;
        integer shift_bits;
 
        begin
            combined_words = {newer_word, older_word};
            shift_bits = lane * 16;
            // shifts out old samples and aligns the new samples to the output word, keeps lowest 128 bits of the result
            align_words = combined_words >> shift_bits;
        end
    endfunction
 
    always @(posedge axis_aclk) begin
        if (!axis_aresetn) begin
            state <= STATE_WAIT_PHASE;
 
            previous_word <= 128'd0;
 
            active_phase      <= 4'd0;
            phase_initialized <= 1'b0;
            gpio_phase_seen   <= 4'd0;
 
            gpio_phase_increment_d <= 1'b0;
 
            phase_update_pending <= 1'b0;
            pending_phase        <= 4'd0;
 
            m_axis_tdata  <= 128'd0;
            m_axis_tvalid <= 1'b0;
        end else begin
            gpio_phase_increment_d <= gpio_phase_increment;
 
            if (output_transfer) begin
                m_axis_tvalid <= 1'b0;
            end
 
            /* Remember a direct GPIO write immediately so that holding the
             * new value does not generate repeated requests. */
            if (direct_phase_change) begin
                gpio_phase_seen <= gpio_phase;
            end
 
            /* Queue the newest request.  If it is applied later in this same
             * clock, the STREAM branch below clears the pending flag. */
            if (phase_request_new) begin
                pending_phase        <= requested_phase_now;
                phase_update_pending <= 1'b1;
            end
 
            case (state)
                // Initial phase, do this while reset. Wait until the first valid phase is seen.
                STATE_WAIT_PHASE: begin
                    m_axis_tvalid       <= 1'b0;
                    phase_update_pending <= 1'b0;
 
                    if (gpio_phase_valid) begin
                        active_phase      <= gpio_phase;
                        gpio_phase_seen   <= gpio_phase;
                        phase_initialized <= 1'b1;
 
                        /* Phases 8-15 begin one complete 128-bit word later. */
                        if (gpio_phase[3]) begin
                            state <= STATE_SKIP_WORD;
                        end else begin
                            state <= STATE_CAPTURE_FIRST;
                        end
                    end
                end
 
                STATE_SKIP_WORD: begin
                    m_axis_tvalid <= 1'b0;
 
                    if (input_transfer) begin
                        state <= STATE_CAPTURE_FIRST;
                    end
                end
 
                STATE_CAPTURE_FIRST: begin
                    m_axis_tvalid <= 1'b0;
 
                    if (input_transfer) begin
                        previous_word <= s_axis_tdata;
                        state         <= STATE_STREAM;
                    end
                end
 
                STATE_STREAM: begin
                    if (input_transfer) begin
                        if (phase_update_available) begin
                            active_phase         <= phase_to_apply;
                            phase_update_pending <= 1'b0; 
 
                            case (whole_word_advance)
                                2'd0: begin
                                    /* The new start position is still inside
                                     * previous_word, so this input word completes
                                     * the shifted output immediately. */
                                    m_axis_tdata <= align_words(previous_word,s_axis_tdata,updated_lane);
                                    m_axis_tvalid <= 1'b1;
                                    previous_word <= s_axis_tdata;
                                end
 
                                2'd1: begin
                                    /* The new output begins inside the current
                                     * input word.  Save it and wait for one more
                                     * word to complete the 128-bit output. */
                                    previous_word <= s_axis_tdata;
                                    m_axis_tvalid <= 1'b0;
                                end
 
                                default: begin
                                    /* The requested phase moves forward by two
                                     * complete words relative to the normal next
                                     * output.  Discard the current word, capture
                                     * the following word, then resume streaming. */
                                    state <= STATE_CAPTURE_FIRST;
                                    m_axis_tvalid <= 1'b0;
                                end
                            endcase
                        end else begin
                            // No samples lost!
                            m_axis_tdata <= align_words(previous_word,s_axis_tdata,active_phase[2:0]);
                            m_axis_tvalid <= 1'b1;
                            previous_word <= s_axis_tdata;
                        end
                    end
                end
 
                // Protection against uninitialized states
                default: begin
                    state <= STATE_WAIT_PHASE;
 
                    previous_word <= 128'd0;
 
                    active_phase      <= 4'd0;
                    phase_initialized <= 1'b0;
                    gpio_phase_seen   <= 4'd0;
 
                    phase_update_pending <= 1'b0;
                    pending_phase        <= 4'd0;
 
                    m_axis_tdata  <= 128'd0;
                    m_axis_tvalid <= 1'b0;
                end
            endcase
        end
    end
 
endmodule