/******************************************************************************
*  (c) Copyright 2018-2024 Advanced Micro Devices, Inc. All rights reserved.
*
*  This file contains confidential and proprietary information
*  of Advanced Micro Devices, Inc. and is protected under U.S. and
*  international copyright and other intellectual property
*  laws.
*
*  DISCLAIMER
*  This disclaimer is not a license and does not grant any
*  rights to the materials distributed herewith. Except as
*  otherwise provided in a valid license issued to you by
*  AMD, and to the maximum extent permitted by applicable
*  law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
*  WITH ALL FAULTS, AND AMD HEREBY DISCLAIMS ALL WARRANTIES
*  AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
*  BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
*  INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
*  (2) AMD shall not be liable (whether in contract or tort,
*  including negligence, or under any other theory of
*  liability) for any loss or damage of any kind or nature
*  related to, arising under or in connection with these
*  materials, including for any direct, or any indirect,
*  special, incidental, or consequential loss or damage
*  (including loss of data, profits, goodwill, or any type of
*  loss or damage suffered as a result of any action brought
*  by a third party) even if such damage or loss was
*  reasonably foreseeable or AMD had been advised of the
*  possibility of the same.
*
*  CRITICAL APPLICATIONS
*  AMD products are not designed or intended to be fail-
*  safe, or for use in any application requiring fail-safe
*  performance, such as life-support or safety devices or
*  systems, Class III medical devices, nuclear facilities,
*  applications related to the deployment of airbags, or any
*  other applications that could lead to death, personal
*  injury, or severe property or environmental damage
*  (individually and collectively, "Critical
*  Applications"). Customer assumes the sole risk and
*  liability of any use of AMD products in Critical
*  Applications, subject only to applicable laws and
*  regulations governing limitations on product liability.
*
*  THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
*  PART OF THIS FILE AT ALL TIMES.
******************************************************************************/



/***************************** Include Files *********************************/
#include <stdio.h>
#include <stdlib.h>
#include "xil_io.h"
#include "xil_types.h"
#include "cli.h"
#include "xparameters.h"
#include "xrfdc.h"
//#include "xrfdc_mts.h"
#include "main.h"
#include "rfdc_cmd.h"


/************************** Constant Definitions *****************************/

/**************************** Type Definitions *******************************/

/***************** Macros (Inline Functions) Definitions *********************/

/************************** Function Prototypes ******************************/

/************************** Variable Definitions *****************************/

XRFdc_MultiConverter_Sync_Config ADC_Sync_Config2;
XRFdc_MultiConverter_Sync_Config DAC_Sync_Config2;


/************************** Function Definitions ******************************/


/*****************************************************************************/
/**
*
* cli_cmd_func_dac_init Add functions from this file to CLI
*
* @param	None
*
* @return	None
*
* @note		TBD
*
******************************************************************************/

void cli_rfdc_cmd_init(void)
{
	static CMDSTRUCT cliCmds[] = {
		//000000000011111111112222    000000000011111111112222222222333333333
		//012345678901234567890123    012345678901234567890123456789012345678
		{"#################### rfdc commands #####################" , " " , 0, *cmdComment   },
		{"rfdcReady"          , "- Display ready status for DAC/ADCs"     , 0, *rfdcReady},
		{"rfdcShutdown"       , "- Shut down all data converters"         , 0, *rfdcShutdown},
		{"rfdcStartup"        , "- Startup up all data converters"        , 0, *rfdcStartup},
		{"rfdcPowerDownTiles" , "- <adc mask> <dac mask> <State> Power down ADC/DAC Tiles"    , 3, *rfdcPowerDownTiles},
		{"rfdcPowerOnTiles"   , "- <adc mask> <dac mask> Power up ADC/DAC Tiles"      , 2, *rfdcPowerOnTiles},
		{"########### DAC and ADC Registers and Status ###########" , " " , 0, *cmdComment   },
		{"adcDumpRegs"        , "<tile> - Dump ADC registers for tile#"   , 1, *adcDumpRegs  },
		{"dacDumpRegs"        , "<tile> - Dump DAC registers for tile#"   , 1, *dacDumpRegs  },
		{"adcDumpStatus"      , "- Dump ADC status"                       , 0, *adcDumpStatus},
		{"dacDumpStatus"      , "- Dump DAC status"                       , 0, *dacDumpStatus},
		{"################## DAC and ADC Reset ###################" , " " , 0, *cmdComment   },
		{"dacReset"           , "<tile> - Reset DAC"                      , 1, *dacReset},
		{"adcReset"           , "<tile> - Reset ADC"                      , 1, *adcReset},
		{"dacResetAll"        , "- Reset all DAC's"                       , 0, *dacResetAll},
		{"adcResetAll"        , "- Reset all ADC's"                       , 0, *adcResetAll},
		{"################## DAC only commands ###################" , " " , 0, *cmdComment   },
		{"dacCurrent"         , "- Display DAC current for all tiles"     , 0, *dacCurrent},
//		{"############### DAC Gen3 only commands #################" , " " , 0, *cmdComment   },
		{"dacSetVOP"         , "<tile> <dac> <setting> - Set VOP for Gen3", 3, *dacSetVOP},
		{"dacSetNCO"		 , "<tile> <dac> <freq_MHz> - Set DAC mixer/NCO frequency", 3, *dacSetNCO},
//		{"############### ADC Gen3 only commands #################" , " " , 0, *cmdComment   },
		{"adcSetNCO"         , "<tile> <adc> <freq_MHz> - Set ADC mixer/NCO frequency", 3, *adcSetNCO},
//		{"adcSetDSA"         , "<tile> <adc> <setting> - Set DSA for Gen3", 3, *adcSetDSA},
//		{"adcGetDSA"         , "<tile> <adc> - Get DSA for Gen3"          , 2, *adcSetDSA},
		{" "                       , " "                                  , 0, *cmdComment   },

	};

	cli_addCmds(cliCmds, sizeof(cliCmds)/sizeof(cliCmds[0]));
}

void dacSetNCO(u32 *cmdVals)
{
    XRFdc* RFdcInstPtr = &RFdcInst;
    int Status;

    u32 Tile_Id;
    u32 Block_Id;
    double NewFreqMHz;

    XRFdc_Mixer_Settings MixerSettings;

    Tile_Id = cmdVals[0];
    Block_Id = cmdVals[1];
    NewFreqMHz = (double) cmdVals[2];

    xil_printf("\r\n###############################################\r\n");
    xil_printf("Setting DAC NCO/Mixer Frequency\r\n");
    xil_printf("  DAC Tile  : %d\r\n", Tile_Id);
    xil_printf("  DAC Block : %d\r\n", Block_Id);
    printf("  New Freq  : %f MHz\r\n", NewFreqMHz);

    if (!XRFdc_IsDACBlockEnabled(RFdcInstPtr, Tile_Id, Block_Id)) {
        xil_printf("ERROR: DAC Tile %d Block %d is not enabled\r\n", Tile_Id, Block_Id);
        xil_printf("###############################################\r\n\n");
        return;
    }

    /* Get Current Mixer Settings */
    Status = XRFdc_GetMixerSettings(RFdcInstPtr,
                                    XRFDC_DAC_TILE,
                                    Tile_Id,
                                    Block_Id,
                                    &MixerSettings);

    if (Status != XST_SUCCESS) {
        xil_printf("ERROR: XRFdc_GetMixerSettings failed\r\n");
        xil_printf("###############################################\r\n\n");
        return;
    }

    xil_printf("Old Mixer Settings:\r\n");
    printf    ("  FREQ:         %f MHz\r\n", MixerSettings.Freq);
    printf    ("  PHASE OFFSET: %f\r\n", MixerSettings.PhaseOffset);
    xil_printf("  EVENT SOURCE: %d\r\n", MixerSettings.EventSource);
    xil_printf("  MIXER MODE:   %d\r\n", MixerSettings.MixerMode);
    xil_printf("  COARSE FREQ:  %d\r\n", MixerSettings.CoarseMixFreq);

    MixerSettings.Freq = NewFreqMHz;
    MixerSettings.EventSource = XRFDC_EVNT_SRC_TILE;

    /* Set new mixer settings */
    Status = XRFdc_SetMixerSettings(RFdcInstPtr, XRFDC_DAC_TILE, Tile_Id, Block_Id, &MixerSettings);
    if (Status != XST_SUCCESS) {
        xil_printf("ERROR: XRFdc_SetMixerSettings failed\r\n");
        xil_printf("###############################################\r\n\n");
        return;
    }

    Status = XRFdc_UpdateEvent(RFdcInstPtr, XRFDC_DAC_TILE, Tile_Id, Block_Id, XRFDC_EVENT_MIXER);

    if (Status != XST_SUCCESS) {
        xil_printf("ERROR: XRFdc_UpdateEvent failed\r\n");
        xil_printf("###############################################\r\n\n");
        return;
    }

    /* Read back mixer settings */
    Status = XRFdc_GetMixerSettings(RFdcInstPtr, XRFDC_DAC_TILE, Tile_Id, Block_Id, &MixerSettings);

    if (Status != XST_SUCCESS) {
        xil_printf("ERROR: XRFdc_GetMixerSettings readback failed\r\n");
        xil_printf("###############################################\r\n\n");
        return;
    }

    xil_printf("New Mixer Settings:\r\n");
    printf    ("  FREQ:         %f MHz\r\n", MixerSettings.Freq);
    printf    ("  PHASE OFFSET: %f\r\n", MixerSettings.PhaseOffset);
    xil_printf("  EVENT SOURCE: %d\r\n", MixerSettings.EventSource);
    xil_printf("  MIXER MODE:   %d\r\n", MixerSettings.MixerMode);
    xil_printf("  COARSE FREQ:  %d\r\n", MixerSettings.CoarseMixFreq);

    xil_printf("DAC NCO update complete.\r\n");
    xil_printf("###############################################\r\n\n");

    return;

}

