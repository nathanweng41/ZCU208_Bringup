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
#include "rfdc_mts.h"
#include "sleep.h"


/************************** Constant Definitions *****************************/

/**************************** Type Definitions *******************************/

/***************** Macros (Inline Functions) Definitions *********************/

/************************** Function Prototypes ******************************/
int mygetline(void);

/************************** Variable Definitions *****************************/

XRFdc_MultiConverter_Sync_Config ADC_Sync_Config;
XRFdc_MultiConverter_Sync_Config DAC_Sync_Config;


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
void cli_cmd_mts_init(void)
{
	static CMDSTRUCT cliCmds[] = {
		//000000000011111111112222    000000000011111111112222222222333333333
		//012345678901234567890123    012345678901234567890123456789012345678
		{"################### DAC and ADC MTS ####################" , " " , 0, *cmdComment   },
		{"dacMTS"             , "<tileMask> <ref tile> - DAC MTS"                    , 2, *dacMTS},
		{"dacMTSwl"           , "<tileMask> <ref tile> - DAC MTS with fixed latency" , 2, *dacMTSwl},
		{"adcMTS"             , "<tileMask> <ref tile> - ADC MTS"                    , 2, *adcMTS},
		{"adcMTSwl"           , "<tileMask> <ref tile> - ADC MTS with fixed latency" , 2, *adcMTSwl},
		{"dacAdcMTSStatus"    , "- Dump DAC & ADC Sync status"            , 0, *dacAdcMTSStatus},
        {"syncNCO"            , "- Synchronize DAC230_0 and ADC224_0 NCO phase using SYSREF", 0, *syncNCO},
		{" "                       , " "                                  , 0, *cmdComment   },

	};

	cli_addCmds(cliCmds, sizeof(cliCmds)/sizeof(cliCmds[0]));
}

