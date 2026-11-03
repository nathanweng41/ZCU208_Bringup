
/***************************** Include Files *********************************/
#include "main.h"
#include "sleep.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "xparameters.h"
#include "xstatus.h"
#include <stdarg.h>
#include <stdio.h>

#include "LMK_display.h"
#include "LMX_display.h"
#include "uram_play_cap.h"
#include "xrfclk.h"
#include "xrfdc.h"


#include "cli.h"
#include <metal/log.h>
#include <metal/sys.h>

// Includes for user added CLI functions used in this file
#include "adc_FreezeCal.h"
#include "cmd_func_mem.h"
#include "rfdc_cmd.h"
#include "rfdc_interpolation_decimation.h"
#include "rfdc_nyquistzone.h"
#include "rfdc_poweron_status.h"

//#include "rfdc_dsa_vop.h"
//#include "dac_waves.h"
#include "adcDisableCoeffOvrd.h"
#include "adcGetCalCoefficients.h"
#include "adcLoadCalCoefficients.h"
#include "adcSaveCalCoefficients.h"
#include "adcThresholds.h"
#include "adc_dither.h"
#include "rfdc_mts.h"

//#include "rfdc_interrupts.h"
//#include "rfdc_LinkCoupling.h"

/******************** Constant Definitions **********************************/
#define ENABLE_METAL_PRINTS

//#define URAM_PLAY_BASE XPAR_AXI_BRAM_CTRL_0_BASEADDR

#define GPIO_FIR_BYPASS_MUX XPAR_HIER_MODULATION_CAPTURE_AXI_GPIO_BYPASS_FIR_M10_BASEADDR
#define GPIO_FIR_BYPASS_MUX2 XPAR_HIER_MODULATION_CAPTURE2_AXI_GPIO_BYPASS_FIR_M10_BASEADDR
#define GPIO_RRC_BYPASS_MUX XPAR_AXI_GPIO_RRC_BYPASS1_BASEADDR
#define GPIO_RRC_BYPASS_MUX2 XPAR_AXI_GPIO_RRC_BYPASS2_BASEADDR

// FIR bypass selection
// 0 = FIR enabled
// 1 = FIR bypassed
#define FIR_BYPASS 1

// PLL debug defines. Will print all calculated values
#undef LMK_DEBUG
#undef LMX_DEBUG

/**************************** Type Definitions *******************************/

/***************** Macros (Inline Functions) Definitions *********************/

/************************** Function Prototypes ******************************/

void my_metal_default_log_handler(enum metal_log_level level,
                                  const char *format, ...);

static int resetAllClk104(void);
void reverse32bArray(u32 *src, int size);
void printCLK104_settings(void);

static int readLMKRegister( u16 regAddr, u8 *regValue );
static void debugLMKJ10(void);

/************************** Variable Definitions *****************************/

// VT100 esc sequences
char CHAR_ATTRIB_OFF[5] = "\x1B[0m";
char BOLD_ON[5] = "\x1B[1m";
char UNDERLINE_ON[5] = "\x1B[4m";
char BLINK_ON[5] = "\x1B[5m";
char REVERSE_ON[5] = "\x1B[5m";

char CLR_SCREEN[5] = "\x1B[2J";

// data buffer used for reading PLL registers
static u32 data[256];

const char clkoutBrdNames[][18] = {
    "RFIN_RF1",   "RF1_ADC_SYNC", "NC",         "AMS_SYSREF",
    "RFIN_RF2",   "RF2_DAC_SYNC", "DAC_REFCLK", "DDR_PL_CAP_SYNC",
    "PL_CLK",     "PL_SYSREF",    "NC",         "J10 SINGLE END",
    "ADC_REFCLK", "NC",
};

lmk_config_t lmkConfig;
lmx_config_t lmxConfig;

extern const u32 LMK_CKin[LMK_FREQ_NUM][LMK_COUNT];
extern const u32 LMX2594[][LMX2594_COUNT];

/*
 * Device instance definitions
 */

XRFdc RFdcInst; /* RFdc driver instance */

/*****************************************************************************/
/**
 *
 * Main function
 *
 * TBD
 *
 * @param	None
 *
 * @return
 *		- XST_SUCCESS if tests pass
 *		- XST_FAILURE if fails.
 *
 * @note		None.
 *
 ******************************************************************************/
