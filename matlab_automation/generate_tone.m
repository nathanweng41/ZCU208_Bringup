function [start_ptr, stop_ptr, fn, fp] = generate_tone(fc, dphi_deg, amplitude_dbfs, interpolation_rate, filedir, filename, debug)
% Inputs:
%   fc: tone signal
%   dphi_deg: phase shift
%   amplitude_dbfs: tone signal's amplitude in DBFS
%   interpolation_rate: interpolation, usually 1
%   file_dir: directory of the file destination
%   filename: filename, can be full path if wanted
%   debug: set to 1 if needed
%   NOTE: ref and sig should be same length
% Outputs:
%   start_ptr: start_ptr for io
%   stop_ptr: stop_ptr for io
%   fn: file path
%   fp: struct to store variables used

filedir = char(filedir);

fs_dac = 9.8e9;
fs = fs_dac/ interpolation_rate;

mem_bytes = 131072; % 128kB
bytes_per_sample = 2;
samples_per_word = 32; % 32 samples per beat

num_bits = 2^15;
total_samples = mem_bytes / bytes_per_sample; % 65536 samples
bytes_per_word = samples_per_word * bytes_per_sample; % 64

if ~isnumeric(fc) || fc <= 0
    error('fc must be a positive number.');
end

if ~isnumeric(dphi_deg) 
    error('dphi_deg must be a number.');
end

samples_per_cycle = fs / fc;
if abs(samples_per_cycle - round(samples_per_cycle)) > 1e-3
    error("fs/fc is not an integer. fs/fc=%.12f. Choose fc so that samples_per_cycle is an integer.", samples_per_cycle);
end

samples_per_cycle = round(samples_per_cycle);

% We want N such that:
% 1) N is a multiple of 32.
% 2) N is a multiple of samples_per_cycle if samples_per_cycle is int.

N = lcm(samples_per_word, samples_per_cycle); % minimum segment length needed in samples
m_cycles = N / samples_per_cycle; % cycles from samples above

beats = N / samples_per_word; 
start_ptr = uint32(0);
stop_ptr = uint32((beats-1) * bytes_per_word);

k_tone = 1 + (N / samples_per_cycle); % bin k = MATLAB FFT (k+1) idx

% Signal Generation
n = (0:N-1).'; % transpose into column
phi_rad = deg2rad(dphi_deg);

sig_float = sin(2*pi*fc*n/fs + phi_rad);
sig_i16 = int16( round ( sig_float / max(abs(sig_float)) * (num_bits-1) * 10^(amplitude_dbfs/20) ));

reps = ceil(total_samples / N);
sig_full = repmat(sig_i16, reps, 1);
sig_full = sig_full(1:total_samples);

filename = char(filename);
[p,~,~] = fileparts(filename);
if isempty(p)
    fn = fullfile(filedir, filename);
else
    fn = filename;
end

% Write File
fid = fopen(fn, 'w');
if fid<0; error('Can not open %s for writing.', fn); end
fwrite(fid, sig_full, 'int16', 0, 'ieee-le');
fclose(fid);

phi_float_deg = NaN;
phi_i16_deg = NaN;

if debug
    fprintf("fs = %.3f GHz\n", fs/1e9);
    fprintf("fc = %.3f MHz (EXACT)\n", fc/1e6);
    fprintf("samples_per_cycle = %d\n", samples_per_cycle);
    fprintf("Loop segment N = %d samples (%d cycles)\n", N, m_cycles);
    fprintf("beats = %d words (32 samples each)\n", beats);
    fprintf("start_addr = 0x%08X\n", uint32(start_ptr));
    fprintf("stop_addr = 0x%08X\n", uint32(stop_ptr));
    fprintf("Segment time = %.3f ns\n", (N/fs) *1e9);

    % Plot one loop segment
    figure;
    plot(double(sig_i16(1:N)));
    title(sprintf("One loop segment: N=%d samples, (%d cycles)", N, m_cycles));
    xlabel("sample"); ylabel("int16");

    % FFT of one loop segment
    x = double(sig_i16(1:N));
    x = x - mean(x); 

    Nfft = length(x);
    f = (0:Nfft-1) * (fs/Nfft);
    Y = fft(x);
    mag_db = 20*log10(abs(Y(1:floor(Nfft/2))) + eps);
    mag_db(~isfinite(mag_db)) = -200; % clamp any leftovers

    figure;
    plot(f(1:floor(Nfft/2))/1e6, mag_db);
    grid on;
    xlim([0 700]); ylim([-150 0]);
    title("FFT of one BRAM loop segment");
    xlabel("MHz"); ylabel("dB");

    Xf = fft(sig_float);
    Xi = fft(double(sig_i16));

    phi_float_deg = rad2deg(angle(Xf(k_tone)));
    phi_i16_deg   = rad2deg(angle(Xi(k_tone)));

    fprintf("Analog tone phase: %.3f\n", phi_float_deg);
    fprintf("Quantized tone phase: %.3f\n", phi_i16_deg);
end

% Rest of the information can be stored in fp
fp = struct();
fp.fs = fs;
fp.fc = fc;
fp.samples_per_cycle = samples_per_cycle;
fp.N = N;
fp.m_cycles = m_cycles;
fp.beats= beats;
fp.bytes_per_word = bytes_per_word;
fp.total_samples = total_samples;
fp.k_tone = k_tone;
fp.segment_time_ns = (N/fs)*1e9;
fp.amplitude_dbfs = amplitude_dbfs;
fp.dphi_deg = dphi_deg;
fp.debug = debug;
fp.phi_float_deg = phi_float_deg;
fp.phi_i16_deg = phi_i16_deg;

fprintf("Completed tone generation.\n");
end