void syncNCO(u32 *cmdVals)
{
    XRFdc *RFdcInstPtr = &RFdcInst;
    XRFdc_Mixer_Settings DAC_MixerSettings;
    XRFdc_Mixer_Settings ADC_MixerSettings;

    u32 Status;

    /*
     * ZCU208 tile numbering used by RFdc driver:
     *
     * DAC230_0 -> DAC tile 2, block 0
     * ADC224_0 -> ADC tile 0, block 0
     */
    const u32 DAC_TILE  = 2;
    const u32 DAC_BLOCK = 0;

    const u32 ADC_TILE  = 0;
    const u32 ADC_BLOCK = 0;


    xil_printf("\r\n");
    xil_printf("###############################################\r\n");
    xil_printf("Synchronizing DAC/ADC fine-mixer NCO phase\r\n");
    xil_printf("  DAC: Tile %d Block %d\r\n",
               DAC_TILE, DAC_BLOCK);
    xil_printf("  ADC: Tile %d Block %d\r\n",
               ADC_TILE, ADC_BLOCK);


    /*
     * ---------------------------------------------------------
     * Verify that MTS has actually been run on these tiles.
     * ---------------------------------------------------------
     */
    if ((DAC_Sync_Config.Tiles & (1U << DAC_TILE)) == 0U) {
        xil_printf(
            "ERROR: DAC tile %d is not present in DAC MTS config\r\n",
            DAC_TILE);
        xil_printf("Run dacMTS first.\r\n");
        return;
    }

    if ((ADC_Sync_Config.Tiles & (1U << ADC_TILE)) == 0U) {
        xil_printf(
            "ERROR: ADC tile %d is not present in ADC MTS config\r\n",
            ADC_TILE);
        xil_printf("Run adcMTS first.\r\n");
        return;
    }


    /*
     * ---------------------------------------------------------
     * 1. Disable analog SYSREF receiver.
     *
     * No SYSREF event can occur while we are programming/
     * arming the two fine mixers.
     * ---------------------------------------------------------
     */
    Status = XRFdc_MTS_Sysref_Config(
        RFdcInstPtr,
        &DAC_Sync_Config,
        &ADC_Sync_Config,
        0);

    if (Status != XST_SUCCESS) {
        xil_printf(
            "ERROR: XRFdc_MTS_Sysref_Config(disable) failed\r\n");
        return;
    }

    xil_printf("SYSREF receiver disabled\r\n");


    /*
     * ---------------------------------------------------------
     * 2. Read current mixer settings.
     *
     * dacSetNCO / adcSetNCO have already set frequency.
     * We preserve those frequencies here.
     * ---------------------------------------------------------
     */
    Status = XRFdc_GetMixerSettings(
        RFdcInstPtr,
        XRFDC_DAC_TILE,
        DAC_TILE,
        DAC_BLOCK,
        &DAC_MixerSettings);

    if (Status != XST_SUCCESS) {
        xil_printf(
            "ERROR: XRFdc_GetMixerSettings(DAC) failed\r\n");
        goto cleanup;
    }


    Status = XRFdc_GetMixerSettings(
        RFdcInstPtr,
        XRFDC_ADC_TILE,
        ADC_TILE,
        ADC_BLOCK,
        &ADC_MixerSettings);

    if (Status != XST_SUCCESS) {
        xil_printf(
            "ERROR: XRFdc_GetMixerSettings(ADC) failed\r\n");
        goto cleanup;
    }


    xil_printf("Current mixer settings:\r\n");

    printf(
        "  DAC Freq = %f MHz, Phase = %f deg\r\n",
        DAC_MixerSettings.Freq,
        DAC_MixerSettings.PhaseOffset);

    printf(
        "  ADC Freq = %f MHz, Phase = %f deg\r\n",
        ADC_MixerSettings.Freq,
        ADC_MixerSettings.PhaseOffset);


    /*
     * ---------------------------------------------------------
     * 3. Change only the EVENT SOURCE to SYSREF.
     *
     * Don't touch frequency, mixer mode, mixer type, etc.
     * ---------------------------------------------------------
     */
    DAC_MixerSettings.EventSource = XRFDC_EVNT_SRC_SYSREF;
    ADC_MixerSettings.EventSource = XRFDC_EVNT_SRC_SYSREF;


    Status = XRFdc_SetMixerSettings(
        RFdcInstPtr,
        XRFDC_DAC_TILE,
        DAC_TILE,
        DAC_BLOCK,
        &DAC_MixerSettings);

    if (Status != XST_SUCCESS) {
        xil_printf(
            "ERROR: XRFdc_SetMixerSettings(DAC) failed\r\n");
        goto cleanup;
    }


    Status = XRFdc_SetMixerSettings(
        RFdcInstPtr,
        XRFDC_ADC_TILE,
        ADC_TILE,
        ADC_BLOCK,
        &ADC_MixerSettings);

    if (Status != XST_SUCCESS) {
        xil_printf(
            "ERROR: XRFdc_SetMixerSettings(ADC) failed\r\n");
        goto cleanup;
    }


    /*
     * ---------------------------------------------------------
     * 4. Arm DAC and ADC NCO phase resets.
     *
     * Because EventSource == SYSREF, these calls ARM the reset.
     * They do not need separate TILE UpdateEvent commands.
     * ---------------------------------------------------------
     */
    Status = XRFdc_ResetNCOPhase(
        RFdcInstPtr,
        XRFDC_DAC_TILE,
        DAC_TILE,
        DAC_BLOCK);

    if (Status != XST_SUCCESS) {
        xil_printf(
            "ERROR: XRFdc_ResetNCOPhase(DAC) failed\r\n");
        goto cleanup;
    }

    xil_printf("DAC NCO phase reset armed\r\n");


    Status = XRFdc_ResetNCOPhase(
        RFdcInstPtr,
        XRFDC_ADC_TILE,
        ADC_TILE,
        ADC_BLOCK);

    if (Status != XST_SUCCESS) {
        xil_printf(
            "ERROR: XRFdc_ResetNCOPhase(ADC) failed\r\n");
        goto cleanup;
    }

    xil_printf("ADC NCO phase reset armed\r\n");


    /*
     * ---------------------------------------------------------
     * 5. Enable the analog SYSREF receiver.
     *
     * CLK104 is already generating continuous SYSREF.
     * The next SYSREF edge should launch both armed events.
     * ---------------------------------------------------------
     */
    Status = XRFdc_MTS_Sysref_Config(
        RFdcInstPtr,
        &DAC_Sync_Config,
        &ADC_Sync_Config,
        1);

    if (Status != XST_SUCCESS) {
        xil_printf(
            "ERROR: XRFdc_MTS_Sysref_Config(enable) failed\r\n");
        goto cleanup;
    }

    xil_printf("SYSREF receiver enabled\r\n");


    /*
     * SYSREF is ~1 MHz in your current clock configuration:
     * period ~= 1 us.
     *
     * Give it multiple cycles.
     */
    usleep(10);


    /*
     * ---------------------------------------------------------
     * 6. Disable analog SYSREF receiver again.
     * ---------------------------------------------------------
     */
    Status = XRFdc_MTS_Sysref_Config(
        RFdcInstPtr,
        &DAC_Sync_Config,
        &ADC_Sync_Config,
        0);

    if (Status != XST_SUCCESS) {
        xil_printf(
            "ERROR: Failed to disable SYSREF after event\r\n");
        return;
    }


    xil_printf("SYSREF event completed\r\n");
    xil_printf("NCO synchronization sequence completed\r\n");
    xil_printf("###############################################\r\n\r\n");

    return;


cleanup:

    /*
     * Best effort: leave SYSREF gated if something failed.
     */
    XRFdc_MTS_Sysref_Config(
        RFdcInstPtr,
        &DAC_Sync_Config,
        &ADC_Sync_Config,
        0);

    xil_printf("NCO synchronization FAILED\r\n");
    xil_printf("###############################################\r\n\r\n");
}



