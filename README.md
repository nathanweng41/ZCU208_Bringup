# ZCU208_Bringup
MATLAB, Verilog, SystemVerilog scripts and testbenches to bringup RF SoC ZCU208 as a lab tool. Versions described below correspond to XSA files. 

## [2.2] (2026-08-17)

### Features
* **ADC**: Add ADC features on ADC Tile 225. Now able to calibrate with programmable delay and stream data out of BRAM

* Example flow:
* 1. Download data (`dow -force -data ./dac_ramp_10MHz_128k.bin 0xa00a0000`)
* 2. Set stop ptr (`mwr 0xa01b0000 0x0001fdc0`)
* 3. Set start ptr (`mwr 0xa0130000 0`)
* 4. Enable stream (`uramPlay`)
* 5. 

* **FIR**: Optional FIR enable through Vitis before downsampler on RX

* **DAC**: DAC Tile 231 has 2 channels for waveform streaming

### Bugs
* **NCO**: NCO on DAC is not working

## [2.1] 

### Features
* **NCO**: DAC has NCO working, validated up to 950 MHz
* **DAC**: DAC is able to send QPSK symbols successfully with baseband rate of 160 MHz
