%% generate_dac_ramp_128k.m

clear;
clc;
close all;

%% ================================================================
% Configuration
% ================================================================

BRAM_SIZE_BYTES = 131072;    % 128 kB
BYTES_PER_SAMPLE = 2;        % int16
N = BRAM_SIZE_BYTES / BYTES_PER_SAMPLE; % 65536

Fs_dac = 6.4e9;              % DAC sample rate
f_ramp = 10e6;
amplitude = 0.80;            % 80% full scale

Ntotal = 65536;
Nperiod = round(Fs_dac / f_ramp); % 640 samples
Nperiods = floor(Ntotal / Nperiod);

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

one_ramp = linspace(-1, 1, Nperiod+1).';
one_ramp(end) = []; 

x = repmat(one_ramp, ceil(Ntotal/Nperiod), 1);
x = x(1:Ntotal);

% Quantization
x = int16(round(amplitude * 32767 * x));

% stop_ptr: 0x1FDC0


%% ================================================================
% Write binary file
%
% Sequential int16 samples:
%
% x0, x1, x2, ...
%
% 32 consecutive samples make each 512-bit URAM word.
% ================================================================

filename = 'dac_ramp_10MHz_128k.bin';

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

fprintf('DAC Fs                  = %.3f GSPS\n', ...
    Fs_dac/1e9);

fprintf('Target ramp frequency   = %.6f MHz\n', ...
    f_ramp/1e6);

fprintf('Actual ramp frequency   = %.6f MHz\n', ...
    Fs_dac/Nperiod/1e6);

fprintf('Ramp period             = %.6f ns\n', ...
    Nperiod/Fs_dac*1e9);

fprintf('Samples/ramp            = %d\n', ...
    Nperiod);

fprintf('Complete ramp periods   = %d\n', ...
    Nperiods);

fprintf('Minimum played sample   = %d\n', ...
    min(x));

fprintf('Maximum played sample   = %d\n', ...
    max(x));

fprintf('Binary file size        = %d bytes\n', ...
    dir(filename).bytes);

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