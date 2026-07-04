`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//
// Nathan Weng 07/2026
//
// Input: 
// 	512-bit packed QPSK symbol word from uram_play_modulation_128k
//
// Packing convention:
// 	symbol 0 = s_axis_tdata[1:0]
// 	symbol 1 = s_axis_tdata[3:2]
// 	symbol 2 = s_axis_tdata[5:4]
// 	...
// 	symbol 255 = s_axis_tdata[511:510]
//
// Output:
// 	m_axis_tdata[1:0] = one QPSK symbol
// 	m_axis_tdata[7:2] = 0
//
// symbol_advance should pulse when downstream is ready for next QPSK symbol
//
//////////////////////////////////////////////////////////////////////////////////

//Make sure parameter and interface_parameter bram_size_bytes matches mem_size
//Make sure parameter and interface_parameter BRAM_CPU_DWIDTH matches MEM_WIDTH

//           parameter MEM_SIZE_BYTES = 32768

module qpsk_symbol_unpacker_axis (        

	 input wire axis_clk, 
	 
	 input wire axis_aresetn,
	 
	 input wire enable,
	 
	 // AXI-stream input: packed symbols from uramPlay modulation block
	 input wire [511:0]        s_axis_tdata,
	 input wire				   s_axis_tvalid,
	 output wire			   s_axis_tready,
	 
	 // Advance one symbol when downstream needs a new symbol
	 input wire symbol_advance,
	 
	 // AXI-stream output: one symbol code at a time
	 output reg [7:0]                 m_axis_tdata,
	 output reg						  m_axis_tvalid,
	 // m_axis_tready is present for AXIS compatability. 
	 // This block will be symbol-timed, so downstream should keep tready high.
	 input wire						  m_axis_tready,
	 
	 // Debug
	 output reg [7:0] symbol_idx,
	 output reg 	  word_loaded
   );
   
   localparam integer IN_WIDTH		   = 512;
   localparam integer BITS_PER_SYMBOL  = 2;
   localparam integer SYMBOLS_PER_WORD = IN_WIDTH / BITS_PER_SYMBOL;
   localparam integer IDX_WIDTH		   = 8;
   
   reg [IN_WIDTH-1:0] word_reg;
   
   // Last symbol before new word
   wire last_symbol;
   assign last_symbol = (symbol_idx == SYMBOLS_PER_WORD-1);
   
   // Accept a new packed word when:
   // 1. No word is currently loaded, OR
   // 2. We are advancing past the last symbol of the current word. 
   
   assign s_axis_tready = enable && ((!word_loaded) || (word_loaded && symbol_advance && last_symbol));
   
   wire new_word;
   assign new_word = s_axis_tvalid && s_axis_tready;
   
   // Current selected QPSK symbol from loaded word
   wire [BITS_PER_SYMBOL-1:0] current_symbol;
   assign current_symbol = word_reg[(symbol_idx)*BITS_PER_SYMBOL +: BITS_PER_SYMBOL];
   
   // Next symbol index
   wire [IDX_WIDTH-1:0] next_symbol_idx;
   assign next_symbol_idx = last_symbol ? {IDX_WIDTH{1'b0}} : symbol_idx + 1'b1;
   
   // Next selected QPSK symbol from loaded word
   wire [BITS_PER_SYMBOL-1:0] next_symbol;
   assign next_symbol = word_reg[next_symbol_idx*BITS_PER_SYMBOL +: BITS_PER_SYMBOL];
   
   // First QPSK symbol from incoming packed word
   wire [BITS_PER_SYMBOL-1:0] first_input_symbol;
   assign first_input_symbol = s_axis_tdata[BITS_PER_SYMBOL-1:0];
   
   wire unused_m_axis_tready;
   assign unused_m_axis_tready = m_axis_tready;
   
initial begin
    $display("*****************************************************");
    $display("XXXXXX QPSK_SYMBOL_UNPACKER IN_WIDTH                       = %d", IN_WIDTH);
    $display("XXXXXX QPSK_SYMBOL_UNPACKER BITS_PER_SYMBOL                = %d", BITS_PER_SYMBOL);
    $display("XXXXXX QPSK_SYMBOL_UNPACKER SYMBOLS_PER_WORD               = %d", SYMBOLS_PER_WORD);
	$display("XXXXXX QPSK_SYMBOL_UNPACKER IDX_WIDTH						= %d", IDX_WIDTH);
end

always @(posedge axis_clk) begin
	if (!axis_aresetn) begin
		word_reg		<= {IN_WIDTH{1'b0}};
		word_loaded 	<= 1'b0;
		symbol_idx  	<= {IDX_WIDTH{1'b0}};	
		m_axis_tdata 	<= 8'd0;
		m_axis_tvalid 	<= 1'b0;
	end else begin
		if (!enable) begin
			word_reg		<= {IN_WIDTH{1'b0}};
			word_loaded 	<= 1'b0;
			symbol_idx  	<= {IDX_WIDTH{1'b0}};
			m_axis_tdata	<= 8'd0;
			m_axis_tvalid	<= 1'b0;
		end else begin
			// Load new packed word if needed
			if (new_word) begin
				word_reg		<= s_axis_tdata;
				word_loaded		<= 1'b1;		
				symbol_idx		<= {IDX_WIDTH{1'b0}};
				m_axis_tdata	<= {{(8-BITS_PER_SYMBOL){1'b0}}, first_input_symbol};
				m_axis_tvalid 	<= 1'b1;
			end
			
			// Omit m_axis_tready here, Force tready=1 downstream. 
			else if (word_loaded && symbol_advance) begin
				if (last_symbol) begin
					word_loaded 	<= 1'b0;
					symbol_idx		<= {IDX_WIDTH{1'b0}};
					m_axis_tvalid 	<= 0;			
					m_axis_tdata    <= {{(8-BITS_PER_SYMBOL){1'b0}}, current_symbol};
				end else begin
					symbol_idx		<= symbol_idx + 1'b1;
					m_axis_tdata	<= {{(8-BITS_PER_SYMBOL){1'b0}}, next_symbol};
					m_axis_tvalid	<= 1;
				end
			end
		end
	end
end

endmodule