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
 * cli.h
 *
 */

#ifndef SRC_CLI_H_   /* prevent circular inclusions */
#define SRC_CLI_H_   /* by using protection macros */

/***************************** Include Files *********************************/
#include "xil_types.h"

/******************** Constant Definitions **********************************/
//maximum number of values for a command
#define MAX_CMD_VALS    7
#define CMD_STRING_LEN 56
#define CMD_HELP_LEN   56

// Max cli command line length
#define LINEMAX 81

// Max number of cli command table indexes
#define TBL_PTR_MAX 100



/**************************** Type Definitions *******************************/

//cmd interface
typedef struct cmdStruct {
	char cmdString[CMD_STRING_LEN];
	char cmdHelp[CMD_HELP_LEN];
	unsigned char valCnt;
	void (*cmdFunc)();
} CMDSTRUCT;

//cli cmd table structure
typedef struct tblStruct {
	CMDSTRUCT *cmdPointer;
	int cmdCount;
} TBLSTRUCT;

/***************** Macros (Inline Functions) Definitions *********************/

/************************** Variable Definitions *****************************/

extern u32 cmdVals[MAX_CMD_VALS];
extern CMDSTRUCT cmdtab[];
extern unsigned char numCmdVals;
extern int cmdExitVal;

/************************** Function Prototypes ******************************/

void cmdComment(void);		//null command

void cli_init(void);
void cli_addCmds(CMDSTRUCT *cmds2add, int numCmds);
void cli_cpyCmds(CMDSTRUCT *cmds2add, CMDSTRUCT *cmdsTable, int curCliCmds, int numCmds);

int my_sscanf(char *tokenPtr, u32 *value);
char* getAndParseInput( void );
void doHelp(void);
int cmdParseAndRun( void );
void doExit(void);

u8 myChar_getRx(u32 BaseAddress);
int myChar_checkRx(u32 BaseAddress);

char *my_strcpy(char *DestPtr, const char *SrcPtr);
char * my_strcat(char* Str1Ptr, const char* Str2Ptr);

#endif /* SRC_CLI_H_ */

