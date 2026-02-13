clear s;

X = XsdbClient(host, port);
X.cd(pwd);

host = "127.0.0.1";
port = 2000;

s = SerialClient("COM13", 115200);
s.open();
disp(s.drain(2.5));

pause(3);
disp(s.uramCap());

disp(X.readCapture());

fc = 1e6;
fs_adc = 4.9e9;

[adc_ch0, pxx0, f0, fpk0, SNDR0] = adc_read_periodogram(0, fc, debug_adc);
pause(1);
[adc_ch1, pxx1, f1, fpk1, SNDR1] = adc_read_periodogram(1, fc, debug_adc);
pause(1);
[adc_ch2, pxx2, f2, fpk2, SNDR2] = adc_read_periodogram(2, fc, debug_adc);
pause(1);
[adc_ch3, pxx3, f3, fpk3, SNDR3] = adc_read_periodogram(3, fc, debug_adc);
pause(1);

x0 = double(adc_ch0(:));
x1 = double(adc_ch1(:));

    x0 = x0 - mean(x0);
    x1 = x1 - mean(x1);

    N = round(5*fs_adc/fc);

    time_ps = (0:N-1)'/fs_adc * 1e12;

    figure;
    plot(time_ps, x0(1:N), 'LineWidth',1.4); hold on;
    plot(time_ps, x1(1:N), 'LineWidth',1.4);
    hold off;
    grid on;
    title(sprintf('Raw Time Domain: ch0 vs ch3 @ %.2f MHz', fc/1e6));
    xlabel('Time (ps)');
    ylabel('Amplitude');
    legend('ch0','ch3','Location','best');
    ax = gca;
    ax.XAxis.Exponent = -12;

    
s.close();
X.close();
clear X;
