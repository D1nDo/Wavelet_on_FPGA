`timescale 1ns / 1ps

module Axis_dds_sine_2048 #
(
    parameter PHASE_WIDTH = 32,
    parameter LUT_BITS    = 11   // 2048 samples
)
(
    input wire clk,
    input wire reset_n,

    // Controllo DDS
    input wire [PHASE_WIDTH-1:0] phase_step,
    input wire [PHASE_WIDTH-1:0] phase_offset,

    // AXIS output
    output reg signed [31:0] m_axis_tdata,
    output reg               m_axis_tvalid
);

localparam LUT_SIZE = (1 << LUT_BITS);

/*==============================
=        PHASE ACCUM           =
==============================*/
reg [PHASE_WIDTH-1:0] phase_acc;

always @(posedge clk) begin
    if (!reset_n)
        phase_acc <= 0;
    else
        phase_acc <= phase_acc + phase_step;
end


/*==============================
=      PHASE + OFFSET          =
==============================*/
wire [PHASE_WIDTH-1:0] phase_total;
assign phase_total = phase_acc + phase_offset;


/*==============================
=        LFSR DITHER           =
==============================*/
reg [15:0] lfsr;

always @(posedge clk) begin
    if (!reset_n)
        lfsr <= 16'hACE1;
    else
        lfsr <= {lfsr[14:0],
                 lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
end

// Dithering sui 10 bit meno significativi
wire [PHASE_WIDTH-1:0] dither;
assign dither = {{(PHASE_WIDTH-10){1'b0}}, lfsr[9:0]};


/*==============================
=      PHASE DITHERED          =
==============================*/
wire [PHASE_WIDTH-1:0] phase_dithered;
assign phase_dithered = phase_total + dither;


/*==============================
=        LUT INDEX             =
==============================*/
reg [LUT_BITS-1:0] lut_index;

always @(posedge clk) begin
    lut_index <= phase_dithered[PHASE_WIDTH-1 -: LUT_BITS];
end


/*==============================
=        LUT MEMORY            =
==============================*/
(* rom_style = "block" *)
reg signed [15:0] lut [0:LUT_SIZE-1];

initial begin
    $readmemh("lut_sin.mem", lut);
end


/*==============================
=        OUTPUT PIPELINE       =
==============================*/
reg signed [15:0] lut_data;

always @(posedge clk) begin
    lut_data <= lut[lut_index];
end

always @(posedge clk) begin
    if (!reset_n) begin
        m_axis_tdata  <= 32'sd0;
        m_axis_tvalid <= 1'b0;
    end
    else begin
        // Estensione del segno da 16 a 32 bit
        m_axis_tdata  <= {{16{lut_data[15]}}, lut_data};
        m_axis_tvalid <= 1'b1;
    end
end

endmodule