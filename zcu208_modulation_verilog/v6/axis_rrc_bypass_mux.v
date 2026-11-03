`timescale 1ns / 1ps

/*
 * RRC filter bypass mux
 *
 * bypass_rrc = 0: Send data through the RRC filter
 * bypass_rrc = 1: Bypass the RRC filter
 *
 * Set bypass_rrc before starting the data stream and keep it
 * unchanged while streaming.
 */

module axis_rrc_bypass_mux (

    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 axis_aclk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axis:rrc_s_axis:rrc_m_axis:m_axis, ASSOCIATED_RESET axis_aresetn, FREQ_HZ 20000000" *)
    input wire         axis_aclk,

    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 axis_aresetn RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input wire         axis_aresetn,

    // 0 = use RRC output
    // 1 = bypass RRC and use input data
    input wire         bypass_rrc,

    // Input from previous block
    input wire [15:0]  s_axis_tdata,
    input wire         s_axis_tvalid,
    output wire        s_axis_tready,

    // Output TO RRC filter
    output wire [15:0] rrc_s_axis_tdata,
    output wire        rrc_s_axis_tvalid,
    input wire         rrc_s_axis_tready,

    // Input FROM RRC filter
    input wire [15:0]  rrc_m_axis_tdata,
    input wire         rrc_m_axis_tvalid,
    output wire        rrc_m_axis_tready,

    // Output to next block
    output wire [15:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input wire         m_axis_tready
);

    // Input routing
    assign rrc_s_axis_tdata  = s_axis_tdata;
    assign rrc_s_axis_tvalid = s_axis_tvalid && !bypass_rrc;

    // Upstream ready depends on the selected path
    assign s_axis_tready = bypass_rrc
                         ? m_axis_tready
                         : rrc_s_axis_tready;

    // Output routing
    assign m_axis_tdata = bypass_rrc
                        ? s_axis_tdata
                        : rrc_m_axis_tdata;

    assign m_axis_tvalid = bypass_rrc
                         ? s_axis_tvalid
                         : rrc_m_axis_tvalid;

    // Accept RRC output only when the RRC path is selected
    assign rrc_m_axis_tready = !bypass_rrc && m_axis_tready;

endmodule