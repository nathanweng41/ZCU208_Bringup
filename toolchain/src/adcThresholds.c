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


/*
 * adcThresholds.c
 *
 *  Created on: Dec 17, 2020
 *      Author: fpinto
 */


/***************************** Include Files *********************************/
#include "xil_io.h"
#include "xil_types.h"
#include <stdio.h>
#include <string.h>
#include "cli.h"
#include "xparameters.h"
#include "main.h"
#include "xrfdc.h"
#include "adcThresholds.h"


/************************** Constant Definitions *****************************/

/**************************** Type Definitions *******************************/

/***************** Macros (Inline Functions) Definitions *********************/

/************************** Function Prototypes ******************************/

/************************** Variable Definitions *****************************/

/************************** Function Definitions ******************************/


/*****************************************************************************/
/**
*
* cli_adcSetUnFreezeCal_init Add functions from this file to CLI
*
* @param	None
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void cli_adcThresholds_init(void)
{
	static CMDSTRUCT cliCmds[] = {
	   	{"############## ADC Threshold Commands ##################" , " "  , 0, *cmdComment   },
		{"adcGetThresh"  , "- <tile> <adc> Get ADC Threshold Settings "    , 2, *adcGetThresh},
		{"adcSetThresh"  , "- <tile> <adc> <num> <mode> <u> <o> <a>      " , 7, *adcSetThresh},
		{"adcClearThresh"  , "- <tile> <adc> <num> Clear Threshold"        , 3, *adcClearThresh},
		// {"adcClearOR"  , "- <tile> <adc> Clear Over Range"                 , 2, *adcClearOR},
		// {"adcClearOV"  , "- <tile> <adc> Clear Over Voltage"			   , 2, *adcClearOV},
		{" "                       , " "                                   , 0, *cmdComment   },
	};

	cli_addCmds(cliCmds, sizeof(cliCmds)/sizeof(cliCmds[0]));
	}

/*****************************************************************************/
/**
*
* adcSetThresh ADC Set Threshold
*
* @param	None
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void adcSetThresh (u32 *cmdVals)
{
  // // Initial Setup
  // XRFdc_Threshold_Settings Threshold_Settings;
  // // Setup values for threshold 0 and 1
  // Threshold_Settings.UpdateThreshold = XRFDC_UPDATE_THRESHOLD_BOTH; 
  // // Set threshold0 mode to Sticky Under
  // Threshold_Settings.ThresholdMode[0] = XRFDC_TRSHD_STICKY_UNDER; 
  // // Measured in 14-bit unsigned LSBs
  // Threshold_Settings.ThresholdUnderVal[0] = 1000; 
  // // Data must be below lower threshold for 10*8 4 GSPS RF-ADC samples
  // Threshold_Settings.ThresholdAvgVal[0] = 10; 
  // // Write threshold values to the selected Tile / RF-ADC
  // XRFdc_SetThresholdSettings(ptr, Tile, Block, &Threshold_Settings);


	u32 Tile_Id;
	u32 Block_Id;
	u32 Num;
	u32 Mode;
	u32 OverVal;
	u32 UnderVal;
	u32 AvgVal;
	char* threshmode;

	//int Status;
	Tile_Id = cmdVals[0];
	Block_Id = cmdVals[1];
	Num = cmdVals[2];
	Mode = cmdVals[3];
	UnderVal = cmdVals[4];
	OverVal = cmdVals[5];
	AvgVal = cmdVals[6];

	XRFdc_IPStatus ipStatus;
	XRFdc* RFdcInstPtr = &RFdcInst;


    XRFdc_Threshold_Settings Threshold_Settings;

    XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);
	xil_printf("\n\r###############################################\n\r");
	xil_printf("=== ADC Set Threshold Settings ===\n\r");

	if(XRFdc_IsADCBlockEnabled(RFdcInstPtr, Tile_Id, Block_Id)) {

		switch(Num) {
		case 0 :
			Threshold_Settings.UpdateThreshold = XRFDC_UPDATE_THRESHOLD_0;
			break;
		case 1 :
			Threshold_Settings.UpdateThreshold = XRFDC_UPDATE_THRESHOLD_1;
			break;
		case 3 :
			Threshold_Settings.UpdateThreshold = XRFDC_UPDATE_THRESHOLD_BOTH;
			break;
		default :
			xil_printf("ERROR: Invalid <num> Value - supported values are [0 1 3]. Aborting command...\r\n\n");
			return;
		}

		switch(Mode) {
		case 0 :
			Threshold_Settings.ThresholdMode[Num] = XRFDC_TRSHD_OFF;
			threshmode = "XRFDC_TRSHD_OFF";
			break;
		case 1 :
			Threshold_Settings.ThresholdMode[Num] = XRFDC_TRSHD_STICKY_OVER;
			threshmode = "XRFDC_TRSHD_STICKY_OVER";
			break;
		case 2 :
			Threshold_Settings.ThresholdMode[Num] = XRFDC_TRSHD_STICKY_UNDER;
			threshmode = "XRFDC_TRSHD_STICKY_UNDER";
			break;
		case 3 :
			Threshold_Settings.ThresholdMode[Num] = XRFDC_TRSHD_HYSTERISIS;
			threshmode = "XRFDC_TRSHD_HYSTERISIS";
			break;
		default :
			xil_printf("ERROR: Invalid <mode> Value - supported values are [0,1,2,3]. Aborting command...\r\n\n");
			return;
		}

		Threshold_Settings.ThresholdUnderVal[Num] = UnderVal;
		Threshold_Settings.ThresholdOverVal[Num] = OverVal;
		// Data must be below lower threshold for AvgVal*8 Fs RF-ADC samples
		Threshold_Settings.ThresholdAvgVal[Num] = AvgVal;

        // Write threshold values to the selected Tile / RF-ADC
		xil_printf("Calling XRFdc_SetThresholdSettings for Tile%d ch%d\r\n", Tile_Id, Block_Id);
		xil_printf("   UpdateThreshold       = %d (Port %d)\r\n",Num, Num+1);
		xil_printf("   ThresholdMode[%d]      = %d (%s)\r\n ", Num, Mode,threshmode );
		xil_printf("  ThresholdUnderVal[%d]  = %d\r\n", Num, UnderVal);
		xil_printf("   ThresholdOverVal[%d]   = %d\r\n", Num, OverVal);
		xil_printf("   ThresholdAvgVal[%d]    = %d\r\n", Num, AvgVal);

        XRFdc_SetThresholdSettings(RFdcInstPtr, Tile_Id, Block_Id, &Threshold_Settings);
	}
	else{xil_printf("ADC Tile%d ch%d is not available.\n\r", Tile_Id, Block_Id);}

	xil_printf("###############################################\r\n\n");


	return;
}


/*****************************************************************************/
/**
*
* adcGetThresh TBD
*
* @param	None
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void adcGetThresh (u32 *cmdVals)
{
  // // Initial Setup
  // XRFdc_Threshold_Settings Threshold_Settings;
  // // Setup values for threshold 0 and 1
  // Threshold_Settings.UpdateThreshold = XRFDC_UPDATE_THRESHOLD_BOTH; 
  // // Set threshold0 mode to Sticky Under
  // Threshold_Settings.ThresholdMode[0] = XRFDC_TRSHD_STICKY_UNDER; 
  // // Measured in 14-bit unsigned LSBs
  // Threshold_Settings.ThresholdUnderVal[0] = 1000; 
  // // Data must be below lower threshold for 10*8 4 GSPS RF-ADC samples
  // Threshold_Settings.ThresholdAvgVal[0] = 10; 
  // // Write threshold values to the selected Tile / RF-ADC
  // XRFdc_SetThresholdSettings(ptr, Tile, Block, &Threshold_Settings);

	u32 Tile_Id;
	u32 Block_Id;

	//int Status;
	Tile_Id = cmdVals[0];
	Block_Id = cmdVals[1];


	XRFdc_IPStatus ipStatus;
	XRFdc* RFdcInstPtr = &RFdcInst;


    XRFdc_Threshold_Settings Threshold_Settings;


    XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);
	xil_printf("\n\r###############################################\n\r");
	xil_printf("=== ADC Get Threshold Settings ===\n\r");

	if(XRFdc_IsADCBlockEnabled(RFdcInstPtr, Tile_Id, Block_Id)) {

		XRFdc_GetThresholdSettings(RFdcInstPtr, Tile_Id, Block_Id, &Threshold_Settings);
		xil_printf("    ADC Tile%d ch%d\n\r", Tile_Id, Block_Id);
		xil_printf("    -------------------------------------------\n\r");

		switch(Threshold_Settings.ThresholdMode[0]) {
		case XRFDC_TRSHD_OFF :
			xil_printf("    ThresholdMode[0]     = %d (XRFDC_TRSHD_OFF)\n\r", Threshold_Settings.ThresholdMode[0]);
			break;
		case XRFDC_TRSHD_STICKY_OVER :
			xil_printf("    ThresholdMode[0]     = %d (XRFDC_TRSHD_STICKY_OVER)\n\r", Threshold_Settings.ThresholdMode[0]);
			break;
		case XRFDC_TRSHD_STICKY_UNDER :
			xil_printf("    ThresholdMode[0]     = %d (XRFDC_TRSHD_STICKY_UNDER)\n\r", Threshold_Settings.ThresholdMode[0]);
			break;
		case XRFDC_TRSHD_HYSTERISIS :
			xil_printf("    ThresholdMode[0]     = %d (XRFDC_TRSHD_HYSTERISIS)\n\r", Threshold_Settings.ThresholdMode[0]);
			break;
		default : // shouldn't get here but print out value just in case
			xil_printf("    ThresholdMode[0]     = %d\n\r", Threshold_Settings.ThresholdMode[0]);
		}

	    xil_printf("    ThresholdUnderVal[0] = %d\n\r", Threshold_Settings.ThresholdUnderVal[0]);
	    xil_printf("    ThresholdOverVal[0]  = %d\n\r", Threshold_Settings.ThresholdOverVal[0]);
	    xil_printf("    ThresholdAvgVal[0]   = %d\n\r", Threshold_Settings.ThresholdAvgVal[0]);
	    xil_printf("    -------------------------------------------\n\r");

	    switch(Threshold_Settings.ThresholdMode[1]) {
		case XRFDC_TRSHD_OFF :
			xil_printf("    ThresholdMode[1]     = %d (XRFDC_TRSHD_OFF)\n\r", Threshold_Settings.ThresholdMode[1]);
			break;
		case XRFDC_TRSHD_STICKY_OVER :
			xil_printf("    ThresholdMode[1]     = %d (XRFDC_TRSHD_STICKY_OVER)\n\r", Threshold_Settings.ThresholdMode[1]);
			break;
		case XRFDC_TRSHD_STICKY_UNDER :
			xil_printf("    ThresholdMode[1]     = %d (XRFDC_TRSHD_STICKY_UNDER)\n\r", Threshold_Settings.ThresholdMode[1]);
			break;
		case XRFDC_TRSHD_HYSTERISIS :
			xil_printf("    ThresholdMode[1]     = %d (XRFDC_TRSHD_HYSTERISIS)\n\r", Threshold_Settings.ThresholdMode[1]);
			break;
		default : // shouldn't get here but print out value just in case
			xil_printf("    ThresholdMode[1] = %d\n\r", Threshold_Settings.ThresholdMode[1]);
		}

	    xil_printf("    ThresholdUnderVal[1] = %d\n\r", Threshold_Settings.ThresholdUnderVal[1]);
	    xil_printf("    ThresholdOverVal[1]  = %d\n\r", Threshold_Settings.ThresholdOverVal[1]);
	    xil_printf("    ThresholdAvgVal[1]   = %d\n\r", Threshold_Settings.ThresholdAvgVal[1]);
	    xil_printf("    -------------------------------------------\n\r");
	}
	else{xil_printf("ADC Tile%d ch%d is not available.\n\r", Tile_Id, Block_Id);}

	xil_printf("###############################################\r\n\n");



	return;
}

/*****************************************************************************/
/**
*
* adcClearOr ADC Clear Threshold
*
* @param	None
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void adcClearThresh (u32 *cmdVals)
{

	u32 Tile_Id;
	u32 Block_Id;
	u32 Num;
	Tile_Id = cmdVals[0];
	Block_Id = cmdVals[1];
	Num = cmdVals[2];
    Num = Num + 1;

	XRFdc_IPStatus ipStatus;
	XRFdc* RFdcInstPtr = &RFdcInst;

    XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);
	xil_printf("\n\r###############################################\n\r");
	xil_printf("=== ADC Clear Threshold ===\n\r");

	if(XRFdc_IsADCBlockEnabled(RFdcInstPtr, Tile_Id, Block_Id) == 1) {
		XRFdc_SetThresholdClrMode(RFdcInstPtr, Tile_Id, Block_Id, Num,XRFDC_THRESHOLD_CLRMD_MANUAL_CLR);
		XRFdc_ThresholdStickyClear(RFdcInstPtr, Tile_Id, Block_Id, Num);
    	xil_printf("   ADC Tile%d ch%d Threshold %d (Port %d) status has been cleared\r\n", Tile_Id, Block_Id, Num - 1, Num );
	}
	else{xil_printf("ADC Tile%d ch%d is not available.\n\r", Tile_Id, Block_Id);}

	xil_printf("###############################################\r\n\n");

	return;
}



