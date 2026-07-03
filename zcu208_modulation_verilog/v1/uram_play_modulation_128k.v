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
// 
//////////////////////////////////////////////////////////////////////////////////

//Make sure parameter and interface_parameter bram_size_bytes matches mem_size
//Make sure parameter and interface_parameter BRAM_CPU_DWIDTH matches MEM_WIDTH

//           parameter MEM_SIZE_BYTES = 32768

module uram_play_modulation_128k #(
           parameter DWIDTH = 512,
           parameter MEM_SIZE_BYTES = 131072
       ) (        

     (* X_INTERFACE_PARAMETER = "MASTER_TYPE BRAM_CTRL, READ_WRITE_MODE READ, MEM_SIZE 131072, MEM_WIDTH 512" *)

     (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_A DIN" *)
     output wire [DWIDTH-1:0] portA_cpu_wdata, // Data In Bus (optional) 0-511

     (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_A WE" *) 
     output [DWIDTH/8-1:0] portA_we, // Byte Enables (optional) 0-63
   
     (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_A EN" *)
     output reg portA_en, // Chip Enable Signal (optional) 
   
     (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_A DOUT" *)
     input wire [DWIDTH-1:0] portA_cpu_rdata, // Data Out Bus (optional) 0-511
   
     (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_A ADDR" *)
     output reg [31:0] portAcpu_addr, // Address Signal (required)
   
     (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_A CLK" *)
     output wire portA_clk, // Clock Signal (required)
   
     (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_A RST" *)
     output wire portA_rst, // Reset Signal (required)

     input wire axis_clk,
	 
     input  wire  axis_aresetn,

     output wire  [DWIDTH-1:0] axis_tdata,
	 
     input wire                axis_tready,
	 
     output wire               axis_tvalid,

     input wire                   enable,
	 
	 input wire [31:0] start_addr,
	 
	 input wire [31:0] stop_addr

   );
   
   localparam URAM_AWIDTH = $clog2(MEM_SIZE_BYTES/(DWIDTH/8));
   
initial begin
    $display("*****************************************************");
    $display("XXXXXX URAM_AWIDTH                       = %d", URAM_AWIDTH);
    $display("XXXXXX MEM_SIZE_BYTES/(DWIDTH/8)         = %d", MEM_SIZE_BYTES/(DWIDTH/8));
    $display("XXXXXX $clog2(MEM_SIZE_BYTES/(DWIDTH/8)) = %d", $clog2(MEM_SIZE_BYTES/(DWIDTH/8)));
end

  reg [DWIDTH-1:0] reg_axis_tdata;
  reg              reg_axis_tvalid;

  assign portA_cpu_wdata = 0;
  assign portA_we = 0; // do not write here, only READ from BRAM

  assign portA_clk = axis_clk;
  assign portA_rst = ~axis_aresetn;
  
  assign axis_tvalid = reg_axis_tvalid;
  assign axis_tdata = reg_axis_tdata;
  
  wire axis_fire;
  assign axis_fire = reg_axis_tvalid && axis_tready;
  
  // FSM
  localparam ST_IDLE	= 2'd0;
  localparam ST_WAIT 	= 2'd1;
  localparam ST_CAPTURE = 2'd2;
  localparam ST_HOLD	= 2'd3;
  
  reg [1:0] state;
  
  always @(posedge axis_clk) begin
	if (!axis_aresetn) begin
		state			<= ST_IDLE;
		
		reg_axis_tdata	<= 0;
		reg_axis_tvalid <= 0;
		
		portAcpu_addr 	<= start_addr;
		portA_en		<= 1'b0;
		
	end else begin
	
        if (enable == 1'b1) begin
                case (state)
                
                    // First enable BRAM read
                    ST_IDLE: begin
                        reg_axis_tvalid		<= 1'b0;
                        portAcpu_addr		<= start_addr;
                        portA_en			<= 1'b1;
                        state				<= ST_WAIT;
                    end
					
					ST_WAIT: begin
						reg_axis_tvalid		<= 1'b0;
						portA_en			<= 1'b1;
						state				<= ST_CAPTURE;
					end
					
                    // Capture BRAM data after read latency (1 clock after portA_en)
                    ST_CAPTURE: begin
                        reg_axis_tdata		<= portA_cpu_rdata;
                        reg_axis_tvalid		<= 1'b1;
                        portA_en            <= 1'b1;
                        state				<= ST_HOLD;
                    end
                    
                    // Continuously output current 512-bit word until downstream accepts
                    ST_HOLD: begin
                        portA_en			<= 1'b1;
                        reg_axis_tvalid		<= 1'b1;
                        
                        if (axis_fire) begin
                            // Current 512 bit word was accepted downstream
                            // Now advance address and request next BRAM word
                            reg_axis_tvalid <= 1'b0;
                            
                            if (portAcpu_addr == stop_addr) begin
                                portAcpu_addr <= start_addr;
                            end else begin
                                portAcpu_addr <= portAcpu_addr + DWIDTH/8; // +64 bytes for 512 bits
                            end
							
                            portA_en <= 1'b1;
                            state	 <= ST_WAIT;
                        end
                    end
                    
                    default: begin
                        state				<= ST_IDLE;
                    end
                endcase
				
        end	else begin
                state		    <= ST_IDLE;
                
                reg_axis_tdata	<= 0;
                reg_axis_tvalid <= 0;
                
                portAcpu_addr 	<= start_addr;
                portA_en		<= 1'b0;
        end
        
    end
    
  end
endmodule