void adcSetNCO(u32 *cmdVals)
{
    XRFdc* RFdcInstPtr = &RFdcInst;
    int Status;

    u32 Tile_Id;
    u32 Block_Id;
    double NewFreqMHz;

    XRFdc_Mixer_Settings MixerSettings;

    Tile_Id = cmdVals[0];
    Block_Id = cmdVals[1];
    NewFreqMHz = (double) ((s32)cmdVals[2]);

    xil_printf("\r\n###############################################\r\n");
    xil_printf("Setting ADC NCO/Mixer Frequency\r\n");
    xil_printf("  ADC Tile  : %d\r\n", Tile_Id);
    xil_printf("  ADC Block : %d\r\n", Block_Id);
    printf("  New Freq  : %f MHz\r\n", NewFreqMHz);

    if (!XRFdc_IsADCBlockEnabled(RFdcInstPtr, Tile_Id, Block_Id)) {
        xil_printf("ERROR: ADC Tile %d Block %d is not enabled\r\n", Tile_Id, Block_Id);
        xil_printf("###############################################\r\n\n");
        return;
    }

    /* Get Current Mixer Settings */
    Status = XRFdc_GetMixerSettings(RFdcInstPtr,
                                    XRFDC_ADC_TILE,
                                    Tile_Id,
                                    Block_Id,
                                    &MixerSettings);

    if (Status != XST_SUCCESS) {
        xil_printf("ERROR: XRFdc_GetMixerSettings failed\r\n");
        xil_printf("###############################################\r\n\n");
        return;
    }

    xil_printf("Old Mixer Settings:\r\n");
    printf("  FREQ:         %f MHz\r\n", MixerSettings.Freq);
    printf("  PHASE OFFSET: %f\r\n", MixerSettings.PhaseOffset);
    xil_printf("  EVENT SOURCE: %d\r\n", MixerSettings.EventSource);
    xil_printf("  MIXER MODE:   %d\r\n", MixerSettings.MixerMode);
    xil_printf("  COARSE FREQ:  %d\r\n", MixerSettings.CoarseMixFreq);

    MixerSettings.Freq = NewFreqMHz;
    MixerSettings.EventSource = XRFDC_EVNT_SRC_TILE;

    /* Set new mixer settings */
    Status = XRFdc_SetMixerSettings(RFdcInstPtr, XRFDC_ADC_TILE, Tile_Id, Block_Id, &MixerSettings);
    if (Status != XST_SUCCESS) {
        xil_printf("ERROR: XRFdc_SetMixerSettings failed\r\n");
        xil_printf("###############################################\r\n\n");
        return;
    }

    Status = XRFdc_UpdateEvent(RFdcInstPtr, XRFDC_ADC_TILE, Tile_Id, Block_Id, XRFDC_EVENT_MIXER);

    if (Status != XST_SUCCESS) {
        xil_printf("ERROR: XRFdc_UpdateEvent failed\r\n");
        xil_printf("###############################################\r\n\n");
        return;
    }

    /* Read back mixer settings */
    Status = XRFdc_GetMixerSettings(RFdcInstPtr, XRFDC_ADC_TILE, Tile_Id, Block_Id, &MixerSettings);

    if (Status != XST_SUCCESS) {
        xil_printf("ERROR: XRFdc_GetMixerSettings readback failed\r\n");
        xil_printf("###############################################\r\n\n");
        return;
    }

    xil_printf("New Mixer Settings:\r\n");
    printf("  FREQ:         %f MHz\r\n", MixerSettings.Freq);
    printf("  PHASE OFFSET: %f\r\n", MixerSettings.PhaseOffset);
    xil_printf("  EVENT SOURCE: %d\r\n", MixerSettings.EventSource);
    xil_printf("  MIXER MODE:   %d\r\n", MixerSettings.MixerMode);
    xil_printf("  COARSE FREQ:  %d\r\n", MixerSettings.CoarseMixFreq);

    xil_printf("ADC NCO update complete.\r\n");
    xil_printf("###############################################\r\n\n");

    return;

}

