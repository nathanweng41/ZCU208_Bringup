# Modulation v2.4 Test Plan

## 16-QAM Test (Skip NCO sync to see if constellation is already close enough to ideal or not) 
### DAC 230_0 -> ADC 224_0

1. Disable DAC playback and download the 16-QAM test waveform into BRAM

    ```tcl
    mwr 0xa0080000 0
    dow -force -data ./qam16_all_symbols_128k.bin 0xa0000000
    ```

2. Set mode to 16-QAM, and set gain
    
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

4. Set symbol period (16 to start)

    ```tcl
    mwr 0xa0070000 0x10
    ```

5. Set NCO on DAC to 600 MHz on Serial Monitor

    ```tcl
    dacSetNCO 2 0 600
    ```

6. Enable DAC waveform playback

    ```tcl
    mwr 0xa0080000 1
    ```

7. Set NCO on ADC to 600 MHz 

    ```tcl
    adcSetNCO 0 0 600

8. Capture ADC output

    ```tcl
    uramCap [mwr 0xa0290000 1]
    ```

9. Download I and Q data and perform post-processing in MATLAB

    ```tcl
    mrd -force -size h -bin -file ./I_data.bin 0xa02a0000 65536
    mrd -force -size h -bin -file ./Q_data.bin 0xa02c0000 65536
    ```

## 16-QAM Test (Sync NCO and see results) 
### DAC 230_0 -> ADC 224_0

1. Disable DAC playback and download the 16-QAM test waveform into BRAM

    ```tcl
    mwr 0xa0080000 0
    dow -force -data ./qam16_all_symbols_128k.bin 0xa0000000
    ```

2. Run MTS

    ```tcl
    adcMTS 0x3 0x0
    dacMTS 0x3 0x0
    ```

3. Set ADC/DAC NCOs

    ```tcl
    dacSetNCO 2 0 600
    adcSetNCO 0 0 600
    ```

4. Set mode to 16-QAM, and set gain
    
    ```tcl
    mwr 0xa0260000 0x1

    Gain = 1:
    mwr 0xa0260008 0x8000

    Gain = 0.5:
    mwr 0xa0260008 0x4000

    Gain ~= 0.3:
    mwr 0xa0260008 0x2666
    ```

5. Set start and stop pointers

    ```tcl
    mwr 0xa0040000 0
    mwr 0xa0060000 0x0001ffc0
    ```

6. Set symbol period (16 to start)

    ```tcl
    mwr 0xa0070000 0x10
    ```

7. Sync NCOs

    ```tcl
    syncNCO
    ```

8. Enable DAC waveform playback

    ```tcl
    mwr 0xa0080000 1
    ```

9. Capture ADC output

    ```tcl
    uramCap [mwr 0xa0290000 1]
    ```

10. Download I and Q data and perform post-processing in MATLAB

    ```tcl
    mrd -force -size h -bin -file ./I_data.bin 0xa02a0000 65536
    mrd -force -size h -bin -file ./Q_data.bin 0xa02c0000 65536
    ```
