# Modulation v2.5 Test Plan

## 16-QAM Test 
### DAC 230_0 -> ADC 225_0, 225_2 (I,Q)

1. Disable DAC playback and download the 16-QAM test waveform into BRAM

    ```tcl
    mwr 0xa0080000 0
    dow -force -data ./qam16_all_symbols_128k.bin 0xa0000000
    ```

2. Set mode to 16-QAM, and set gain (There is a 0.84x backoff internally, so gain_eff = 0.84 * Gain)
    
    ```tcl
    mwr 0xa0260000 0x1

    Gain = 1:
    mwr 0xa0260008 0x8000

    Gain = 0.5:
    mwr 0xa0260008 0x4000

    Gain ~= 0.3:
    mwr 0xa0260008 0x2666
    ```

3. Set start and stop pointers

    ```tcl
    mwr 0xa0040000 0
    mwr 0xa0060000 0x0001ffc0
    ```

4. Originally need to set symbol period, now locked at 2.5MSPS

5. Set NCO on DAC to 600 MHz on Serial Monitor

    ```tcl
    dacSetNCO 2 0 600
    ```

6. Set ADC capture phase and enable valid

    ```tcl
    (225_0): mwr 0xa0210000 (0-15)
    (225_1): mwr 0xa0020000 (0-15)

    (225_0): mwr 0xa01f0000 1
    (225_2): mwr 0xa0240000 1
    ```

7. Enable DAC waveform playback

    ```tcl
    mwr 0xa0080000 1
    ```

8. Capture ADC output

    ```tcl
    uramCap [mwr 0xa0090000 1]
    ```

9. Download I and Q data and perform post-processing in MATLAB

    ```tcl
    (225_0): mrd -force -size h -bin -file ./Q_data.bin 0xa00c0000 65536
    (225_2): mrd -force -size h -bin -file ./I_data.bin 0xa02a0000 65536
    ```

10. Change ADC capture phase on the fly as necessary.
