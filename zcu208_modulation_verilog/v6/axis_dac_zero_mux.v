module axis_dac_zero_mux (
    input  wire                  axis_clk,
    input  wire                  axis_aresetn,

    // Enable may come from another clock domain
    input  wire                  enable_async,

    // AXI-Stream input
    input  wire [255:0]          s_axis_tdata,
    input  wire                  s_axis_tvalid,
    output wire                  s_axis_tready,

    // AXI-Stream output -> RFDC
    output wire [255:0]          m_axis_tdata,
    output wire                  m_axis_tvalid,
    input  wire                  m_axis_tready
);

    localparam integer DATA_WIDTH = 256;
    // ---------------------------------------------------------
    // Synchronize enable into axis_clk domain
    // ---------------------------------------------------------
    (* ASYNC_REG = "TRUE" *) reg enable_meta;
    (* ASYNC_REG = "TRUE" *) reg enable_sync;

    always @(posedge axis_clk) begin
        if (!axis_aresetn) begin
            enable_meta <= 1'b0;
            enable_sync <= 1'b0;
        end
        else begin
            enable_meta <= enable_async;
            enable_sync <= enable_meta;
        end
    end


    assign s_axis_tready = enable_sync ? m_axis_tready : 1'b0;
    assign m_axis_tvalid = enable_sync ? s_axis_tvalid : 1'b0;


    // ---------------------------------------------------------
    // DAC data mux
    //
    // enabled  -> normal waveform
    // disabled -> force all RFDC input samples to zero
    // ---------------------------------------------------------
    assign m_axis_tdata =
        enable_sync ? s_axis_tdata : {DATA_WIDTH{1'b0}};

endmodule