int main(void) {
  u32 Val;
  u32 Minor;
  u32 Major;
  int Status;
  XRFdc_Config *ConfigPtr;
  cmdExitVal = 0;
  int lmkConfigIndex;
  xil_printf("Main is running!");
  // Initialize CLI commands structure
  cli_init();
  cli_cmd_func_mem_init();
  cli_uram_play_cap_init();
  cli_rfdc_cmd_init();
  cli_rfdc_poweron_status_init();
  cli_rfdcNyquistzone_init();
  cli_adc_dither_init();
  cli_adcFreezeCalStatus_init();
  cli_adcGetCalCoefficients_init();
  cli_adcSaveCalCoeff_init();
  cli_adcLoadCalCoeff_init();
  cli_adcDisableCoeffOvrd_init();
  cli_adcThresholds_init();
  cli_DacAdcIntDec_init();
  cli_cmd_mts_init();

  xil_printf("\n\r###############################################\n\r");
  xil_printf("Hello RFSoC World!\n\r\n");

  // Display IP version
  Val = Xil_In32(RFDC_BASE + 0x00000);
  Major = (Val >> 24) & 0xFF;
  Minor = (Val >> 16) & 0xFF;

  xil_printf("RFDC IP Version: %d.%d\r\n", Major, Minor);

  // Configure on board clks
  xil_printf("\nConfiguring the data converter clocks...\r\n");
  sleep(1);
  // initialize and reset CLK104 devices on i2c and i2c muxes
  XRFClk_Init();

  if (resetAllClk104() == EXIT_FAILURE) {
    xil_printf("resetAllClk104() failed\n\r");
    return XST_FAILURE;
  }

  xil_printf("Configuring CLK104 LMK and LMX devices\r\n");

  /* Set config on all chips */
  // using below LMK config index
  lmkConfigIndex = 9;

  //  Due to a yet to be determined issue programming to clocks twice is
  //  required on the first startup and therefore programming twice has been
  //  added, this is expected to be resolved in a future release.
  // LMX2594_FREQ_300M00_PD	if (XST_FAILURE ==
  // XRFClk_SetConfigOnAllChipsFromConfigId(lmkConfigIndex,
  // LMX2594_FREQ_8192M00, LMX2594_FREQ_7864M32)) {
  if (XST_FAILURE == XRFClk_SetConfigOnAllChipsFromConfigId(
                         lmkConfigIndex, LMX2594_FREQ_4900M_612p5M,
                         LMX2594_FREQ_9800M_612p5M)) {
    printf("Failure in XRFClk_SetConfigOnAllChipsFromConfigId()\n\r");
    return XST_FAILURE;
  }

  sleep(2);

  // LMX2594_FREQ_300M00_PD	if (XST_FAILURE ==
  // XRFClk_SetConfigOnAllChipsFromConfigId(lmkConfigIndex,
  // LMX2594_FREQ_8192M00, LMX2594_FREQ_7864M32)) {
  if (XST_FAILURE == XRFClk_SetConfigOnAllChipsFromConfigId(
                         lmkConfigIndex, LMX2594_FREQ_4900M_612p5M,
                         LMX2594_FREQ_9800M_612p5M)) {
    printf("Failure in XRFClk_SetConfigOnAllChipsFromConfigId()\n\r");
    return XST_FAILURE;
  }
  sleep(2);

  // LMX2594_FREQ_300M00_PD	if (XST_FAILURE ==
  // XRFClk_SetConfigOnAllChipsFromConfigId(lmkConfigIndex,
  // LMX2594_FREQ_8192M00, LMX2594_FREQ_7864M32)) {
  if (XST_FAILURE == XRFClk_SetConfigOnAllChipsFromConfigId(
                         lmkConfigIndex, LMX2594_FREQ_4900M_612p5M,
                         LMX2594_FREQ_9800M_612p5M)) {
    printf("Failure in XRFClk_SetConfigOnAllChipsFromConfigId()\n\r");
    return XST_FAILURE;
  }
  ////////////////////////////////////////////////////
  /* Get config from PLLs and display               */

  printCLK104_settings();

  ///////////////////////////////////////////////////
  /* Get LMK regs */

  debugLMKJ10();

  ///////////////////////////////////////////////////
  /* Close spi connections to clk104 */
  XRFClk_Close();


  xil_printf("\nThe design is ready to use.\r\n");
  xil_printf("Open XSCT or the terminal to run commands.\r\n");
  xil_printf("###############################################\n\r");

  xil_printf("\r\n--------------- Entering main() ---------------\n\r");

  /////////////////////////////////////////////////////////////////////////////////
  // Initialize RFdc
  //	.log_level		= METAL_LOG_DEBUG,
  //  .log_level		= METAL_LOG_INFO,

#ifdef ENABLE_METAL_PRINTS
  xil_printf("=== Metal log enabled ===\n\r");

  struct metal_init_params init_param = {
      .log_handler = my_metal_default_log_handler,
      .log_level = METAL_LOG_DEBUG,

  };
#else
  struct metal_init_params init_param = METAL_INIT_DEFAULTS;
#endif

  if (metal_init(&init_param)) {
    xil_printf("ERROR: Failed to run metal initialization\n");
    return XRFDC_FAILURE;
  }
  /* Initialize the RFdc driver. */
  /* Updated for SDT flow. */



#ifndef SDT
  ConfigPtr = XRFdc_LookupConfig(RFDC_DEVICE_ID);
  if (ConfigPtr == NULL) {
    xil_printf("Failed to init RFdc driver\r\n");
    return XST_FAILURE;
  } else {
    xil_printf("\n\rDeviceID: %d \r\nSilicon Revision: %d\r\n",
               ConfigPtr->DeviceId, ConfigPtr->SiRevision);
  }
#else
  ConfigPtr = XRFdc_LookupConfig(RFDC_BASE);
  if (ConfigPtr == NULL) {
    xil_printf("Failed to init RFdc driver\r\n");
    return XST_FAILURE;
  } else {
    xil_printf("\n\rDevice Name: %c \r\nSilicon Revision: %d\r\n",
               ConfigPtr->Name, ConfigPtr->SiRevision);
  }
#endif

  /* Initializes the controller */

  /////////////////////////////////////////////////////////////////////////////////
  // Configure ADC FIR bypass mux before starting the RFDC
  /////////////////////////////////////////////////////////////////////////////////

  Status = XRFdc_CfgInitialize(&RFdcInst, ConfigPtr);
  if (Status != XST_SUCCESS) {
    xil_printf("Failed to init RFdc controller\r\n");
    return XST_FAILURE;
  }

  Xil_Out32(GPIO_FIR_BYPASS_MUX, FIR_BYPASS);
  Xil_Out32(GPIO_FIR_BYPASS_MUX2, FIR_BYPASS);
  Xil_Out32(GPIO_RRC_BYPASS_MUX, FIR_BYPASS);
  Xil_Out32(GPIO_RRC_BYPASS_MUX2, FIR_BYPASS);

  xil_printf("\r\nADC FIR+RRC configuration: ");

  if (FIR_BYPASS) {
    xil_printf("BYPASSED\r\n");
  } else {
    xil_printf("ENABLED\r\n");
  }

  xil_printf("FIR bypass GPIO readback = %lu\r\n", Xil_In32(GPIO_FIR_BYPASS_MUX) & 0x1);
  xil_printf("FIR bypass GPIO readback = %lu\r\n", Xil_In32(GPIO_FIR_BYPASS_MUX2) & 0x1);
  xil_printf("RRC bypass GPIO readback = %lu\r\n", Xil_In32(GPIO_RRC_BYPASS_MUX) & 0x1);
  xil_printf("RRC bypass GPIO readback = %lu\r\n", Xil_In32(GPIO_RRC_BYPASS_MUX2) & 0x1);

  /////////////////////////////////////////////////////////////////////////////////
  // Display various configurations/status of RFDC
  // Startup RFDC's
  rfdcStartup(NULL);
  dacResetAll(NULL);
  adcResetAll(NULL);

///////////////////////////////////////////////
  // DISPLAY ADC STATUS FOR DEBUG
///////////////////////////////////////////////

u8 fifoStatus;
u32 decimation;
XRFdc_BlockStatus blockStatus;

xil_printf("\r\n===== ADC TILE 1 BLOCK 0 DEBUG =====\r\n");

xil_printf("Tile enabled        = %lu\r\n",
           XRFdc_CheckTileEnabled(
               &RFdcInst,
               XRFDC_ADC_TILE,
               1));

xil_printf("ADC block enabled   = %lu\r\n",
           XRFdc_IsADCBlockEnabled(
               &RFdcInst,
               1,
               0));

xil_printf("Digital path enabled= %lu\r\n",
           XRFdc_IsADCDigitalPathEnabled(
               &RFdcInst,
               1,
               0));

Status = XRFdc_GetFIFOStatus(
    &RFdcInst,
    XRFDC_ADC_TILE,
    1,
    &fifoStatus
);

if (Status == XST_SUCCESS) {
    xil_printf("FIFO enabled        = %u\r\n",
               fifoStatus);
} else {
    xil_printf("FIFO status read FAILED\r\n");
}

Status = XRFdc_GetDecimationFactor(
    &RFdcInst,
    1,
    0,
    &decimation
);

if (Status == XST_SUCCESS) {
    xil_printf("Decimation factor   = %lu\r\n",
               decimation);
}

Status = XRFdc_GetBlockStatus(
    &RFdcInst,
    XRFDC_ADC_TILE,
    1,
    0,
    &blockStatus
);

if (Status == XST_SUCCESS) {

    xil_printf("Analog path status  = 0x%08lx\r\n",
               blockStatus.AnalogDataPathStatus);

    xil_printf("Digital path status = 0x%08lx\r\n",
               blockStatus.DigitalDataPathStatus);

    xil_printf("Clock status        = 0x%02x\r\n",
               blockStatus.DataPathClocksStatus);

    xil_printf("FIFO flags enabled  = %u\r\n",
               blockStatus.IsFIFOFlagsEnabled);

    xil_printf("FIFO flags asserted = %u\r\n",
               blockStatus.IsFIFOFlagsAsserted);
}

xil_printf("====================================\r\n");











////////////////////////////////////////////////////
  // display ready status for ADCs and DACs
  rfdcReady(NULL);
  // display the Power On Status ADCs and DACs
  rfdcPoweronStatus(NULL);
  // Display current setting for DAC 0 in tile 0
  dacCurrent(NULL);
  // Initialize the data converter interrupts
  //	rfdc_interrupts_init();
  /////////////////////////////////////////////////////////////////////////////////
  // Main Loop

  xil_printf("--------------------------------\r\n");
  xil_printf("Available commands:\r\n");
  xil_printf("--------------------------------\r\n");
  doHelp();

  // Run command line interpreter
  xil_printf("Enter ? for help on commands\n\r");
  xil_printf("Enter 'exit' to end the application and shutdown the data "
             "converters.\n\r");

  while (!cmdExitVal) {
    xil_printf("> ");
    Status = cmdParseAndRun();
    if (Status == XST_NO_DATA) {
      continue;
    }
    if (Status != XST_SUCCESS) {
      xil_printf("Invalid command or option. Enter ? for help. \n\r");
    }
  }
  // rfdcShutdown(NULL);
  xil_printf("--- Application closed, have a good day! --- \r\n");

  // Exited cmd loop
  while (1)
    ;

  return XST_SUCCESS;
  

}