/*****************************************************************************/
/**
*
* Dac Sync Set
*
* @param	cmdVals[0] bit pattern for DAC tiles to sync. I.E Dac tiles 0 and 1 = 0x3
*           cmdVals[1] 0=event src tile, 1=pl event
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void dacMTS(u32 *cmdVals)
{
	XRFdc* RFdcInstPtr = &RFdcInst;
	u32 tiles;
	u32 ref_tile;
	int status;
    int i;
    u32 factor;

	tiles = cmdVals[0];
	ref_tile = cmdVals[1];

	// Set MTS
	xil_printf("\r\n###############################################\r\n");
	xil_printf("Enabling DAC Multi-Tile Synchronization...\n\r\n");

    XRFdc_MultiConverter_Init (&DAC_Sync_Config, 0, 0, ref_tile);
    DAC_Sync_Config.Tiles = tiles;	/* Sync DAC tiles as defined by bits set */
    xil_printf("DAC_Sync_Config.Tiles: 0x%08x\r\n", DAC_Sync_Config.Tiles);
    xil_printf("DAC_Sync_Config.RefTile: 0x%08x\r\n", DAC_Sync_Config.RefTile);
	xil_printf("\n=== Multi-Tile Synchronization Metal Log Report ===\r\n");
   status = XRFdc_MultiConverter_Sync(RFdcInstPtr, XRFDC_DAC_TILE, &DAC_Sync_Config);
    if(status != XRFDC_MTS_OK) {
    	xil_printf("XRFdc_MultiConverter_Sync() FAILED\r\n");
    	return;
    }

    if(status == XRFDC_MTS_OK) {
    	xil_printf("\n========== DAC Multi-Tile Sync Report ==========\r\n");
    	for(i=0; i<4; i++) {
    		if((1<<i)&DAC_Sync_Config.Tiles) {
                XRFdc_GetInterpolationFactor(RFdcInstPtr, i, 0, &factor);
                xil_printf("DAC%d: Latency(T1) = %3d, Adjusted Delay "
				 "Offset(T%d) = %3d, Marker Delay = %d \r\n", i, DAC_Sync_Config.Latency[i],
						 factor, DAC_Sync_Config.Offset[i],DAC_Sync_Config.Marker_Delay);
                xil_printf("=== MTS DAC Tile%d PLL Report ===\r\n",i);
                xil_printf("    DAC%d: PLL DTC Code =%d \n\r", i, DAC_Sync_Config.DTC_Set_PLL.DTC_Code[i]);
                xil_printf("    DAC%d: PLL Num Windows =%d \n\r", i, DAC_Sync_Config.DTC_Set_PLL.Num_Windows[i]);
                xil_printf("    DAC%d: PLL Max Gap =%d \n\r", i, DAC_Sync_Config.DTC_Set_PLL.Max_Gap[i]);
                xil_printf("    DAC%d: PLL Min Gap =%d \n\r", i, DAC_Sync_Config.DTC_Set_PLL.Min_Gap[i]);
                xil_printf("    DAC%d: PLL Max Overlap =%d \n\r", i, DAC_Sync_Config.DTC_Set_PLL.Max_Overlap[i]);
                xil_printf("=== MTS DAC Tile%d T1 Report ===\r\n",i);
                xil_printf("    DAC%d: T1 DTC Code =%d \n\r", i, DAC_Sync_Config.DTC_Set_T1.DTC_Code[i]);
                xil_printf("    DAC%d: T1 Num Windows =%d \n\r", i, DAC_Sync_Config.DTC_Set_T1.Num_Windows[i]);
                xil_printf("    DAC%d: T1 Max Gap =%d \n\r", i, DAC_Sync_Config.DTC_Set_T1.Max_Gap[i]);
                xil_printf("    DAC%d: T1 Min Gap =%d \n\r", i, DAC_Sync_Config.DTC_Set_T1.Min_Gap[i]);
                xil_printf("    DAC%d: T1 Max Overlap =%d \n\n\r", i, DAC_Sync_Config.DTC_Set_T1.Max_Overlap[i]);

    		}
    	}

		xil_printf("DAC Multi-Tile Synchronization is complete.");
		xil_printf("\r\n###############################################\r\n");
	}

    return;
}


