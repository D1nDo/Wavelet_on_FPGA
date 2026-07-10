module Axis_t_last_adder #(
    parameter T_LAST = 1024
)(
    input  wire clk,
    input  wire reset_n,
    
    input  wire signed [31:0] s_axis_tdata,
    input  wire s_axis_tvalid,
    output wire s_axis_tready,
    
    output wire signed [31:0] m_axis_tdata,
    output wire m_axis_tvalid,
    input  wire m_axis_tready,
    output wire [3:0] m_axis_tkeep,
    output wire m_axis_tlast
);
    reg [$clog2(T_LAST)-1:0] count;

    assign s_axis_tready = m_axis_tready;
    assign m_axis_tvalid  = s_axis_tvalid;
    assign m_axis_tdata   = s_axis_tdata;
    assign m_axis_tkeep   = 4'b1111;
    assign m_axis_tlast   = (count == T_LAST-1);

    always @(posedge clk) begin
        if (!reset_n) begin
            count <= 0;
        end else if (s_axis_tvalid && m_axis_tready) begin
            count <= (count == T_LAST-1) ? {$clog2(T_LAST){1'b0}} : count + 1'b1;
        end
    end
endmodule