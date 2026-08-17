%% generate_qpsk_transition_patterns.m
%
% Generates three 128KB QPSK symbol files
% 
% Symbol mapping:
%   00 -> +I, +Q -> 45 degrees
%   01 -> -I, +Q -> 135 degrees
%   11 -> -I, -Q -> -135 degrees
%   10 -> +I, -Q -> -45 degrees
%
% Settings to run at
% NCO frequency: 1MHz
% Symbol period: 1600
% Symbol rate: 100 KSym/s
% Symbol duration: 10us
% Carrier cycles/symbol: 10
% 
clear;
clc;


file_size_bytes = 128*1024;

patterns = {
    uint8([0 1 3 2]), 'qpsk_ccw_00_01_11_10.bin';
    uint8([0 2 3 1]), 'qpsk_cw_00_10_11_01.bin';
    uint8([0 1 2 3]), 'qpsk_mixed_00_01_10_11.bin';
}

for k = 1:size(patterns,1)
    symbols = patterns{k, 1};
    filename = patterns{k, 2};

    % Pack four 2-bit symbols into one byte, LSB-first. 
    packed_byte = bitshift(symbols(1), 0) + bitshift(symbols(2), 2) + bitshift(symbols(3), 4) + bitshift(symbols(4), 6);

    output_data = repmat(uint8(packed_byte), file_size_bytes, 1);

    fid = fopen(filename, 'wb');

    if fid == -1
        error('Unable to open %s.', filename);
    end

    bytes_written = fwrite(fid, output_data, 'uint8');
    fclose(fid);

    if bytes_written ~= file_size_bytes
        error('Incorrect # of bytes written to %s.', filename);
    end

    fprintf('%s\n', filename);
    fprintf('   Symbol values: %d %d %d %d\n', symbols(1), symbols(2), symbols(3), symbols(4));
    fprintf('   Packed byte: 0x%02X\n', packed_byte);
    fprintf('   File size:  %d bytes\n\n', bytes_written);
end


% Expected output:
%
% qpsk_ccw_00_01_11_10.bin
% Packed byte: 0xB4
%
% qpsk_cw_00_10_11_01.bin
% Packed byte: 0x78
%
% qpsk_mixed_00_01_10_11.bin
% Packed byte: 0xE4
%
