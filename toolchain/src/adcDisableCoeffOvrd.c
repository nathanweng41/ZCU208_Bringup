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
 * adcDisableCoeffOvrd.c
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
#include "adcDisableCoeffOvrd.h"


/************************** Constant Definitions *****************************/

/**************************** Type Definitions *******************************/

/***************** Macros (Inline Functions) Definitions *********************/

/************************** Function Prototypes ******************************/

/************************** Variable Definitions *****************************/

/************************** Function Definitions ******************************/



/*****************************************************************************/
/**
*
* cli_adcDisableCoeffOvrd_init Add functions from this file to CLI
*
* @param	None
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void cli_adcDisableCoeffOvrd_init(void)
{
	static CMDSTRUCT cliCmds[] = {
		{"adcDisableCoeffOvrd", "- <tile> <adc> - Disable Coeff Ovrd"     , 2, *adcDisableCoeffOvrd},
		{" "                       , " "                                  , 0, *cmdComment   },

	};

	cli_addCmds(cliCmds, sizeof(cliCmds)/sizeof(cliCmds[0]));
}

/*****************************************************************************/
/**
*
* adcDisableCoeffOvrd TBD
*
* @param	None
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void adcDisableCoeffOvrd (u32 *cmdVals)
{
	u32 Tile_Id;
	u32 Block_Id;
	u32 Status = XRFDC_FAILURE;
	XRFdc_IPStatus ipStatus;
	XRFdc* RFdcInstPtr = &RFdcInst;

	Tile_Id = cmdVals[0];
	Block_Id = cmdVals[1];

	XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);
	xil_printf("\n\r###############################################\n\r");
	xil_printf("   Disable Coefficients Override for ADC Tile%d ch%d\n\r",Tile_Id,Block_Id);
	xil_printf("      - This should be run to re enable real time calibration \n\r");
	xil_printf("        after loading saved calibration coefficients.    \n\r");

	if(XRFdc_IsADCBlockEnabled(RFdcInstPtr, Tile_Id, Block_Id) == 1) {

		// Disable Cal Coefficients Override for OCB1
		Status = XRFdc_DisableCoefficientsOverride(RFdcInstPtr, Tile_Id, Block_Id,XRFDC_CAL_BLOCK_OCB1);
		if (Status != XRFDC_SUCCESS) {
			xil_printf("   OCB1 Disable Coefficients Override error. \r\n");
			return;
		} else {
			xil_printf("   OCB1 Disable Coefficients Override complete. \r\n");
		}

		// Disable Cal Coefficients Override for OCB2
		Status = XRFdc_DisableCoefficientsOverride(RFdcInstPtr, Tile_Id, Block_Id,XRFDC_CAL_BLOCK_OCB2);
		if (Status != XRFDC_SUCCESS) {
			xil_printf("   OCB2 Disable Coefficients Override error. \r\n");
			return;
		} else {
			xil_printf("   OCB2 Disable Coefficients Override complete. \r\n");
		}

		// Disable Cal Coefficients Override for GCB
		Status = XRFdc_DisableCoefficientsOverride(RFdcInstPtr, Tile_Id, Block_Id,XRFDC_CAL_BLOCK_GCB);
		if (Status != XRFDC_SUCCESS) {
			xil_printf("   GCB Disable Coefficients Override error. \r\n");
			return;
		} else {
			xil_printf("   GCB Disable Coefficients Override complete. \r\n");
		}

		// Disable Cal Coefficients Override for TSCB
		Status = XRFdc_DisableCoefficientsOverride(RFdcInstPtr, Tile_Id, Block_Id,XRFDC_CAL_BLOCK_TSCB);
		if (Status != XRFDC_SUCCESS) {
			xil_printf("   TSCB Disable Coefficients Override error. \r\n");
			return;
		} else {
			xil_printf("   TSCB Disable Coefficients Override complete. \r\n");
		}

	} else {
		(xil_printf("Tile%d Ch%d is not available.\n\r",Tile_Id,Block_Id ));
	}

	xil_printf("###############################################\r\n\n");

	return;
}