/*****************************************************************************/
/**
*
* mygetline
*
* @param	get line from console
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
int mygetline()
{
	char line[10];
	int i=0;
	char mychar;
	int finalVal;

	while(1) {
		 mychar=inbyte();
		 if (mychar == 0x0a) continue;
		 if (mychar == 0x0d) break;
		 if(i>=8) break;
		 xil_printf("%c", mychar);
		 line[i++]=mychar;
	}

	line[i] = 0;
	finalVal = atoi(&line[0]);

	return finalVal;
}

/*****************************************************************************/
/**
*
* Dac Sync Set with fixed latency
*
* @param	Keyboard entry required
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void dacMTSwl(u32 *cmdVals)
{
	XRFdc* RFdcInstPtr = &RFdcInst;
	u32 tiles;
	u32 ref_tile;
	int i;
	int status;
	u32 factor;
	int lat_test;

	tiles = cmdVals[0];
	ref_tile = cmdVals[1];

	xil_printf("\r\n###############################################\r\n");
	xil_printf("Enabling DAC Multi-Tile Synchronization with fixed latency...\n\r\n");
	xil_printf("Set latency to : ");
	lat_test = mygetline();
	xil_printf("\r\n    Latency set to : %d\r\n",lat_test);

	// Set MTS
    XRFdc_MultiConverter_Init (&DAC_Sync_Config, 0, 0, ref_tile);
    DAC_Sync_Config.Tiles = tiles;	/* Sync DAC tiles as defined by bits set */
    DAC_Sync_Config.Target_Latency = lat_test;
    xil_printf("DAC_Sync_Config.Tiles: 0x%08x\r\n", DAC_Sync_Config.Tiles);
    xil_printf("DAC_Sync_Config.RefTile: 0x%08x\r\n", DAC_Sync_Config.RefTile);
	xil_printf("\n=== Multi-Tile Synchronization Metal Log Report ===\r\n");
    status = XRFdc_MultiConverter_Sync(RFdcInstPtr, XRFDC_DAC_TILE, &DAC_Sync_Config);
    if(status != XRFDC_MTS_OK) {
    	xil_printf("XRFdc_MultiConverter_Sync() FAILED\r\n");
    	return;
    }

	if(status == XRFDC_MTS_OK) {
	   	xil_printf("\n========== DAC Multi-Tile Sync Report ==========\r\n");
		for(i=0; i<4; i++) {
			if((1<<i)&DAC_Sync_Config.Tiles) {
				XRFdc_GetInterpolationFactor(RFdcInstPtr, i, 0, &factor);
	               xil_printf("DAC%d: Latency(T1) = %3d, Adjusted Delay "
					 "Offset(T%d) = %3d, Marker Delay = %d \r\n", i, DAC_Sync_Config.Latency[i],
							 factor, DAC_Sync_Config.Offset[i],DAC_Sync_Config.Marker_Delay);
	                xil_printf("=== MTS DAC Tile%d PLL Report ===\r\n",i);
	                xil_printf("    DAC%d: PLL DTC Code =%d \n\r", i, DAC_Sync_Config.DTC_Set_PLL.DTC_Code[i]);
	                xil_printf("    DAC%d: PLL Num Windows =%d \n\r", i, DAC_Sync_Config.DTC_Set_PLL.Num_Windows[i]);
	                xil_printf("    DAC%d: PLL Max Gap =%d \n\r", i, DAC_Sync_Config.DTC_Set_PLL.Max_Gap[i]);
	                xil_printf("    DAC%d: PLL Min Gap =%d \n\r", i, DAC_Sync_Config.DTC_Set_PLL.Min_Gap[i]);
	                xil_printf("    DAC%d: PLL Max Overlap =%d \n\r", i, DAC_Sync_Config.DTC_Set_PLL.Max_Overlap[i]);
	                xil_printf("=== MTS DAC Tile%d T1 Report ===\r\n",i);
	                xil_printf("    DAC%d: T1 DTC Code =%d \n\r", i, DAC_Sync_Config.DTC_Set_T1.DTC_Code[i]);
	                xil_printf("    DAC%d: T1 Num Windows =%d \n\r", i, DAC_Sync_Config.DTC_Set_T1.Num_Windows[i]);
	                xil_printf("    DAC%d: T1 Max Gap =%d \n\r", i, DAC_Sync_Config.DTC_Set_T1.Max_Gap[i]);
	                xil_printf("    DAC%d: T1 Min Gap =%d \n\r", i, DAC_Sync_Config.DTC_Set_T1.Min_Gap[i]);
	                xil_printf("    DAC%d: T1 Max Overlap =%d \n\n\r", i, DAC_Sync_Config.DTC_Set_T1.Max_Overlap[i]);
			}
		}
		xil_printf("DAC Multi-Tile Synchronization with fixed latency is complete.");
		xil_printf("\r\n###############################################\r\n");


	}
    return;
}


