# ZCU208 Bring-Up

MATLAB, Verilog, SystemVerilog scripts and testbenches for bringing up the AMD/Xilinx ZCU208 RFSoC as a lab test platform.

Each version below corresponds to a specific XSA hardware design. 

## [SISO Modulation 2.4]

### Features
- **ADC:** Added ADC NCO as well as a simple capture at 160 MSPS (1 complex sample per clk) to validate SISO Modulation 2.3
- **MTS:** Validated MTS works on Tiles 225 and 230
- **Vitis:** Added Vitis code support to sync DAC/ADC NCO to SYSREF clk, yet to be verified

### Known Issues
- **CLK:** 640 MHz is brought out on the LMK board, but high harmonics (-21 dBm at 1.28 GHz) were observed

---

## [SISO Modulation 2.3]

### Features
- **Modulation Scheme:** Implemented QPSK + 16-QAM modulation support and an option to change the output gain (less than or equal to 1) through Vitis. Note: if you need higher gain, change DAC VOP.

### Bug Fixes
- **Sample Per Symbol Counter:** Counter is fixed from previous version. Design has been verified to output the correct samples per symbol

### Known Issues
- **CLK:** 640 MHz is brought out on the LMK board, but high harmonics (-21 dBm at 1.28 GHz) were observed

--- 

## [SISO Modulation 2.2 ILA]

### Features
- Added 2 ILAs for debug: one at the output of the RFSoC and one after the downsampler

### Known Issues
- **CLK:** 640 MHz is brought out on the LMK board, but high harmonics (-21 dBm at 1.28 GHz) were observed
- **Sample Per Symbol Counter:** Steady state is fine, but it may initially be one clock short

## [SISO Modulation 2.2] 
**Date**: 2026-08-17

### Features

#### ADC
- Added ADC support on **ADC Tile 225**
- Supports programmable phase/delay selection
- Supports ADC capture and BRAM read
- Added explicit downsampling and phase-selectable capture path

#### FIR
- Optional RX FIR filter before the downsampler
- FIR can be enabled or bypassed through Vitis

#### DAC
- **DAC Tile 231** supports 2-channel waveform streaming 
- Supports BRAM waveform playback
- DAC NCO has separate uramPlay, will need to combine GPIOs in the next revision

### Example DAC -> ADC Flow

1. Download the DAC waveform into BRAM:

   ```tcl
   dow -force -data ./dac_ramp_10MHz_128k.bin 0xa00a0000
   ```

2. Set the DAC stop pointer:

   ```tcl
   mwr 0xa01b0000 0x0001FDC0
   ```

3. Set the DAC start pointer:

   ```tcl
   mwr 0xa0130000 0x00000000
   ```

4. Start waveform playback:

   ```tcl
   uramPlay
   ```

5. Enable downsampler:

   ```tcl
   mwr 0xa01f0000 1
   ```

6. Set desired ADC capture phase:

    ```tcl
    mwr 0xa0210000 2
    ```

7. Trigger capture:
`
    ```tcl
    uramCap
    ```

8. Read the ADC capture back from BRAM:
    ```tcl
    mrd -force -size h -bin -file ./cap0.bin 0xa00c0000 65536
    ```

### Known Issues
- **CLK:** 640 MHz is brought out on the LMK board, but high harmonics (-21 dBm at 1.28 GHz) were observed
- **Sample Per Symbol Counter:** Steady state is fine, but it may initially be one clock short

---

## SISO Modulation 2.1

### Features

#### NCO
- DAC NCO operational
- Validated up to **950 MHz**

#### DAC
- QPSK symbol transmission supported on DAC Tile 230
- Complex baseband processing at **160 MSPS**

--- 

## 4x4 MIMO
**XSA:** `zcu208_adc_v03`

### Features

#### DAC / ADC
- 4-TX / 4-RX architecture for MIMO testing
- Multi-Tile Synchronization (MTS) support
- See the Vivado address map / register map for programming details

#### MATLAB
- Some MATLAB automation support available
- See:

  ```text
  matlab_automation/
  ```

---

## Repository Contents

Typical contents include:

- MATLAB waveform-generation and analysis scripts
- Verilog/SystemVerilog RTL
- SystemVerilog testbenches
- RFDC bring-up and configuration code
- DAC waveform playback
- ADC capture and phase-selection logic
- FIR filter design and verification
- Modulation and MIMO test utilities
