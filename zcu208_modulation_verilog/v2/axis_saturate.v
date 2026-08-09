`timescale 1ns / 1ps

module axis_saturate (
    input wire [191:0] s_axis_tdata,
    input wire         s_axis_tvalid,
    output wire        s_axis_tready,

    // 16-bit output stream
    output wire [127:0] m_axis_tdata,
    output wire         m_axis_tvalid,
    input wire          m_axis_tready    

);

    function [15:0] saturate_sample;

        input signed [16:0] sample_in;

        begin 
            if(sample_in > 17'sd32767) begin
                saturate_sample = 16'sh7FFFF;
            end else if(sample_in < -17'sd32768) begin
                saturate_sample = 16'sh8000;
            end else begin
                saturate_sample = sample_in[15:0];
            end
        end
    endfunction

    assign s_axis_tready = m_axis_tready;
    assign m_axis_tvalid = s_axis_tvalid;

    // Each 17-bit sample occupies a 24-bit AXI slot
    // sample 0 --> [16:0]
    // sample 1 --> [40:24]
    // sample 2 --> [64:48]
    // sample 3 --> [88:72]

    assign m_axis_tdata[15:0] = saturate_sample($signed(s_axis_tdata[16:0]));

    assign m_axis_tdata[31:16] = saturate_sample($signed(s_axis_tdata[40:24]));

    assign m_axis_tdata[47:32] = saturate_sample($signed(s_axis_tdata[64:48]));

    assign m_axis_tdata[63:48] = saturate_sample($signed(s_axis_tdata[88:72]));

    assign m_axis_tdata[79:64] = saturate_sample($signed(s_axis_tdata[112:96]));

    assign m_axis_tdata[95:80] = saturate_sample($signed(s_axis_tdata[136:120]));

    assign m_axis_tdata[111:96] = saturate_sample($signed(s_axis_tdata[160:144]));

    assign m_axis_tdata[127:112] = saturate_sample($signed(s_axis_tdata[184:168]));

endmodule