//-----------------------------------------------------------------------------
//
// (c) Copyright 2020-2024 Advanced Micro Devices, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of AMD and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// AMD, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND AMD HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) AMD shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or AMD had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// AMD products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of AMD products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
//
//-----------------------------------------------------------------------------


`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/07/2018 11:37:21 PM
// Design Name: 
// Module Name: uram_capture_128k
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.04 - Build capture for 10 MSPS on a 20-MHz clock. Need TVALID to control each BRAM write and address increment.
// Revision 0.03 - Added pipeline between axis tdata/tvalid in and both bram data
//                 and passthrough tdata/tvalid out
// Revision 0.02 - Removed bram instantiation and added interface to connect to
//                 IPI memory block
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

//Make sure parameter DWIDTH and interface_parameter MEM_WIDTH matche

module uram_capture_128k #(
    parameter DWIDTH = 16,
    
    parameter MEM_SIZE_BYTES = 131072
) (        
    (* X_INTERFACE_PARAMETER = "MASTER_TYPE BRAM_CTRL, READ_WRITE_MODE READ_WRITE, MEM_SIZE 131072, MEM_WIDTH 32" *)

    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTA DIN" *)
    output wire [31:0] bram_wdata, // Data In Bus (optional), 32 bits of data write

    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTA WE" *)
    output wire [3:0] bram_we, // Byte Enables (optional), 4 bytes
  
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTA EN" *)
    output wire bram_en, // Chip Enable Signal (optional)
  
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTA DOUT" *)
    input wire [31:0] bram_rdata, // Data Out Bus (optional)
  
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTA ADDR" *)
    output wire [31:0] bram_addr, // Address Signal (required)
  
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTA CLK" *)
    output wire bram_clk, // Clock Signal (required)
  
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTA RST" *)
    output wire bram_rst, // Reset Signal (required)

    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 axis_clk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF CAP_AXIS:PASSTHROUGH_AXIS, ASSOCIATED_RESET axis_aresetn" *)
    input wire axis_clk,

    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 axis_aresetn RST" *)
    input  wire              axis_aresetn,

    input  wire  [DWIDTH-1:0] CAP_AXIS_tdata,
    output wire               CAP_AXIS_tready,
    input  wire               CAP_AXIS_tvalid,

    output reg  [DWIDTH-1:0]  PASSTHROUGH_AXIS_tdata,
    input  wire               PASSTHROUGH_AXIS_tready,
    output reg                PASSTHROUGH_AXIS_tvalid,

    input  wire               trig_cap,
    
    output wire [1:0]         trig_cap_p_2to1_mon
);
   
    // BRAM interface is now 32 bits --> 4 bytes per word
    localparam BRAM_ADDR_INC = 4; // 4 bytes address increment
    localparam CAP_SIZE = MEM_SIZE_BYTES;
    
    (* ASYNC_REG="TRUE" *) reg [2:0] trig_cap_p;

    wire                             trig_cap_rise;

    assign                           trig_cap_rise = (trig_cap_p[2:1] == 2'b01);

    assign                           trig_cap_p_2to1_mon = trig_cap_p[2:1]; // Debug signal for ILA

    // Sample packing
    // first_sample holds the earlier of the two consecutive valid ADC samples.
    // bram_wdata[15:0] = earlier sample
    // bram_wdata[31:16] = later sample

    reg [15:0]                       first_sample;
    reg                              half_full;

    // BRAM output pipeline
    reg [31:0]                       cap_data_p;
    reg                              cap_valid_p;
    reg [31:0]                       cap_addr_p;

    reg [31:0]                       next_addr;
    reg                              capture_active;

    
    assign bram_clk = axis_clk;
    assign bram_rst = ~axis_aresetn;
    assign bram_en  = cap_valid_p;

    assign bram_wdata = cap_data_p;
    assign bram_addr  = cap_addr_p;

    // we is for per word (8b)
    assign bram_we = cap_valid_p ? 4'b1111 : 4'b0000; // Write enable for all bytes when valid
    
    // Capture block never backpressures ADC stream
    assign CAP_AXIS_tready = 1'b1;

    // Passthrough for ILA debug
    always @(posedge axis_clk)
    begin
        PASSTHROUGH_AXIS_tdata  <= CAP_AXIS_tdata;
        PASSTHROUGH_AXIS_tvalid <= CAP_AXIS_tvalid;
    end

    //sync trig_cap to cap_clk and add bit for rising pulse detect
    always @(posedge axis_clk)
	begin
		if (!axis_aresetn) begin
            cap_data_p      <= 32'd0;
            cap_valid_p     <= 1'b0;
            cap_addr_p      <= 32'd0;

            next_addr       <= 32'd0;
            capture_active  <= 1'b0;
		    trig_cap_p      <= 3'b000;

            first_sample    <= 16'd0;
            half_full       <= 1'b0;
		end else begin

            // Synchronize asynchronous capture trigger
            trig_cap_p[2:0] <= {trig_cap_p[1:0], trig_cap};
            // Default: no BRAM write generated for next cycle
            cap_valid_p     <= 1'b0;

            // Do not capture CAP_AXIS_tdata on the trigger-detection cycle. Only after the trigger has been detected, capture the next 2 samples. This is to avoid capturing a partial sample on the trigger cycle.
            if(trig_cap_rise) begin
                next_addr      <= 32'd0;
                capture_active <= 1'b1;
                half_full      <= 1'b0;
            end

            else if (capture_active && CAP_AXIS_tvalid) begin
                if (!half_full) begin
                    first_sample <= CAP_AXIS_tdata;
                    half_full    <= 1'b1;
                end else begin
                    cap_data_p   <= {CAP_AXIS_tdata, first_sample};
                    cap_valid_p  <= 1'b1;
                    cap_addr_p   <= next_addr;

                    half_full    <= 1'b0; // Reset half_full for next pair of samples

                    if(next_addr < CAP_SIZE-BRAM_ADDR_INC) begin
                        next_addr <= next_addr + BRAM_ADDR_INC;
                    end else begin
                        // Last 32-bit word has been formed
                        capture_active <= 1'b0;
                    end
                end
            end
		end
	end

endmodule