//******************************************************************************/
void adcMTSwl(u32 *cmdVals)
{
	u32 tiles;
	u32 ref_tile;
	int i;
	int status;
	u32 factor;
	int lat_test;
	XRFdc* RFdcInstPtr = &RFdcInst;

	tiles = cmdVals[0];
	ref_tile = cmdVals[1];
	xil_printf("\r\n###############################################\r\n");
	xil_printf("Enabling ADC Multi-Tile Synchronization with fixed latency...\n\r\n");

	xil_printf("Set latency to : ");
	lat_test = mygetline();
	xil_printf("\r\n    Latency set to : %d\r\n",lat_test);

	// Set MTS
	XRFdc_MultiConverter_Init (&ADC_Sync_Config, 0, 0, ref_tile);
	ADC_Sync_Config.Tiles = tiles;	/* Sync DAC tiles as defined by bits set */
	ADC_Sync_Config.Target_Latency = lat_test;
	xil_printf("ADC_Sync_Config.Tiles: 0x%08x\r\n", ADC_Sync_Config.Tiles);
    xil_printf("ADC_Sync_Config.RefTile: 0x%08x\r\n", ADC_Sync_Config.RefTile);
	xil_printf("\n=== Multi-Tile Synchronization Metal Log Report ===\r\n");
	status = XRFdc_MultiConverter_Sync(RFdcInstPtr, XRFDC_ADC_TILE, &ADC_Sync_Config);
	if(status != XRFDC_MTS_OK) {
		xil_printf("XRFdc_MultiConverter_Sync() FAILED\r\n");
		return;
	}

	if(status == XRFDC_MTS_OK) {
	   	xil_printf("\n========== ADC Multi-Tile Sync Report ==========\r\n");
		for(i=0; i<4; i++) {
			if((1<<i)&ADC_Sync_Config.Tiles) {
				XRFdc_GetDecimationFactor(RFdcInstPtr, i, 0, &factor);
	               xil_printf("ADC%d: Latency(T1) = %3d, Adjusted Delay "
					 "Offset(T%d) = %3d, Marker Delay = %d \r\n", i, ADC_Sync_Config.Latency[i],
							 factor, ADC_Sync_Config.Offset[i],ADC_Sync_Config.Marker_Delay);
	                xil_printf("=== MTS ADC Tile%d PLL Report ===\r\n",i);
	                xil_printf("    ADC%d: PLL DTC Code =%d \n\r", i, ADC_Sync_Config.DTC_Set_PLL.DTC_Code[i]);
	                xil_printf("    ADC%d: PLL Num Windows =%d \n\r", i, ADC_Sync_Config.DTC_Set_PLL.Num_Windows[i]);
	                xil_printf("    ADC%d: PLL Max Gap =%d \n\r", i, ADC_Sync_Config.DTC_Set_PLL.Max_Gap[i]);
	                xil_printf("    ADC%d: PLL Min Gap =%d \n\r", i, ADC_Sync_Config.DTC_Set_PLL.Min_Gap[i]);
	                xil_printf("    ADC%d: PLL Max Overlap =%d \n\r", i, ADC_Sync_Config.DTC_Set_PLL.Max_Overlap[i]);
	                xil_printf("=== MTS ADC Tile%d T1 Report ===\r\n",i);
	                xil_printf("    ADC%d: T1 DTC Code =%d \n\r", i, ADC_Sync_Config.DTC_Set_T1.DTC_Code[i]);
	                xil_printf("    ADC%d: T1 Num Windows =%d \n\r", i, ADC_Sync_Config.DTC_Set_T1.Num_Windows[i]);
	                xil_printf("    ADC%d: T1 Max Gap =%d \n\r", i, ADC_Sync_Config.DTC_Set_T1.Max_Gap[i]);
	                xil_printf("    ADC%d: T1 Min Gap =%d \n\r", i, ADC_Sync_Config.DTC_Set_T1.Min_Gap[i]);
	                xil_printf("    ADC%d: T1 Max Overlap =%d \n\n\r", i, ADC_Sync_Config.DTC_Set_T1.Max_Overlap[i]);
			}
		}
		xil_printf("ADC Multi-Tile Synchronization with fixed latency is complete.");
		xil_printf("\r\n###############################################\r\n");


	}


    return;
}



