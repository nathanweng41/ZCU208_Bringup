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


// add these lines to the appropriate location in the cmd_globals.c file
// #include "rfdc_nyquistzone.h"
// {"rfdcNyquistZone"    , "- Display Nyquist Zone for all tiles"    , 0, *rfdcNyquistZone},


/***************************** Include Files *********************************/
#include "xil_io.h"
#include "xil_types.h"
#include <stdio.h>
#include "cli.h"
#include "xparameters.h"
#include "main.h"
#include "xrfdc.h"
#include "rfdc_nyquistzone.h"

/************************** Constant Definitions *****************************/

/**************************** Type Definitions *******************************/

/***************** Macros (Inline Functions) Definitions *********************/

/************************** Function Prototypes ******************************/

/************************** Variable Definitions *****************************/


/*****************************************************************************/
/**
*
* cli_rfdc_nyquistzone_init Add functions from this file to CLI
*
* @param	None
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void cli_rfdcNyquistzone_init(void)
{
	static CMDSTRUCT cliCmds[] = {
		//000000000011111111112222    000000000011111111112222222222333333333
		//012345678901234567890123    012345678901234567890123456789012345678
		{"#################### Nyquist Zone ######################" , " "     , 0, *cmdComment   },
		{"rfdcNyquistZone"    , "- Display Nyquist Zone for all tiles"        , 0, *rfdcNyquistZone},
		{"dacSetNyquistZone"  , "- <tile> <dac> <zone> Set Nyquist Zone"      , 3, *dacSetNyquistZone},
		{"adcSetNyquistZone"  , "- <tile> <adc> <zone> Set Nyquist Zone"      , 3, *adcSetNyquistZone},
		{" "                       , " "                                      , 0, *cmdComment   },

	};

	cli_addCmds(cliCmds, sizeof(cliCmds)/sizeof(cliCmds[0]));
}


/*****************************************************************************/
/**
*
* rfdcNyquistZone TBD
*
* @param	None
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void rfdcNyquistZone(u32 *cmdVals)
{
	XRFdc* RFdcInstPtr = &RFdcInst;
	int Status;
	u32 Tile_Id;
	u32 Block_Id;
	XRFdc_IPStatus ipStatus;
	XRFdc_BlockStatus blockStatus;
	u32 GetNyquistZone;



	// Calling this function gets the status of the IP
	XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);
	xil_printf("\n\r###############################################\r\n");
	xil_printf("=== DAC Nyquist Zone Report ===\n\r");



	for (Tile_Id=0; Tile_Id<=3; Tile_Id++) {
		if (ipStatus.DACTileStatus[Tile_Id].IsEnabled == 1) {
			for(Block_Id=0; Block_Id<=3; Block_Id++) {
				if(XRFdc_IsDACBlockEnabled(RFdcInstPtr, Tile_Id, Block_Id)) {
					XRFdc_GetBlockStatus(RFdcInstPtr, XRFDC_DAC_TILE, Tile_Id, Block_Id, &blockStatus);

					//////////////////////////////////////////////////////////////////////////////
					// DAC Nyquist Zone
					Status = XRFdc_GetNyquistZone(RFdcInstPtr, XRFDC_DAC_TILE, Tile_Id, Block_Id, &GetNyquistZone);
					if (Status != XST_SUCCESS) {
						xil_printf("XRFdc_GetNyquistZone() for DAC Tile%d ch%d failed.\n\r",Tile_Id,Block_Id);
						return;
					}

					XRFdc_GetBlockStatus(RFdcInstPtr, XRFDC_DAC_TILE, Tile_Id, Block_Id, &blockStatus);
					printf("   DAC Tile%d ch%d Nyquist Zone: %d",Tile_Id,Block_Id,GetNyquistZone);
					printf(" - Sampling Frequency: %f GHz.\n\r", blockStatus.SamplingFreq);
				}
			}
		}
	}


	xil_printf("=== ADC Nyquist Zone Report ===\n\r");


	for (Tile_Id=0; Tile_Id<=3; Tile_Id++) {
		if (ipStatus.ADCTileStatus[Tile_Id].IsEnabled == 1) {

			for(Block_Id=0; Block_Id<=3; Block_Id++) {
				if(XRFdc_IsADCBlockEnabled(RFdcInstPtr, Tile_Id, Block_Id)) {
					XRFdc_GetBlockStatus(RFdcInstPtr, XRFDC_ADC_TILE, Tile_Id, Block_Id, &blockStatus);

					//////////////////////////////////////////////////////////////////////////////
					// DAC Nyquist Zone
					Status = XRFdc_GetNyquistZone(RFdcInstPtr, XRFDC_ADC_TILE, Tile_Id, Block_Id, &GetNyquistZone);
					if (Status != XST_SUCCESS) {
						xil_printf("XRFdc_GetNyquistZone() for ADC Tile%d ch%d failed.\n\r",Tile_Id,Block_Id);
						return;
					}

					XRFdc_GetBlockStatus(RFdcInstPtr, XRFDC_ADC_TILE, Tile_Id, Block_Id, &blockStatus);
					printf("   ADC Tile%d ch%d Nyquist Zone: %d",Tile_Id,Block_Id,GetNyquistZone);
					printf(" - Sampling Frequency: %f GHz.\n\r", blockStatus.SamplingFreq);
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
* dacSetNyquistZone TBD
*
* @param	None
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void dacSetNyquistZone(u32 *cmdVals)
{
	XRFdc* RFdcInstPtr = &RFdcInst;
	int Status;
	u32 Tile_Id;
	u32 Block_Id;
	XRFdc_IPStatus ipStatus;
	XRFdc_BlockStatus blockStatus;
	u32 GetNyquistZone;
	u32 Nyquist_Zone;

	Tile_Id = cmdVals[0];
	Block_Id = cmdVals[1];
	Nyquist_Zone = cmdVals[2];

	// Calling this function gets the status of the IP
	XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);
	xil_printf("\n\r###############################################\r\n");
	if(XRFdc_IsDACBlockEnabled(RFdcInstPtr, Tile_Id, Block_Id)) {
		xil_printf("Set DAC Nyquist zone...\n\r");
		XRFdc_GetBlockStatus(RFdcInstPtr, XRFDC_DAC_TILE, Tile_Id, Block_Id, &blockStatus);

		//////////////////////////////////////////////////////////////////////////////
		// DAC Nyquist Zone
		Status = XRFdc_SetNyquistZone(RFdcInstPtr, XRFDC_DAC_TILE, Tile_Id, Block_Id, Nyquist_Zone);
		if (Status != XST_SUCCESS) {
			xil_printf("XRFdc_SetNyquistZone() for DAC Tile%d ch%d failed.\n\r",Tile_Id,Block_Id);
			return;
		}

		Status = XRFdc_GetNyquistZone(RFdcInstPtr, XRFDC_DAC_TILE, Tile_Id, Block_Id, &GetNyquistZone);
		if (Status != XST_SUCCESS) {
			xil_printf("XRFdc_GetNyquistZone() for DAC Tile%d ch%d failed.\n\r",Tile_Id,Block_Id);
			return;
		}

		XRFdc_GetBlockStatus(RFdcInstPtr, XRFDC_DAC_TILE, Tile_Id, Block_Id, &blockStatus);
		printf("   DAC Tile%d ch%d Nyquist Zone: %d",Tile_Id,Block_Id,GetNyquistZone);
		printf(" - Sampling Frequency: %f GHz.\n\r", blockStatus.SamplingFreq);
	} else{
		xil_printf("DAC Tile%d ch%d is not available.\n\r", Tile_Id, Block_Id);
	}

	xil_printf("###############################################\r\n\n");

	return;
}


/*****************************************************************************/
/**
*
* adcSetNyquistZone TBD
*
* @param	None
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void adcSetNyquistZone(u32 *cmdVals)
{
	XRFdc* RFdcInstPtr = &RFdcInst;
	int Status;
	u32 Tile_Id;
	u32 Block_Id;
	XRFdc_IPStatus ipStatus;
	XRFdc_BlockStatus blockStatus;
	u32 GetNyquistZone;
	u32 Nyquist_Zone;

	Tile_Id = cmdVals[0];
	Block_Id = cmdVals[1];
	Nyquist_Zone = cmdVals[2];

	// Calling this function gets the status of the IP
	XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);
	xil_printf("\n\r###############################################\r\n");
	if(XRFdc_IsADCBlockEnabled(RFdcInstPtr, Tile_Id, Block_Id)) {
		xil_printf("Set ADC Nyquist zone...\n\r");
		XRFdc_GetBlockStatus(RFdcInstPtr, XRFDC_ADC_TILE, Tile_Id, Block_Id, &blockStatus);
		//////////////////////////////////////////////////////////////////////////////
		// ADC Nyquist Zone
		Status = XRFdc_SetNyquistZone(RFdcInstPtr, XRFDC_ADC_TILE, Tile_Id, Block_Id, Nyquist_Zone);
		if (Status != XST_SUCCESS) {
			xil_printf("XRFdc_SetNyquistZone() for ADC Tile%d ch%d failed.\n\r",Tile_Id,Block_Id);
			return;
		}

		Status = XRFdc_GetNyquistZone(RFdcInstPtr, XRFDC_ADC_TILE, Tile_Id, Block_Id, &GetNyquistZone);
		if (Status != XST_SUCCESS) {
			xil_printf("XRFdc_GetNyquistZone() for DAC Tile%d ch%d failed.\n\r",Tile_Id,Block_Id);
			return;
		}

		XRFdc_GetBlockStatus(RFdcInstPtr, XRFDC_ADC_TILE, Tile_Id, Block_Id, &blockStatus);
		printf("   ADC Tile%d ch%d Nyquist Zone: %d",Tile_Id,Block_Id,GetNyquistZone);
		printf(" - Sampling Frequency: %f GHz.\n\r", blockStatus.SamplingFreq);
	} else{
		xil_printf("ADC Tile%d ch%d is not available.\n\r", Tile_Id, Block_Id);
	}
	xil_printf("###############################################\r\n\n");

	return;
}

