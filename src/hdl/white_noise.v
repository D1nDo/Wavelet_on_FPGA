`timescale 1ns / 1ps

module Axis_awgn_generator #
(
    parameter DATA_WIDTH = 32,
    parameter integer SIGMA = 1000   // deviazione standard in LSB
)
(
    input  wire clk,
    input  wire reset_n,

    output reg signed [DATA_WIDTH-1:0] m_axis_tdata,
    output reg                         m_axis_tvalid
);


integer seed = 123456;

always @(posedge clk) begin

    if(!reset_n) begin

        m_axis_tdata  <= 'sd0;
        m_axis_tvalid <= 1'b0;

    end
    else begin
        m_axis_tdata <= $dist_normal(seed,0,SIGMA);
        m_axis_tvalid <= 1'b1;
    end
end


endmodule