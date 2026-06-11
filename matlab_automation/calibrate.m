% System Setup
clear s;
clc;
clear;
close all;

dac_ch0 = "228_0.bin";
dac_ch1 = "228_2.bin";
dac_ch2 = "229_0.bin";
dac_ch3 = "229_2.bin";

dac_ch0_addr = "0xA0000000";
dac_ch1_addr = "0xA0020000";
dac_ch2_addr = "0xA0040000";
dac_ch3_addr = "0xA0060000";

host = "127.0.0.1";
port = 2000;

% User Input
fc = 1e6;
amplitude_dbfs = 0;
debug_dac = 0;
debug_adc = 1;
dphi_deg = 0;
interpolation = 1;
fs_adc = 4.9e9;

% Tone Generation
[start_ch0, stop_ch0, fn_ch0, fp_ch0] = generate_tone(fc, dphi_deg, amplitude_dbfs, interpolation, "./out",dac_ch0,debug_dac);
[start_ch1, stop_ch1, fn_ch1, fp_ch1] = generate_tone(fc, dphi_deg, amplitude_dbfs, interpolation, "./out",dac_ch1,debug_dac);
[start_ch2, stop_ch2, fn_ch2, fp_ch2] = generate_tone(fc, dphi_deg, amplitude_dbfs, interpolation, "./out",dac_ch2,debug_dac);
[start_ch3, stop_ch3, fn_ch3, fp_ch3] = generate_tone(fc, dphi_deg, amplitude_dbfs, interpolation, "./out",dac_ch3,debug_dac);

% Start XSDB
X = XsdbClient(host, port);
X.cd(pwd);

% Download Tones
disp(X.setTargetPSU());
disp(X.downloadTone(fn_ch0, dac_ch0_addr));
pause(2);
disp(X.downloadTone(fn_ch1, dac_ch1_addr));
pause(2);
disp(X.downloadTone(fn_ch2, dac_ch2_addr));
pause(2);
disp(X.downloadTone(fn_ch3, dac_ch3_addr));

ptr_hex = "0x" + upper(string(dec2hex(uint32(stop_ch0), 8)));
fprintf("%s", ptr_hex);

disp(X.setPtrs("0xA0110000",ptr_hex));
disp(X.setPtrs("0xA00E0000",ptr_hex));
disp(X.setPtrs("0xA00F0000",ptr_hex));
disp(X.setPtrs("0xA0100000",ptr_hex));

disp(serialportlist("available"));

% Play and Capture Tone on Serial Monitor
s = SerialClient("COM5", 115200);
s.open();
disp(s.drain(2.5));
disp(s.uramStop());
pause(5);
disp(s.dacMTS('0x3','0x0',10));
pause(3);
disp(s.adcMTS('0x3','0x1',10));
pause(3);
disp(s.uramPlay());
pause(5);
disp(s.uramCap());

disp(X.readCapture());

[adc_ch0, pxx0, f0, fpk0, SNDR0] = adc_read_periodogram(0, fc, debug_adc);
pause(1);
[adc_ch1, pxx1, f1, fpk1, SNDR1] = adc_read_periodogram(1, fc, debug_adc);
pause(1);
[adc_ch2, pxx2, f2, fpk2, SNDR2] = adc_read_periodogram(2, fc, debug_adc);
pause(1);
[adc_ch3, pxx3, f3, fpk3, SNDR3] = adc_read_periodogram(3, fc, debug_adc);
pause(1);

% Use Cross-Correlation for Calibration
[dphi_20, dt_20, lag_samp20, fs_ds, ref23_ds, sig23_ds] = PhaseEstimator.estimate_phase_xcorr_filtered(adc_ch2, adc_ch3, fc, fs_adc);
[dphi_21, dt_21, lag_samp21, ~, ref21_ds, sig21_ds] = PhaseEstimator.estimate_phase_xcorr_filtered(adc_ch2, adc_ch1, fc, fs_adc);
[dphi_22, dt_22, lag_samp22, ~, ref22_ds, sig22_ds] = PhaseEstimator.estimate_phase_xcorr_filtered(adc_ch2, adc_ch0, fc, fs_adc);

% Log results
log_fn = "./out/phase_log_calibration.csv";

log_phase_results(log_fn, fc, "ch2-ch3", dphi_20, dt_20, lag_samp20);
log_phase_results(log_fn, fc, "ch2-ch1", dphi_21, dt_21, lag_samp21);
log_phase_results(log_fn, fc, "ch2-ch0", dphi_22, dt_22, lag_samp22);

% Plot all 4 ADC channels
x0 = double(adc_ch0(:));
x1 = double(adc_ch1(:));
x2 = double(adc_ch2(:));
x3 = double(adc_ch3(:));

% Remove DC offset
x0 = x0 - mean(x0);
x1 = x1 - mean(x1);
x2 = x2 - mean(x2);
x3 = x3 - mean(x3);

% Plot 5 cycles
N = round(5 * fs_adc / fc);
N = min([N, length(x0), length(x1), length(x2), length(x3)]);

time_ps = (0:N-1)' / fs_adc * 1e12;

figure;
plot(time_ps, x0(1:N), 'LineWidth', 1.4); hold on;
plot(time_ps, x1(1:N), 'LineWidth', 1.4);
plot(time_ps, x2(1:N), 'LineWidth', 1.4);
plot(time_ps, x3(1:N), 'LineWidth', 1.4);
hold off;

grid on;
title(sprintf('ADC2 Reference Calibration %.2f MHz', fc/1e6));
xlabel('Time (ps)');
ylabel('Amplitude');
legend('ch0', 'ch1', 'ch2', 'ch3', 'Location', 'best');

ax = gca;
ax.XAxis.Exponent = -12;

s.close();
X.close();
clear X;

function log_phase_results(log_fn, fc, ch_pair, dphi_deg, dt_sec, lag_samp) 
    if log_fn == ""
        log_fn = "./phase_log_calibration.csv";
    end

    ts = datetime('now','Format','dd-MMM-uuuu HH:mm:ss');

    is_new = false;

    if ~isfile(log_fn)
        is_new = true;
    else
        info = dir(log_fn);
        if info.bytes == 0
            is_new = true;
        end
    end

    fid = fopen(log_fn, "a");
    if fid < 0
        error("Cannot open log file for append: %s", log_fn);
    end

    if is_new
        fprintf(fid, "timestamp,fc(Hz),channel,dphi_deg,delay(sec),lag_samples\n");
    end

    if isnan(lag_samp)
        lag_str = "NaN";
    else
        lag_str = string(int32(lag_samp));
    end

    fprintf(fid, "%s,%.15g,%s,%.6f,%.15g,%s\n", string(ts), fc, string(ch_pair), dphi_deg, dt_sec, lag_str);

    fclose(fid);
end
