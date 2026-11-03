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


#ifndef SRC_CMD_FUNC_DAC_H_   /* prevent circular inclusions */
#define SRC_CMD_FUNC_DAC_H_   /* by using protection macros */

// Specify which ADC tiles and DAC tiles to have on
// In the ZCU208 only one set of SAMTEC bullseye connectors (part no) are included; this runs the risk of having unterminated inputs and outputs
// Make sure to only define the tiles which are properly connected and terminated
#define ADC_224_225
//#define ADC_226_227
//#define DAC_228_229
#define DAC_230_231


/***************************** Include Files *********************************/
#include "xil_types.h"
#include "xrfdc.h"

/************************** Constant Definitions *****************************/

/**************************** Type Definitions *******************************/

/***************** Macros (Inline Functions) Definitions *********************/

/************************** Function Prototypes ******************************/

void cli_rfdc_cmd_init(void);

void dacDumpStatus(u32 *cmdVals);
void dacDumpRegs (u32 *cmdVals);
void adcDumpStatus(u32 *cmdVals);
void rfSetMixerFreqOptPrint(u32 type, u32 Tile_Id, u32 Block_Id, double newFreq, int printEnable);
void dacReset(u32 *cmdVals);
void adcReset(u32 *cmdVals);
void dacResetAll(u32 *cmdVals);
void adcResetAll(u32 *cmdVals);
void dacCurrent(u32 *cmdVals);
void dacSetVOP(u32 *cmdVals);
void dacSetNCO(u32 *cmdVals);
void adcSetDSA(u32 *cmdVals);
void adcSetNCO(u32 *cmdVals);
void adcGetDSA(u32 *cmdVals);
void rfdcReady (u32 *cmdVals);
void rfdcShutdown (u32 *cmdVals);
void rfdcStartup (u32 *cmdVals);
void rfdcPowerDownTiles (u32 *cmdVals);
void rfdcPowerOnTiles (u32 *cmdVals);
void adcDumpRegs (u32 *cmdVals);
void RFdcCheckAxisWidth(XRFdc *RFdcInstPtr, u32 DacExpectedBits, u32 AdcExpectedBits);


/************************** Variable Definitions *****************************/

/************************** Function Definitions ******************************/


#endif /* SRC_CMD_FUNC_DAC_H_ */