/*****************************************************************************/
/**
*
* Dump DAC status via API
*
* @param	None
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void dacDumpStatus(u32 *cmdVals)
{
	XRFdc* RFdcInstPtr = &RFdcInst;
	int Status;
	u32 Tile_Id;
	u32 Block_Id;
	XRFdc_IPStatus ipStatus;
	XRFdc_BlockStatus blockStatus;
	XRFdc_Mixer_Settings GetMixer_Settings;
	u32 InterpolationFactor;
	XRFdc_QMC_Settings GetQMCSettings;
	XRFdc_CoarseDelay_Settings GetCoarseDelaySettings;
	u32 GetDecoderMode;
	u32 GetNyquistZone;
	u32 GetFabricRate;

    // Calling this function gets the status of the IP
    XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);

    for (Tile_Id=0; Tile_Id<=3; Tile_Id++) {
        xil_printf("=================================================\r\n");
    	if (ipStatus.DACTileStatus[Tile_Id].IsEnabled == 1) {
			xil_printf("Tile: %d DAC Enabled\r\n", Tile_Id);
			xil_printf("  BlockStatus:  0x%x\r\n", ipStatus.DACTileStatus[Tile_Id].BlockStatusMask);
			xil_printf("  TileState:    0x%08x\r\n", ipStatus.DACTileStatus[Tile_Id].TileState);
			xil_printf("  PowerUpState: 0x%08x\r\n", ipStatus.DACTileStatus[Tile_Id].PowerUpState);
			xil_printf("  PLLState:     0x%08x\r\n", ipStatus.DACTileStatus[Tile_Id].PLLState);

			for(Block_Id=0; Block_Id<=3; Block_Id++) {
				if(XRFdc_IsDACBlockEnabled(RFdcInstPtr, Tile_Id, Block_Id)) {
					xil_printf("  ***********************************\r\n");
					xil_printf("  Block: %d Enabled\r\n", Block_Id);

					//////////////////////////////////////////////////////////////////////////////
					// blockStatus
					XRFdc_GetBlockStatus(RFdcInstPtr, XRFDC_DAC_TILE, Tile_Id, Block_Id, &blockStatus);
					printf("    SamplingFreq:          %f\r\n", blockStatus.SamplingFreq);
					xil_printf("    DigitalDataPathStatus: %d\r\n", blockStatus.DigitalDataPathStatus);
					xil_printf("    AnalogDataPathStatus:  %d\r\n", blockStatus.AnalogDataPathStatus);
					xil_printf("    IsFIFOFlagsEnabled:    %d\r\n", blockStatus.IsFIFOFlagsEnabled);
					xil_printf("    IsFIFOFlagsAsserted:   %d\r\n", blockStatus.IsFIFOFlagsAsserted);
					xil_printf("    DataPathClocksStatus:  %d\r\n", blockStatus.DataPathClocksStatus);


					//////////////////////////////////////////////////////////////////////////////
					// DAC Interpolation factor
					Status = XRFdc_GetInterpolationFactor(RFdcInstPtr, Tile_Id, Block_Id, &InterpolationFactor);
					if (Status != XST_SUCCESS) {
						xil_printf("XRFdc_GetInterpolationFactor() failed\r\n");
						return;
					}
					xil_printf("    Interpolation Factor:  %d\r\n",InterpolationFactor);

					//////////////////////////////////////////////////////////////////////////////
					// DAC Fabric Rate
					Status = XRFdc_GetFabWrVldWords(RFdcInstPtr, XRFDC_DAC_TILE, Tile_Id, Block_Id, &GetFabricRate);
					if (Status != XST_SUCCESS) {
						xil_printf("XRFdc_GetFabWrVldWords() failed\r\n");
						return;
					}
					xil_printf("    Fabric Rate         :  %d\r\n",GetFabricRate);

					//////////////////////////////////////////////////////////////////////////////
					// DAC Decoder Mode
					Status = XRFdc_GetDecoderMode(RFdcInstPtr, Tile_Id, Block_Id, &GetDecoderMode);
					if (Status != XST_SUCCESS) {
						xil_printf("XRFdc_GetDecoderMode() failed\n\r");
						return;
					}
					xil_printf("    Decoder Mode        :  %d\r\n",GetDecoderMode);


					//////////////////////////////////////////////////////////////////////////////
					// DAC Nyquist Zone
					Status = XRFdc_GetNyquistZone(RFdcInstPtr, XRFDC_DAC_TILE, Tile_Id, Block_Id, &GetNyquistZone);
					if (Status != XST_SUCCESS) {
						xil_printf("XRFdc_GetNyquistZone() failed\n\r");
						return;
					}
					xil_printf("    Nyquist Zone        :  %d\r\n",GetNyquistZone);


					//////////////////////////////////////////////////////////////////////////////
					// MixerSettings
			        Status =  XRFdc_GetMixerSettings(RFdcInstPtr, XRFDC_DAC_TILE, Tile_Id, Block_Id, &GetMixer_Settings);
					if (Status != XST_SUCCESS) {
				      xil_printf("Getting Fine Mixer failed\r\n");
					  	return ;
					}

					xil_printf("    **********Mixer Settings*********\r\n");
			        printf("    FREQ:              %f\r\n", GetMixer_Settings.Freq);
			        printf("    PHASE OFFSET:      %f\r\n", GetMixer_Settings.PhaseOffset);
			        xil_printf("    EVENT SOURCE:      %d\r\n", GetMixer_Settings.EventSource);
			        xil_printf("    MIXER MODE:        %d: ", GetMixer_Settings.MixerMode);
			        switch(GetMixer_Settings.MixerMode) {
			        case XRFDC_MIXER_MODE_OFF: xil_printf("OFF");
			        	break;
			        case XRFDC_MIXER_MODE_C2C: xil_printf("C2C");
			        	break;
			        case XRFDC_MIXER_MODE_C2R: xil_printf("C2R");
			        	break;
			        case XRFDC_MIXER_MODE_R2C: xil_printf("R2C");
			        	break;
			        default: xil_printf("unknown");
			        }
			        xil_printf("\r\n");

			        xil_printf("    COARSE MIXER FREQ: %d\r\n", GetMixer_Settings.CoarseMixFreq);


					//////////////////////////////////////////////////////////////////////////////
					// QMC Settings
			        Status = XRFdc_GetQMCSettings(RFdcInstPtr, XRFDC_DAC_TILE, Tile_Id, Block_Id, &GetQMCSettings);
					if (Status != XST_SUCCESS) {
						xil_printf("XRFdc_GetQMCSettings() failed\n\r");
						return;
					}

					xil_printf("    **********QMC Settings***********\r\n");
			        printf("    GainCorrectionFactor:   %f\r\n", GetQMCSettings.GainCorrectionFactor);
			        printf("    PhaseCorrectionFactor:  %f\r\n", GetQMCSettings.PhaseCorrectionFactor);
			        xil_printf("    EnablePhase:            %d\r\n", GetQMCSettings.EnablePhase);
			        xil_printf("    EnableGain:             %d\r\n", GetQMCSettings.EnableGain);
			        xil_printf("    OffsetCorrectionFactor: %d\r\n", GetQMCSettings.OffsetCorrectionFactor);
			        xil_printf("    EventSource:            %d\r\n", GetQMCSettings.EventSource);


					//////////////////////////////////////////////////////////////////////////////
					// Coarse Delay Settings
					Status = XRFdc_GetCoarseDelaySettings(RFdcInstPtr, XRFDC_DAC_TILE, Tile_Id, Block_Id, &GetCoarseDelaySettings);
					if (Status != XST_SUCCESS) {
						xil_printf("XRFdc_GetCoarseDelaySettings() failed\n\r");
						return;
					}
					xil_printf("    ******Coarse Delay Settings******\r\n");
			        xil_printf("    CoarseDelay:            %d\r\n", GetCoarseDelaySettings.CoarseDelay);
			        xil_printf("    EventSource:            %d\r\n", GetCoarseDelaySettings.EventSource);


				} else {
					xil_printf("  ***********************************\r\n");
					xil_printf("  Block: %d Disabled\r\n", Block_Id);
				}
			}
    	} else {
			xil_printf("Tile: %d DAC Disabled\r\n", Tile_Id);
    	}
    }


    return;
}


/*****************************************************************************/
/**
*
* Dump DAC registers via API
*
* @param	None
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void dacDumpRegs (u32 *cmdVals) {
	u32 Tile_Id;
	XRFdc_IPStatus ipStatus;
	XRFdc* RFdcInstPtr = &RFdcInst;

	Tile_Id = cmdVals[0];

    // Calling this function gets the status of the IP
    XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);

	xil_printf("\n\r###############################################\n\r");
    if (ipStatus.DACTileStatus[Tile_Id].IsEnabled == 1) {
		xil_printf("Tile: %d DAC Enabled\r\n", Tile_Id);
		XRFdc_DumpRegs(RFdcInstPtr, XRFDC_DAC_TILE, Tile_Id);
    } else {
		xil_printf("Tile: %d DAC DISABLED\r\n", Tile_Id);
    }

	xil_printf("###############################################\r\n\n");

	return;
}


/*****************************************************************************/
/**
*
* Dump DAC registers via API
*
* @param	None
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void adcDumpRegs (u32 *cmdVals) {
	u32 Tile_Id;
	XRFdc_IPStatus ipStatus;
	XRFdc* RFdcInstPtr = &RFdcInst;

	Tile_Id = cmdVals[0];

	// Calling this function gets the status of the IP
    XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);

	xil_printf("\n\r###############################################\n\r");
   if (ipStatus.ADCTileStatus[Tile_Id].IsEnabled == 1) {
		xil_printf("Tile: %d ADC Enabled\r\n", Tile_Id);
		XRFdc_DumpRegs(RFdcInstPtr, XRFDC_ADC_TILE, Tile_Id);
    } else {
		xil_printf("Tile: %d ADC DISABLED\r\n", Tile_Id);
    }

	xil_printf("###############################################\r\n\n");

	return;
}


/*****************************************************************************/
/**
*
* Dump DAC status via API
*
* @param	TBD
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void rfSetMixerFreqOptPrint(u32 type, u32 Tile_Id, u32 Block_Id, double newFreq, int printEnable)
{
	XRFdc* RFdcInstPtr = &RFdcInst;
	int Status;
	XRFdc_Mixer_Settings GetMixer_Settings;

	Status = XRFdc_GetMixerSettings(RFdcInstPtr, type, Tile_Id, Block_Id, &GetMixer_Settings);

	if(printEnable) {
		xil_printf("Old Mixer Settings for %s: Tile:%d Block:%d\r\n", (type==XRFDC_DAC_TILE) ? "DAC" : "ADC", Tile_Id, Block_Id);
		printf("    FREQ:              %f\r\n", GetMixer_Settings.Freq);
		printf("    PHASE OFFSET:      %f\r\n", GetMixer_Settings.PhaseOffset);
		xil_printf("    EVENT SOURCE:      %d\r\n", GetMixer_Settings.EventSource);
		xil_printf("    MIXER MODE:        %d: ", GetMixer_Settings.MixerMode);
		switch(GetMixer_Settings.MixerMode) {
			case XRFDC_MIXER_MODE_OFF: xil_printf("OFF");
				break;
			case XRFDC_MIXER_MODE_C2C: xil_printf("C2C");
				break;
			case XRFDC_MIXER_MODE_C2R: xil_printf("C2R");
				break;
			case XRFDC_MIXER_MODE_R2C: xil_printf("R2C");
				break;
			default: xil_printf("unknown");
        }
        xil_printf("\r\n");
		xil_printf("    COARSE MIXER FREQ: %d\r\n", GetMixer_Settings.CoarseMixFreq);
		xil_printf("\r\n");
	}

	// change mixer freq
	GetMixer_Settings.Freq = (double)newFreq;

	// Set the new NCO frequency
	Status = XRFdc_SetMixerSettings(RFdcInstPtr, type, Tile_Id, Block_Id, &GetMixer_Settings);
	if (Status != XST_SUCCESS) {
		xil_printf("SetMixerSettings failed\r\n");
		return;
	}

	// Update event to update all the required registers
	XRFdc_UpdateEvent(RFdcInstPtr, type, Tile_Id, Block_Id, GetMixer_Settings.EventSource);

	// Read back and display MixerSettings
	Status =  XRFdc_GetMixerSettings(RFdcInstPtr, type, Tile_Id, Block_Id, &GetMixer_Settings);
	if (Status != XST_SUCCESS) {
	   xil_printf("Getting Fine Mixer failed\r\n");
	   return ;
	}

	if(printEnable) {
		xil_printf("New Mixer Settings for %s: Tile:%d Block:%d\r\n", (type==XRFDC_DAC_TILE) ? "DAC" : "ADC", Tile_Id, Block_Id);
		printf("    FREQ:              %f\r\n", GetMixer_Settings.Freq);
		printf("    PHASE OFFSET:      %f\r\n", GetMixer_Settings.PhaseOffset);
		xil_printf("    EVENT SOURCE:      %d\r\n", GetMixer_Settings.EventSource);
        xil_printf("    MIXER MODE:        %d: ", GetMixer_Settings.MixerMode);
        switch(GetMixer_Settings.MixerMode) {
        case XRFDC_MIXER_MODE_OFF: xil_printf("OFF");
        	break;
        case XRFDC_MIXER_MODE_C2C: xil_printf("C2C");
        	break;
        case XRFDC_MIXER_MODE_C2R: xil_printf("C2R");
        	break;
        case XRFDC_MIXER_MODE_R2C: xil_printf("R2C");
        	break;
        default: xil_printf("unknown");
        }
        xil_printf("\r\n");
		xil_printf("    COARSE MIXER FREQ: %d\r\n", GetMixer_Settings.CoarseMixFreq);
	}


    return;
}

/****************************************************************************/
/**
*
* This function verifies the DAC has been configured for the correct AXIS width.
*
* @param	RFdcDeviceId is the XPAR_<XRFDC_instance>_DEVICE_ID value
*		from xparameters.h.
*
* @return   None
*
* @note   	None
*
****************************************************************************/
void RFdcCheckAxisWidth(XRFdc *RFdcInstPtr, u32 DacExpectedBits, u32 AdcExpectedBits)
{
	int Status;
	u16 Tile;
	u16 Block;
	u32 GetFabricRate;

	xil_printf("Verifying Fabric rate matches expected rate\r\n");

	for (Tile = 0; Tile <4; Tile++) {
		for (Block = 0; Block <4; Block++) {
			/* Check for DAC block Enable */
			if (XRFdc_IsDACBlockEnabled(RFdcInstPtr, Tile, Block)) {
				/* Get DAC fabric rate */
				Status = XRFdc_GetFabWrVldWords(RFdcInstPtr, XRFDC_DAC_TILE, Tile, Block, &GetFabricRate);
				if (Status != XST_SUCCESS) {
					xil_printf("Call to XRFdc_GetFabWrVldWords() failed\r\n");
					return;
				}
				if (GetFabricRate*16 != DacExpectedBits) {
					xil_printf("ERROR: Expected datawidth is %dbits wide but DAC tile configured as %d 16bit-words (%dbits)\r\n",
							DacExpectedBits, GetFabricRate, GetFabricRate*16);
				}
			}

			if (XRFdc_IsADCBlockEnabled(RFdcInstPtr, Tile, Block)) {
				/* Get ADC fabric rate */
				Status = XRFdc_GetFabRdVldWords(RFdcInstPtr, XRFDC_ADC_TILE, Tile, Block, &GetFabricRate);
				if (Status != XST_SUCCESS) {
					xil_printf("Call to XRFdc_GetFabRdVldWords() failed\r\n");
					return;
				}
				if (GetFabricRate*16 != AdcExpectedBits) {
					xil_printf("ERROR: Expected datawidth is %dbits wide but ADC tile configured as %d 16bit-words (%dbits)\r\n",
							AdcExpectedBits, GetFabricRate, GetFabricRate*16);
				}
			}
		}
	}
	return;
}


