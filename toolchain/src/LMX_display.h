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

#ifndef __LMX_DISPLAY_H_
#define __LMX_DISPLAY_H_


#define LMX_OUTA_MUX_CHAN_DIV 0
#define LMX_OUTA_MUX_VCO      1
#define LMX_OUTA_MUX_PD       3

#define LMX_OUTB_MUX_CHAN_DIV 0
#define LMX_OUTB_MUX_VCO      1
#define LMX_OUTB_SYSREF       2
#define LMX_OUTB_MUX_PD       3


typedef struct lmx_reg_def_struct {
	unsigned int  mask;
	unsigned char shift;
	unsigned char offset;
	u32           addr;
} lmx_reg_def_t;

typedef enum{
	LMX_OSC_2X = 0,
	LMX_PLL_R_PRE,
	LMX_MULT,
	LMX_PLL_R,
	LMX_PLL_N_l,
	LMX_PLL_N_h,
	LMX_PLL_NUM_l,
	LMX_PLL_NUM_h,
	LMX_PLL_DEN_l,
	LMX_PLL_DEN_h,
	LMX_CHDIV,
	LMX_OUTA_MUX,
	LMX_OUTB_MUX,
	LMX_SYSREF_DIV_PRE,
	LMX_SYSREF_DIV,
	LMX_OUTA_PD,
	LMX_OUTB_PD,
} LMX_regNames_t;

typedef struct lmx_config_struct {

	char osc_doubler_multiplier;
	int pll_preR_div;
	int pll_multiplier;
	int pll_r_divider;
	int pll_n_divider;
	long int pll_fraction_numerator;
	long int pll_fraction_denominator;
	int channel_div;
	int sysref_pre_div;
	int sysref_div;

	long int Fpd_freq;
	long int VCO_freq;
	long int chandiv_freq;
	long int sysref_freq;
	long int RFoutA_freq;
	long int RFoutB_freq;

} lmx_config_t;


void LMX_intermediateDump(lmx_config_t *lmxInstPtr);
void LMX_SettingsInit(long int inFreq, const u32 *regdataSrc, lmx_config_t *lmxInstPtr);


#endif
