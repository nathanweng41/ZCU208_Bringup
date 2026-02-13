clear s;

dac_ch0 = "228_0_calibrated.bin";
dac_ch1 = "228_2_calibrated.bin";
dac_ch2 = "229_0_calibrated.bin";
dac_ch3 = "229_2_calibrated.bin";

dac_ch0_addr = "0xA0000000";
dac_ch1_addr = "0xA0020000";
dac_ch2_addr = "0xA0040000";
dac_ch3_addr = "0xA0060000";

host = "127.0.0.1";
port = 2000;

fs_adc = 4.9e9;

% User Input (keep same as initial calibration)
fc = 200e6;
amplitude_dbfs = -5;
debug_dac = 0;
debug_adc = 1;
interpolation = 1;

log_fn = "./phase_log_calibration.csv";

s = SerialClient("COM13", 115200);
s.open();
disp(s.drain(2.0));

disp(s.uramStop());
pause(3);

dphi1_apply = get_phase_correction(log_fn, "ch0-ch1", fc);
dphi2_apply = get_phase_correction(log_fn, "ch0-ch2", fc);
dphi3_apply = get_phase_correction(log_fn, "ch0-ch3", fc);

fprintf("Corrections (deg): ch1=%+.3f, ch2=%+.3f, ch3=%.3f\n", dphi1_apply, dphi2_apply, dphi3_apply);


[start_ch1, stop_ch1, fn_ch1] = generate_tone(fc, dphi1_apply, amplitude_dbfs, interpolation, "../out", dac_ch1, debug_dac);
[start_ch2, stop_ch2, fn_ch2] = generate_tone(fc, dphi2_apply, amplitude_dbfs, interpolation, "../out", dac_ch2, debug_dac);
[start_ch3, stop_ch3, fn_ch3] = generate_tone(fc, dphi3_apply, amplitude_dbfs, interpolation, "../out", dac_ch3, debug_dac);

X = XsdbClient(host, port);
X.cd(pwd);

disp(X.setTargetPSU());
%disp(X.downloadTone(fn_ch0, dac_ch0_addr)); 
disp(X.downloadTone(fn_ch1, dac_ch1_addr));
disp(X.downloadTone(fn_ch2, dac_ch2_addr));
disp(X.downloadTone(fn_ch3, dac_ch3_addr));

ptr_hex = "0x" + upper(string(dec2hex(uint32(stop_ch0), 8)));
disp(X.setPtrs(ptr_hex));

disp(s.uramPlay());
pause(5);
disp(s.uramCap());

disp(X.readCapture());

[adc_ch0, pxx0, f0, fpk0, SNDR0] = adc_read_periodogram(0, fc, debug_adc);
[adc_ch1, pxx1, f1, fpk1, SNDR1] = adc_read_periodogram(1, fc, debug_adc);
[adc_ch2, pxx2, f2, fpk2, SNDR2] = adc_read_periodogram(2, fc, debug_adc);
[adc_ch3, pxx3, f3, fpk3, SNDR3] = adc_read_periodogram(3, fc, debug_adc);

% Use Cross-Correlation for Calibration
[dphi_01, dt_01, lag_samp1] = PhaseEstimator.estimate_phase_xcorr(adc_ch0, adc_ch1, fc);
[dphi_02, dt_02, lag_samp2] = PhaseEstimator.estimate_phase_xcorr(adc_ch0, adc_ch2, fc);
[dphi_03, dt_03, lag_samp3] = PhaseEstimator.estimate_phase_xcorr(adc_ch0, adc_ch3, fc);

fprintf("Post-correction dphi (deg): ch1=%+.3f, ch2=%+.3f, ch3=%+.3f\n", dphi_01, dphi_02, dphi_03);

% Plot for Debug
x0 = double(adc_ch0(:));
x3 = double(adc_ch3(:));

x0 = x0 - mean(x0);
x3 = x3 - mean(x3);

N = round(5*fs_adc/fc);

time_ps = (0:N-1)'/fs_adc * 1e12;

figure;
plot(time_ps, x0(1:N), 'LineWidth',1.4); hold on;
plot(time_ps, x3(1:N), 'LineWidth',1.4);
hold off;
grid on;
title(sprintf('Raw Time Domain: ch0 vs ch3 @ %.2f MHz', fc/1e6));
xlabel('Time (ps)');
ylabel('Amplitude');
legend('ch0','ch3','Location','best');
ax = gca;
ax.XAxis.Exponent = -12;

% Log Corrected Results

log_phase_results(log_fn, fc, "ch0-ch1", dphi_01, dt_01, lag_samp1);
log_phase_results(log_fn, fc, "ch0-ch2", dphi_02, dt_02, lag_samp2);
log_phase_results(log_fn, fc, "ch0-ch3", dphi_03, dt_03, lag_samp3);

s.close();
X.close();
clear X;

function dphi_apply = get_phase_correction(log_fn, channel, fc)
    if ~isfile(log_fn)
        error("Log file not found: %s", log_fn);
    end

    T = readtable(log_fn, "TextType", "string");
    col_names = T.Properties.VariableNames;

    fc_col = find(contains(col_names,"fc"), 1);
    ch_col = find(contains(col_names,"channel"), 1);
    dphi_col = find(contains(col_names,"dphi_deg"), 1);

    if isempty(fc_col) || isempty(ch_col) || isempty(dphi_col)
        error("Expected columns not found in %s", log_fn);
    end

    ch_vec = string(T{:, ch_col});
    fc_vec = double(T{:, fc_col});

    tol_hz = 2e5;

    idx = (ch_vec == string(channel)) & (abs(fc_vec - fc) <= tol_hz);
    if ~any(idx)
        error("No matching entry for channel=%s at fc=%.6f MHz", channel, fc/1e6);
    end

    Tsel = T(idx, :);

    row = Tsel(end, :); % Select Latest Entry

    dphi_meas = double(row{1,dphi_col});
    dphi_apply = dphi_meas; % already phase wrapped to 180
end

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

    fprintf(fid, "%s,%.15g,%s,%.6f,%.15g,%d\n", string(ts), fc, string(ch_pair), dphi_deg, dt_sec, int32(lag_samp));

    fclose(fid);
end

