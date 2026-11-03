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
 * adcFreezeCal.c
 *
 *  Created on: 06/23/2020
 *      Author: jlantz
 */
/***************************** Include Files *********************************/
#include "xil_io.h"
#include "xil_types.h"
#include <stdio.h>
#include "cli.h"
#include "xparameters.h"
#include "main.h"
#include "xrfdc.h"
#include "adc_FreezeCal.h"



/************************** Constant Definitions *****************************/

/**************************** Type Definitions *******************************/

/***************** Macros (Inline Functions) Definitions *********************/

/************************** Function Prototypes ******************************/

/************************** Variable Definitions *****************************/

/************************** Function Definitions ******************************/


/*****************************************************************************/
/**
*
* cli_adcFreezeCalStatus_init Add functions from this file to CLI
*
* @param	None
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void cli_adcFreezeCalStatus_init(void)
{
	static CMDSTRUCT cliCmds[] = {
		{"################### ADC Calibration ####################" , " " , 0, *cmdComment   },
		{"adcFreezeCalStatus" , "- Freeze ADC calibration Status"         , 0, *adcFreezeCalStatus},
		{"adcSetFreezeCal"    , "- <tile> <adc> Set Freeze ADC cal"       , 2, *adcSetFreezeCal},
		{"adcSetUnFreezeCal"  , "- <tile> <adc> UnFreeze ADC cal"         , 2, *adcSetUnFreezeCal},
		{" "                       , " "                                  , 0, *cmdComment   },
	};

	cli_addCmds(cliCmds, sizeof(cliCmds)/sizeof(cliCmds[0]));
}

/*****************************************************************************/
/**
*
* adcFreezeCalStatus TBD
*
* @param	None
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void adcFreezeCalStatus (u32 *cmdVals)
{
	u32 Tile_Id;
	u32 Block_Id;
	XRFdc_IPStatus ipStatus;
	XRFdc* RFdcInstPtr = &RFdcInst;
	XRFdc_Cal_Freeze_Settings calFreezeSettings;

	Tile_Id = cmdVals[0];
	Block_Id = cmdVals[1];

	XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);
	xil_printf("\n\r###############################################\n\r");
	xil_printf("=== ADC Cal Freeze Report ===\n\r");

	for (Tile_Id=0; Tile_Id<=3; Tile_Id++) {
		for(Block_Id=0; Block_Id<=3; Block_Id++) {
			if(XRFdc_IsADCBlockEnabled(RFdcInstPtr, Tile_Id, Block_Id)) {
				XRFdc_GetCalFreeze(RFdcInstPtr, Tile_Id, Block_Id, &calFreezeSettings);
				if (calFreezeSettings.CalFrozen == 0){
					xil_printf("   ADC Tile%d ch%d Cal Frozen: %d (Not Frozen)\r\n", Tile_Id, Block_Id,calFreezeSettings.CalFrozen);
				}
				if (calFreezeSettings.CalFrozen  == 1){
					xil_printf("   ADC Tile%d ch%d Cal Frozen: %d (Frozen)\r\n", Tile_Id, Block_Id,calFreezeSettings.CalFrozen);
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
* Set Freeze Background Calibration TBD
*
* @param	None
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void adcSetFreezeCal (u32 *cmdVals)
{
	u32 Tile_Id;
	u32 Block_Id;
	XRFdc_IPStatus ipStatus;
	XRFdc* RFdcInstPtr = &RFdcInst;
	XRFdc_Cal_Freeze_Settings calFreezeSettings;

	Tile_Id = cmdVals[0];
	Block_Id = cmdVals[1];

	XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);
	xil_printf("\n\r###############################################\n\r");
	xil_printf("=== ADC Cal Freeze Report ===\n\r");

	if((XRFdc_IsADCBlockEnabled(RFdcInstPtr, Tile_Id, Block_Id) == 1) && \
					(Tile_Id < NUM_TILES) && (Block_Id < NUM_BLOCKS))
	{
		XRFdc_GetCalFreeze(RFdcInstPtr, Tile_Id, Block_Id, &calFreezeSettings);
		xil_printf("   ADC Tile%d ch%d Cal Freeze Status before command: %d\r\n", Tile_Id, Block_Id,calFreezeSettings.CalFrozen);
		calFreezeSettings.DisableFreezePin = 1;
		calFreezeSettings.FreezeCalibration = 1;
		XRFdc_SetCalFreeze(RFdcInstPtr, Tile_Id, Block_Id, &calFreezeSettings);
		XRFdc_GetCalFreeze(RFdcInstPtr, Tile_Id, Block_Id, &calFreezeSettings);
		sleep(1);
		XRFdc_GetCalFreeze(RFdcInstPtr, Tile_Id, Block_Id, &calFreezeSettings);
		xil_printf("   ADC Tile%d ch%d Cal Freeze Status after command: %d\r\n", Tile_Id, Block_Id,calFreezeSettings.CalFrozen);
	} else {
		xil_printf("ADC Tile%d ch%d is not available.\n\r", Tile_Id, Block_Id);
	}

	xil_printf("###############################################\r\n\n");

	return;
}

/*****************************************************************************/
/**
*
* Unset ADC Freeze Background Calibration TBD
*
* @param	None
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void adcSetUnFreezeCal (u32 *cmdVals)
{
	u32 Tile_Id;
	u32 Block_Id;
	XRFdc_IPStatus ipStatus;
	XRFdc* RFdcInstPtr = &RFdcInst;
	XRFdc_Cal_Freeze_Settings calFreezeSettings;

	Tile_Id = cmdVals[0];
	Block_Id = cmdVals[1];

	XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);
	xil_printf("\n\r###############################################\n\r");
	xil_printf("=== ADC Cal Freeze Report ===\n\r");

	if((XRFdc_IsADCBlockEnabled(RFdcInstPtr, Tile_Id, Block_Id) == 1) && \
					(Tile_Id < NUM_TILES) && (Block_Id < NUM_BLOCKS))
	{
		XRFdc_GetCalFreeze(RFdcInstPtr, Tile_Id, Block_Id, &calFreezeSettings);
		xil_printf("   ADC Tile%d ch%d Cal Freeze Status before command: %d\r\n", Tile_Id, Block_Id,calFreezeSettings.CalFrozen);
		calFreezeSettings.DisableFreezePin = 1;
		calFreezeSettings.FreezeCalibration = 0;
		XRFdc_SetCalFreeze(RFdcInstPtr, Tile_Id, Block_Id, &calFreezeSettings);
		XRFdc_GetCalFreeze(RFdcInstPtr, Tile_Id, Block_Id, &calFreezeSettings);
		sleep(1);
		XRFdc_GetCalFreeze(RFdcInstPtr, Tile_Id, Block_Id, &calFreezeSettings);
		xil_printf("   ADC Tile%d ch%d Cal Freeze Status after command: %d\r\n", Tile_Id, Block_Id,calFreezeSettings.CalFrozen);
	} else {
		xil_printf("ADC Tile%d ch%d is not available.\n\r", Tile_Id, Block_Id);
	}

	xil_printf("###############################################\r\n\n");

	return;
}

