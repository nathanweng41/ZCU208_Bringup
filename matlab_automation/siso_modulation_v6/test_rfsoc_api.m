%% test_rfsoc_api.m

clear;
clc;

%% ============================================================
% User settings
% ============================================================

tile = 1;
channel = 0;

fc = 640e6;            % 640 MHz raw DAC tone
amplitude_dbfs = -3;  % -3 dBFS, -8.71dBm (1.1Ghz), -5.66dBm (640 MHz)
phase_deg = 0;         % 0 degree phase
interpolation = 1;

%% ============================================================
% Connect to RFSoC
% ============================================================

rf = RFSoC("COM5");

fprintf("Connecting to RFSoC...\n");
rf.connect();

%% ============================================================
% Generate + download waveform
% ============================================================

fprintf("Generating waveform...\n");

result = rf.generateRawTone(tile, channel, fc, amplitude_dbfs, phase_deg, interpolation);

fprintf("\nWaveform loaded:\n");
fprintf("  DAC          = Tile %d Channel %d\n", tile, channel);
fprintf("  Requested fc = %.6f MHz\n", result.fcRequested/1e6);
fprintf("  Actual fc    = %.6f MHz\n", result.fcExact/1e6);
fprintf("  Amplitude    = %.2f dBFS\n", result.amplitudeDbfs);
fprintf("  Start ptr    = 0x%08X\n", result.startPtr);
fprintf("  Stop ptr     = 0x%08X\n", result.stopPtr);
fprintf("  File         = %s\n", result.filename);

%% ============================================================
% Start DAC playback
% ============================================================

fprintf("\nStarting DAC playback...\n");

rf.startDAC(tile, channel);

fprintf("DAC is now playing.\n");

%% ============================================================
% Wait until user wants to stop
% ============================================================

input("Press ENTER to stop playback...");

rf.stopDAC(tile, channel);

fprintf("DAC stopped.\n");

%% ============================================================
% Disconnect
% ============================================================

rf.disconnect();

fprintf("Done.\n");