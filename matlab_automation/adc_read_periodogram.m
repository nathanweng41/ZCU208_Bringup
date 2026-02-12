function [x_i16, pxx, f, fpk, SNDR_dB] = adc_read_periodogram(ch_idx, fc, debug)
    if nargin < 3
        debug = 0;
    end

    if ch_idx < 0 || ch_idx > 3 || ch_idx ~= floor(ch_idx)
        error("ch_ix must be an integer 0..3");
    end

    fs = 4.9e9;
    numberOfSamples = 2^16;
    FS_pk = 32768;
    out_dir = "../out";

    samples_per_cycle_adc = fs / fc;
    [~, max_samples_adc] = maxIntegerCycles(numberOfSamples, samples_per_cycle_adc);

    fprintf("Number of ADC Samples: %d\n", max_samples_adc);

    cap_files = ["cap0.bin", "cap1.bin", "cap2.bin", "cap3.bin"];
    fn = fullfile(out_dir, cap_files(ch_idx+1));

    fid = fopen(fn, "r");
    if fid < 0
        error("Cannot open %s", fn);
    end

    x_i16 = fread(fid, max_samples_adc, "int16",0,'native');
    fclose(fid);

    pxx = [];
    f = [];
    fpk = [];
    SNDR_dB = [];

    if debug == 1
        x = double(x_i16) / FS_pk; % Normalize to full-scale
        x = x - mean(x);

        [pxx, f] = periodogram(x, [], max_samples_adc, fs, 'power');

        total_power = sum(pxx); 
        [~,kpk] = max(pxx);
        fpk = f(kpk);
        signal_power = pxx(kpk);
        noise_dist_power = total_power - signal_power;
        SNDR_dB = 10 * log10(signal_power / noise_dist_power);

        fprintf("Channel %d peak = %.6f MHz\n", ch_idx, fpk/1e6);
        fprintf("SNDR = %.3f dB\n", SNDR_dB);

        figure;
        plot(f, 10*log10(pxx+eps));
        xlabel('Frequency (Hz)');
        ylabel('Power (dB)');
        title(sprintf('Periodogram - Channel %d', ch_idx));
        grid on;
    end
end

function [cycles_max, samples_max, num, denom, k_max] = maxIntegerCycles(total_samples, samples_per_cycle)
    [num,denom] = rat(samples_per_cycle);

    if num <= 0 || denom == 0
        error('Invalid samples/cycle.');
    end

    k_max = floor(total_samples / num);

    cycles_max = k_max * denom;
    samples_max = k_max * num;
end