/*****************************************************************************/
/**
 *
 * My libmetal logger
 * Intercepts log prints and adjusts \r\n prints to display the some on a uart
 * or through a jtagUart.
 *
 ******************************************************************************/

void my_metal_default_log_handler(enum metal_log_level level,
                                  const char *format, ...) {
  char msg[1024];
  char msgOut[1048];
  char *outPtr;
  int i;

  va_list args;
  static const char *level_strs[] = {
      "metal: emergency: ", "metal: alert:     ", "metal: critical:  ",
      "metal: error:     ", "metal: warning:   ", "metal: notice:    ",
      "metal: info:      ", "metal: debug:     ",
  };

  va_start(args, format);
  vsnprintf(msg, sizeof(msg), format, args);
  va_end(args);

  // replace single \n with \n\r
  outPtr = msgOut;
  for (i = 0; i < 1024; i++) {
    // if /n/r or /r/n combo
    if ((msg[i] == '\r' && msg[i + 1] == '\n') ||
        (msg[i] == '\n' && msg[i + 1] == '\r')) {
      *outPtr++ = msg[i++];
    } else if (msg[i] == '\n') {
      // if first char in string is \n, then remove
      if (i == 0) {
        continue;
      } else {
        *outPtr++ = '\r';
      }
    }
    *outPtr++ = msg[i];
    if (msg[i] == 0) {
      break;
    }
  }
  // if line doesn't end with \n\r, then add it
  if ((msg[i - 1] != '\n') && (msg[i - 1] != '\r')) {
    *(outPtr - 1) = '\r';
    *outPtr++ = '\n';
    *outPtr++ = 0;
  }

  if (level <= METAL_LOG_EMERGENCY || level > METAL_LOG_DEBUG)
    level = METAL_LOG_EMERGENCY;

  xil_printf("%s%s", level_strs[level], msgOut);
}

