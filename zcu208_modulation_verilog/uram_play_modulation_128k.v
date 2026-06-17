`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Nathan Weng 06/2026
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
  localparam ST_CAPTURE = 2'd1;
  localparam ST_HOLD	= 2'd2;
  
  reg [1:0] state;
  
  always @(posedge axis_clk) begin
	if (!axis_aresetn) begin
		state			<= ST_IDLE;
		
		reg_axis_tdata	<= 0;
		reg_axis_tvalid <= 0;
		
		portAcpu_addr 	<= start_addr;
		portA_en		<= 1'b0;
		
	end else begin
		
		if (!enable) begin
			state		<= ST_IDLE;
			
			reg_axis_tdata	<= 0;
			reg_axis_tvalid <= 0;
			
			portAcpu_addr 	<= start_addr;
			portA_en		<= 1'b0;
			
		end else begin
			
			case (state)
			
				// First enable BRAM read
				ST_IDLE: begin
					reg_axis_tvalid		<= 1'b0;
					portAcpu_addr		<= start_addr;
					portA_en			<= 1'b1;
					state				<= ST_CAPTURE;
				end
				// Capture BRAM data after read latency (1 clock after portA_en)
				ST_CAPTURE: begin
					reg_axis_tdata		<= portA_cpu_rdata;
					reg_axis_tvalid		<= 1'b1;
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
						state	 <= ST_CAPTURE;
					end
				end
				
				default: begin
					state				<= ST_IDLE;
				end
				
			endcase
		end
	end
  end
  
endmodule