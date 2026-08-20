%% generate_qam16_test_pattern.m

% Packing convention
%   Symbol 0 = bits[3:0]
%   Symbol 1 = bits[7:4]
%   ... (4 bits per QAM symbol)
%   [7:4] is later symbol, [3:0] is earlier symbol
% Test sequence:
%   Loop through all possible values: 0,1,2,...F,0,1,2,...F,...
% Mapper convention:
%   symbol[3:2] = Q code
%   symbol[1:0] = I code
% AXIS Gray map:
%   00 -> +MAX
%   01 -> +INNER
%   11 -> -INNER
%   10 -> -MAX

clear;
clc;

%% User settings
MEM_SIZE_BYTES = 131072;
MAX_AMPLITUDE = 22000;

INNER_AMPLITUDE = floor(MAX_AMPLITUDE / 3); %7333

gain_q15 = hex2dec('8000');

filename = 'qam16_all_symbols_128k.bin';

%% Memory definitions

BITS_PER_SYMBOL = 4;
SYMBOLS_PER_BYTE = 8 / BITS_PER_SYMBOL; % 2
BYTES_PER_WORD = 512 / 8; %64
SYMBOLS_PER_WORD = 512 / BITS_PER_SYMBOL; % 128

NUM_SYMBOLS = MEM_SIZE_BYTES * SYMBOLS_PER_BYTE;
NUM_WORDS = MEM_SIZE_BYTES / BYTES_PER_WORD;

fprintf('===============================================\n');
fprintf('16-QAM deterministic test pattern\n');
fprintf('===============================================\n');
fprintf('Memory size        : %d bytes\n', MEM_SIZE_BYTES);
fprintf('512-bit words      : %d\n', NUM_WORDS);
fprintf('Symbols / word     : %d\n', SYMBOLS_PER_WORD);
fprintf('Total QAM symbols  : %d\n', NUM_SYMBOLS);
fprintf('\n');

%% Generate symbols
% symbol[0] = 0x0
% symbol[1] = 0x1
% byte[0] = 0x10, you have to left shift the odd bits up so that byte[0] =
% {symbol[1], symbol[0]}
symbols = uint8(mod(0:NUM_SYMBOLS-1, 16));

symbol_even = symbols(1:2:end);
symbol_odd = symbols(2:2:end);

packed_bytes = bitor(symbol_even, bitshift(symbol_odd,4));

%% 
assert(length(packed_bytes) == MEM_SIZE_BYTES);

expected_first_bytes = uint8([ ...
    hex2dec('10'), ...
    hex2dec('32'), ...
    hex2dec('54'), ...
    hex2dec('76'), ...
    hex2dec('98'), ...
    hex2dec('BA'), ...
    hex2dec('DC'), ...
    hex2dec('FE') ]);

assert(isequal(packed_bytes(1:8), expected_first_bytes), 'QAM packing is incorrect');

fprintf('First 32 QAM symbols:\n');

for k = 1:32
    fprintf('%X ', symbols(k));
end

fprintf('\n\n');


fprintf('First 16 packed bytes:\n');

for k = 1:16
    fprintf('%02X ', packed_bytes(k));
end

fprintf('\n\n');

%% Write to file

fid = fopen(filename, 'wb');

if fid < 0
    error('Could not open %s', filename);
end

count = fwrite(fid, packed_bytes, 'uint8');

fclose(fid);

assert(count == MEM_SIZE_BYTES);

fprintf('Wrote:\n')
fprintf('   %s\n', filename);
fprintf('   %d bytes\n\n', count);

%% Generate expected mapper output for all 16 symbols

% 00, 01, 10, 11
axis_map = [MAX_AMPLITUDE, INNER_AMPLITUDE, -MAX_AMPLITUDE, -INNER_AMPLITUDE];

test_symbols = uint8((0:15)');

i_code = bitand(test_symbols, uint8(3));
q_code = bitshift(test_symbols, -2);

i_mapper = axis_map(double(i_code) + 1).';
q_mapper = axis_map(double(q_code) + 1).';

i_scaled = rtl_gain_q15(i_mapper, gain_q15);
q_scaled = rtl_gain_q15(q_mapper, gain_q15);

%% Display expected results

symbol_hex = string(dec2hex(test_symbols, 1));
symbol_bin = string(dec2bin(test_symbols,4));

i_bits = string(dec2bin(i_code, 2));
q_bits = string(dec2bin(q_code, 2));

T = table( ...
    symbol_hex, ...
    symbol_bin, ...
    q_bits, ...
    i_bits, ...
    i_mapper, ...
    q_mapper, ...
    i_scaled, ...
    q_scaled, ...
    'VariableNames', { ...
        'SymbolHex', ...
        'SymbolBinary', ...
        'QBits', ...
        'IBits', ...
        'MapperI', ...
        'MapperQ', ...
        'ScaledI', ...
        'ScaledQ'});

disp(T);

%% Plot constellation
figure;
scatter(double(i_scaled), double(q_scaled), 80, 'filled');
grid on;
axis equal;
xlabel('I');
ylabel('Q');

title(sprintf('Expected 16-QAM constellation, gain=%.6f', gain_q15 / 32768));

hold on;

for k = 1:16
    text(double(i_scaled(k)) + 500, double(q_scaled(k)) + 500, sprintf('%X', test_symbols(k)));
end

hold off;

%% Helper functions

function y = rtl_gain_q15(x, gain_q15)

    x = int64(x);
    g = int64(gain_q15);

    product = x .* g;

    y = zeros(size(product), 'int64');

    positive = product >= 0;

    % Positive values
    y(positive) = floor( ...
        double(product(positive) + 16384) / 32768);

    % Negative values:
    %
    % Do magnitude-based implementation for exact symmetry.
    neg_mag = -product(~positive);

    y(~positive) = -floor( ...
        double(neg_mag + 16384) / 32768);

    y = int16(y);

end




