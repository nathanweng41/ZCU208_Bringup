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
#include "rfdc_interpolation_decimation.h"


/************************** Constant Definitions *****************************/

/**************************** Type Definitions *******************************/

/***************** Macros (Inline Functions) Definitions *********************/

/************************** Function Prototypes ******************************/

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
void cli_DacAdcIntDec_init(void)
{
	static CMDSTRUCT cliCmds[] = {
		//000000000011111111112222    000000000011111111112222222222333333333
		//012345678901234567890123    012345678901234567890123456789012345678
		{"############### Interpolation/Decimation ###############" , " " , 0, *cmdComment   },
		{"adcDecimation"      , "- Report ADC Decimation"                   , 0, *adcGetDecimation},
		{"dacInterpolation"   , "- Report DAC Interpolation"                , 0, *dacGetInterpolation},
		{" "                       , " "                                  , 0, *cmdComment   },

	};

	cli_addCmds(cliCmds, sizeof(cliCmds)/sizeof(cliCmds[0]));
}




/*****************************************************************************/
/**
*
* ADC Decimation Report
*
* @param
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void adcGetDecimation(u32 *cmdVals)
{
	int Status;
	XRFdc* RFdcInstPtr = &RFdcInst;
	XRFdc_IPStatus ipStatus;
    u32 DecimationFactortest;
    int Tile_Id;
    int Block_Id;
	xil_printf("\r\n###############################################\r\n");

    // Calling this function gets the status of the IP
    XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);

	xil_printf("ADC Decimation Setting\r\n");
	for ( Tile_Id=0; Tile_Id<=3; Tile_Id++) {
		if (ipStatus.ADCTileStatus[Tile_Id].IsEnabled == 1) {
			for ( Block_Id=0; Block_Id<=3; Block_Id++) {
				if(XRFdc_IsADCBlockEnabled(RFdcInstPtr, Tile_Id, Block_Id)) {

					Status = XRFdc_GetDecimationFactor(RFdcInstPtr, Tile_Id, Block_Id, &DecimationFactortest);
					if (Status != XST_SUCCESS) {
						xil_printf("XRFdc_GetDecimationFactor() failed\r\n");
						return;
					}
				}
				if (ipStatus.ADCTileStatus[Tile_Id].IsEnabled == 1) {
					if(XRFdc_IsADCBlockEnabled(RFdcInstPtr, Tile_Id, Block_Id)) {
						xil_printf("    ADC Tile%d ch%d Decimation Factor:  %d\r\n",Tile_Id,Block_Id,DecimationFactortest);
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
* DAC Interpolation Report
*
* @param
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void dacGetInterpolation(u32 *cmdVals)
{
	int Status;
	XRFdc* RFdcInstPtr = &RFdcInst;
	XRFdc_IPStatus ipStatus;
    u32 InterpolationFactortest;
    int Tile_Id;
    int Block_Id;
	xil_printf("\r\n###############################################\r\n");

    // Calling this function gets the status of the IP
    XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);

	xil_printf("DAC Interpolation Setting\r\n");
	for ( Tile_Id=0; Tile_Id<=3; Tile_Id++) {

		if (ipStatus.DACTileStatus[Tile_Id].IsEnabled == 1) {
			for ( Block_Id=0; Block_Id<=3; Block_Id++) {
				if(XRFdc_IsDACBlockEnabled(RFdcInstPtr, Tile_Id, Block_Id)) {
					Status = XRFdc_GetInterpolationFactor(RFdcInstPtr, Tile_Id, Block_Id, &InterpolationFactortest);
					if (Status != XST_SUCCESS) {
						xil_printf("XRFdc_GetInterpolationFactor() failed\r\n");
						return;
					}
				}
				if (ipStatus.DACTileStatus[Tile_Id].IsEnabled == 1) {
					if(XRFdc_IsDACBlockEnabled(RFdcInstPtr, Tile_Id, Block_Id)) {
						xil_printf("    DAC Tile%d ch%d Interpolation Factor:  %d\r\n",Tile_Id,Block_Id,InterpolationFactortest);
					}
				}
			}
		}
	}

	xil_printf("###############################################\r\n\n");

    return;
}