/*****************************************************************************/
/**
*
* Dump ADC status via API
*
* @param	None
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void adcDumpStatus(u32 *cmdVals)
{
	XRFdc* RFdcInstPtr = &RFdcInst;
	int Status;
	u32 Tile_Id;
	u32 Block_Id;
	XRFdc_IPStatus ipStatus;
	XRFdc_BlockStatus blockStatus;
	XRFdc_Mixer_Settings GetMixer_Settings;
	XRFdc_QMC_Settings GetQMCSettings;
	XRFdc_CoarseDelay_Settings GetCoarseDelaySettings;
	u32 GetNyquistZone;
	u32 DecimationFactor;

    // Calling this function gets the status of the IP
    XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);

    for (Tile_Id=0; Tile_Id<=3; Tile_Id++) {
        xil_printf("=================================================\r\n");
    	if (ipStatus.ADCTileStatus[Tile_Id].IsEnabled == 1) {
			xil_printf("Tile: %d ADC Enabled\r\n", Tile_Id);
			xil_printf("  BlockStatus:  0x%x\r\n", ipStatus.ADCTileStatus[Tile_Id].BlockStatusMask);
			xil_printf("  TileState:    0x%08x\r\n", ipStatus.ADCTileStatus[Tile_Id].TileState);
			xil_printf("  PowerUpState: 0x%08x\r\n", ipStatus.ADCTileStatus[Tile_Id].PowerUpState);
			xil_printf("  PLLState:     0x%08x\r\n", ipStatus.ADCTileStatus[Tile_Id].PLLState);

			for(Block_Id=0; Block_Id<=3; Block_Id++) {
				if(XRFdc_IsADCBlockEnabled(RFdcInstPtr, Tile_Id, Block_Id)) {
					xil_printf("  ***********************************\r\n");
					xil_printf("  Block: %d Enabled\r\n", Block_Id);

					//////////////////////////////////////////////////////////////////////////////
					// blockStatus
					XRFdc_GetBlockStatus(RFdcInstPtr, XRFDC_ADC_TILE, Tile_Id, Block_Id, &blockStatus);
					printf("    SamplingFreq:          %f\r\n", blockStatus.SamplingFreq);
					xil_printf("    DigitalDataPathStatus: %d\r\n", blockStatus.DigitalDataPathStatus);
					xil_printf("    AnalogDataPathStatus:  %d\r\n", blockStatus.AnalogDataPathStatus);
					xil_printf("    IsFIFOFlagsEnabled:    %d\r\n", blockStatus.IsFIFOFlagsEnabled);
					xil_printf("    IsFIFOFlagsAsserted:   %d\r\n", blockStatus.IsFIFOFlagsAsserted);
					xil_printf("    DataPathClocksStatus:  %d\r\n", blockStatus.DataPathClocksStatus);


					//////////////////////////////////////////////////////////////////////////////
					// Nyquist Zone
					Status = XRFdc_GetNyquistZone(RFdcInstPtr, XRFDC_ADC_TILE, Tile_Id, Block_Id, &GetNyquistZone);
					if (Status != XST_SUCCESS) {
						xil_printf("XRFdc_GetNyquistZone() failed\n\r");
						return;
					}
					xil_printf("    Nyquist Zone        :  %d\r\n", GetNyquistZone);


					//////////////////////////////////////////////////////////////////////////////
					// MixerSettings
			        Status =  XRFdc_GetMixerSettings(RFdcInstPtr, XRFDC_ADC_TILE, Tile_Id, Block_Id, &GetMixer_Settings);
					if (Status != XST_SUCCESS) {
				      xil_printf("Getting Fine Mixer failed\r\n");
					  	return ;
					}

					xil_printf("    **********Mixer Settings*********\r\n");
			        printf("    FREQ:              %f\r\n", GetMixer_Settings.Freq);
			        printf("    PHASE OFFSET:      %f\r\n", GetMixer_Settings.PhaseOffset);
			        xil_printf("    EVENT SOURCE:      %d\r\n", GetMixer_Settings.EventSource);
			        xil_printf("    MIXER MODE:        %d: ", GetMixer_Settings.MixerMode);
			        switch(GetMixer_Settings.MixerMode) {
			        case XRFDC_MIXER_MODE_OFF: xil_printf("OFF");
			        	break;
			        case XRFDC_MIXER_MODE_C2C: xil_printf("C2C");
			        	break;
			        case XRFDC_MIXER_MODE_C2R: xil_printf("C2R");
			        	break;
			        case XRFDC_MIXER_MODE_R2C: xil_printf("R2C");
			        	break;
			        default: xil_printf("unknown");
			        }
			        xil_printf("\r\n");
			        xil_printf("    COARSE MIXER FREQ: %d\r\n", GetMixer_Settings.CoarseMixFreq);


					//////////////////////////////////////////////////////////////////////////////
					// QMC Settings
			        Status = XRFdc_GetQMCSettings(RFdcInstPtr, XRFDC_ADC_TILE, Tile_Id, Block_Id, &GetQMCSettings);
					if (Status != XST_SUCCESS) {
						xil_printf("XRFdc_GetQMCSettings() failed\n\r");
						return;
					}

					xil_printf("    **********QMC Settings***********\r\n");
			        printf("    GainCorrectionFactor:   %f\r\n", GetQMCSettings.GainCorrectionFactor);
			        printf("    PhaseCorrectionFactor:  %f\r\n", GetQMCSettings.PhaseCorrectionFactor);
			        xil_printf("    EnablePhase:            %d\r\n", GetQMCSettings.EnablePhase);
			        xil_printf("    EnableGain:             %d\r\n", GetQMCSettings.EnableGain);
			        xil_printf("    OffsetCorrectionFactor: %d\r\n", GetQMCSettings.OffsetCorrectionFactor);
			        xil_printf("    EventSource:            %d\r\n", GetQMCSettings.EventSource);


					//////////////////////////////////////////////////////////////////////////////
					// Coarse Delay Settings
					Status = XRFdc_GetCoarseDelaySettings(RFdcInstPtr, XRFDC_ADC_TILE, Tile_Id, Block_Id, &GetCoarseDelaySettings);
					if (Status != XST_SUCCESS) {
						xil_printf("XRFdc_GetCoarseDelaySettings() failed\n\r");
						return;
					}
					xil_printf("    ******Coarse Delay Settings******\r\n");
			        xil_printf("    CoarseDelay:            %d\r\n", GetCoarseDelaySettings.CoarseDelay);
			        xil_printf("    EventSource:            %d\r\n", GetCoarseDelaySettings.EventSource);

   					//////////////////////////////////////////////////////////////////////////////
   					// Decimation Factor
					Status = XRFdc_GetDecimationFactor(RFdcInstPtr, Tile_Id, Block_Id, &DecimationFactor);
					if (Status != XST_SUCCESS) {
						xil_printf("XRFdc_GetDecimationFactor() failed\r\n");
						return;
					}

					xil_printf("    ******Decimation Factor**********\r\n");
					xil_printf("    Decimation Factor:      %d\r\n", DecimationFactor);

				} else {
					xil_printf("  ***********************************\r\n");
					xil_printf("  Block: %d Disabled\r\n", Block_Id);
				}
			}
    	} else {
			xil_printf("Tile: %d DAC Disabled\r\n", Tile_Id);
    	}
    }

    return;
}


/*****************************************************************************/
/**
*
* Reset DAC block via API
*
* @param	cmdVals[0] tile
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void dacReset(u32 *cmdVals)
{
	XRFdc* RFdcInstPtr = &RFdcInst;
	u32 Tile_Id;
	Tile_Id = cmdVals[0];
    int Status;
	XRFdc_IPStatus ipStatus;
    XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);


	xil_printf("\r\n###############################################\r\n");
	//Reset DAC tile

	if (ipStatus.DACTileStatus[Tile_Id].IsEnabled == 1) {

		Status = XRFdc_Reset(RFdcInstPtr, XRFDC_DAC_TILE, Tile_Id);
		if (Status != XST_SUCCESS) {
			xil_printf("XRFdc_Reset() failed for DAC Tile%d.\r\n",Tile_Id);
			return;
		}
		else{
  	  		xil_printf("DAC Tile%d reset.\r\n",Tile_Id);}
	}
	else{xil_printf("DAC Tile%d is not available.\n\r", Tile_Id);
	}
	xil_printf("###############################################\r\n\n");


    return;
}

void dacResetAll(u32 *cmdVals)
{
	XRFdc* RFdcInstPtr = &RFdcInst;
	u32 Tile_Id;
	Tile_Id = cmdVals[0];
    int Status;
	XRFdc_IPStatus ipStatus;
    XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);


	xil_printf("\r\n###############################################\r\n");
	//Reset DAC tile
	for ( Tile_Id=0; Tile_Id<=3; Tile_Id++) {
		if (ipStatus.DACTileStatus[Tile_Id].IsEnabled == 1) {
			Status = XRFdc_Reset(RFdcInstPtr, XRFDC_DAC_TILE, Tile_Id);
			if (Status != XST_SUCCESS) {
				xil_printf("XRFdc_Reset() failed for DAC Tile%d.\r\n",Tile_Id);
				return;
			}
			else{
				xil_printf("DAC Tile%d reset.\r\n",Tile_Id);}
		}
		else{xil_printf("DAC Tile%d is not available.\n\r", Tile_Id);
		}
	}
	xil_printf("###############################################\r\n\n");

    return;
}
/*****************************************************************************/
/**
*
* Reset ADC block via API
*
* @param	cmdVals[0] tile
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void adcReset(u32 *cmdVals)
{
	XRFdc* RFdcInstPtr = &RFdcInst;
	u32 Tile_Id = cmdVals[0];
    int Status;
	XRFdc_IPStatus ipStatus;
    XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);


	xil_printf("\r\n###############################################\r\n");
	//Reset ADC tile
	if (ipStatus.ADCTileStatus[Tile_Id].IsEnabled == 1) {

		Status = XRFdc_Reset(RFdcInstPtr, XRFDC_ADC_TILE, Tile_Id);

		if (Status != XST_SUCCESS) {
			xil_printf("XRFdc_Reset() failed for ADC Tile%d.\r\n",Tile_Id);
			return;
		}
		else{
			xil_printf("ADC Tile%d reset.\r\n",Tile_Id);}
		}
	else{xil_printf("ADC Tile%d is not available.\n\r", Tile_Id);
	}
	xil_printf("###############################################\r\n\n");


    return;
}

void adcResetAll(u32 *cmdVals)
{
	XRFdc* RFdcInstPtr = &RFdcInst;
	u32 Tile_Id;
    int Status;
	XRFdc_IPStatus ipStatus;
    XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);

	(void)cmdVals;

	XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);

	xil_printf("\r\n###############################################\r\n");
	//Reset ADC tiles
	for ( Tile_Id=0; Tile_Id<=3; Tile_Id++) {
		if (ipStatus.ADCTileStatus[Tile_Id].IsEnabled == 1) {

			Status = XRFdc_Reset(RFdcInstPtr, XRFDC_ADC_TILE, Tile_Id);

			if (Status != XST_SUCCESS) {
				xil_printf("XRFdc_Reset() failed for ADC Tile%d.\r\n",Tile_Id);
				return;
			}
			else{
				xil_printf("ADC Tile%d reset.\r\n",Tile_Id);}
			}
		else{xil_printf("ADC Tile%d is not available.\n\r", Tile_Id);
		}
	}
	xil_printf("###############################################\r\n\n");


    return;
}


/*****************************************************************************/
/**
*
* Dump DAC current setting via API
*
* Updated for Gen3 - JL 06/29/2020
* @param	None
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void dacCurrent(u32 *cmdVals)
{
	int Status;
	XRFdc* RFdcInstPtr = &RFdcInst;
	XRFdc_IPStatus ipStatus;
	u32 Tile_Id;
	u32 Block_Id;
	u32 OutputCurr;
	u32 OutputCurr2;

//	u32 OutputCurrSet;
	// Calling this function gets the status of the IP
	XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);

	xil_printf("\r\n###############################################\r\n");
	xil_printf("=== Data Current Report ===\n\r");

	for ( Tile_Id=0; Tile_Id < 4; Tile_Id++) {

		xil_printf(
            "DAC Tile %d: enabled = %d\r\n",
            Tile_Id,
            ipStatus.DACTileStatus[Tile_Id].IsEnabled
        );
		
    	if (ipStatus.DACTileStatus[Tile_Id].IsEnabled == 1) {
			for ( Block_Id=0; Block_Id<=3; Block_Id++) {
				if (XRFdc_IsDACBlockEnabled(RFdcInstPtr, Tile_Id, Block_Id) != 0U) {
					Status = XRFdc_GetOutputCurr(RFdcInstPtr, Tile_Id, Block_Id, &OutputCurr);
					if (RFdcInstPtr->RFdc_Config.IPType < XRFDC_GEN3) {
						if (Status != XST_SUCCESS) {
							xil_printf("XRFdc_GetOutputCurr() failed for DAC Tile%d Ch%d.\r\n",Tile_Id,Block_Id);
							return;
						}
						switch(OutputCurr) {
							case XRFDC_OUTPUT_CURRENT_20MA:
								xil_printf("   DAC Tile%d Ch%d output current is 20mA. DAC_AVTT should be 2.5V\r\n",Tile_Id,Block_Id);
								break;
							case XRFDC_OUTPUT_CURRENT_32MA:
								xil_printf("   DAC Tile%d Ch%d output current is 32mA. DAC_AVTT should be 3.0V\r\n",Tile_Id,Block_Id);
								break;
							default:
								xil_printf("DAC output current is not recognized.  Channel may not be enabled.\r\n");
								break;
						}
						}// gen3
						else{
							Status = XRFdc_GetDACCompMode(RFdcInstPtr, Tile_Id, Block_Id, &OutputCurr2);
							if (Status != XST_SUCCESS) {
								xil_printf("XRFdc_GetDACCompMode() failed for DAC Tile%d Ch%d.\r\n",Tile_Id,Block_Id);
								return;
								}
								switch(OutputCurr2) {
									case 0:
										xil_printf("   DAC Tile%d Ch%d output current mode is set to RFSoC Gen3.\r\n",Tile_Id,Block_Id);
										xil_printf("   DAC Tile%d Ch%d output current is set to %d uA.\r\n",Tile_Id,Block_Id,OutputCurr);
										break;
									case 1:
										xil_printf("   DAC Tile%d Ch%d output current mode is set to RFSoC Gen1/2.\r\n",Tile_Id,Block_Id);
										break;
									default:
										xil_printf("DAC output current is not recognized.  Channel may not be enabled.\r\n");
										break;
								}

						}
    			}
    		}
		}
	}
	xil_printf("###############################################\r\n\n");

	return;
}

/*****************************************************************************/
/**
*
* Dac Sync Start
*
* @param	None
*
* @return	None
*
* @note		Pulled from xrfdc_mts_example.c
*
******************************************************************************/
void dacAdcSyncStart(u32 *cmdVals)
{
	XRFdc* RFdcInstPtr = &RFdcInst;

	XRFdc_ClrSetReg(RFdcInstPtr, XRFDC_ADC_TILE_DRP_ADDR(1) + XRFDC_HSCOM_ADDR,  0xB0, 0x0F, 0x01);
	XRFdc_ClrSetReg(RFdcInstPtr, XRFDC_ADC_TILE_DRP_ADDR(3) + XRFDC_HSCOM_ADDR,  0xB0, 0x0F, 0x01);

	/* Initialize DAC and ADC MTS Settings */
	XRFdc_MultiConverter_Init (&ADC_Sync_Config2, 0, 0, 0);
	XRFdc_MultiConverter_Init (&DAC_Sync_Config2, 0, 0, 0);


	return;
}

