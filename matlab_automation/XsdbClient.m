classdef XsdbClient < handle % allows clearing of this object

    properties
        Host (1,1) string = "127.0.0.1"
        Port (1,1) double = 2000
        Timeout_s (1,1) double = 3.0
        T tcpclient
    end

    methods
        function obj = XsdbClient(host, port, timeout_s)
            if nargin >= 1 && ~isempty(host), obj.Host = string(host); end
            if nargin >= 2 && ~isempty(port), obj.Port = double(port); end
            if nargin >= 3 && ~isempty(timeout_s), obj.Timeout_s = double(timeout_s); end

            obj.T = tcpclient(obj.Host, obj.Port);
        end

        function delete(obj)
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

        function close(obj)
            obj.delete()
        end

        function resp = send_and_read(obj, cmd, timeout_s)     
            if nargin < 3 || isempty(timeout_s), timeout_s = obj.Timeout_s; end
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

            if resp == ""
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
            a = string(addr);
            v = string(value);
            resp = obj.send_and_read("mwr " + a + " " + v, timeout_s);
        end

        function resp = downloadTone(obj, fn, addr)
            obj.setTargetPSU();
            fn = string(fn);
            a = string(addr);
            cmd = "dow -force -data {" + fn + "} " + a;
            resp = obj.send_and_read(cmd, 10.0);
        end

         % Sets stop ptrs
        function resp = setPtrs(obj, ptrValue)
            resp = "";
            resp = resp + "Setting ptrs" + newline;
            resp = resp + obj.mwr("0xA0110000", ptrValue, 2.0); % s00 on Vivado, Tile 228_0 on board
            resp = resp + obj.mwr("0xA00E0000", ptrValue, 2.0); % s02 on Vivado, Tile 228_2 on board
            resp = resp + obj.mwr("0xA00F0000", ptrValue, 2.0); % s10 on Vivado, Tile 229_0 on board
            resp = resp + obj.mwr("0xA0100000", ptrValue, 2.0); % s12 on Vivado, Tile 229_2 on board
            resp = resp + "Successfully finished setting ptrs" + newline;
        end

        % This function shouldn't change much (capture)
        function resp = readCapture(obj, outDir, timeout_s)
            if nargin < 2 || isempty(outDir)
                outDir = "../out";
            end
            if nargin < 3 || isempty(timeout_s)
                timeout_s = (obj.Timeout_s + 10);
            end

            outDir = string(outDir);

            resp = "";
            resp = resp + obj.setTargetPSU();
            resp = resp + obj.send_and_read("mrd -force -size h -bin -file {" + outDir + "/cap0.bin} 0xA0120000 65536", timeout_s); % m00 on Vivado, Tile 224_0 on board
            resp = resp + obj.send_and_read("mrd -force -size h -bin -file {" + outDir + "/cap1.bin} 0xA0180000 65536", timeout_s); % m02 on Vivado, Tile 224_2 on board
            resp = resp + obj.send_and_read("mrd -force -size h -bin -file {" + outDir + "/cap2.bin} 0xA01A0000 65536", timeout_s); % m10 on Vivado, Tile 225_0 on board        
            resp = resp + obj.send_and_read("mrd -force -size h -bin -file {" + outDir + "/cap3.bin} 0xA01C0000 65536", timeout_s); % m12 on Vivado, Tile 225_2 on board
        end

    end
end

   