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
 * rfdc_dsa_vop.c
 *
 *  Created on: 06/23/2020
 *      Author: jlantz
 */
/***************************** Include Files *********************************/
#include <stdio.h>
#include <stdlib.h>
#include "xil_io.h"
#include "xil_types.h"
#include "cli.h"
#include "xparameters.h"
#include "xrfdc.h"
#include "main.h"
#include "rfdc_dsa_vop.h"


/************************** Constant Definitions *****************************/

/**************************** Type Definitions *******************************/

/***************** Macros (Inline Functions) Definitions *********************/

/************************** Function Prototypes ******************************/
float mygetline(void);

/************************** Variable Definitions *****************************/


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

void cli_rfdcDSAVOP_init(void)
{
	static CMDSTRUCT cliCmds[] = {
		{"################ VOP and DSA commands ##################" , " " , 0, *cmdComment   },
		{"dacSetVOP"    , "<tile> <dac> <setting(uA)> - Set DAC VOP for Gen3", 3, *dacSetVOP},
		{"adcGetDSA"    , "- Get the ADC DSA for Gen3"      , 0, *adcGetDSA},
		{"adcSetDSA"    , "<tile> <adc> - Set the ADC DSA for Gen3"      , 2, *adcSetDSA},
		{" "            , " "                                  , 0, *cmdComment   },
	};

	cli_addCmds(cliCmds, sizeof(cliCmds)/sizeof(cliCmds[0]));
}

