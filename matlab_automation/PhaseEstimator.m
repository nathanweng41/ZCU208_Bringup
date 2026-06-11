classdef PhaseEstimator
    methods (Static)
        % ----------------- 
        % Delay Calculation using FFT
        % -----------------
        function [dphi_deg, fc_estimate, dt_sec, k] = estimate_phase_fft(ref, sig)
        % Inputs:
        %   ref: reference signal
        %   sig: signal to compare against
        %   NOTE: ref and sig should be same length
        % Outputs:
        %   dphi_deg: phase difference (deg)
        %   fc_estimate: estimated tone frequency from FFT
        %   dt_sec: time skew (sec)
        %   k: FFT bin for tone frequency
        
        fs = 4.9e9;
        ref = double(ref(:)) - mean(ref);
        sig = double(sig(:)) - mean(sig);
        N = length(ref);
        
        % find tone bin from reference
        Xref = fft(ref);
        mag = abs(Xref(2:floor(N/2)));
        [~, mag_pk] = max(mag);
        k = mag_pk + 1;
        
        fc_estimate = (k-1) * fs / N;
        
        Xsig = fft(sig);
        
        phi_ref = angle(Xref(k));
        phi_sig = angle(Xsig(k));
        
        dphi_deg = wrapTo180(rad2deg(phi_sig - phi_ref));
        dt_sec = (dphi_deg/360) / fc_estimate;
        end
        
        function [dphi_deg, dt_sec] = estimate_phase_tone(ref, sig, fc, fs)
            ref = double(ref(:)) - mean(double(ref(:)));
            sig = double(sig(:)) - mean(double(sig(:)));
        
            N = min(length(ref), length(sig));
            ref = ref(1:N);
            sig = sig(1:N);
        
            n = (0:N-1).';
            w = exp(-1j * 2*pi*fc*n/fs);
        
            R = sum(ref .* w);
            S = sum(sig .* w);
        
            dphi_deg = wrapTo180(rad2deg(angle(S) - angle(R)));
            dt_sec = (dphi_deg / 360) / fc;
        end

        % ----------------
        % Delay Calculation using Cross-Correlation
        %-----------------
        function [dphi_deg, dt_sec, lag_samp] = estimate_phase_xcorr(ref, sig, fc)
        % Inputs:
        %   ref: reference signal
        %   sig: signal to compare against
        %   fc: expected tone frequency
        %   NOTE: ref and sig should be same length
        % Outputs:
        %   dphi_deg: phase difference (deg)
        %   dt_sec: time skew (sec)
        %   lag_samp: integer Lag (samples)
        
        fs = 4.9e9;
        ref = double(ref(:)) - mean(ref);
        sig = double(sig(:)) - mean(sig);
        
        [c, lags] = xcorr(sig, ref, 'coeff');
        [~, max_idx] = max(c);
        lag_samp = lags(max_idx);

        dt_sec = lag_samp / fs;
        dphi_deg = wrapTo180(360 * fc * dt_sec);
        
        end

        function [dphi_deg, dt_sec, lag_samp, fs_ds] = estimate_phase_xcorr_filtered(ref, sig, fc, fs)
            ref = double(ref(:)) - mean(ref);
            sig = double(sig(:)) - mean(sig);

            % Choose decimation factor
            D = 100;
            fs_ds = fs/D;

            cutoff_hz = 5e6;

            % FIR lowpass
            filt_order = 512;
            b = fir1(filt_order, cutoff_hz/(fs/2),'low');

            ref_f = filtfilt(b,1,ref);
            sig_f = filtfilt(b,1,sig);

            % Remove filter edge regions
            guard = 3 * filt_order;
            
            if length(ref_f) <= 2*guard
                error("Capture is too short for the selected filter order.");
            end
            
            ref_f = ref_f(guard+1:end-guard);
            sig_f = sig_f(guard+1:end-guard);

            % Downsample
            ref_ds = ref_f(1:D:end);
            sig_ds = sig_f(1:D:end);

            % Reperform cross-corr
            [c,lags] = xcorr(sig_ds, ref_ds, 'coeff');
            [~, max_idx] = max(c);

            lag_samp = lags(max_idx);
            dt_sec = lag_samp / fs_ds;
            dphi_deg = wrapTo180(360 * fc * dt_sec);

            % We also plot downsampled waveforms

            samples_per_cycle_ds = fs_ds / fc;
            Nplot = round(5 * samples_per_cycle_ds);

            time_us = (0:Nplot-1).' / fs_ds * 1e6;

            figure;
            plot(time_us, ref_ds(1:Nplot), 'LineWidth',1.4);
            hold on;
            plot(time_us, sig_ds(1:Nplot), 'LineWidth',1.4);

            title(sprintf("Filtered and Downsampled Waveforms: %.2f MHz, D = %d", fc/1e6, D));
        
            legend("Reference", "Signal", "Location", "best");
                    
            grid on;

            fprintf("Downsampled sampling rate: %.3f MHz\n", fs_ds/1e6);
            fprintf("Samples per cycle after downsampling: %.3f\n", samples_per_cycle_ds);
            fprintf("XCorr lag: %d downsampled samples\n", lag_samp);
            fprintf("Estimated phase: %+.6f deg\n", dphi_deg);
        end

        % ---------------
        % Delay Calculation using XOR Phase Detector
        % ----------------- 
        
        function [dphi_deg, dt_sec, duty] = estimate_phase_xor_pd(ref, sig, fc, dt_sign_ref)
        % Inputs:
        %   ref: reference signal
        %   sig: signal to compare against
        %   fc: exepcted tone frequency
        %   dt_sign_ref: time skew used for sign of phase
        %   NOTE: ref and sig should be same length
        % Outputs:
        %   dphi_deg: phase difference (deg)
        %   dt_sec: time skew (sec)
        %   duty: duty cycle
        
        ref = double(ref(:)) - mean(ref);
        sig = double(sig(:)) - mean(sig);
        
        ref_1 = (ref >= 0);
        sig_1 = (sig >= 0);
        
        x_xor = xor(ref_1, sig_1);
        
        % mean duty cycle assuming phase is constant
        duty = mean(x_xor);
        
        phi_mag_deg = rad2deg(duty * pi);
        
        sgn = sign(dt_sign_ref);
        if sgn == 0, sgn = 1; end
        
        dphi_deg = wrapTo180(sgn * phi_mag_deg);
        
        dt_sec = (dphi_deg/360) / fc;
        
        end
    end
end
