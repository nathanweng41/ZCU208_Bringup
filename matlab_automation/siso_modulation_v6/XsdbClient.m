classdef XsdbClient < handle % allows clearing of this object

    properties
        Host (1,1) string = "127.0.0.1"
        Port (1,1) double = 2000
        Timeout_s (1,1) double = 3.0
        T = []
    end

    methods
        function obj = XsdbClient(host, port, timeout_s)
            if nargin >= 1 && ~isempty(host), obj.Host = string(host); end
            if nargin >= 2 && ~isempty(port), obj.Port = double(port); end
            if nargin >= 3 && ~isempty(timeout_s), obj.Timeout_s = double(timeout_s); end

            obj.T = tcpclient(obj.Host, obj.Port);
        end

        function delete(obj)
            obj.close();
        end

        function close(obj)
            try
                if ~isempty(obj.T)
                    t = obj.T;
                    obj.T = [];
                    clear t
                end
            catch
                fprintf("Clearing Object Failed\n")
            end
        end

        function resp = send_and_read(obj, cmd, timeout_s)     
            if nargin < 3 || isempty(timeout_s), timeout_s = obj.Timeout_s; end

            % clear stale TCP input
            if obj.T.NumBytesAvailable > 0
                read(obj.T, obj.T.NumBytesAvailable, "uint8");
            end

            cmd = string(cmd);
            write(obj.T, uint8([char(cmd) 13 10])); % CRLF
    
            resp = "";
            t0 = tic;
            while toc(t0) < timeout_s
                n = obj.T.NumBytesAvailable;
                if n > 0
                    resp = resp + string(char(read(obj.T,n)));
                    if contains(resp, "okay") || contains(resp, "error")
                        break;
                    end
                else 
                    pause(0.02);
                end
            end

            if strlength(resp) == 0
                    resp = "WARNING: no response received (timeout).";
            end
        end

        function resp = pwd(obj)
            resp = obj.send_and_read("pwd", 2.0);
        end

        function resp = cd(obj, dirPath)
            dirPath = string(dirPath);
            resp = obj.send_and_read("cd {" + dirPath + "}", 2.0);
        end

        function resp = setTargetPSU(obj)
            resp = obj.send_and_read('targets -set -filter {name =~ "PSU"}', 2.0);
        end

        function resp = mwr(obj, addr, value, timeout_s)
            if nargin < 4 || isempty(timeout_s), timeout_s = 2.0; end
            % Assume given inputs are already in hex format
            a = obj.hexAddr(addr);
            v = obj.hexValue(value);

            resp = obj.send_and_read("mwr " + a + " " + v, timeout_s);
        end

        function resp = downloadData(obj, fn, addr)
            obj.setTargetPSU();

            fn = string(fn);
            a = obj.hexAddr(addr);
            cmd = "dow -force -data {" + fn + "} " + a;
            resp = obj.send_and_read(cmd, 10.0);
        end

        function resp = readCapture(obj, outDir, fn, adcAddr, capBytes, timeout_s)
            
            if nargin < 6 || isempty(timeout_s)
                timeout_s = (obj.Timeout_s + 10);
            end

            outDir = string(outDir);
            fn = string(fn);

            obj.setTargetPSU();

            adcAddr = obj.hexAddr(adcAddr);

            if mod(capBytes, 2) ~= 0 
                error("capBytes must be divisible by 2");
            end

            numHalfWords = uint64(capBytes) / 2;

            countStr = string(numHalfWords);
            
            resp = obj.send_and_read("mrd -force -size h -bin -file {" + outDir + "/" + fn + "} " + adcAddr + " " + countStr, timeout_s); % general ADC capture for Vivado
        end

        function s = hexAddr(~,x)
            if isstring(x) || ischar(x)
                s = string(x);
            else
                s = "0x" + lower(string(dec2hex(uint64(x), 8)));
            end
        end

        function s = hexValue(~,x)
            if isstring(x) || ischar(x)
                s = string(x);
            else
                s = "0x" + lower(string(dec2hex(uint64(x))));
            end
        end
    end
end

   
