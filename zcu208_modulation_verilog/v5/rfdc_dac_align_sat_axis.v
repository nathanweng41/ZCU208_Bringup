`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//
// Nathan Weng 08/2026
// RFDC DAC Align + Saturation AXIS
//
// Purpose:
//   Convert internal signed DAC-code units to the RFDC's
//   16-bit MSB-aligned DAC format.
//
// Input:
//   8 complex samples / AXIS beat
//   Each I/Q component is signed 16-bit:
//
//   [ 15:  0] = I0
//   [ 31: 16] = Q0
//   [ 47: 32] = I1
//   [ 63: 48] = Q1
//        ...
//   [239:224] = I7
//   [255:240] = Q7
//
// Operation per component:
//
//        native DAC code
//             x
//             |
//            << 2
//             |
//       saturate to RFDC
//       16-bit aligned range
//
// Native safe input range:
//      -8192 ... +8191
//
// RFDC aligned output range:
//      -32768 ... +32764
//
// Examples:
//       5500 -> 22000
//      -5500 -> -22000
//       8191 -> 32764
//      -8192 -> -32768
//
// Any unexpected over-range sample is saturated.
//
//////////////////////////////////////////////////////////////////////////////////

module rfdc_dac_align_sat_axis (

    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 axis_aclk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axis:m_axis, FREQ_HZ 20000000" *)
    input wire axis_aclk,

    input  wire [255:0] s_axis_tdata,
    input  wire         s_axis_tvalid,
    output wire         s_axis_tready,

    output wire [255:0] m_axis_tdata,
    output wire         m_axis_tvalid,
    input  wire         m_axis_tready
);


    // ------------------------------------------------------------
    // Shift one signed sample by 2 and saturate.
    //
    // Important:
    //   Use an 18-bit intermediate so the <<2 cannot overflow
    //   before the saturation comparison.
    // ------------------------------------------------------------

    function automatic signed [15:0] align_and_saturate;
        input signed [15:0] x;

        reg signed [17:0] shifted;

        begin

            // Sign-extend first, THEN shift.
            shifted = $signed({{2{x[15]}}, x}) <<< 2;

            if (shifted > 18'sd32764)
                align_and_saturate = 16'sh7FFC; // 32764

            else if (shifted < -18'sd32768)
                align_and_saturate = 16'sh8000; // -32768;

            else
                align_and_saturate = shifted[15:0];

        end
    endfunction


    // ------------------------------------------------------------
    // AXIS handshake
    // ------------------------------------------------------------

    assign s_axis_tready = m_axis_tready;
    assign m_axis_tvalid = s_axis_tvalid;


    // ------------------------------------------------------------
    // Process all 8 complex samples
    // ------------------------------------------------------------

    genvar lane;

    generate

        for (lane = 0; lane < 8; lane = lane + 1) begin : GEN_DAC_ALIGN

            wire signed [15:0] i_in;
            wire signed [15:0] q_in;

            wire signed [15:0] i_out;
            wire signed [15:0] q_out;


            assign i_in =
                $signed(s_axis_tdata[lane*32 +: 16]);

            assign q_in =
                $signed(s_axis_tdata[lane*32 + 16 +: 16]);


            assign i_out = align_and_saturate(i_in);
            assign q_out = align_and_saturate(q_in);


            assign m_axis_tdata[lane*32 +: 16] =
                i_out;

            assign m_axis_tdata[lane*32 + 16 +: 16] =
                q_out;

        end

    endgenerate


endmodule