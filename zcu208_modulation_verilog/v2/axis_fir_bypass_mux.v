`timescale 1ns / 1ps

/* 
 IN APPLICATION, MAKE SURE TO ALWAYS SET BYPASS_FIR FIRST BEFORE STARTING CAPTURE. SHOULD DO THIS IN VITIS BEFORE STARTING UP THE RFDC!

 */
module axis_fir_bypass_mux (
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 axis_aclk CLK" *)
    (* X_INTERFACE_PARAMETER =  "ASSOCIATED_BUSIF s_axis:fir_s_axis:fir_m_axis:m_axis, ASSOCIATED_RESET axis_aresetn, FREQ_HZ 20000000" *)
    input wire         axis_aclk,

    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 axis_aresetn RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input wire         axis_aresetn,

    /*
     * 0 = use FIR output
     * 1 = bypass FIR and use input data
     */
    input wire         bypass_fir,

    // Input from FIFO
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis TDATA" *)
    input wire [127:0] s_axis_tdata,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis TVALID" *)
    input wire         s_axis_tvalid,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis TREADY" *)
    output wire        s_axis_tready,

    // Output TO FIR Compiler
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 fir_s_axis TDATA" *)
    output wire [127:0] fir_s_axis_tdata,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 fir_s_axis TVALID" *)
    output wire         fir_s_axis_tvalid,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 fir_s_axis TREADY" *)
    input wire          fir_s_axis_tready,

    // Input FROM FIR Compiler
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 fir_m_axis TDATA" *)
    input wire [127:0]  fir_m_axis_tdata,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 fir_m_axis TVALID" *)
    input wire          fir_m_axis_tvalid,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 fir_m_axis TREADY" *)
    output wire         fir_m_axis_tready,

    // Output to 128 -> 256 bit packer

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis TDATA" *)
    output wire [127:0]  m_axis_tdata,
    
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis TVALID" *)
    output wire          m_axis_tvalid,
    
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis TREADY" *)
    input wire           m_axis_tready
);

    // Input routing
    // Data can always be physically connected to the FIR, TVALID determines whether the FIR actually accepts it
    assign fir_s_axis_tdata  = s_axis_tdata;
    assign fir_s_axis_tvalid = s_axis_tvalid && (!bypass_fir);

    // Upstream depends on selected path
    assign s_axis_tready     = bypass_fir ? m_axis_tready : fir_s_axis_tready;

    // Output routing
    // Select either FIFO data directly or FIR output data
    assign m_axis_tdata = bypass_fir ? s_axis_tdata : fir_m_axis_tdata;
    assign m_axis_tvalid = bypass_fir ? s_axis_tvalid : fir_m_axis_tvalid;

    assign fir_m_axis_tready = (!bypass_fir) && m_axis_tready;

endmodule