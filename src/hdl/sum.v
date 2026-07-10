`timescale 1ns / 1ps

module Axis_adder #(
parameter DATA_WIDTH = 32
)(

    input  wire [DATA_WIDTH-1:0] s_axis_a_tdata,
    input  wire                  s_axis_a_tvalid,
    output wire                  s_axis_a_tready,

    input  wire [DATA_WIDTH-1:0] s_axis_b_tdata,
    input  wire                  s_axis_b_tvalid,
    output wire                  s_axis_b_tready,

    output wire [DATA_WIDTH-1:0] m_axis_tdata,
    output wire                  m_axis_tvalid,
    input  wire                  m_axis_tready
);

assign s_axis_a_tready = m_axis_tready;
assign s_axis_b_tready = m_axis_tready;

// Somma combinatoria
assign m_axis_tdata  = $signed(s_axis_a_tdata) + $signed(s_axis_b_tdata);

// Valid combinatorio
assign m_axis_tvalid = s_axis_a_tvalid & s_axis_b_tvalid;

endmodule