/*****************************************************************************/
/**
*
* mygetline
*
* @param	get line from console - Float Value
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
float mygetlinef()
{
	char line[10];
	int i=0;
	char mychar;
	float finalVal;

	while(1) {
		 mychar=inbyte();
		 if (mychar == 0x0a) continue;
		 if (mychar == 0x0d) break;
		 if(i>=8) break;
		 xil_printf("%c", mychar);
		 line[i++]=mychar;
	}

	line[i] = 0;
	finalVal = atof(&line[0]);

	return finalVal;
}


/*****************************************************************************/
/**
*
* Set the DAC VOP via API
*
* @param	None
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void dacSetVOP(u32 *cmdVals)
{

	u32 Tile_Id;
	u32 Block_Id;
	u32 uACurrent;
	XRFdc_IPStatus ipStatus;
	XRFdc* RFdcInstPtr = &RFdcInst;
	u32 Status;
	u32 OutputCurr;

	Tile_Id = cmdVals[0];
	Block_Id = cmdVals[1];
	uACurrent = cmdVals[2];

	// Calling this function gets the status of the IP
	XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);
	xil_printf("\n\r###############################################\r\n");

	if (RFdcInstPtr->RFdc_Config.IPType >= XRFDC_GEN3) {

		if(XRFdc_IsDACBlockEnabled(RFdcInstPtr, Tile_Id, Block_Id)) {

			// DAC Set Output Power
			Status = XRFdc_SetDACVOP(RFdcInstPtr,  Tile_Id, Block_Id, uACurrent);
			if (Status != XST_SUCCESS) {
				xil_printf("XRFdc_SetDACVOP() for DAC Tile%d ch%d failed.\n\r",Tile_Id,Block_Id);
				return;
			}
			else{
				Status = XRFdc_GetOutputCurr(RFdcInstPtr, Tile_Id, Block_Id, &OutputCurr);
				xil_printf("   DAC Tile%d ch%d VOP set to %d uA.\n\r",Tile_Id,Block_Id,OutputCurr);
			}
		}
		else{
			xil_printf("DAC Tile%d ch%d is not available.\n\r", Tile_Id, Block_Id);
		}
		}
	else{
		xil_printf("This command is for RFSoC Gen3 devices only.\n\r");
	}

		xil_printf("###############################################\r\n");
		return;
}

/*****************************************************************************/
/**
*
* Set the ADC DSA via API
*
* @param	None
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void adcSetDSA(u32 *cmdVals)
{

	u32 Tile_Id;
	u32 Block_Id;
	u32 Status;
	float Attenuation;
	float Attenuation_get;
	XRFdc_IPStatus ipStatus;
	XRFdc* RFdcInstPtr = &RFdcInst;
	XRFdc_DSA_Settings DSA_Settings;

	Tile_Id = cmdVals[0];
	Block_Id = cmdVals[1];

	xil_printf("Set Attenuation in dB to : ");
	Attenuation = mygetlinef();

	// Calling this function gets the status of the IP
	XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);
	xil_printf("\n\r###############################################\r\n");

	if (RFdcInstPtr->RFdc_Config.IPType >= XRFDC_GEN3) {

		if(XRFdc_IsADCBlockEnabled(RFdcInstPtr, Tile_Id, Block_Id)) {
			DSA_Settings.Attenuation = Attenuation;
			// ADC Set Attenuation
			Status = XRFdc_SetDSA(RFdcInstPtr,  Tile_Id, Block_Id, &DSA_Settings);
			if (Status != XST_SUCCESS) {
				xil_printf("XRFdc_SetDSA() for ADC Tile%d ch%d failed.\n\r",Tile_Id,Block_Id);
				return;
			}
			else{
				Status = XRFdc_GetDSA(RFdcInstPtr,  Tile_Id, Block_Id, &DSA_Settings);
				Attenuation_get = DSA_Settings.Attenuation;

				printf("   ADC Tile%d ch%d DSA set to %.1f dB.\n\r",Tile_Id,Block_Id,Attenuation_get);
			}
		}
		else{
			xil_printf("ADC Tile%d ch%d is not available.\n\r", Tile_Id, Block_Id);
		}
		}  // Gen1 or Gen2
	else{
		xil_printf("This command is for RFSoC Gen3 devices only.\n\r");
	}
		xil_printf("###############################################\r\n");
		return;
}


/*****************************************************************************/
/**
*
* Get the ADC DSA via API
*
* @param	None
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void adcGetDSA(u32 *cmdVals)
{
	u32 Tile_Id;
	u32 Block_Id;
	u32 Status;
	float Attenuation2;
	XRFdc_IPStatus ipStatus;
	XRFdc* RFdcInstPtr = &RFdcInst;

	XRFdc_DSA_Settings DSA_Settings;

	// Calling this function gets the status of the IP
	XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);

	xil_printf("\r\n###############################################\r\n");
	xil_printf("=== ADC DSA Report ===\n\r");

	for ( Tile_Id=0; Tile_Id<=3; Tile_Id++) {
    	if (ipStatus.ADCTileStatus[Tile_Id].IsEnabled == 1) {
			for ( Block_Id=0; Block_Id<=3; Block_Id++) {
				if (XRFdc_IsADCBlockEnabled(RFdcInstPtr, Tile_Id, Block_Id) != 0U) {
					if (RFdcInstPtr->RFdc_Config.IPType >= XRFDC_GEN3) {

						if(XRFdc_IsADCBlockEnabled(RFdcInstPtr, Tile_Id, Block_Id)) {

							// ADC Set Attenuation
							Status = XRFdc_GetDSA(RFdcInstPtr,  Tile_Id, Block_Id, &DSA_Settings);
							Attenuation2 = DSA_Settings.Attenuation;
							if (Status != XST_SUCCESS) {
								xil_printf("XRFdc_SetDSA() for ADC Tile%d ch%d failed.\n\r",Tile_Id,Block_Id);
								return;
							}
							else{
								printf("   ADC Tile%d ch%d DSA set to %.1f dB.\n\r",Tile_Id,Block_Id,Attenuation2);
							}
						}
						else{
							xil_printf("ADC Tile%d ch%d is not available.\n\r", Tile_Id, Block_Id);
						}
						}
					else{
						xil_printf("This command is for RFSoC Gen3 devices only.\n\r");
					}
    			}
    		}
		}
	}
	xil_printf("###############################################\r\n");

	return;
}


