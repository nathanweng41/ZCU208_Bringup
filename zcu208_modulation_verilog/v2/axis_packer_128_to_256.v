`timescale 1ns / 1ps

module axis_packer_128_to_256 #(
    parameter integer S_DATA_WIDTH = 128,
    parameter integer M_DATA_WIDTH = 256
) (
    input wire                          axis_aclk,
    input wire                          axis_aresetn,

    input wire [S_DATA_WIDTH-1:0]       s_axis_tdata,
    input wire                          s_axis_tvalid,
    output wire                         s_axis_tready,

    output wire [M_DATA_WIDTH-1:0]      m_axis_tdata,
    output wire                         m_axis_tvalid,
    input wire                          m_axis_tready
);

    reg [S_DATA_WIDTH-1:0] first_word;
    reg                    first_word_valid;

    wire input_transfer;
    wire output_transfer;
    wire output_slot_available;

    assign output_transfer = m_axis_tvalid && m_axis_tready;

    // Can create/replace output when there is no current output waiting or current output is being accepted this clock
    assign output_slot_available = !m_axis_tvalid || m_axis_tready;

    assign s_axis_tready = axis_aresetn && (!first_word_valid || output_slot_available);

    assign input_transfer = s_axis_tvalid && s_axis_tready;

    always @(posedge axis_aclk) begin
        if(!axis_aresetn) begin

            first_word <= 0;
            first_word_valid <= 1'b0;

            m_axis_tdata <= 0;
            m_axis_tvalid <= 0;

        end else begin
            if (output_transfer) begin
                // clear valid once the output has been accepted, a new output may replace it later in this same clock
                m_axis_tvalid <= 1'b0;
            end

            if (input_transfer) begin
                if (!first_word_valid) begin
                    first_word <= s_axis_tdata;
                    first_word_valid <= 1'b1;
                end else if (output_slot_available) begin
                    m_axis_tdata <= {s_axis_tdata, first_word};
                    m_axis_tvalid <= 1'b1;
                    first_word_valid <= 1'b0;
                end
            end
        end
    end
endmodule


