%% design_rrc_fir.m
clear;
clc;
close all;
 
beta = 0.25;
span = 8; %filt span in symbols
sps  = 8; %samples per symbol (interp factor)
 
h = rcosdesign(beta, span, sps, 'sqrt');
 
h = h(:);
 
Ntaps = length(h);
 
fprintf('============================================================================\n');
fprintf('RRC Filter\n');
fprintf('============================================================================\n');
fprintf('Rollout beta:      %.3f\n', beta);
fprintf('Span:              %d symbols\n', span);
fprintf('Samples/symbol:    %d\n', sps);
fprintf('Number of taps:    %d\n', Ntaps);
fprintf('Group delay:       %.1f output samples\n', (Ntaps-1)/2);
fprintf('Group delay:       %.1f symbols\n', (Ntaps-1)/(2*sps));
 
fprintf('\nRRC coefficients: \n\n');
 
for k=1:Ntaps
    fprintf('%3d : %.18f\n', k-1, h(k));
end
 
%% Plot impulse response
n = -(Ntaps-1)/2 : (Ntaps-1)/2;
 
figure;
stem(n, h, 'filled');
 
grid on;
xlabel('Output Sample Index');
ylabel('Coefficient');
title(sprintf('RRC Impulse Response, \\beta = %.2f, SPS = %d, Span = %d', beta, sps, span));
 
%% Plot in symbol time units
figure;
plot(n/sps, h, '.-');
 
grid on;
xlabel('Time (symbols)');
ylabel('Amplitude');
title('Root Raised Cosine Pulse Shape');
 
%% Frequency Response
NFFT = 16384;
 
H = fftshift(fft(h, NFFT));
 
Hmag = abs(H);
Hmag = Hmag / max(Hmag);
 
HdB = 20*log10(max(Hmag, 1e-12));
 
f_norm = (-NFFT/2:NFFT/2-1).' / NFFT;
 
figure;
 
plot(f_norm, HdB);
 
grid on;
xlabel('Normalized Frequency (cycles/sample)');
ylabel(['Magnitude (dB)']);
title('RRC Frequency Response');
ylim([-100 5]);
 
%% WRITE floating-point COEs
coe_filename = 'rrc_beta025_sps8_span8.coe';
 
fid = fopen(coe_filename, 'w');
 
if fid == -1
    error('Could not create %s', coe_filename);
end
 
fprintf(fid, 'radix=10;\n');
fprintf(fid, 'coefdata=\n');
 
for k = 1:Ntaps
 
    if k < Ntaps
        fprintf(fid, '%.18f,\n', h(k));
    else
        fprintf(fid, '%.18f;\n', h(k));
    end
end
 
fclose(fid);
 
fprintf('\nCreated FIR Compiler coefficients\n')