/****************************************************************************/
/**
 *
 * This function resets all CLK_104 PLL I2C devices.
 *
 * @param	None
 *
 * @return
 *	- XST_SUCCESS if successful.
 *	- XST_FAILURE if failed.
 *
 * @note		None
 *
 ****************************************************************************/
static int resetAllClk104(void) {
  int ret = EXIT_FAILURE;
  //	printf("Reset LMK\n\r");
  if (XST_FAILURE == XRFClk_ResetChip(RFCLK_LMK)) {
    printf("Failure in XRFClk_ResetChip(RFCLK_LMK)\n\r");
    return ret;
  }

  //	printf("Reset LMX2594_1\n\r");
  if (XST_FAILURE == XRFClk_ResetChip(RFCLK_LMX2594_1)) {
    printf("Failure in XRFClk_ResetChip(RFCLK_LMX2594_1)\n\r");
    return ret;
  }

  //	printf("Reset LMX2594_2\n\r");
  if (XST_FAILURE == XRFClk_ResetChip(RFCLK_LMX2594_2)) {
    printf("Failure in XRFClk_ResetChip(RFCLK_LMX2594_2)\n\r");
    return ret;
  }

#ifdef XPS_BOARD_ZCU111
  //	printf("Reset LMX2594_3\n\r");
  if (XST_FAILURE == XRFClk_ResetChip(RFCLK_LMX2594_3)) {
    printf("Failure in XRFClk_ResetChip(RFCLK_LMX2594_3)\n\r");
    return ret;
  }
#endif

  return EXIT_SUCCESS;
}

