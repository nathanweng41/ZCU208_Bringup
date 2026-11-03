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
 *  Created on: Aug 10, 2019
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
#include "adcGetCalCoefficients.h"


/************************** Constant Definitions *****************************/

/**************************** Type Definitions *******************************/

/***************** Macros (Inline Functions) Definitions *********************/

/************************** Function Prototypes ******************************/
void displayCoeff(XRFdc_Calibration_Coefficients *CoeffPtr);

/************************** Variable Definitions *****************************/

/************************** Function Definitions ******************************/


/*****************************************************************************/
/**
*
* cli_adcGetCalCoefficients_init Add functions from this file to CLI
*
* @param	None
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void cli_adcGetCalCoefficients_init(void)
{
	static CMDSTRUCT cliCmds[] = {
		{"adcGetCalCoeff"     , "- <tile> <adc> Get Cal Coeff for ch"     , 2, *adcGetCalCoeff},
	};

	cli_addCmds(cliCmds, sizeof(cliCmds)/sizeof(cliCmds[0]));
}


/*****************************************************************************/
/**
*
* adcGetCalCoeff TBD
*
* @param	None
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void adcGetCalCoeff (u32 *cmdVals)
{
	u32 Tile_Id;
	u32 Block_Id;
	XRFdc_IPStatus ipStatus;
	XRFdc* RFdcInstPtr = &RFdcInst;
	XRFdc_Calibration_Coefficients calCoefficients;

	Tile_Id = cmdVals[0];
	Block_Id = cmdVals[1];

    XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);
	xil_printf("\n\r###############################################\n\r");
	xil_printf("=== ADC Cal Coefficients Report ===\n\r");

	if(XRFdc_IsADCBlockEnabled(RFdcInstPtr, Tile_Id, Block_Id) == 1) {

		XRFdc_GetCalCoefficients(RFdcInstPtr, Tile_Id, Block_Id,XRFDC_CAL_BLOCK_OCB1, &calCoefficients);
		xil_printf("   ADC Tile%d ch%d OCB1 Cal Coefficients: \r\n", Tile_Id, Block_Id);
		displayCoeff(&calCoefficients);

		XRFdc_GetCalCoefficients(RFdcInstPtr, Tile_Id, Block_Id,XRFDC_CAL_BLOCK_OCB2, &calCoefficients);
		xil_printf("   ADC Tile%d ch%d OCB2 Cal Coefficients: \r\n", Tile_Id, Block_Id);
		displayCoeff(&calCoefficients);

		XRFdc_GetCalCoefficients(RFdcInstPtr, Tile_Id, Block_Id,XRFDC_CAL_BLOCK_GCB, &calCoefficients);
		xil_printf("   ADC Tile%d ch%d GCB Cal Coefficients: \r\n", Tile_Id, Block_Id);
		displayCoeff(&calCoefficients);

		XRFdc_GetCalCoefficients(RFdcInstPtr, Tile_Id, Block_Id,XRFDC_CAL_BLOCK_TSCB, &calCoefficients);
		xil_printf("   ADC Tile%d ch%d TSCB Cal Coefficients: \r\n", Tile_Id, Block_Id);
		displayCoeff(&calCoefficients);

	} else {
			(xil_printf("Tile%d Ch%d is not available.\n\r",Tile_Id,Block_Id ));
	}

	xil_printf("###############################################\r\n\n");

	return;
}


/*****************************************************************************/
/**
*
* displayCoeff TBD
*
* @param	None
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void displayCoeff(XRFdc_Calibration_Coefficients *CoeffPtr)
{
	xil_printf("      Coeff0: 0x%08x : %11d\r\n", CoeffPtr->Coeff0, CoeffPtr->Coeff0);
	xil_printf("      Coeff1: 0x%08x : %11d\r\n", CoeffPtr->Coeff1, CoeffPtr->Coeff1);
	xil_printf("      Coeff2: 0x%08x : %11d\r\n", CoeffPtr->Coeff2, CoeffPtr->Coeff2);
	xil_printf("      Coeff3: 0x%08x : %11d\r\n", CoeffPtr->Coeff3, CoeffPtr->Coeff3);
	xil_printf("      Coeff4: 0x%08x : %11d\r\n", CoeffPtr->Coeff4, CoeffPtr->Coeff4);
	xil_printf("      Coeff5: 0x%08x : %11d\r\n", CoeffPtr->Coeff5, CoeffPtr->Coeff5);
	xil_printf("      Coeff6: 0x%08x : %11d\r\n", CoeffPtr->Coeff6, CoeffPtr->Coeff6);
	xil_printf("      Coeff7: 0x%08x : %11d\r\n", CoeffPtr->Coeff7, CoeffPtr->Coeff7);

	return;
}



