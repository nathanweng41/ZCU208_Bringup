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
        dphi_deg = wrapTo180(-360 * fc * dt_sec);
        
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
