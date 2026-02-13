% System Setup
clear s;

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
fc_750 = 751e6;
fc_15 = 1.5e9;
fc_640 = 640e6;
amplitude_dbfs_750 = -13.98;
amplitude_dbfs_15 = 0;
amplitude_dbfs_640 = 13.98;
debug_dac = 1;
debug_adc = 1;
dphi_deg = 0;
interpolation = 1;
adc = 1;

% Tone Generation
[start_ch0, stop_ch0, fn_ch0, fp_ch0] = generate_tone(fc_750, dphi_deg, amplitude_dbfs_750, interpolation, "../out",dac_ch0,debug_dac);
[start_ch1, stop_ch1, fn_ch1, fp_ch1] = generate_tone(fc_640, dphi_deg, amplitude_dbfs_640, interpolation, "../out",dac_ch1,debug_dac);
[start_ch2, stop_ch2, fn_ch2, fp_ch2] = generate_tone(fc_15, dphi_deg, amplitude_dbfs_15, interpolation, "../out",dac_ch2,debug_dac);

% Start XSDB
X = XsdbClient(host, port);
X.cd(pwd);

s = SerialClient("COM13", 115200);
s.open();
disp(s.drain(2.5));

disp(s.uramStop());
pause(3);

% Download Tones
 disp(X.setTargetPSU());
 disp(X.downloadTone(fn_ch0, dac_ch0_addr));
 disp(X.downloadTone(fn_ch1, dac_ch1_addr));
 disp(X.downloadTone(fn_ch2, dac_ch2_addr));
 pause(2);

 ptr_hex_ch0 = "0x" + upper(string(dec2hex(uint32(stop_ch0), 8)));
 fprintf("%s", ptr_hex_ch0);

 ptr_hex_ch1 = "0x" + upper(string(dec2hex(uint32(stop_ch1), 8)));
 fprintf("%s", ptr_hex_ch1);

 ptr_hex_ch2 = "0x" + upper(string(dec2hex(uint32(stop_ch2), 8)));
 fprintf("%s", ptr_hex_ch2);

disp(X.setPtrs("0xA0110000",ptr_hex_ch0));
disp(X.setPtrs("0xA00E0000",ptr_hex_ch1));
disp(X.setPtrs("0xA00F0000",ptr_hex_ch2));

disp(serialportlist("available"));

% Play and Capture Tone on Serial Monitor
disp(s.uramPlay());
pause(5);

s.close();
X.close();
clear X;
