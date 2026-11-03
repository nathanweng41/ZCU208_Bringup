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

#ifndef __LMK_DISPLAY_H_
#define __LMK_DISPLAY_H_


// PLL1 VCXO freq is fixed to external VCXO freq for zcu216
#define VCXO_FREQ 160000000

#define LMK_PLL2_NCLK_MUX_PLL2_P  0
#define LMK_FB_MUX_DCLKout6       0
#define LMK_FB_MUX_DCLKout8       1
#define LMK_FB_MUX_SYSREF_DIVIDER 2
#define LMK_FB_MUX_EXTERNAL       3
#define LMK_PLL1_NCLK_MUX_OSCIN   0

#define LMK_CLKin_SEL_MODE_CLKIN0_MANUAL 0
#define LMK_CLKin_SEL_MODE_CLKIN1_MANUAL 1
#define LMK_CLKin_SEL_MODE_CLKIN2_MANUAL 2
#define LMK_CLKin_SEL_MODE_PIN_SEL_MODE  3
#define LMK_CLKin_SEL_MODE_AUTO_MODE     4

#define SCLK_SRC_VC0_MUX 0
#define SCLK_SRC_SYSREF  1


typedef struct reg_def_struct {
	unsigned char mask;
	unsigned char shift;
	unsigned char offset;
	u32           addr;
} reg_def_t;

typedef enum {
	LMK_DCLKoutX_1_PD = 0 ,
	LMK_DCLKoutx_FMT  ,
	LMK_DCLKoutX_MUX  ,
	LMK_DCLKoutX_DIV  ,
	LMK_SDCLKoutY_PD ,
	LMK_SDCLKoutY_FMT,
	LMK_SDCLKoutY_MUX,
	LMK_SYSREF_DIV_h,
	LMK_SYSREF_DIV_l,
	LMK_PLL2_N_h,
	LMK_PLL2_N_m,
	LMK_PLL2_N_l,
	LMK_PLL2_NCLK_MUX,
	LMK_FB_MUX_EN,
	LMK_FB_MUX,
	LMK_PLL2_R_h,
	LMK_PLL2_R_l,
	LMK_PLL2_REF_2X_EN,
	LMK_PLL1_NCLK_MUX,
	LMK_PLL1_N_h,
	LMK_PLL1_N_l,
	LMK_CLKin_SEL_MODE,
	LMK_CLKin0_R_h,
	LMK_CLKin0_R_l,
	LMK_CLKin1_R_h,
	LMK_CLKin1_R_l,
	LMK_CLKin2_R_h,
	LMK_CLKin2_R_l,
	LMK_CLKin0_EN,
	LMK_CLKin1_EN,
	LMK_CLKin2_EN,
	LMK_VCO_MUX,
	LMK_PLL2_P,
} LMK_regNames_t;


typedef struct lmk_clkout_struct {
	unsigned char dclk_pwrdwn;
	unsigned char sclk_pwrdwn;
	unsigned char sclk_src;
	int           dclk_div;
	int           sclk_div;

	long int      dclk_freq;
	long int      sclk_freq;
} lmk_clkout_t;


typedef struct lmk_clkin_struct {
	unsigned char en;
	int           div;
	long int      freq;
} lmk_clkin_t;


typedef struct lmk_config_struct {
	int sysref_div;

	int pll1_n_divider;
	int pll2_n_prescaler;
	int pll2_n_divider;
	int pll2_r_divider;
	int pll2_doubler;

	lmk_clkin_t   clkin[3];
	lmk_clkout_t  clkout[7];
	int clkin_sel_mode;

	long int PLL2_Phase_Detector_Freq;
	long int PLL2_vco_fdbk_div;
	long int PLL1_Phase_Detector_Freq;
	long int PLL2_VCO_freq;
	long int sysref_freq;

} lmk_config_t;


void LMK_clkinAndPLLInit(const u32 *regdataSrc, lmk_config_t *lmkInstPtr);
void LMK_sysrefInit(const u32 *regdataSrc, lmk_config_t *lmkInstPtr);
void LMK_clkoutCfgInit(const u32 *regdataSrc, lmk_config_t *lmkInstPtr);
void LMK_intermediateDump(lmk_config_t *lmkInstPtr);
void LMK_init(const u32 *regdataSrc, lmk_config_t *lmkInstPtr);
void LMK_clkoutFreqInit(lmk_config_t *lmkInstPtr);


#endif
