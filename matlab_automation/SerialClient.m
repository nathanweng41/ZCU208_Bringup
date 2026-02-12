classdef SerialClient < handle % Don't close this when script is done

    properties
        Port (1,1) string = "COM13"
        BaudRate (1,1) double = 115200
        Terminator (1,1) string = "CR/LF"
        ReadPoll_s (1,1) double = 0.02
        DefaultTimeout_s (1,1) double = 3.0
        S
    end

    methods
        function obj = SerialClient(port, baud)
            if nargin >= 1 && ~isempty(port), obj.Port = string(port); end
            if nargin >= 2 && ~isempty(baud), obj.BaudRate = double(baud); end
        end

        function open(obj)
            if ~isempty(obj.S)
                return;
            end

            obj.S = serialport(obj.Port, obj.BaudRate);
            configureTerminator(obj.S, char(obj.Terminator));
            obj.S.Timeout = obj.DefaultTimeout_s;
        end

        function close(obj)
            try
                if ~isempty(obj.S)
                    flush(obj.S);
                    obj.S = [];
                end
            catch
            end
        end

        function delete(obj)
            obj.close()
        end

        function writeLine(obj, cmd)
            if isempty(obj.S), obj.open(); end
            writeline(obj.S, string(cmd));
        end
         
        % helper to get bytes
        function out = readAvailable(obj) 
            if isempty(obj.S), obj.open(); end
            n = obj.S.NumBytesAvailable;
            if n <= 0 
                out = "";
                return;
            end
            out = string(char(read(obj.S,n,"uint8")));
        end

        % empties receive buffer
        function out = drain(obj, duration_s)
            if isempty(obj.S), obj.open(); end
            if nargin < 2 || isempty(duration_s), duration_s = obj.DefaultTimeout_s; end
            flush(obj.S, "input");

            out = "";
            t0 = tic;
            while toc(t0) < duration_s
                chunk = obj.readAvailable();
                if chunk ~= ""
                    out = out + chunk;
                else
                    pause(obj.ReadPoll_s);
                end
            end
        end

        function out = sendLine(obj, cmd, timeout_s)           
            if isempty(obj.S), obj.open(); end
            if nargin < 3 || isempty(timeout_s), timeout_s = obj.DefaultTimeout_s; end
            
            flush(obj.S,"input");
            obj.writeLine(cmd);

            out = "";
            t0 = tic;
            while toc(t0) < timeout_s
                chunk = obj.readAvailable();
                if chunk ~= ""
                    out = out + chunk;
                else
                    pause(obj.ReadPoll_s);
                end
            end

            if out == ""
                out = "WARNING: no serial output received (timeout).";
            end       
        end

        function out = uramPlay(obj, timeout_s)
            if nargin < 2, timeout_s = obj.DefaultTimeout_s; end
            out = obj.sendLine("uramPlay", timeout_s);
        end

        function out = uramCap(obj, timeout_s) 
            if nargin < 2, timeout_s = obj.DefaultTimeout_s; end
            out = obj.sendLine("uramCap", timeout_s);
        end

        function out = adcMTS(obj, a, b, timeout_s)
            if nargin < 4 || isempty(timeout_s), timeout_s = 10.0; end
            out = obj.sendLine("adcMTS " + string(a) + " " + string(b), timeout_s);
        end

        function out = dacMTS(obj, a, b, timeout_s)
            if nargin < 4 || isempty(timeout_s), timeout_s = 10.0; end
            out = obj.sendLine("dacMTS " + string(a) + " " + string(b), timeout_s);
        end

    end
end