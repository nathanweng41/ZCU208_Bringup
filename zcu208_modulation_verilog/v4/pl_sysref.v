`timescale 1ns / 1ps

module pl_sysref (

    (* X_INTERFACE_INFO =
       "xilinx.com:interface:diff_clock:1.0 pl_sysref CLK_P" *)
    input wire pl_sysref_p,

    (* X_INTERFACE_INFO =
       "xilinx.com:interface:diff_clock:1.0 pl_sysref CLK_N" *)
    input wire pl_sysref_n,

    // Common PL clock used to capture SYSREF.
    // Example: 640 MHz from CLK104.
    input wire pl_clk_buf,

    // RFDC AXIS clocks derived from the same PL clock source
    input wire pl_clk_adc,     // 160 MHz
    input wire pl_clk_dac,     // 20 MHz

    input wire resetn,

    // Must be synchronous to the corresponding RFDC AXIS clocks
    output reg user_sysref_adc,
    output reg user_sysref_dac
);

    wire pl_sysref_i;

    reg pl_sysref_captured;

    ////////////////////////////////////////////////////////////////
    // Differential SYSREF input
    ////////////////////////////////////////////////////////////////

    IBUFDS IBUFDS_sysref_inst (
        .O  (pl_sysref_i),
        .I  (pl_sysref_p),
        .IB (pl_sysref_n)
    );


    ////////////////////////////////////////////////////////////////
    // Capture SYSREF using common PL clock
    //
    // Example:
    //     pl_clk_buf = 640 MHz
    ////////////////////////////////////////////////////////////////

    always @(posedge pl_clk_buf) begin
        if (!resetn)
            pl_sysref_captured <= 1'b0;
        else
            pl_sysref_captured <= pl_sysref_i;
    end


    ////////////////////////////////////////////////////////////////
    // Retiming into RF-ADC AXIS domain
    //
    // ADC AXIS = 160 MHz
    ////////////////////////////////////////////////////////////////

    always @(posedge pl_clk_adc) begin
        if (!resetn)
            user_sysref_adc <= 1'b0;
        else
            user_sysref_adc <= pl_sysref_captured;
    end


    ////////////////////////////////////////////////////////////////
    // Retiming into RF-DAC AXIS domain
    //
    // DAC AXIS = 20 MHz
    ////////////////////////////////////////////////////////////////

    always @(posedge pl_clk_dac) begin
        if (!resetn)
            user_sysref_dac <= 1'b0;
        else
            user_sysref_dac <= pl_sysref_captured;
    end

endmodule