/*****************************************************************************/
/**
*
* Adc Sync Set
*
* @param	cmdVals[0] bit pattern for ADC tiles to sync. I.E ADC tiles 0 and 1 = 0x3
*           cmdVals[1] 0=event src tile, 1=pl event
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void adcMTS(u32 *cmdVals)
{
	XRFdc* RFdcInstPtr = &RFdcInst;
	u32 tiles;
	u32 ref_tile;
	int status;
	int i;
	u32 factor;

	tiles = cmdVals[0];
	ref_tile = cmdVals[1];
	xil_printf("\r\n###############################################\r\n");
	xil_printf("Enabling ADC Multi-Tile Synchronization...\n\r\n");

	// Set MTS
	XRFdc_MultiConverter_Init (&ADC_Sync_Config, 0, 0, ref_tile);
	ADC_Sync_Config.Tiles = tiles;	/* Sync ADC tiles as defined by bits set */
	xil_printf("ADC_Sync_Config.Tiles: 0x%08x\r\n", ADC_Sync_Config.Tiles);
    xil_printf("ADC_Sync_Config.RefTile: 0x%08x\r\n", ADC_Sync_Config.RefTile);
	xil_printf("\n=== Multi-Tile Synchronization Metal Log Report ===\r\n");
	status = XRFdc_MultiConverter_Sync(RFdcInstPtr, XRFDC_ADC_TILE, &ADC_Sync_Config);
	if(status != XRFDC_MTS_OK) {
		xil_printf("XRFdc_MultiConverter_Sync() FAILED with error 0x%08x\r\n", status);
	}


	if(status == XRFDC_MTS_OK) {
	   	xil_printf("\n========== ADC Multi-Tile Sync Report ==========\r\n");
		for(i=0; i<4; i++) {
			if((1<<i)&ADC_Sync_Config.Tiles) {
				XRFdc_GetDecimationFactor(RFdcInstPtr, i, 0, &factor);
	               xil_printf("ADC%d: Latency(T1) = %3d, Adjusted Delay "
					 "Offset(T%d) = %3d, Marker Delay = %d \r\n", i, ADC_Sync_Config.Latency[i],
							 factor, ADC_Sync_Config.Offset[i],ADC_Sync_Config.Marker_Delay);
	                xil_printf("=== MTS ADC Tile%d PLL Report ===\r\n",i);
	                xil_printf("    ADC%d: PLL DTC Code =%d \n\r", i, ADC_Sync_Config.DTC_Set_PLL.DTC_Code[i]);
	                xil_printf("    ADC%d: PLL Num Windows =%d \n\r", i, ADC_Sync_Config.DTC_Set_PLL.Num_Windows[i]);
	                xil_printf("    ADC%d: PLL Max Gap =%d \n\r", i, ADC_Sync_Config.DTC_Set_PLL.Max_Gap[i]);
	                xil_printf("    ADC%d: PLL Min Gap =%d \n\r", i, ADC_Sync_Config.DTC_Set_PLL.Min_Gap[i]);
	                xil_printf("    ADC%d: PLL Max Overlap =%d \n\r", i, ADC_Sync_Config.DTC_Set_PLL.Max_Overlap[i]);
	                xil_printf("=== MTS ADC Tile%d T1 Report ===\r\n",i);
	                xil_printf("    ADC%d: T1 DTC Code =%d \n\r", i, ADC_Sync_Config.DTC_Set_T1.DTC_Code[i]);
	                xil_printf("    ADC%d: T1 Num Windows =%d \n\r", i, ADC_Sync_Config.DTC_Set_T1.Num_Windows[i]);
	                xil_printf("    ADC%d: T1 Max Gap =%d \n\r", i, ADC_Sync_Config.DTC_Set_T1.Max_Gap[i]);
	                xil_printf("    ADC%d: T1 Min Gap =%d \n\r", i, ADC_Sync_Config.DTC_Set_T1.Min_Gap[i]);
	                xil_printf("    ADC%d: T1 Max Overlap =%d \n\n\r", i, ADC_Sync_Config.DTC_Set_T1.Max_Overlap[i]);
			}
		}
		xil_printf("ADC Multi-Tile Synchronization is complete.");
		xil_printf("\r\n###############################################\r\n");

	}

    return;
}

