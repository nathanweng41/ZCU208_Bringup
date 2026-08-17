%% generate_dac_ramp_128k.m

clear;
clc;
close all;

%% ================================================================
% Configuration
% ================================================================

BRAM_SIZE_BYTES = 131072;    % 128 kB
BYTES_PER_SAMPLE = 2;        % int16
N = BRAM_SIZE_BYTES / BYTES_PER_SAMPLE; % 65536 samples

Fs_dac = 6.4e9;              % DAC sample rate
amplitude = 0.80;            % 80% full scale

fprintf('Number of samples = %d\n', N);
fprintf('BRAM bytes        = %d\n', N*BYTES_PER_SAMPLE);


%% ================================================================
% Generate ramp
%
% One complete sawtooth fills the entire 128-kB BRAM.
%
% First sample ~= -0.8 FS
% Last sample  ~= +0.8 FS
% Then playback wraps back to the first sample.
% ================================================================

ramp_norm = linspace(-1, 1, N).';

x = int16(round(amplitude * 32767 * ramp_norm));


%% ================================================================
% Write binary file
%
% Sequential int16 samples:
%
% x0, x1, x2, ...
%
% 32 consecutive samples make each 512-bit URAM word.
% ================================================================

filename = 'dac_ramp_128k.bin';

fid = fopen(filename, 'wb');

if fid == -1
    error('Could not open %s', filename);
end

fwrite(fid, x, 'int16', 0, 'ieee-le');

fclose(fid);


%% ================================================================
% Also generate HEX file for debugging if useful
% ================================================================

x_uint = typecast(x, 'uint16');

fid = fopen('dac_ramp_128k.hex', 'w');

for k = 1:N
    fprintf(fid, '%04X\n', x_uint(k));
end

fclose(fid);


%% ================================================================
% Information
% ================================================================

fprintf('\n');
fprintf('================ Ramp Information ================\n');
fprintf('DAC Fs                  = %.3f GSPS\n', Fs_dac/1e9);
fprintf('Samples                  = %d\n', N);
fprintf('Samples / 512-bit word   = %d\n', 512/16);
fprintf('512-bit words            = %d\n', N/(512/16));

fprintf('Minimum sample           = %d\n', min(x));
fprintf('Maximum sample           = %d\n', max(x));

fprintf('Binary file size         = %d bytes\n', ...
    dir(filename).bytes);

fprintf('Ramp repetition rate     = %.6f kHz\n', ...
    Fs_dac/N/1e3);

fprintf('Ramp period              = %.6f us\n', ...
    N/Fs_dac*1e6);


%% ================================================================
% Verify file is exactly 128 kB
% ================================================================

info = dir(filename);

assert(info.bytes == BRAM_SIZE_BYTES, ...
    'ERROR: output file is not exactly 128 kB');

fprintf('\nFile size verified: exactly 128 kB.\n');


%% ================================================================
% Plot entire ramp
% ================================================================

figure;

plot(double(x));

grid on;
xlabel('DAC Sample Index');
ylabel('DAC Code');
title('128-kB DAC Ramp');


%% ================================================================
% Plot first 1000 samples
% ================================================================

figure;

plot(0:999, double(x(1:1000)), '.-');

grid on;
xlabel('DAC Sample Index');
ylabel('DAC Code');
title('First 1000 DAC Ramp Samples');