/****************************************************************************/
/**
 *
 * Print LMK PLL device settings such as input and output clk frequencies.
 * The instance structure is initialized by calling LMK_init()
 *
 * @param
 *	- lmkInstPtr a pointer to the LMK instance structure
 *
 * @return
 *	- void
 *
 * @note		None
 *
 ****************************************************************************/
void printLMKsettings(lmk_config_t *lmkInstPtr) {

#ifdef LMK_DEBUG
  LMK_intermediateDump(lmkInstPtr);
#endif

  // Print LMK CLKin frequencies
  if (lmkInstPtr->clkin_sel_mode == LMK_CLKin_SEL_MODE_AUTO_MODE) {
    xil_printf("CLKin Auto Mode Enabled\n\r");
  }
  for (int i = 0; i < 3; i++) {
    if (lmkInstPtr->clkin[i].freq != -1) {
      xil_printf("CLKin%d_freq: %12ld KHz\n\r", i,
                 lmkInstPtr->clkin[i].freq / 1000);
    }
  }

  // Print LMK CLKout frequencies
  for (int i = 0; i < 7; i++) {
    xil_printf("DCLKout%02d(%-10s):", i * 2, clkoutBrdNames[i * 2]);
    if (lmkInstPtr->clkout[i].dclk_freq == -1) {
      xil_printf("%13s", "-----");
    } else {
      xil_printf("%9ld KHz", lmkInstPtr->clkout[i].dclk_freq / 1000);
    }

    xil_printf(" SDCLKout%02d(%-15s):", i * 2 + 1, clkoutBrdNames[i * 2 + 1]);
    if (lmkInstPtr->clkout[i].sclk_freq == -1) {
      xil_printf("%13\n\r", "-----");
    } else {
      xil_printf("%9ld KHz\n\r", lmkInstPtr->clkout[i].sclk_freq / 1000);
    }
  }
}

/****************************************************************************/
/**
 *
 * Print LMX PLL device output clk frequencies.
 * The instance structure is initialized by calling LMX_SettingsInit()
 *
 * @param
 * 	- clkin is the clk freq fed into the LMX PLL. This value is used to
 * 	  calculate and display the output frequencies
 *	- lmxInstPtr a pointer to the LMX instance structure
 *
 * @return
 *	- void
 *
 * @note		None
 *
 ****************************************************************************/
