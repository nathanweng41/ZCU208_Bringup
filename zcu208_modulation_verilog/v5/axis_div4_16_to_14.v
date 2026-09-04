`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//
// Nathan Weng 08/2026
// AXIS Divide-by-4 / 16-bit to 14-bit Scale
//
// Purpose:
//   Scale signed 16-bit RX sample by 1/4 before RX RRC.
//
// Input:
//   signed 16-bit sample
//
// Operation:
//   arithmetic right shift by 2
//
// Output numerical range:
//   -8192 ... +8191
//
// AXIS output remains 16 bits wide for byte alignment.
// The 14-bit result is sign-extended into the 16-bit AXIS slot.
//
// FIR Compiler configured for 14-bit input will use:
//   m_axis_tdata[13:0]
//
// Examples:
//    22000 ->  5500
//   -22000 -> -5500
//    32767 ->  8191
//   -32768 -> -8192
//
//////////////////////////////////////////////////////////////////////////////////

module axis_div4_16_to_14 (

    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 axis_aclk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axis:m_axis, FREQ_HZ 20000000" *)
    input wire axis_aclk,

    input  wire [15:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,

    output wire [15:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready
);

    wire signed [15:0] input_sample;
    wire signed [13:0] scaled_sample;

    // Interpret incoming sample as signed two's complement.
    assign input_sample = $signed(s_axis_tdata);

    // Arithmetic divide by 4.
    //
    // Because input_sample is signed, >>> preserves the sign bit.
    // Result always fits exactly within signed 14-bit range.
    assign scaled_sample = input_sample >>> 2;

    // Sign-extend 14-bit result back into the 16-bit AXIS slot.
    assign m_axis_tdata = {{2{scaled_sample[13]}}, scaled_sample};

    // Combinational AXIS passthrough.
    assign s_axis_tready = m_axis_tready;
    assign m_axis_tvalid = s_axis_tvalid;

endmodule