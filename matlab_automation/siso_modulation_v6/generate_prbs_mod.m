function [start_ptr, stop_ptr, fn, fp] = generate_prbs15_mod(mode, filedir, filename, seed, debug)
%GENERATE_PRBS15_MOD Generate exactly 32 KiB of packed PRBS15 symbols.
%
% Inputs:
%   mode      : "QPSK" or "16QAM"
%   filedir   : output directory
%   filename  : output .bin filename
%   seed      : PRBS15 initial state, 1 ... 0x7FFF
%   debug     : true/false
%
% Outputs:
%   start_ptr : playback start byte pointer
%   stop_ptr  : playback stop byte pointer
%   fn        : generated file path
%   fp        : metadata structure
%
% Packing:
%
% QPSK:
%   2 bits/symbol
%
%   word[1:0]   = symbol 0
%   word[3:2]   = symbol 1
%   ...
%   word[511:510] = symbol 255
%
% 16-QAM:
%   4 bits/symbol
%
%   word[3:0]   = symbol 0
%   word[7:4]   = symbol 1
%   ...
%   word[511:508] = symbol 127
%
% Within each symbol, the earliest PRBS bit becomes the LSB.
%
% PRBS15:
%   polynomial: x^15 + x^14 + 1
%   output bit: state(15)
%   feedback  : state(15) XOR state(14)

    %% ============================================================
    % Configuration
    % ============================================================

    mem_bytes = 32768;          % 32 KiB
    bits_per_byte = 8;

    word_bits = 512;
    word_bytes = word_bits / 8; % 64 bytes

    if nargin < 4 || isempty(seed)
        seed = 1;
    end

    if nargin < 5 || isempty(debug)
        debug = false;
    end

    mode = upper(string(mode));
    filedir = string(filedir);
    filename = string(filename);

    %% ============================================================
    % Modulation format
    % ============================================================

    switch mode

        case "QPSK"
            bits_per_symbol = 2;

        case {"16QAM", "16-QAM"}
            bits_per_symbol = 4;
            mode = "16QAM";

        otherwise
            error("mode must be 'QPSK' or '16QAM'.");
    end

    %% ============================================================
    % Validate seed
    % ============================================================

    seed = uint16(seed);

    if seed == 0 || seed > hex2dec("7FFF")
        error("PRBS15 seed must be between 1 and 0x7FFF.");
    end

    %% ============================================================
    % Sizes
    % ============================================================

    total_bits = mem_bytes * bits_per_byte;

    num_symbols = total_bits / bits_per_symbol;

    symbols_per_word = word_bits / bits_per_symbol;

    num_words = mem_bytes / word_bytes;

    %% ============================================================
    % Generate PRBS15 bitstream
    % ============================================================

    prbs = zeros(total_bits, 1, "uint8");

    state = seed;

    for k = 1:total_bits

        % Output MSB of 15-bit PRBS state
        out_bit = bitget(state, 15);

        prbs(k) = uint8(out_bit);

        % x^15 + x^14 + 1
        feedback = xor(bitget(state, 15), bitget(state, 14));

        % Shift toward MSB:
        %
        % Verilog equivalent:
        % state <= {state[13:0], feedback};
        %
        state = bitand(bitshift(state, 1), uint16(hex2dec("7FFF")));

        if feedback
            state = bitor(state, uint16(1));
        end
    end

    %% ============================================================
    % Pack PRBS bits into bytes
    %
    % First PRBS bit -> bit 0 of byte 0
    % Second bit     -> bit 1 of byte 0
    % ...
    %
    % Therefore:
    %
    % QPSK:
    %   first 2 PRBS bits -> byte[1:0]
    %
    % 16QAM:
    %   first 4 PRBS bits -> byte[3:0]
    %
    % ============================================================

    packed = zeros(mem_bytes, 1, "uint8");

    for byteIdx = 1:mem_bytes

        byteValue = uint8(0);

        bitBase = (byteIdx - 1) * 8;

        for b = 0:7

            if prbs(bitBase + b + 1)
                byteValue = bitor( ...
                    byteValue, ...
                    bitshift(uint8(1), b));
            end
        end

        packed(byteIdx) = byteValue;
    end

    %% ============================================================
    % Pointers
    % ============================================================

    start_ptr = uint32(0);

    % Last 512-bit word starts 64 bytes before end of BRAM
    stop_ptr = uint32(mem_bytes - word_bytes);

    %% ============================================================
    % Output filename
    % ============================================================

    if ~isfolder(filedir)
        mkdir(filedir);
    end

    [pathPart, ~, ~] = fileparts(filename);

    if strlength(pathPart) == 0
        fn = fullfile(filedir, filename);
    else
        fn = filename;
    end

    %% ============================================================
    % Write binary file
    % ============================================================

    fid = fopen(fn, "w");

    if fid < 0
        error("Could not open %s for writing.", fn);
    end

    cleanupObj = onCleanup(@() fclose(fid));

    fwrite(fid, packed, "uint8");

    %% ============================================================
    % Metadata
    % ============================================================

    fp = struct();

    fp.mode = mode;

    fp.mem_bytes = mem_bytes;
    fp.word_bits = word_bits;
    fp.word_bytes = word_bytes;

    fp.bits_per_symbol = bits_per_symbol;
    fp.num_symbols = num_symbols;
    fp.symbols_per_word = symbols_per_word;
    fp.num_words = num_words;

    fp.total_bits = total_bits;

    fp.seed = seed;

    fp.start_ptr = start_ptr;
    fp.stop_ptr = stop_ptr;

    %% ============================================================
    % Debug
    % ============================================================

    if debug

        fprintf("PRBS15 modulation file generated\n");
        fprintf("--------------------------------\n");
        fprintf("Mode              : %s\n", mode);
        fprintf("File              : %s\n", fn);

        fprintf("Buffer size       : %d bytes\n", mem_bytes);
        fprintf("Words             : %d\n", num_words);

        fprintf("Bits/symbol       : %d\n", bits_per_symbol);
        fprintf("Symbols/word      : %d\n", symbols_per_word);
        fprintf("Total symbols     : %d\n", num_symbols);

        fprintf("Seed              : 0x%04X\n", seed);

        fprintf("Start ptr         : 0x%08X\n", start_ptr);
        fprintf("Stop ptr          : 0x%08X\n", stop_ptr);

        fprintf("\nFirst 16 bytes:\n");

        for k = 1:min(16, length(packed))
            fprintf("%02X ", packed(k));
        end

        fprintf("\n");
    end
end