void printLMXsettings(long int clkin, lmx_config_t *lmxInstPtr) {

#ifdef LMX_DEBUG
  LMX_intermediateDump(lmxInstPtr);
#endif

  // Print LMX CLKin freq
  xil_printf("CLKin_freq: %10ld KHz\n\r", clkin / 1000);

  // Print LMX CLKout frequencies
  xil_printf("RFoutA Freq:");
  if (lmxInstPtr->RFoutA_freq == -1) {
    xil_printf("%13s\n\r", "-----");
  } else {
    xil_printf("%10ld KHz\n\r", lmxInstPtr->RFoutA_freq / 1000);
  }

  xil_printf("RFoutB Freq:");
  if (lmxInstPtr->RFoutB_freq == -1) {
    xil_printf("%13s\n\r", "-----");
  } else {
    xil_printf("%10ld KHz\n\r", lmxInstPtr->RFoutB_freq / 1000);
  }
}

/****************************************************************************/
/**
 *
 * Reads the configuration of LMK and LMX PLL then calculates and displays
 * the PLL frequencies and settings.
 * The instance structures ar initialized by calling LMK_init() or
 * LMX_SettingsInit()
 *
 * @param
 * 	- nil
 *
 * @return
 *	- void
 *
 * @note		None
 *
 ****************************************************************************/
void printCLK104_settings(void) {
  char pllNames[3][9] = {"LMK ----", "LMX_RF1", "LMX_RF2"};
  u32 chipIds[3] = {RFCLK_LMK, RFCLK_LMX2594_1, RFCLK_LMX2594_2};

  for (int i = 0; i < 3; i++) {
    if (XST_FAILURE == XRFClk_GetConfigFromOneChip(chipIds[i], data)) {
      printf("Failure in XRFClk_GetConfigFromOneChip()\n\r");
      return;
    }

    // For LMX, reverse readback data to match exported register sets and
    // order of LMX2594[][]
    if (chipIds[i] != RFCLK_LMK) {
      reverse32bArray(data, LMX2594_COUNT - 3);
    }

#if 0
		// Dump raw data read from device
		printf("Config data is:\n\r");
		for (int j = 0; j < ((chipIds[i]==RFCLK_LMK) ? LMK_COUNT : LMX2594_COUNT-3); j++) {
			printf("%08X, ", data[j]);
			if( !(j % 6) ) printf("\n\r");
		}
		printf("\n\r");
#endif

    // Display clock values of device
    printf("Clk settings read from %s ---------------------\n\r", pllNames[i]);
    if (chipIds[i] == RFCLK_LMK) {
      LMK_init(data, &lmkConfig);
      printLMKsettings(&lmkConfig);
    } else {
      // clkout index is i=1 idx = 0, i=2 idx=2. i&2 meets this alg
      LMX_SettingsInit(lmkConfig.clkout[(i & 2)].dclk_freq, data, &lmxConfig);
      printLMXsettings(lmkConfig.clkout[(i & 2)].dclk_freq, &lmxConfig);
    }
    xil_printf("\n\r");
  }
}

void reverse32bArray(u32 *src, int size) {
  u32 tmp[200];
  int i, j;

  // copy src into temp
  for (i = 0, j = size - 1; i < size; i++, j--) {
    tmp[i] = src[j];
  }

  // copy swapped array to original
  for (i = 0; i < size; i++) {
    src[i] = tmp[i];
  }
  return;
}

/****************************************************************************/
/*
 * Read one LMK04828 register back from the actual device.
 *
 * regAddr  = LMK register address, e.g. 0x12C
 * regValue = returned 8-bit register value
 */
