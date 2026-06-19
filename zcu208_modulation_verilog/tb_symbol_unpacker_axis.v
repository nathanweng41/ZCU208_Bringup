`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Nathan Weng
// 
// Create Date: 06/18/2026 04:22:53 PM
// Design Name: 
// Module Name: tb_symbol_unpacker_axis
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_symbol_unpacker_axis;
	
	// Use smaller width for simulation waveforms
	localparam int IN_WIDTH = 16;
	localparam int BITS_PER_SYMBOL = 1;
	localparam int SYMBOLS_PER_WORD = IN_WIDTH / BITS_PER_SYMBOL;
	localparam int IDX_WIDTH = $clog2(SYMBOLS_PER_WORD);
	
	// ---- clocks / resets ----
	logic axis_clk	    = 1'b0;
	logic axis_aresetn  = 1'b0;
	logic enable 		= 1'b0;
	
	always #5 axis_clk = ~axis_clk;
	
	// ---- axis input from simulated uramPlay ----
	logic [IN_WIDTH-1:0] s_axis_tdata;
	logic 				 s_axis_tvalid;
	wire				 s_axis_tready;
	
	logic symbol_advance;
	
	// ---- output symbol stream ----
	wire [7:0] m_axis_tdata;
	wire	   m_axis_tvalid;
	logic	   m_axis_tready = 1'b1;
	
	// Debug outputs
	wire [IDX_WIDTH-1:0] symbol_idx;
	wire				 word_loaded;
	
    symbol_unpacker_axis #(
        .IN_WIDTH(IN_WIDTH),
		.BITS_PER_SYMBOL(BITS_PER_SYMBOL),
		.IDX_WIDTH(IDX_WIDTH)
     ) dut (
		.axis_clk(axis_clk),
		.axis_aresetn(axis_aresetn),
		.enable(enable),
		.s_axis_tdata(s_axis_tdata),
		.s_axis_tvalid(s_axis_tvalid),
		.s_axis_tready(s_axis_tready),
		.symbol_advance(symbol_advance),
		.m_axis_tdata(m_axis_tdata),
		.m_axis_tvalid(m_axis_tvalid),
		.m_axis_tready(m_axis_tready),
		.symbol_idx(symbol_idx),
		.word_loaded(word_loaded)
	 );
	
	logic [IN_WIDTH-1:0] word0;
	logic [IN_WIDTH-1:0] word1;
	
	task automatic load_word(input logic [IN_WIDTH-1:0] word);
		begin
			@(negedge axis_clk);
			s_axis_tdata  = word;
			s_axis_tvalid = 1'b1;
			
			wait(s_axis_tready == 1'b1);
			
			@(posedge axis_clk);
			#1;
			
			s_axis_tvalid = 1'b0;
		end
	endtask
	
    task automatic pulse_advance();
        begin
            @(negedge axis_clk);
            symbol_advance = 1'b1;

            @(posedge axis_clk);
            #1;

            symbol_advance = 1'b0;
        end
    endtask

    task automatic check_symbol(
        input int idx,
        input logic expected_bit
    );
        begin
            assert(m_axis_tvalid == 1'b1)
                else $fatal("FAIL: idx=%0d m_axis_tvalid=0", idx);

            assert(m_axis_tdata[0] == expected_bit)
                else $fatal("FAIL: idx=%0d got=%0b expected=%0b m_axis_tdata=%h", idx, m_axis_tdata[0], expected_bit, m_axis_tdata);

            assert(symbol_idx == idx)
                else $fatal("FAIL: symbol_idx got=%0d expected=%0d", symbol_idx, idx);

            $display("PASS idx=%0d bit=%0b valid=%0b ready=%0b", symbol_idx, m_axis_tdata[0], m_axis_tvalid, s_axis_tready);
        end
    endtask
	
	initial begin	
		$display(" ==== TB symbol_unpacker_axis START ==== ");
		
		// initial values
		s_axis_tdata   = 0;
		s_axis_tvalid  = 0;
		symbol_advance = 0;
		
		// build test words (16 bits)
		for (int i = 0; i < IN_WIDTH; i++) begin
			word0[i] = i % 2; 			// 0, 1, 0, 1...
			word1[i] = (i % 3) == 0; 	// 1, 0, 0, 1, 0, 0, 1...
		end
		
		// reset
		repeat (3) @(posedge axis_clk);
		
		@(negedge axis_clk);
		axis_aresetn	= 1;
		enable			= 1;
	
		// test 1 - load first word
		load_word(word0);
		
		assert(word_loaded == 1'b1)
			else $fatal("FAIL: word_loaded not set after load");
		
		check_symbol(0, word0[0]);
		
		// test 2 - advance through symbols 1 to 14
		for (int i = 1; i < SYMBOLS_PER_WORD-1; i++) begin
			pulse_advance();
			check_symbol(i, word0[i]);
		end
		
		assert(symbol_idx == SYMBOLS_PER_WORD-2)
			else $fatal("FAIL: expected idx=%0d got=%0d", SYMBOLS_PER_WORD-2, symbol_idx);
		
		// advance to last symbol
		pulse_advance();
		check_symbol(SYMBOLS_PER_WORD-1, word0[SYMBOLS_PER_WORD-1]);
		
		// test 3 - last symbol, present new word
		@(negedge axis_clk);
		s_axis_tdata   = word1;
		s_axis_tvalid  = 1;
		symbol_advance = 1;
		
		@(posedge axis_clk);
		#1;
		
		s_axis_tvalid = 1'b0;
		symbol_advance = 1'b0;
		
		// should be immediately at word1 symbol 0
		assert(word_loaded == 1'b1)
			else $fatal("FAIL: word1 not loaded at boundary");
		
		check_symbol(0, word1[0]);
		
		// advance a few symbols in word1
		for (int i = 1; i < 5; i++) begin
			pulse_advance();
			check_symbol(i, word1[i]);
		end
		
		// test 4 - no next word available after final symbol. Finish word1 with s_axis_tvalid low. After last symbol advances, m_axis_tvalid should clear. 
		
		for (int i = 5; i < SYMBOLS_PER_WORD; i++) begin
			pulse_advance();
			
			if (i < SYMBOLS_PER_WORD-1) begin
				check_symbol(i, word1[i]);
			end
		end
		
		@(negedge axis_clk);
		s_axis_tvalid  = 0;
		symbol_advance = 1;
		
		@(posedge axis_clk);
		#1;
		
		symbol_advance = 0;
		
        assert(word_loaded == 1'b0)
            else $fatal("FAIL: word_loaded should clear when no next word exists");

        assert(m_axis_tvalid == 1'b0)
            else $fatal("FAIL: m_axis_tvalid should clear when word finishes and no next word exists");

        assert(s_axis_tready == 1'b1)
            else $fatal("FAIL: s_axis_tready should be high when no word is loaded");

        $display("PASS final no-next-word behavior");

        $display("==== TB symbol_unpacker_axis PASS ====");
        $finish;		
		
	end
	
	
endmodule