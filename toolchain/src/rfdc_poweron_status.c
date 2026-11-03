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
 * rfdc_poweron_status.c
 *
 *  Created on: Aug 9, 2019
 *      Author: jlantz
 */

/***************************** Include Files *********************************/
#include "xil_io.h"
#include "xil_types.h"
#include <stdio.h>
#include "xparameters.h"
#include "main.h"
#include "xrfdc.h"
#include "rfdc_poweron_status.h"
#include "cli.h"

/************************** Constant Definitions *****************************/

/**************************** Type Definitions *******************************/

/***************** Macros (Inline Functions) Definitions *********************/

/************************** Function Prototypes ******************************/

/************************** Variable Definitions *****************************/



/*****************************************************************************/
/**
*
* cli_cmd_func_mem_init Add functions from this file to CLI
*
* @param	None
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void cli_rfdc_poweron_status_init(void)
{
	static CMDSTRUCT cliCmds[] = {
		//000000000011111111112222    000000000011111111112222222222333333333
		//012345678901234567890123    012345678901234567890123456789012345678
    	{"################### Power-On Status ####################" , " "     , 0, *cmdComment   },
		{"rfdcPoweronStatus"       , "Display Power Status"                  , 0, *rfdcPoweronStatus},
		{" "                       , " "                                       , 0, *cmdComment   },
	};

	cli_addCmds(cliCmds, sizeof(cliCmds)/sizeof(cliCmds[0]));
}


/*****************************************************************************/
/**
*
* Power on status of the DAC's and ADC's
*
* @param	None
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void rfdcPoweronStatus (u32 *cmdVals) {
	u32 Tile_Id;
	XRFdc_IPStatus ipStatus;
	XRFdc* RFdcInstPtr = &RFdcInst;
	u32 val;
    XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);

	xil_printf("\r\n###############################################\r\n");
	xil_printf("The Power-on sequence step. 0xF is complete.\r\n");

	for ( Tile_Id=0; Tile_Id<=3; Tile_Id++) {
		if (ipStatus.DACTileStatus[Tile_Id].IsEnabled == 1) {
  //  		val = XRFdc_ReadReg16(RFdcInstPtr, XRFDC_DAC_TILE_CTRL_STATS_ADDR(Tile_Id), XRFDC_DAC_DEBUG_RST_OFFSET);
 //   		if(val & XRFDC_DBG_RST_CAL_MASK) {
   // 			xil_printf("  DAC Tile: %d NOT enabled.\r\n", Tile_Id);
  //  		} else {
    		    xil_printf("   DAC Tile%d Power-on Sequence Step: 0x%08x\r\n",Tile_Id,
    		    	Xil_In32(RFDC_BASE + 0x0000C + 0x04000 + Tile_Id * 0x4000));
   // 		}
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


	xil_printf("###############################################\r\n\n");


	return;
}


