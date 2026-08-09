clear;
clc;
close all;
 
Fs_in = 160e6;
 
Fp  = 4e6;
Fst = 6e6;
 
Ap = 0.1;
Ast = 55;
 
%% Design minimum-order equiripple FIR
 
 
fir_filter = designfilt('lowpassfir', 'PassbandFrequency', Fp, 'StopbandFrequency', Fst, 'PassbandRipple', Ap, 'StopbandAttenuation', Ast, 'DesignMethod', 'equiripple', 'SampleRate', Fs_in);
 
b = fir_filter.Coefficients(:);
 
NTAPS = length(b);
 
fprintf('Number of FIR taps: %d\n', NTAPS);
fprintf('Group delay: %.1f input samples\n', (NTAPS-1)/2);
fprintf('Group delay: %.3f us\n', ((NTAPS-1)/2) / Fs_in * 1e6);
 
%% Plot frequency response
freqz(b,1,65536, Fs_in);
 
title(sprintf('FIR response: %d taps, Fp = %.1f MHz, Fst = %.1f MHz', NTAPS, Fp/1e6, Fst/1e6));
 
%% Quantize coefficients to signed Q1.17
 
COEFF_WIDTH = 18;
COEFF_FRAC = 17;
 
coefficient_scale = 2^COEFF_FRAC;
 
b_int = round(b*coefficient_scale);
 
% Signed 18 bit range
minimum_coefficient = -2^(COEFF_WIDTH-1);
maximum_coefficient = 2^(COEFF_WIDTH-1)-1;
 
if any(b_int < minimum_coefficient) || any(b_int > maximum_coefficient)
    error('At least one coefficient exceeds the signed 18-bit range.');
end
 
b_int = int32(b_int);
 
%% Examine quantized response
b_quantized = double(b_int) / coefficient_scale;
 
figure;
freqz(b_quantized, 1, 65536, Fs_in);
 
title(sprintf('Quantized FIR response: signed Q1.%d', COEFF_FRAC));
 
%% Export FIR Compiler COE file
fid = fopen('adc_lowpass_q17.coe','w');
 
if fid < 0 
    error('Could not create adc_lowpass_q17.coe.');
end
 
fprintf(fid, 'radix=10;\n');
fprintf(fid, 'coefdata=\n');
 
for index = 1:NTAPS
    if index < NTAPS
        fprintf(fid, '%d,\n', b_int(index));
    else
        fprintf(fid, '%d;\n', b_int(index));
    end
end
 
fclose(fid);
 
writematrix(b_int, 'adc_lowpass_q17.txt','Delimiter', 'tab');
 
% Save MATLAB data
save('adc_fir_reference.mat', 'Fs_in', 'Fp', 'Fst', 'Ap','Ast','NTAPS','COEFF_WIDTH','COEFF_FRAC', 'b', 'b_int', 'b_quantized');
 
 
%% Test the filter
duration = 100e-6;
n = (0:round(duration * Fs_in)-1).';
t = n / Fs_in;
 
desired_frequency = 4e6;
unwanted_frequency = 20e6;
 
x = 0.8 * sin(2*pi*desired_frequency*t) + 0.2 * sin(2*pi*unwanted_frequency*t);
 
%% Apply FIR
y = filter(b_quantized, 1, x);
 
%% Downsample using phase 3
M = 16;
phase = 10;
 
y_downsampled = y(phase+1:M:end);
 
Fs_out = Fs_in / M;
 
%% Plot time domain results
samples_to_plot = 1000;
figure;
plot(t(1:samples_to_plot) * 1e6, x(1:samples_to_plot));
hold on;
plot(t(1:samples_to_plot) * 1e6, y(1:samples_to_plot));
 
grid on;
 
xlabel('Time (\mus)');
ylabel('Normalized Amplitude');
 
legend('Unfiltered input', 'FIR-filtered signal');
 
title('Input and FIR-filtered waveform');
 
%% Plot downsampled signal
t_downsampled = (phase + (0:length(y_downsampled)-1).' * M) / Fs_in;
 
figure;
 
stem(t_downsampled(1:100) * 1e6, y_downsampled(1:100), 'filled');
 
grid on;
 
xlabel('Time (\mus)');
ylabel('Normalized Amplitude');
 
title(sprintf('Downsampled %.1f-MHz tone at %.1f MSPS', desired_frequency/1e6, Fs_out/1e6));