/*****************************************************************************/
/**
*
* Display DAC and ADC ready status
*
* @param	None
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void rfdcReady (u32 *cmdVals) {
	u32 Tile_Id;
	XRFdc_IPStatus ipStatus;
	XRFdc* RFdcInstPtr = &RFdcInst;
	u32 val;

	// Calling this function gets the status of the IP
	XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);

	xil_printf("\r\n###############################################\r\n");
	xil_printf("=== Data Converter Status Report ===\n\r");


	xil_printf("DAC Status\r\n");
	for ( Tile_Id=0; Tile_Id<=3; Tile_Id++) {
    	if (ipStatus.DACTileStatus[Tile_Id].IsEnabled == 1) {
    		val = XRFdc_ReadReg16(RFdcInstPtr, XRFDC_DAC_TILE_CTRL_STATS_ADDR(Tile_Id), XRFDC_ADC_DEBUG_RST_OFFSET);
    		if(val & XRFDC_DBG_RST_CAL_MASK) {
    			xil_printf("   Tile: %d NOT ready\r\n", Tile_Id);
    		} else {
    			xil_printf("   Tile: %d ready\r\n", Tile_Id);
    		}
    	}
	}

	xil_printf("ADC Status\r\n");
	for ( Tile_Id=0; Tile_Id<=3; Tile_Id++) {
    	if (ipStatus.ADCTileStatus[Tile_Id].IsEnabled == 1) {
    		val = XRFdc_ReadReg16(RFdcInstPtr, XRFDC_ADC_TILE_CTRL_STATS_ADDR(Tile_Id), XRFDC_ADC_DEBUG_RST_OFFSET);
    		if(val & XRFDC_DBG_RST_CAL_MASK) {
    			xil_printf("   Tile: %d NOT ready\r\n", Tile_Id);
    		} else {
    			xil_printf("   Tile: %d ready\r\n", Tile_Id);
    		}
    	}
	}
	xil_printf("###############################################\r\n\n");

	return;
}


/*****************************************************************************/
/**
*
* Shutdown DAC's and ADC's
*
* @param	None
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void rfdcShutdown (u32 *cmdVals) {
	u32 Tile_Id;
	XRFdc_IPStatus ipStatus;
	XRFdc* RFdcInstPtr = &RFdcInst;
	u32 Status;

	xil_printf("\r\n###############################################\r\n");
	xil_printf("Shutdown in progress...\n\r");
	// Calling this function gets the status of the IP
	Status = XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);
	if(Status != XRFDC_SUCCESS){
			xil_printf("Error in XRFdc_GetIPStatus function call.");
			return;
		}

 	for ( Tile_Id=0; Tile_Id<=3; Tile_Id++) {
    	if (ipStatus.DACTileStatus[Tile_Id].IsEnabled == 1) {
   // 		val = XRFdc_ReadReg16(RFdcInstPtr, XRFDC_DAC_TILE_CTRL_STATS_ADDR(Tile_Id), XRFDC_ADC_DEBUG_RST_OFFSET);
   // 		if(val & XRFDC_DBG_RST_CAL_MASK) {
   // 			xil_printf("  DAC Tile%d NOT ready\r\n", Tile_Id);
   // 		} else {
    			XRFdc_Shutdown(RFdcInstPtr,1,Tile_Id);
    			xil_printf("   DAC Tile%d shutdown.\r\n", Tile_Id);
   // 		}
    	}

	}

 	for ( Tile_Id=0; Tile_Id<=3; Tile_Id++) {
    	if (ipStatus.ADCTileStatus[Tile_Id].IsEnabled == 1) {
    //		val = XRFdc_ReadReg16(RFdcInstPtr, XRFDC_ADC_TILE_CTRL_STATS_ADDR(Tile_Id), XRFDC_ADC_DEBUG_RST_OFFSET);
    	//	if(val & XRFDC_DBG_RST_CAL_MASK) {
    	//		xil_printf("   ADC Tile%d NOT ready.\r\n", Tile_Id);
  			XRFdc_Shutdown(RFdcInstPtr,0,Tile_Id);
    		xil_printf("   ADC Tile%d shutdown.\r\n", Tile_Id);
    	} else {
    		xil_printf("   ADC Tile%d not enabled.\r\n", Tile_Id);
      //		}
    	}
	}
	xil_printf("All enabled DAC's and ADC's shutdown. \r\n");

	sleep(1);

	xil_printf("\r\nThe Power-on sequence step. 0xF is complete.\r\n");

	for ( Tile_Id=0; Tile_Id<=3; Tile_Id++) {
    	if (ipStatus.DACTileStatus[Tile_Id].IsEnabled == 0) {
    //		val = XRFdc_ReadReg16(RFdcInstPtr, XRFDC_ADC_TILE_CTRL_STATS_ADDR(Tile_Id), XRFDC_ADC_DEBUG_RST_OFFSET);
    //		if(val & XRFDC_DBG_RST_CAL_MASK) {
    			xil_printf("  Tile: %d NOT ready.\r\n", Tile_Id);
    	}else {
    		    xil_printf("   DAC Tile%d Power-on Sequence Step: 0x%08x\r\n",Tile_Id,
    		    		Xil_In32(RFDC_BASE + 0x0000C + 0x04000 + Tile_Id * 0x4000));
    		//}
    	}
	}

	for ( Tile_Id=0; Tile_Id<=3; Tile_Id++) {
    	if (ipStatus.ADCTileStatus[Tile_Id].IsEnabled == 0) {
    //		val = XRFdc_ReadReg16(RFdcInstPtr, XRFDC_ADC_TILE_CTRL_STATS_ADDR(Tile_Id), XRFDC_ADC_DEBUG_RST_OFFSET);
    	//	if(val & XRFDC_DBG_RST_CAL_MASK) {
    			xil_printf("  ADC Tile%d NOT ready.\r\n", Tile_Id);
    		} else {
    		    xil_printf("   ADC Tile%d Power-on Sequence Step: 0x%08x\r\n",Tile_Id,
    		    		Xil_In32(RFDC_BASE + 0x0000C + 0x14000 + Tile_Id * 0x4000));
    		}
 //   	}
	}

	xil_printf("\n\rData Converter shutdown is complete!");
	xil_printf("\r\n###############################################\r\n\n");


	return;
}


/*****************************************************************************/
/**
*
* Startup DAC's and ADC's
*
* @param	None
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void rfdcStartup (u32 *cmdVals) {

	int Tile_Id = 0;
	XRFdc_IPStatus ipStatus;
	XRFdc* RFdcInstPtr = &RFdcInst;
	u32 val;
	u32 Status;

	// Calling this function gets the status of the IP
	Status = XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);
	if(Status != XRFDC_SUCCESS){
		xil_printf("Error in XRFdc_GetIPStatus function call.");
		return;
	}

	xil_printf("\r\n###############################################\r\n");
	xil_printf("Data Converter startup up in progress...\n\r");
	// Writing 1 to the master reset register to reset all logic in the RFDC core and restart
	// the power-on sequence of all converters in this core
	Xil_Out32(RFDC_BASE + XRFDC_RESTART_OFFSET, 1);
	xil_printf("RF Data Converters Reset and Powered up.\r\n");
	sleep(1);

	// startup
	for ( Tile_Id=0; Tile_Id<=3; Tile_Id++) {
		if (ipStatus.DACTileStatus[Tile_Id].IsEnabled == 1) {
			val = XRFdc_ReadReg16(RFdcInstPtr, XRFDC_ADC_TILE_CTRL_STATS_ADDR(Tile_Id), XRFDC_ADC_DEBUG_RST_OFFSET);
			if(val & XRFDC_DBG_RST_CAL_MASK) {
				xil_printf("  Tile: %d NOT ready.\r\n", Tile_Id);
			} else {
				XRFdc_StartUp(RFdcInstPtr, 1, Tile_Id);
				usleep(200000);
			}
		}
	}

	for ( Tile_Id=0; Tile_Id<=3; Tile_Id++) {
		if (ipStatus.ADCTileStatus[Tile_Id].IsEnabled == 1) {
			val = XRFdc_ReadReg16(RFdcInstPtr, XRFDC_ADC_TILE_CTRL_STATS_ADDR(Tile_Id), XRFDC_ADC_DEBUG_RST_OFFSET);
			if(val & XRFDC_DBG_RST_CAL_MASK) {
				xil_printf("  ADC Tile%d NOT ready.\r\n", Tile_Id);
			} else {
				XRFdc_StartUp(RFdcInstPtr, 0, Tile_Id);
				usleep(200000);
			}
		}
	}

	xil_printf("\r\nThe Power-on sequence step. 0xF is complete.\r\n");


	for ( Tile_Id=0; Tile_Id<=3; Tile_Id++) {
		if (ipStatus.DACTileStatus[Tile_Id].IsEnabled == 1) {
			val = XRFdc_ReadReg16(RFdcInstPtr, XRFDC_ADC_TILE_CTRL_STATS_ADDR(Tile_Id), XRFDC_ADC_DEBUG_RST_OFFSET);
			if(val & XRFDC_DBG_RST_CAL_MASK) {
				xil_printf("  Tile: %d NOT ready.\r\n", Tile_Id);
			} else {
				xil_printf("   DAC Tile%d Power-on Sequence Step: 0x%08x\r\n",Tile_Id,
						Xil_In32(RFDC_BASE + 0x0000C + 0x04000 + Tile_Id * 0x4000));
			}
		}
	}

	for ( Tile_Id=0; Tile_Id<=3; Tile_Id++) {
		if (ipStatus.ADCTileStatus[Tile_Id].IsEnabled == 1) {
			val = XRFdc_ReadReg16(RFdcInstPtr, XRFDC_ADC_TILE_CTRL_STATS_ADDR(Tile_Id), XRFDC_ADC_DEBUG_RST_OFFSET);
			if(val & XRFDC_DBG_RST_CAL_MASK) {
				xil_printf("  ADC Tile%d NOT ready.\r\n", Tile_Id);
			} else {
				xil_printf("   ADC Tile%d Power-on Sequence Step: 0x%08x\r\n",Tile_Id,
						Xil_In32(RFDC_BASE + 0x0000C + 0x14000 + Tile_Id * 0x4000));
			}
		}
	}


	xil_printf("\n\rData Converter power up is complete!");
	xil_printf("\r\n###############################################\r\n");

	return;
}

/*****************************************************************************/
/**
*
* Startup up specified DAC and ADC Tiles using a tile mask. 0x8 = Tile 3, 0x1 = Tile 0,
* 0x9 = Tiles 0 and 3
*
* Existing register settings are not lost or altered in the process. It just starts
* the requested tile(s).
*
* @param	cmdVals[0] tiles
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void rfdcPowerOnTiles (u32 *cmdVals) {

	u32 ADC_Tile_Id = 0;
	u32 DAC_Tile_Id = 0;
	u32 PowerOnState = 0xf;

	XRFdc_IPStatus ipStatus;
	XRFdc* RFdcInstPtr = &RFdcInst;

	u32 Status;
	u32 Tile_Id;

    ADC_Tile_Id = cmdVals[0];
	DAC_Tile_Id = cmdVals[1];

	// Calling this function gets the status of the IP
	Status = XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);
	if(Status != XRFDC_SUCCESS){
		xil_printf("Error in XRFdc_GetIPStatus function call.");
		return;
	}

	xil_printf("\r\n###############################################\r\n");
	xil_printf("Data Converter startup up in progress...\n\r");

	// startup

	for ( Tile_Id=0; Tile_Id<=3; Tile_Id++) {
		if (ipStatus.ADCTileStatus[Tile_Id].IsEnabled == 1) {
				if ((ADC_Tile_Id & (1<<Tile_Id)) == 1<<Tile_Id){
					switch (Tile_Id){
					case 0:
						Xil_Out32(RFDC_BASE + 0x00008 + 0x14000 + Tile_Id * 0x4000,PowerOnState);
						Xil_Out32(RFDC_BASE + 0x00004 + 0x14000 + Tile_Id * 0x4000,0x1);
						usleep(20000);
						break;
					case 1:
						Xil_Out32(RFDC_BASE + 0x00008 + 0x14000 + Tile_Id * 0x4000,PowerOnState);
						Xil_Out32(RFDC_BASE + 0x00004 + 0x14000 + Tile_Id * 0x4000,0x1);
						usleep(20000);
						break;
					case 2:
						Xil_Out32(RFDC_BASE + 0x00008 + 0x14000 + Tile_Id * 0x4000,PowerOnState);
						Xil_Out32(RFDC_BASE + 0x00004 + 0x14000 + Tile_Id * 0x4000,0x1);
						usleep(20000);
						break;
					case 3:
						Xil_Out32(RFDC_BASE + 0x00008 + 0x14000 + Tile_Id * 0x4000,PowerOnState);
						Xil_Out32(RFDC_BASE + 0x00004 + 0x14000 + Tile_Id * 0x4000,0x1);
						usleep(20000);
						break;
				}
			}
		}
	}

	for ( Tile_Id=0; Tile_Id<=3; Tile_Id++) {
		if (ipStatus.DACTileStatus[Tile_Id].IsEnabled == 1) {
				if ((DAC_Tile_Id & (1<<Tile_Id)) == 1<<Tile_Id){
					if ((DAC_Tile_Id & (1<<Tile_Id)) == 1<<Tile_Id){
						switch (Tile_Id){
						case 0:
							Xil_Out32(RFDC_BASE + 0x00008 + 0x04000 + Tile_Id * 0x4000,PowerOnState);
							Xil_Out32(RFDC_BASE + 0x00004 + 0x04000 + Tile_Id * 0x4000,0x1);
							usleep(20000);
							break;
						case 1:
							Xil_Out32(RFDC_BASE + 0x00008 + 0x04000 + Tile_Id * 0x4000,PowerOnState);
							Xil_Out32(RFDC_BASE + 0x00004 + 0x04000 + Tile_Id * 0x4000,0x1);
							usleep(20000);
							break;
						case 2:
							Xil_Out32(RFDC_BASE + 0x00008 + 0x04000 + Tile_Id * 0x4000,PowerOnState);
							Xil_Out32(RFDC_BASE + 0x00004 + 0x04000 + Tile_Id * 0x4000,0x1);
							usleep(20000);
							break;
						case 3:
							Xil_Out32(RFDC_BASE + 0x00008 + 0x04000 + Tile_Id * 0x4000,PowerOnState);
							Xil_Out32(RFDC_BASE + 0x00004 + 0x04000 + Tile_Id * 0x4000,0x1);
							usleep(20000);
							break;
						}
					}
				}
		}
	}

	for ( Tile_Id=0; Tile_Id<=3; Tile_Id++) {
		if (ipStatus.ADCTileStatus[Tile_Id].IsEnabled == 1) {
				xil_printf("   ADC Tile%d Power-on Sequence Step: 0x%08x\r\n",Tile_Id,
						Xil_In32(RFDC_BASE + 0x0000C + 0x14000 + Tile_Id * 0x4000));
		}
	}

	for ( Tile_Id=0; Tile_Id<=3; Tile_Id++) {
		if (ipStatus.DACTileStatus[Tile_Id].IsEnabled == 1) {
				xil_printf("   DAC Tile%d Power-on Sequence Step: 0x%08x\r\n",Tile_Id,
						Xil_In32(RFDC_BASE + 0x0000C + 0x04000 + Tile_Id * 0x4000));
				usleep(200000);
			}
		}

	xil_printf("\n\rData Converter power up is complete!");
	xil_printf("\r\n###############################################\r\n");

	return;
}


/*****************************************************************************/
/**
*
* Startup up specified DAC and ADC Tiles using a tile mask. 0x8 = Tile 3, 0x1 = Tile 0,
* 0x9 = Tiles 0 and 3
*
* Existing register settings are not lost or altered in the process. It just starts
* the requested tile(s).
*
* @param	cmdVals[0] tiles
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void rfdcPowerDownTiles (u32 *cmdVals) {

	u32 ADC_Tile_Id = 0;
	u32 DAC_Tile_Id = 0;
	u32 ADC_PD_State = 0;
	XRFdc_IPStatus ipStatus;
	XRFdc* RFdcInstPtr = &RFdcInst;
	u32 Status;
	u32 Tile_Id;

    ADC_Tile_Id = cmdVals[0];
	DAC_Tile_Id = cmdVals[1];
	ADC_PD_State = cmdVals[2];
	// Calling this function gets the status of the IP
	Status = XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);
	if(Status != XRFDC_SUCCESS){
		xil_printf("Error in XRFdc_GetIPStatus function call.");
		return;
	}

	xil_printf("\r\n###############################################\r\n");
	xil_printf("Data Converter startup up in progress...\n\r");

	// startup

	for ( Tile_Id=0; Tile_Id<=3; Tile_Id++) {
		if (ipStatus.ADCTileStatus[Tile_Id].IsEnabled == 1) {
				if ((ADC_Tile_Id & (1<<Tile_Id)) == 1<<Tile_Id){
					switch (Tile_Id){
					case 0:
						Xil_Out32(RFDC_BASE + 0x00008 + 0x14000 + Tile_Id * 0x4000,ADC_PD_State);
						Xil_Out32(RFDC_BASE + 0x00004 + 0x14000 + Tile_Id * 0x4000,0x1);
						usleep(20000);
						break;
					case 1:
						Xil_Out32(RFDC_BASE + 0x00008 + 0x14000 + Tile_Id * 0x4000,ADC_PD_State);
						Xil_Out32(RFDC_BASE + 0x00004 + 0x14000 + Tile_Id * 0x4000,0x1);
						usleep(20000);
						break;
					case 2:
						Xil_Out32(RFDC_BASE + 0x00008 + 0x14000 + Tile_Id * 0x4000,ADC_PD_State);
						Xil_Out32(RFDC_BASE + 0x00004 + 0x14000 + Tile_Id * 0x4000,0x1);
						usleep(20000);
						break;
					case 3:
						Xil_Out32(RFDC_BASE + 0x00008 + 0x14000 + Tile_Id * 0x4000,ADC_PD_State);
						Xil_Out32(RFDC_BASE + 0x00004 + 0x14000 + Tile_Id * 0x4000,0x1);
						usleep(20000);
						break;
				}
			}
		}
	}

	for ( Tile_Id=0; Tile_Id<=3; Tile_Id++) {
		if (ipStatus.DACTileStatus[Tile_Id].IsEnabled == 1) {
				if ((DAC_Tile_Id & (1<<Tile_Id)) == 1<<Tile_Id){
					if ((DAC_Tile_Id & (1<<Tile_Id)) == 1<<Tile_Id){
						switch (Tile_Id){
						case 0:
							Xil_Out32(RFDC_BASE + 0x00008 + 0x04000 + Tile_Id * 0x4000,ADC_PD_State);
							Xil_Out32(RFDC_BASE + 0x00004 + 0x04000 + Tile_Id * 0x4000,0x1);
							usleep(20000);
							break;
						case 1:
							Xil_Out32(RFDC_BASE + 0x00008 + 0x04000 + Tile_Id * 0x4000,ADC_PD_State);
							Xil_Out32(RFDC_BASE + 0x00004 + 0x04000 + Tile_Id * 0x4000,0x1);
							usleep(20000);
							break;
						case 2:
							Xil_Out32(RFDC_BASE + 0x00008 + 0x04000 + Tile_Id * 0x4000,ADC_PD_State);
							Xil_Out32(RFDC_BASE + 0x00004 + 0x04000 + Tile_Id * 0x4000,0x1);
							usleep(20000);
							break;
						case 3:
							Xil_Out32(RFDC_BASE + 0x00008 + 0x04000 + Tile_Id * 0x4000,ADC_PD_State);
							Xil_Out32(RFDC_BASE + 0x00004 + 0x04000 + Tile_Id * 0x4000,0x1);
							usleep(20000);
							break;
						}
					}

				}
			}
		else{
			xil_printf("Tile %d not enabled.\n\r",Tile_Id);
		}
	}

	for ( Tile_Id=0; Tile_Id<=3; Tile_Id++) {
		if (ipStatus.ADCTileStatus[Tile_Id].IsEnabled == 1) {
				xil_printf("   ADC Tile%d Power-on Sequence Step: 0x%08x\r\n",Tile_Id,
						Xil_In32(RFDC_BASE + 0x0000C + 0x14000 + Tile_Id * 0x4000));
				usleep(200000);
		}
	}

	for ( Tile_Id=0; Tile_Id<=3; Tile_Id++) {
		if (ipStatus.DACTileStatus[Tile_Id].IsEnabled == 1) {
				xil_printf("   DAC Tile%d Power-on Sequence Step: 0x%08x\r\n",Tile_Id,
						Xil_In32(RFDC_BASE + 0x0000C + 0x04000 + Tile_Id * 0x4000));
		}
 	}

	xil_printf("\n\rData Converter power down is complete!");
	xil_printf("\r\n###############################################\r\n");

	return;
}


