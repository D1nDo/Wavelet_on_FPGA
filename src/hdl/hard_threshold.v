module Axis_Hard_threshold_fixed #(
    parameter THRESHOLD = 800
)(
    input  wire clk,
    input  wire reset_n,

    input  wire signed [31:0] s_axis_tdata,
    input  wire s_axis_tvalid,
    output wire s_axis_tready,

    output wire signed [31:0] m_axis_tdata,
    output wire m_axis_tvalid,
    input  wire m_axis_tready
);

    wire signed [31:0] abs_data;

    // AXI Stream handshake
    assign s_axis_tready = m_axis_tready;
    assign m_axis_tvalid = s_axis_tvalid;

    // Valore assoluto del coefficiente signed
    assign abs_data = (s_axis_tdata[31]) ? -s_axis_tdata : s_axis_tdata;

    // Hard threshold:
    // |x| > threshold --> passa il valore originale
    // |x| <= threshold --> zero
    assign m_axis_tdata = (abs_data > THRESHOLD) ? s_axis_tdata : 32'sd0;

endmodule