/*****************************************************************************/
/**
*
* Dac and ADC Sync Dump
*
* @param	None
*
* @return	None
*
* @note		Report Overall Latency in T1 (Sample Clocks) and
*           Offsets (in terms of PL words) added to each FIFO
*
******************************************************************************/
void dacAdcMTSStatus(u32 *cmdVals)
{
	int i;
	u32 factor;
	XRFdc* RFdcInstPtr = &RFdcInst;
	xil_printf("\r\n###############################################\r\n");
	xil_printf("=== Multi-Tile Sync Report ===\r\n");
	for(i=0; i<4; i++) {
		if((1<<i)&DAC_Sync_Config.Tiles) {
				XRFdc_GetInterpolationFactor(RFdcInstPtr, i, 0, &factor);
				xil_printf("DAC%d: Latency(T1) =%3d, Adjusted Delay"
				 "Offset(T%d) =%3d\r\n", i, DAC_Sync_Config.Latency[i],
						 factor, DAC_Sync_Config.Offset[i]);
		}
	}

	for(i=0; i<4; i++) {
		if((1<<i)&ADC_Sync_Config.Tiles) {
			XRFdc_GetDecimationFactor(RFdcInstPtr, i, 0, &factor);
			xil_printf("ADC%d: Latency(T1) =%3d, Adjusted Delay"
			 "Offset(T%d) =%3d\r\n", i, ADC_Sync_Config.Latency[i],
					 factor, ADC_Sync_Config.Offset[i]);
		}
	}
	xil_printf("###############################################\r\n\n");
	return;
}





