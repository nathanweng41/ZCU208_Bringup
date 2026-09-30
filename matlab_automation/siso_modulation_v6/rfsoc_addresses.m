function A = rfsoc_addresses()
    %RFSOC_ADDRESSES Central address map for ZCU208 design.
    %
    % All addresses in one place. High-level code should never hard-code them.
    %
    %% ============================================================
    %  DAC Tile 0
    % ============================================================

    A.dac.t0.c0.name       = "DAC00";
    A.dac.t0.c0.kind       = "raw-tone";
    A.dac.t0.c0.bram       = hexaddr("A0340000");
    A.dac.t0.c0.startPtr   = hexaddr("A0290000");
    A.dac.t0.c0.stopPtr    = hexaddr("A02C0000");
    A.dac.t0.c0.uramEn     = hexaddr("A02F0000");

    A.dac.t0.c0.bufferBytes = uint32(131072);
    A.dac.t0.c0.wordBytes   = uint32(64);

    A.dac.t0.c2.name       = "DAC02";
    A.dac.t0.c2.kind       = "raw-tone";
    A.dac.t0.c2.bram       = hexaddr("A0360000");
    A.dac.t0.c2.startPtr   = hexaddr("A02A0000");
    A.dac.t0.c2.stopPtr    = hexaddr("A02D0000");
    A.dac.t0.c2.uramEn     = hexaddr("A0320000");

    A.dac.t0.c2.bufferBytes = uint32(131072);
    A.dac.t0.c2.wordBytes   = uint32(64);


    %% ============================================================
    %  DAC Tile 1
    % ============================================================

    A.dac.t1.c0.name       = "DAC10";
    A.dac.t1.c0.kind       = "raw-tone";
    A.dac.t1.c0.bram       = hexaddr("A0300000");
    A.dac.t1.c0.startPtr   = hexaddr("A00F0000");
    A.dac.t1.c0.stopPtr    = hexaddr("A0270000");
    A.dac.t1.c0.uramEn     = hexaddr("A0280000");

    A.dac.t1.c0.bufferBytes = uint32(131072);
    A.dac.t1.c0.wordBytes = uint32(64);

    A.dac.t1.c2.name       = "DAC12";
    A.dac.t1.c2.kind       = "raw-tone";
    A.dac.t1.c2.bram       = hexaddr("A0380000");
    A.dac.t1.c2.startPtr   = hexaddr("A02B0000");
    A.dac.t1.c2.stopPtr    = hexaddr("A02E0000");
    A.dac.t1.c2.uramEn     = hexaddr("A0330000");

    A.dac.t1.c2.bufferBytes = uint32(131072);
    A.dac.t1.c2.wordBytes   = uint32(64);


    %% ============================================================
    %  DAC Tile 2 - Modulation
    % ============================================================

    A.dac.t2.c0.name       = "DAC20";
    A.dac.t2.c0.kind       = "mod";
    A.dac.t2.c0.bram       = hexaddr("A0000000");
    A.dac.t2.c0.startPtr   = hexaddr("A0040000");
    A.dac.t2.c0.stopPtr    = hexaddr("A0060000");
    A.dac.t2.c0.uramEn     = hexaddr("A0080000");
    A.dac.t2.c0.modMode    = hexaddr("A0260000");
    A.dac.t2.c0.gain       = hexaddr("A0260008");

    A.dac.t2.c0.bufferBytes = uint32(32768);
    A.dac.t2.c0.wordBytes   = uint32(64);

    A.dac.t2.c2.name       = "DAC22";
    A.dac.t2.c2.kind       = "mod";
    A.dac.t2.c2.bram       = hexaddr("A00E0000");
    A.dac.t2.c2.startPtr   = hexaddr("A0050000");
    A.dac.t2.c2.stopPtr    = hexaddr("A01A0000");
    A.dac.t2.c2.uramEn     = hexaddr("A0010000");
    A.dac.t2.c2.modMode    = hexaddr("A0250000");
    A.dac.t2.c2.gain       = hexaddr("A0250008");

    A.dac.t2.c2.bufferBytes = uint32(32768);
    A.dac.t2.c2.wordBytes   = uint32(64);


    %% ============================================================
    %  DAC Tile 3
    % ============================================================

    A.dac.t3.c0.name       = "DAC30";
    A.dac.t3.c0.kind       = "raw-tone";
    A.dac.t3.c0.bram       = hexaddr("A00A0000");
    A.dac.t3.c0.startPtr   = hexaddr("A0130000");
    A.dac.t3.c0.stopPtr    = hexaddr("A01B0000");
    A.dac.t3.c0.uramEn     = hexaddr("A01C0000");

    A.dac.t3.c0.bufferBytes = uint32(131072);
    A.dac.t3.c0.wordBytes   = uint32(64);

    A.dac.t3.c2.name       = "DAC32";
    A.dac.t3.c2.kind       = "raw-tone";
    A.dac.t3.c2.bram       = hexaddr("A0100000");
    A.dac.t3.c2.startPtr   = hexaddr("A0180000");
    A.dac.t3.c2.stopPtr    = hexaddr("A0190000");
    A.dac.t3.c2.uramEn     = hexaddr("A01D0000");

    A.dac.t3.c2.bufferBytes = uint32(131072);
    A.dac.t3.c2.wordBytes   = uint32(64);


    %% ============================================================
    %  ADC Capture
    % ============================================================

    A.adc.c0.name           = "ADC10";
    A.adc.c0.bram           = hexaddr("A00C0000");
    A.adc.c0.bypassFir      = hexaddr("A01E0000");
    A.adc.c0.phaseValid     = hexaddr("A01F0000");
    A.adc.c0.phaseIncrement = hexaddr("A0200000");
    A.adc.c0.phase          = hexaddr("A0210000");
    A.adc.c0.captureBytes   = uint32(131072);

    A.adc.c2.name           = "ADC12";
    A.adc.c2.bram           = hexaddr("A0020000");
    A.adc.c2.bypassFir      = hexaddr("A0070000");
    A.adc.c2.phaseIncrement = hexaddr("A0220000");
    A.adc.c2.phase          = hexaddr("A0230000");
    A.adc.c2.phaseValid     = hexaddr("A0240000");
    A.adc.c2.captureBytes   = uint32(131072);
    
    A.adc.trigCap = hexaddr("A0090000");
    end

function x = hexaddr(s)
    x = uint64(hex2dec(s));
end
