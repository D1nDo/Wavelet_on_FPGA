module Axis_data_and_valid_delay #(
    parameter DATA_WIDTH = 16,
    parameter DELAY      = 512
)(
    input  wire                     clk,
    input  wire                     reset_n,

    input  wire [DATA_WIDTH-1:0]    s_axis_tdata,
    input  wire                     s_axis_tvalid,
    output wire                     s_axis_tready,

    output wire [DATA_WIDTH-1:0]    m_axis_tdata,
    output wire                     m_axis_tvalid,
    input  wire                     m_axis_tready
);

    assign s_axis_tready = 1'b1;

    // Pipeline di DELAY stadi: pipe_data[0] = 1° registro, pipe_data[DELAY-1] = ultimo
    reg [DATA_WIDTH-1:0] pipe_data  [0:DELAY-1];
    reg                  pipe_valid [0:DELAY-1];

    integer i;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            for (i = 0; i < DELAY; i = i + 1) begin
                pipe_data[i]  <= {DATA_WIDTH{1'b0}};
                pipe_valid[i] <= 1'b0;
            end
        end else begin
            pipe_data[0]  <= s_axis_tdata;
            pipe_valid[0] <= s_axis_tvalid;
            for (i = 1; i < DELAY; i = i + 1) begin
                pipe_data[i]  <= pipe_data[i-1];
                pipe_valid[i] <= pipe_valid[i-1];
            end
        end
    end

    // L'uscita è il contenuto dell'ultimo stadio, senza ulteriore registrazione
    assign m_axis_tdata  = pipe_data[DELAY-1];
    assign m_axis_tvalid = pipe_valid[DELAY-1];

endmodule