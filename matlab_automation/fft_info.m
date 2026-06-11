function fft_info(x, fs, label)
    x = double(x(:));
    x = x - mean(x);

    N = length(x);

    % Hann window
    w = hann(N);
    xw = x .* w;

    % FFT
    X = fft(xw);
    X = X(1:floor(N/2)+1);

    % Frequency axis
    f = (0:floor(N/2)).' * fs / N;

    % Magnitude spectrum
    Xmag = abs(X) / sum(w);
    Xmag(2:end-1) = 2 * Xmag(2:end-1);

    Xdb = 20*log10(Xmag + eps);

    % Find strongest non-DC peak
    [peak_db, peak_idx] = max(Xdb(2:end));
    peak_idx = peak_idx + 1;
    peak_freq = f(peak_idx);

    % Estimate noise floor / SNR
    exclude_bins = 5;
    noise_mask = true(size(Xmag));
    noise_mask(1) = false;

    tone_start = max(1, peak_idx - exclude_bins);
    tone_stop  = min(length(Xmag), peak_idx + exclude_bins);
    noise_mask(tone_start:tone_stop) = false;

    noise_power = sum(Xmag(noise_mask).^2);
    signal_power = sum(Xmag(tone_start:tone_stop).^2);

    snr_est_db = 10*log10(signal_power / noise_power);
    noise_floor_db = median(Xdb(noise_mask));

    % Print info to terminal
    fprintf("\n===== FFT information: %s =====\n", label);
    fprintf("Number of samples:      %d\n", N);
    fprintf("Sampling rate:          %.6f MHz\n", fs/1e6);
    fprintf("FFT-bin spacing:        %.3f Hz\n", fs/N);
    fprintf("Peak frequency:         %.9f MHz\n", peak_freq/1e6);
    fprintf("Peak magnitude:         %.3f dB\n", peak_db);
    fprintf("Median noise floor:     %.3f dB/bin\n", noise_floor_db);
    fprintf("Estimated spectral SNR: %.3f dB\n", snr_est_db);

    % Plot FFT
    figure;
    plot(f/1e6, Xdb, 'LineWidth', 1.4);
    grid on;
    xlabel('Frequency (MHz)');
    ylabel('Magnitude (dB)');
    title(sprintf('FFT Spectrum: %s', label));

    % Optional zoom around low frequencies
    xlim([0, min(10, fs/(2*1e6))]);   % show 0 to 10 MHz if possible
end
