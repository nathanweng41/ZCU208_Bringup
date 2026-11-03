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
//#include "xil_types.h"
#include "xil_io.h"
#include <stdio.h>
#include "cli.h"
#include "xparameters.h"
#include "main.h"
#include "cmd_func_mem.h"

/************************** Constant Definitions *****************************/


/**************************** Type Definitions *******************************/

/***************** Macros (Inline Functions) Definitions *********************/

/************************** Function Prototypes ******************************/

/************************** Variable Definitions *****************************/

/************************** Function Definitions ******************************/


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
void cli_cmd_func_mem_init(void)
{
	static CMDSTRUCT cliCmds[] = {
		//000000000011111111112222    000000000011111111112222222222333333333
		//012345678901234567890123    012345678901234567890123456789012345678
		{"################ Memory Write and Reads ################" , " "      , 0, *cmdComment   },
		{"memwrite"                , "<addr> <value>"                          , 2, *memwrite     },
		{"memread"                 , "<addr>"                                  , 1, *memread      },
		{"rfwrite"                 , "<offset> <value>"                        , 2, *dacwrite     },
		{"rfread"                  , "<offset>"                                , 1, *dacread      },
		{" "                       , " "                                       , 0, *cmdComment   },
	};

	cli_addCmds(cliCmds, sizeof(cliCmds)/sizeof(cliCmds[0]));
}

/*****************************************************************************/
/**
*
* Memwrite function for command interface
*
* @param	cmdVals[0]=addr cmdVals[1]=value
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void memwrite(u32 *cmdVals) {
	Xil_Out32(cmdVals[0],cmdVals[1]);
}


/*****************************************************************************/
/**
*
* Memread function for command interface
*
* @param	cmdVals[0]=addr
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void memread(u32 *cmdVals) {
	xil_printf("addr: 0x%08x data: 0x%08x\n\r", cmdVals[0], Xil_In32(cmdVals[0]));
}


/*****************************************************************************/
/**
*
* Memwrite function for command interface
*
* @param	cmdVals[0]=offset cmdVals[1]=value
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void dacwrite(u32 *cmdVals) {
	if(cmdVals[0] > 0x23FFF) {
		xil_printf("rfdc_write: offset too large\r\n");
	} else {
		Xil_Out32(RFDC_BASE + cmdVals[0],cmdVals[1]);
	}
}


/*****************************************************************************/
/**
*
* Memread function for command interface
*
* @param	cmdVals[0]=offset
*
* @return	None
*
* @note		TBD
*
******************************************************************************/
void dacread(u32 *cmdVals) {
	if(cmdVals[0] > 0x23FFF) {
		xil_printf("rfdc_read: offset too large\r\n");
	} else {
		xil_printf("addr: 0x%08x rfdc_read: 0x%08x\n\r", RFDC_BASE + cmdVals[0], Xil_In32(RFDC_BASE + cmdVals[0]));
	}
}