/****************************************************************************/
static int readLMKRegister(u16 regAddr, u8 *regValue)
{
    u32 raw;

    if (regValue == NULL) {
        xil_printf("ERROR: NULL regValue pointer\r\n");
        return XST_FAILURE;
    }

    /*
     * LMK SPI format:
     *
     * bits [20:8] = register address
     * bits [7:0]  = register data
     *
     * XRFClk_ReadReg() automatically sets the READ bit.
     */
    raw = ((u32)regAddr << 8);

    if (XRFClk_ReadReg(RFCLK_LMK, &raw) == XST_FAILURE) {
        xil_printf("ERROR: Failed to read LMK register 0x%03X\r\n",
                   regAddr);
        return XST_FAILURE;
    }

    *regValue = (u8)(raw & 0xFF);

    xil_printf("LMK 0x%03X -> raw = 0x%06lX, data = 0x%02X\r\n",
               regAddr,
               raw & 0xFFFFFF,
               *regValue);

    return XST_SUCCESS;
}


/****************************************************************************/
/*
 * Debug the J10 / SDCLKout11 clock path.
 */
/****************************************************************************/
static void debugLMKJ10(void)
{
    u8 r12c;
    u8 r12e;
    u8 r12f;
    u8 r144;

    xil_printf("\r\n");
    xil_printf("========================================\r\n");
    xil_printf(" LMK J10 / SDCLKout11 READBACK\r\n");
    xil_printf("========================================\r\n");

    /*
     * 0x12C:
     * bit 5 = SDCLKout11_MUX
     *
     * 0 -> Device clock
     * 1 -> SYSREF
     */
    if (readLMKRegister(0x12C, &r12c) == XST_SUCCESS) {

        xil_printf("0x12C = 0x%02X\r\n", r12c);

        if (r12c & 0x20) {
            xil_printf("  SDCLKout11_MUX = SYSREF\r\n");
        } else {
            xil_printf("  SDCLKout11_MUX = DEVICE CLOCK\r\n");
        }
    }

    /*
     * 0x12E:
     *
     * bit 3 = CLKout10_11_PD
     *         0 = output group enabled
     *         1 = output group powered down
     *
     * bit 0 = SDCLKout11_PD
     *         0 = SDCLKout11 enabled
     *         1 = SDCLKout11 powered down
     */
    if (readLMKRegister(0x12E, &r12e) == XST_SUCCESS) {

        xil_printf("0x12E = 0x%02X\r\n", r12e);

        xil_printf("  CLKout10_11 group = %s\r\n",
                   (r12e & 0x08) ? "POWERED DOWN" : "ENABLED");

        xil_printf("  SDCLKout11        = %s\r\n",
                   (r12e & 0x01) ? "POWERED DOWN" : "ENABLED");
    }

    /*
     * 0x12F:
     *
     * bits 6:4 = SDCLKout11_FMT
     *
     * 0 = powerdown
     * 1 = LVDS
     * 2 = HSDS 6 mA
     * 3 = HSDS 8 mA
     * 4 = HSDS 10 mA
     * 5 = LVPECL 1600 mV
     * 6 = LVPECL 2000 mV
     * 7 = LCPECL
     */
    if (readLMKRegister(0x12F, &r12f) == XST_SUCCESS) {

        u8 fmt = (r12f >> 4) & 0x07;

        xil_printf("0x12F = 0x%02X\r\n", r12f);
        xil_printf("  SDCLKout11_FMT = %u\r\n", fmt);

        switch (fmt) {
        case 0:
            xil_printf("  OUTPUT FORMAT = POWERDOWN !!!\r\n");
            break;

        case 1:
            xil_printf("  OUTPUT FORMAT = LVDS\r\n");
            break;

        case 2:
            xil_printf("  OUTPUT FORMAT = HSDS 6mA\r\n");
            break;

        case 3:
            xil_printf("  OUTPUT FORMAT = HSDS 8mA\r\n");
            break;

        case 4:
            xil_printf("  OUTPUT FORMAT = HSDS 10mA\r\n");
            break;

        case 5:
            xil_printf("  OUTPUT FORMAT = LVPECL 1600mV\r\n");
            break;

        case 6:
            xil_printf("  OUTPUT FORMAT = LVPECL 2000mV\r\n");
            break;

        case 7:
            xil_printf("  OUTPUT FORMAT = LCPECL\r\n");
            break;
        }
    }

    /*
     * 0x144 bit 5 = SYNC_DIS10
     */
    if (readLMKRegister(0x144, &r144) == XST_SUCCESS) {

        xil_printf("0x144 = 0x%02X\r\n", r144);

        xil_printf("  SYNC_DIS10 = %u\r\n",
                   (r144 >> 5) & 0x1);
    }

    xil_printf("========================================\r\n\r\n");
}
