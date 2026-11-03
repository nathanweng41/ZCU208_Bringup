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


// in the main.h file add #include "adc_dither.h"
//  In this section of the main.c file add...
	// Initialize CLI commands structure
	//	cli_adc_dither_init();


/***************************** Include Files *********************************/
#include "xil_io.h"
#include "xil_types.h"
#include <stdio.h>
#include "cli.h"
#include "xparameters.h"
#include "main.h"
#include "xrfdc.h"
#include "adc_dither.h"

/************************** Constant Definitions *****************************/

/**************************** Type Definitions *******************************/

/***************** Macros (Inline Functions) Definitions *********************/

/************************** Function Prototypes ******************************/

/************************** Variable Definitions *****************************/


/*****************************************************************************/
/**
*
* cli_adc_dither_init Add functions from this file to CLI
*
* @param	None
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void cli_adc_dither_init(void)
{
	static CMDSTRUCT cliCmds[] = {
		{"##################### ADC Dither #######################" , " "    , 0, *cmdComment   },
		{"adcGetDither"    , "- Display Dither Setting for all tiles"        , 0, *adcGetDither},
		{"adcSetDither"    , "- <tile> <adc> <dither> 0-off, 1-on"           , 3, *adcSetDither},
		{" "                       , " "                                     , 0, *cmdComment   },
	};
	cli_addCmds(cliCmds, sizeof(cliCmds)/sizeof(cliCmds[0]));
}


/*****************************************************************************/
/**
*
* adcGetDither TBD
*
* @param	None
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void adcGetDither(u32 *cmdVals)
{
	u32 Tile_Id;
	u32 Block_Id;
	XRFdc_IPStatus ipStatus;
	XRFdc* RFdcInstPtr = &RFdcInst;
	u32 getDitherSettings;

	Tile_Id = cmdVals[0];
	Block_Id = cmdVals[1];

	XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);
	xil_printf("\n\r###############################################\n\r");
	xil_printf("=== ADC Get Dither ===\n\r");

	for (Tile_Id=0; Tile_Id<=3; Tile_Id++) {
		for(Block_Id=0; Block_Id<=3; Block_Id++) {
			if(XRFdc_IsADCBlockEnabled(RFdcInstPtr, Tile_Id, Block_Id)) {
				XRFdc_GetDither(RFdcInstPtr, Tile_Id, Block_Id, &getDitherSettings);
				if (getDitherSettings == 1){
					xil_printf("   ADC Tile%d ch%d Dither: %d (Dither Enabled)\r\n", Tile_Id, Block_Id,getDitherSettings);
				}
				if (getDitherSettings == 0){
					xil_printf("   ADC Tile%d ch%d Dither: %d (Dither Disabled)\r\n", Tile_Id, Block_Id,getDitherSettings);
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
* adcSetDither TBD
*
* @param	None
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void adcSetDither(u32 *cmdVals)
{
	XRFdc* RFdcInstPtr = &RFdcInst;
	int Status;
	u32 Tile_Id;
	u32 Block_Id;
	XRFdc_IPStatus ipStatus;
	XRFdc_BlockStatus blockStatus;
	u32 GetDither;
	u32 Dither;

	Tile_Id = cmdVals[0];
	Block_Id = cmdVals[1];
	Dither = cmdVals[2];

	// Calling this function gets the status of the IP
	XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);
	xil_printf("\n\r###############################################\r\n");
	if(XRFdc_IsADCBlockEnabled(RFdcInstPtr, Tile_Id, Block_Id)) {
		xil_printf("Set ADC Dither...\n\r");
		XRFdc_GetBlockStatus(RFdcInstPtr,XRFDC_ADC_TILE, Tile_Id, Block_Id, &blockStatus);
		//////////////////////////////////////////////////////////////////////////////
		// ADC Set Dither
		Status = XRFdc_SetDither(RFdcInstPtr, Tile_Id, Block_Id, Dither);
		if (Status != XST_SUCCESS) {
			xil_printf("XRFdc_SetDither() for ADC Tile%d ch%d failed.\n\r",Tile_Id,Block_Id);
			return;
		}

		Status = XRFdc_GetDither(RFdcInstPtr, Tile_Id, Block_Id, &GetDither);
		if (Status != XST_SUCCESS) {
			xil_printf("XRFdc_GetDither() for DAC Tile%d ch%d failed.\n\r",Tile_Id,Block_Id);
			return;
		}else{
			if (GetDither == 1){
				xil_printf("   ADC Tile%d ch%d Dither: %d (Dither Enabled)\r\n", Tile_Id, Block_Id,GetDither);
			}
			if (GetDither == 0){
				xil_printf("   ADC Tile%d ch%d Dither: %d (Dither Disabled)\r\n", Tile_Id, Block_Id,GetDither);
			}
		}

	} else{
		xil_printf("ADC Tile%d ch%d is not available.\n\r", Tile_Id, Block_Id);
	}
	xil_printf("###############################################\r\n\n");

	return;
}

