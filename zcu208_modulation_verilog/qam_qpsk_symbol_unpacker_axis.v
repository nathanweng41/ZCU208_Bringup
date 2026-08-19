`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//
// Nathan Weng 08/2026
//
// QPSK / 16-QAM Symbol Unpacker AXIS
//
// Input: 
// 	   512-bit packed QPSK/QAM symbol word from uram_play_modulation_128k
//
// mod_mode: 
//     0 = QPSK, 1 = 16-QAM
//
// Packing convention QPSK:
// 	   symbol 0 = s_axis_tdata[1:0]
// 	   symbol 1 = s_axis_tdata[3:2]
// 	   symbol 2 = s_axis_tdata[5:4]
// 	   ...
// 	   symbol 255 = s_axis_tdata[511:510]
//
// Packing convention 16-QAM:
// 	   symbol 0 = s_axis_tdata[3:0]
// 	   symbol 1 = s_axis_tdata[7:4]
// 	   symbol 2 = s_axis_tdata[11:8]
// 	   ...
// 	   symbol 127 = s_axis_tdata[511:508]
//
// Output:
// 	   m_axis_tdata[3:0] = one QPSK/QAM symbol
// 	   m_axis_tdata[7:4] = 0
//
// QAM AXIS Gray mapping:
//      00 -> +MAX
//      01 -> +INNER
//      11 -> -INNER
//      10 -> -MAX
//
// QPSK symbols are converted to the four outer QAM corners:
//
//      QPSK    QAM code      I       Q
//       00      0000        +MAX    +MAX
//       01      0010        -MAX    +MAX
//       11      1010        -MAX    -MAX
//       10      1000        +MAX    -MAX
//
// symbol_advance should pulse when downstream is ready for next QPSK symbol
//
//////////////////////////////////////////////////////////////////////////////////

//Make sure parameter and interface_parameter bram_size_bytes matches mem_size
//Make sure parameter and interface_parameter BRAM_CPU_DWIDTH matches MEM_WIDTH


module qam_qpsk_symbol_unpacker_axis (        

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

     input wire mod_mode, // 0 = QPSK, 1 = 16-QAM

     // Used by samples_per_symbol_counter to determine when a sample is accepted
     output wire sample_fire,
	 
	 // Debug
	 output reg [7:0] symbol_idx,
	 output reg 	  word_loaded
   );
   
   localparam integer IN_WIDTH		   = 512;
   localparam integer IDX_WIDTH		   = 8;
   
   localparam [7:0] QPSK_LAST_IDX = 8'd255;
   localparam [7:0] QAM_LAST_IDX  = 8'd127;

   reg [IN_WIDTH-1:0] word_reg;

   // Latch the modulation mode together with each word
   // Prevents a GPIO mode change from changing interpretation halfway through an already-loaded word
   reg word_mod_mode;

   function [3:0] qpsk_to_qam;
        input [1:0] qpsk_bits;
        begin
             case (qpsk_bits)
                2'b00: qpsk_to_qam = 4'b0000; // +MAX +MAX
                2'b01: qpsk_to_qam = 4'b0010; // -MAX +MAX
                2'b11: qpsk_to_qam = 4'b1010; // -MAX -MAX
                2'b10: qpsk_to_qam = 4'b1000; // +MAX -MAX
                default: qpsk_to_qam = 4'b0000;
             endcase
        end
   endfunction
   
   // Last symbol before new word
   wire last_symbol;
   assign last_symbol = word_mod_mode ? (symbol_idx == QAM_LAST_IDX) : (symbol_idx == QPSK_LAST_IDX);
   
   // Accept a new packed word when:
   // 1. No word is currently loaded, OR
   // 2. We are on the last symbol of the current word. 
   
   assign s_axis_tready = enable && ((!word_loaded) || (word_loaded && symbol_advance && last_symbol));
   
   wire new_word;
   assign new_word = s_axis_tvalid && s_axis_tready;
   
   /////////////////////////////////////////////////////////////////////
   // Symbol extraction from currently loaded word
   /////////////////////////////////////////////////////////////////////
  
   // QPSK extraction
   wire [1:0] current_qpsk_symbol;
   wire [1:0] next_qpsk_symbol;

   // QAM extraction
   wire [3:0] current_qam_symbol;
   wire [3:0] next_qam_symbol;

   // Next symbol index
   wire [IDX_WIDTH-1:0] next_symbol_idx;
   assign next_symbol_idx = last_symbol ? {IDX_WIDTH{1'b0}} : symbol_idx + 1'b1;

   // Current QPSK symbol:
   // 
   // idx 0 -> bits [1:0]
   // idx 1 -> bits [3:2]
   // ...
   assign current_qpsk_symbol = word_reg[symbol_idx*2 +: 2];

   assign next_qpsk_symbol = word_reg[next_symbol_idx*2 +: 2];

   // Current QAM symbol:
   //
   // idx 0 -> bits [3:0]
   // idx 1 -> bits [7:4]
   // ...

   assign current_qam_symbol = word_reg[symbol_idx*4 +: 4];
   assign next_qam_symbol = word_reg[next_symbol_idx*4 +: 4];

   /////////////////////////////////////////////////////////////////////
   // Convert selected symbol to 4-bit QAM mapper input
   /////////////////////////////////////////////////////////////////////
   
   wire [3:0] current_symbol;
   wire [3:0] next_symbol;

   assign current_symbol = word_mod_mode ? current_qam_symbol : qpsk_to_qam(current_qpsk_symbol);
   assign next_symbol = word_mod_mode ? next_qam_symbol : qpsk_to_qam(next_qpsk_symbol);

   /////////////////////////////////////////////////////////////////////
   // First symbol from incoming word
   //
   // Use current external modulation mode here 
   /////////////////////////////////////////////////////////////////////
   
   wire [1:0] first_input_qpsk_symbol;
   wire [3:0] first_input_qam_symbol;
   wire [3:0] first_input_symbol;

   assign first_input_qpsk_symbol = s_axis_tdata[1:0];
   assign first_input_qam_symbol = s_axis_tdata[3:0];

   assign first_input_symbol = mod_mode ? first_input_qam_symbol : qpsk_to_qam(first_input_qpsk_symbol);
   
   assign sample_fire = m_axis_tvalid && m_axis_tready;

initial begin
    $display("*****************************************************");
    $display("XXXXXX QAM_QPSK_SYMBOL_UNPACKER");
    $display("XXXXXX IN_WIDTH                       = %d", IN_WIDTH);
    $display("XXXXXX QPSK SYMBOLS/WORD              = %d", 256);
    $display("XXXXXX QAM SYMBOLS/WORD               = %d", 128);
	$display("XXXXXX IDX_WIDTH						= %d", IDX_WIDTH);
end

always @(posedge axis_clk) begin
	if (!axis_aresetn) begin
		word_reg		<= {IN_WIDTH{1'b0}};
		word_loaded 	<= 1'b0;
        word_mod_mode   <= 1'b0; // Default is QPSK

		symbol_idx  	<= {IDX_WIDTH{1'b0}};	
		m_axis_tdata 	<= 8'd0;
		m_axis_tvalid 	<= 1'b0;
	end else begin
		if (!enable) begin
			word_reg		<= {IN_WIDTH{1'b0}};
			word_loaded 	<= 1'b0;
            word_mod_mode   <= 1'b0; // Default is QPSK

			symbol_idx  	<= {IDX_WIDTH{1'b0}};
			m_axis_tdata	<= 8'd0;
			m_axis_tvalid	<= 1'b0;
		end else begin
			// Load new packed word if needed
			if (new_word) begin
				word_reg		<= s_axis_tdata;
				word_loaded		<= 1'b1;	

                word_mod_mode   <= mod_mode; // Latch the modulation mode with the word

				symbol_idx		<= {IDX_WIDTH{1'b0}};
				m_axis_tdata	<= {{4{1'b0}}, first_input_symbol};
				m_axis_tvalid 	<= 1'b1;
			end
			
			else if (word_loaded && symbol_advance) begin
				if (last_symbol) begin
					word_loaded 	<= 1'b0;
					symbol_idx		<= {IDX_WIDTH{1'b0}};
                    // Stop streaming since no new word
					m_axis_tvalid 	<= 0;			
					m_axis_tdata    <= 8'd0;
				end else begin
					symbol_idx		<= symbol_idx + 1'b1;
					m_axis_tdata	<= {{4{1'b0}}, next_symbol};
					m_axis_tvalid	<= 1;
				end
			end
		end
	end
end

endmodule