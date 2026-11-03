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
/*****************************************************************************/
/**
*
* @file xrfclk.h
* @addtogroup xrfclk_v1_1
* @{
*
* Contains the API of the XRFclk middleware.
*
* <pre>
* MODIFICATION HISTORY:
*
* Ver   Who    Date     Changes
* ----- ---    -------- -----------------------------------------------
* 1.0   dc     07/21/19 Initial version
* 1.1   dc     11/21/19 Remove xil dependencies from linux build
*       dc     11/25/19 update LMX and LMK configs
*       dc     12/05/19 adjust LMX and LMK configs to a rftool needs
*
* </pre>
*
******************************************************************************/
#ifndef __XRFCLK_H_
#define __XRFCLK_H_

#ifdef __cplusplus
extern "C" {
#endif

#if !defined(XPS_BOARD_ZCU111) && !defined(XPS_BOARD_ZCU216)
#define XPS_BOARD_ZCU216
#endif

#if defined __BAREMETAL__
#include "xil_types.h"
#else
typedef unsigned char u8;
typedef unsigned int u32;
typedef int s32;
#define XST_SUCCESS 0L
#define XST_FAILURE 1L
#endif

#define RFCLK_LMX2594_1 0 /* I0 on MUX and SS3 on Bridge */
#define RFCLK_LMX2594_2 1 /* I1 on MUX and SS2 on Bridge */
#define RFCLK_LMK 2 /* I2 on MUX and SS1 on Bridge */
#ifdef XPS_BOARD_ZCU111
#define RFCLK_LMX2594_3 3 /* I3 on MUX and SS0 on Bridge */
#define RFCLK_CHIP_NUM 4
#define LMK_COUNT 26
#define LMK_FREQ_NUM 3 /* Number of LMK freq. configs */
#define LMX_ADC_NUM 17 /* Number of LMX ADC configs */
#define LMX_DAC_NUM 26 /* Number of LMX DAC configs */
#else
#define RFCLK_CHIP_NUM 3
#define LMK_COUNT 128//// 136 //128
#define LMK_FREQ_NUM 10 /* Number of LMK freq. configs */
#define LMX_ADC_NUM 38 /* Number of LMX ADC configs */
#define LMX_DAC_NUM 38 /* Number of LMX DAC configs */
#endif

#define LMX2594_COUNT 116
#define FREQ_LIST_STR_SIZE 16 /* Frequency string size */

#ifndef XPS_BOARD_ZCU111
typedef enum {
	LMX2594_FREQ_204M80,
	LMX2594_FREQ_245M76,
	LMX2594_FREQ_491M52,
	LMX2594_FREQ_1024M00,
	LMX2594_FREQ_1966M08,
	LMX2594_FREQ_2000M00,
	LMX2594_FREQ_2211M84,
	LMX2594_FREQ_2457M60,
	LMX2594_FREQ_2500M00,
	LMX2594_FREQ_3072M00,
	LMX2594_FREQ_3932M16,
	LMX2594_FREQ_4000M00,
	LMX2594_FREQ_4096M00,
	LMX2594_FREQ_4423M68,
	LMX2594_FREQ_4915M20,
	LMX2594_FREQ_5000M00,
	LMX2594_FREQ_5400M00,
	LMX2594_FREQ_5898M24,
	LMX2594_FREQ_6144M00,
	LMX2594_FREQ_6881M28,
	LMX2594_FREQ_7000M00,
	LMX2594_FREQ_7372M80,
	LMX2594_FREQ_7864M32,
	LMX2594_FREQ_8000M00,
	LMX2594_FREQ_8192M00,
	LMX2594_FREQ_8847M36,
	LMX2594_FREQ_9830M40,
	LMX2594_FREQ_10000M00,
	LMX2594_FREQ_10800M00,
	LMX2594_FREQ_300M00_PD,
	LMX2594_FREQ_300M00,
	LMX2594_FREQ_4000M00B,
	LMX2594_FREQ_2500M_312p5M,
	LMX2594_FREQ_5000M_312p5M,
	LMX2594_FREQ_10000M_625p0M,
	LMX2594_FREQ_5000M_625p0M,
	LMX2594_FREQ_9800M_612p5M,
	LMX2594_FREQ_4900M_612p5M,
} LMK_freq_idx_t;
#endif

u32 XRFClk_WriteReg(u32 ChipId, u32 Data);
u32 XRFClk_ReadReg(u32 ChipId, u32 *Data);
#if defined __BAREMETAL__ || defined XPS_BOARD_ZCU111
u32 XRFClk_Init();
#else
u32 XRFClk_Init(int GpioId);
#endif
void XRFClk_Close();
u32 XRFClk_ResetChip(u32 ChipId);
u32 XRFClk_SetConfigOnOneChipFromConfigId(u32 ChipId, u32 ConfigId);
u32 XRFClk_SetConfigOnOneChip(u32 ChipId, u32 *cfgData, u32 len);
u32 XRFClk_GetConfigFromOneChip(u32 ChipId, u32 *cfgData);
u32 XRFClk_SetConfigOnAllChipsFromConfigId(u32 ConfigId_LMK, u32 ConfigId_RF1,
#ifdef XPS_BOARD_ZCU111
					   u32 ConfigId_RF2, u32 ConfigId_RF3);
#else
					   u32 ConfigId_RF2);
#endif
u32 XRFClk_ControlOutputPortLMK(u32 PortId, u32 state);
u32 XRFClk_ConfigOutputDividerAndMUXOnLMK(u32 PortId, u32 DCLKoutX_DIV,
					  u32 DCLKoutX_MUX, u32 SDCLKoutY_MUX,
					  u32 SYSREF_DIV);

#ifdef __cplusplus
}
#endif

#endif
/** @} */
