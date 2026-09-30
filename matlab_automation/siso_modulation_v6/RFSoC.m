classdef RFSoC < handle
    % RFSoC
    %
    % High-level abstraction for ZCU208 control.
    %
    % Hardware-specific addresses live in rfsoc_addresses.m.
    %
    % XSDB handles:
    %   - BRAM downloads and reads
    %   - start/stop pointers
    %   - modulation mode (GPIO)
    %   - modulation gain (GPIO)
    %
    % Serial handles:
    %   - RFDC NCO
    %   - MTS
    %   - playback enable
    %   - DAC VOP
    %   - RFDC startup/shutdown/reset

    properties
        Addr

        X = []      % XsdbClient
        S = []      % SerialClient

        Host (1,1) string = "127.0.0.1"
        XsdbPort (1,1) double = 2000

        SerialPort (1,1) string = "COM13"
        BaudRate (1,1) double = 115200

        DefaultOutDir (1,1) string = "./out"

        Connected (1,1) logical = false
    end


    methods

        %% =========================================================
        % Constructor / connection
        % ==========================================================

        function obj = RFSoC(serialPort, host, xsdbPort)

            obj.Addr = rfsoc_addresses();

            if nargin >= 1 && ~isempty(serialPort)
                obj.SerialPort = string(serialPort);
            end

            if nargin >= 2 && ~isempty(host)
                obj.Host = string(host);
            end

            if nargin >= 3 && ~isempty(xsdbPort)
                obj.XsdbPort = double(xsdbPort);
            end
        end


        function connect(obj)

            if obj.Connected
                return;
            end

            % Connect XSDB
            obj.X = XsdbClient(obj.Host, obj.XsdbPort);
            obj.X.cd(pwd);
            obj.X.setTargetPSU();

            % Connect serial firmware console
            obj.S = SerialClient(obj.SerialPort, obj.BaudRate);
            obj.S.open();

            % Discard startup text / stale serial output
            obj.S.drain(0.5);

            obj.Connected = true;
        end


        function disconnect(obj)

            try
                if ~isempty(obj.S)
                    obj.S.close();
                end
            catch
                warning("There may be an issue with closing the SerialClient.");
            end

            try
                if ~isempty(obj.X)
                    obj.X.close();
                end
            catch
                warning("There may be an issue with closing the XSDBClient.");
            end

            obj.S = [];
            obj.X = [];
            obj.Connected = false;
        end


        function delete(obj)
            obj.disconnect();
        end


        %% =========================================================
        % Generic DAC memory control
        % ==========================================================
        % filename here requires the full path to the file
        function loadData(obj, tile, channel, filename)

            obj.requireConnected();

            d = obj.getDAC(tile, channel);

            filename = string(filename);

            if ~isfile(filename)
                error("RFSoC:FileNotFound", "File does not exist: %s", filename);
            end

            info = dir(filename);

            if isfield(d, 'bufferBytes')
                if info.bytes > double(d.bufferBytes)
                    error("RFSoC:BufferOverflow", "File is %d bytes, but %s BRAM holds only %d bytes.", info.bytes, d.name, d.bufferBytes);
                end
            end

            obj.X.downloadData(filename, d.bram);
        end

        % ptr input format is integer, you can also put the exact string
        % "0x..."
        function setPointers(obj, tile, channel, startPtr, stopPtr)

            obj.requireConnected();

            d = obj.getDAC(tile, channel);

            startPtr = uint64(startPtr);
            stopPtr  = uint64(stopPtr);

            if startPtr > stopPtr
                error("startPtr must be <= stopPtr.");
            elseif startPtr == stopPtr
                warning("startPtr is same as stopPtr.");
            end

            if isfield(d, 'bufferBytes')
                if stopPtr >= uint64(d.bufferBytes)
                    error("stopPtr 0x%X exceeds %s buffer size.", stopPtr, d.name);
                end
            end

            obj.X.mwr(d.startPtr, startPtr);
            obj.X.mwr(d.stopPtr, stopPtr);
        end


        function setFullBufferPointers(obj, tile, channel)

            d = obj.getDAC(tile, channel);

            if ~isfield(d, 'bufferBytes') || ~isfield(d, 'wordBytes')
                error("Buffer geometry not defined for %s.", d.name);
            end

            startPtr = uint32(0);

            stopPtr = uint32(double(d.bufferBytes) - double(d.wordBytes));

            obj.setPointers(tile, channel, startPtr, stopPtr);
        end


        function startDAC(obj, tile, channel)

            obj.requireConnected();

            d = obj.getDAC(tile, channel);

            obj.X.mwr(d.uramEn, 1);
        end


        function stopDAC(obj, tile, channel)

            obj.requireConnected();

            d = obj.getDAC(tile, channel);

            obj.X.mwr(d.uramEn, 0);
        end

        %% =========================================================
        % ADC controls
        % ==========================================================

        function trigADCCap(obj)

            % Trigger ADC capture directly through GPIO
            obj.requireConnected();
            
            % Generate a clean rising-edge trigger
            obj.X.mwr(obj.Addr.adc.trigCap, 0);
            obj.X.mwr(obj.Addr.adc.trigCap, 1);

            % Short pulse
            pause(0.001);

            obj.X.mwr(obj.Addr.adc.trigCap, 0);
        end

        function setADCPhase(obj, channel, phase)

            obj.requireConnected();

            if ~isscalar(phase) || phase < 0 || phase > 15 || phase ~= floor(phase)
                error("ADC phase must be an integer from 0 to 15");
            end

            a = obj.getADC(channel);

            obj.X.mwr(a.phase, phase);

            obj.X.mwr(a.phaseValid, 1);
        end

        function incrementADCPhase(obj, channel)

            obj.requireConnected();

            a = obj.getADC(channel);

            obj.X.mwr(a.phaseIncrement, 0);
            obj.X.mwr(a.phaseIncrement, 1);

            pause(0.001);

            obj.X.mwr(a.phaseIncrement, 0);
        end

        function disableADCPhaseValid(obj, channel)

            obj.requireConnected();
        
            a = obj.getADC(channel);
        
            obj.X.mwr(a.phaseValid, 0);
        end

        function enableADCPhaseValid(obj, channel)

            obj.requireConnected();
        
            a = obj.getADC(channel);
        
            obj.X.mwr(a.phaseValid, 1);
        end
        %% =========================================================
        % Modulation controls
        % ==========================================================

        function setGain(obj, tile, channel, gainLinear)
            % gainLinear:
            %   0.0 -> 0x0000
            %   0.5 -> 0x4000
            %   1.0 -> 0x8000

            obj.requireConnected();

            d = obj.getDAC(tile, channel);

            if ~isfield(d, 'gain')
                error("%s does not have modulation gain control.", d.name);
            end

            if gainLinear < 0 || gainLinear > 1
                error("gainLinear must currently be between 0 and 1.");
            end

            gainQ15 = uint32(round(gainLinear * 32768));

            obj.X.mwr(d.gain, gainQ15);
        end


        function setGainQ15(obj, tile, channel, gainQ15)
            % Direct raw register write if needed.

            obj.requireConnected();

            d = obj.getDAC(tile, channel);

            if ~isfield(d, 'gain')
                error("%s does not have modulation gain control.", d.name);
            end

            gainQ15 = uint32(gainQ15);

            if gainQ15 > 32678
                error("%s 's gain is not supposed to go above 1.", d.name);
            end

            obj.X.mwr(d.gain, gainQ15);
        end


        function setModMode(obj, tile, channel, mode)

            obj.requireConnected();

            d = obj.getDAC(tile, channel);

            if ~isfield(d, 'modMode')
                error("%s does not support selectable modulation.", d.name);
            end

            if isnumeric(mode)

                modeValue = double(mode);

                if modeValue ~= 0 && modeValue ~= 1
                    error("Numeric modulation mode must be 0 or 1.");
                end

            else

                mode = upper(string(mode));

                switch mode
                    case "QPSK"
                        modeValue = 0;

                    case {"16QAM", "16-QAM"}
                        modeValue = 1;

                    otherwise
                        error("Unsupported modulation mode: %s", mode);
                end
            end

            obj.X.mwr(d.modMode, modeValue);
        end


        function configureModulation(obj, tile, channel, filename, startPtr, stopPtr, mode, gainLinear)

            d = obj.getDAC(tile, channel);

            if ~isfield(d, 'kind') || string(d.kind) ~= "mod"
                error("%s is not a modulation datapath.", d.name);
            end

            obj.stopDAC(tile, channel);

            obj.loadData(tile, channel, filename);

            obj.setModMode(tile, channel, mode);

            obj.setGain(tile, channel, gainLinear);

            obj.setPointers(tile, channel, startPtr, stopPtr);

        end

        function cap = modCapture(obj, phaseQ, phaseI, outDir, playbackTile, playbackChannel)

            % Complete ADC I/Q capture sequence.
            %
            % Example:
            %
            %   cap = rf.captureIQ(0, 2);
            %
            % Returns:
            %   cap.Q
            %   cap.I
            %   cap.QFile
            %   cap.IFile
            %   cap.serialResponse
        
            obj.requireConnected();
        
            if nargin < 4 || isempty(outDir)
                outDir = obj.DefaultOutDir;
            end
        
            % Default playback source = DAC tile 2 channel 0
            if nargin < 5 || isempty(playbackTile)
                playbackTile = 2;
            end
        
            if nargin < 6 || isempty(playbackChannel)
                playbackChannel = 0;
            end
        
            outDir = string(outDir);
        
            if ~isfolder(outDir)
                mkdir(outDir);
            end
        
            % ---------------------------------------------------------
            % 1. Configure ADC phases and enable phase_valid
            % ---------------------------------------------------------
        
            obj.setADCPhase(0, phaseQ);
            obj.setADCPhase(2, phaseI);
        
        
            % ---------------------------------------------------------
            % 3. Arm + trigger ADC capture
            % ---------------------------------------------------------
        
            obj.trigADCCap();
        
            pause(0.010);
        
            % ---------------------------------------------------------
            % 4. Save captured memories to bin file
            % ---------------------------------------------------------
        
        
            obj.X.readCapture(outDir, "Q_data.bin", adcQ.bram, adcQ.captureBytes);
        
            obj.X.readCapture(outDir, "I_data.bin", adcI.bram, adcI.captureBytes);
        end

        %% =========================================================
        % RFDC controls
        % ==========================================================

        function out = setNCO(obj, tile, channel, frequencyMHz)
            % Firmware dacSetNCO currently expects MHz.

            obj.requireConnected();

            out = obj.S.dacSetNCO(tile, channel, frequencyMHz);
        end


        function out = setVOP(obj, tile, channel, current_uA)

            obj.requireConnected();

            if current_uA < 0 || current_uA > 40500
                error("DAC VOP must be between 0 and 40500 uA.");
            end

            out = obj.S.dacSetVOP(tile, channel, current_uA);
        end


        function out = dacMTS(obj, a, b)

            obj.requireConnected();

            out = obj.S.dacMTS(a, b);
        end


        function out = adcMTS(obj, a, b)

            obj.requireConnected();

            out = obj.S.adcMTS(a, b);
        end


        function out = startupRFDC(obj)

            obj.requireConnected();

            out = obj.S.rfdcStartup();
        end


        function out = shutdownRFDC(obj)

            obj.requireConnected();

            out = obj.S.rfdcShutdown();
        end

        function out = resetDacs(obj)

            obj.requireConnected();

            out = obj.S.dacResetAll();
        end

        function out = resetAdcs(obj)

            obj.requireConnected();

            out = obj.S.adcResetAll();
        end

        %% =========================================================
        % Raw tone generation
        % ==========================================================

        function result = generateRawTone(obj, tile, channel, fc, amplitude_dbfs, phase_deg, interpolation_rate, outDir, debug)

            obj.requireConnected();

            d = obj.getDAC(tile, channel);

            if isfield(d, 'kind') && string(d.kind) ~= "raw-tone"
                error("%s is a modulation-symbol datapath. " + "generate_tone() cannot be used on this channel.", d.name);
            end

            if nargin < 8 || isempty(outDir)
                outDir = obj.DefaultOutDir;
            end

            if nargin < 9 || isempty(debug)
                debug = false;
            end

            outDir = string(outDir);

            if ~isfolder(outDir)
                mkdir(outDir);
            end

            filename = sprintf("dac_t%d_c%d_tone.bin", tile, channel);

            [startPtr, stopPtr, fn, fp] = generate_tone(fc, phase_deg, amplitude_dbfs, interpolation_rate, outDir, filename, debug);

            % Stop before rewriting BRAM/pointers
            obj.stopDAC(tile, channel);

            % Download waveform
            obj.loadData(tile, channel, fn);

            % Program playback range
            obj.setPointers(tile, channel, startPtr, stopPtr);

            % Return everything useful to caller / GUI
            result = struct();

            result.tile = tile;
            result.channel = channel;
            result.name = d.name;

            result.filename = string(fn);

            result.startPtr = startPtr;
            result.stopPtr = stopPtr;

            result.fcRequested = fc;
            result.fcExact = fp.fc_exact;

            result.amplitudeDbfs = amplitude_dbfs;
            result.phaseDeg = phase_deg;

            result.fp = fp;
        end

    end


    methods (Access = private)

        function requireConnected(obj)

            if ~obj.Connected || isempty(obj.X) || isempty(obj.S)
                error("RFSoC is not connected. Call rf.connect() first.");
            end
        end


        function d = getDAC(obj, tile, channel)

            tileField = sprintf("t%d", tile);
            chField   = sprintf("c%d", channel);

            if ~isfield(obj.Addr.dac, tileField)
                error("DAC tile %d does not exist.", tile);
            end

            tileStruct = obj.Addr.dac.(tileField);

            if ~isfield(tileStruct, chField)
                error( ...
                    "DAC tile %d channel %d does not exist.", ...
                    tile, channel);
            end

            d = tileStruct.(chField);
        end

        function a = getADC(obj, channel)

            chField = sprintf("c%d", channel);

            if ~isfield(obj.Addr.adc, chField)
                error("ADC channel %d does not exist in address map.", channel);
            end

            a = obj.Addr.adc.(chField);
        end

    end
end