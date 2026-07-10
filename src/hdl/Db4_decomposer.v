`timescale 1ns/1ps

// =============================================================================
// Modulo: Axis_Db4_decomposer
// Autore: Ludovico Dindelli
// Data: Gennaio 2026
//
// Description: 
//   Modulo di decomposizione wavelet DWT con filtro Daubechies4 (8 taps).
//   Include una FIFO interna per i campioni d'ingresso, stadi pipeline per la
//   convoluzione con i filtri H (Low-Pass) e G (High-Pass), un albero di somma
//   e un'uscita AXI-Stream con downsampling a fattore 2.
// =============================================================================

module Axis_Db4_decomposer #(
    parameter DATA_WIDTH = 32  
)(
    input wire clk,
    input wire reset_n, 
    
    // AXI-Stream input
    input wire s_axis_tvalid,
    output wire s_axis_tready,
    input wire signed [DATA_WIDTH-1:0] s_axis_tdata,
    
    // AXI-Stream output
    output reg m_axis_cA_tvalid,
    input wire m_axis_cA_tready,
    output reg signed [DATA_WIDTH-1:0] m_axis_cA_tdata,
    
    output reg m_axis_cD_tvalid,
    input wire m_axis_cD_tready,
    output reg signed [DATA_WIDTH-1:0] m_axis_cD_tdata
);

	// Registri interni per i campioni 
	reg signed [DATA_WIDTH-1:0] sample [0:7];

	localparam PARAM_WIDTH = 17;
	localparam TERM_WIDTH = DATA_WIDTH + PARAM_WIDTH;
	localparam SUM_WIDTH = TERM_WIDTH + 3;
	localparam TAPS = 8;

	// Coefficienti low-pass
	localparam signed [PARAM_WIDTH-1:0] h0 = 17'b00011101011111001;
	localparam signed [PARAM_WIDTH-1:0] h1 = 17'b01011011100000000;
	localparam signed [PARAM_WIDTH-1:0] h2 = 17'b01010000110000001;
	localparam signed [PARAM_WIDTH-1:0] h3 = 17'b11111100011010111;
	localparam signed [PARAM_WIDTH-1:0] h4 = 17'b11101000000011111;
	localparam signed [PARAM_WIDTH-1:0] h5 = 17'b00000011111100101;
	localparam signed [PARAM_WIDTH-1:0] h6 = 17'b00000100001101011;
	localparam signed [PARAM_WIDTH-1:0] h7 = 17'b11111110101001010;

	// Coefficienti high-pass
	localparam signed [PARAM_WIDTH-1:0] g0 = ~h7 + 1;
	localparam signed [PARAM_WIDTH-1:0] g1 = h6;
	localparam signed [PARAM_WIDTH-1:0] g2 = ~h5 + 1;
	localparam signed [PARAM_WIDTH-1:0] g3 = h4;
	localparam signed [PARAM_WIDTH-1:0] g4 = ~h3 + 1;
	localparam signed [PARAM_WIDTH-1:0] g5 = h2;
	localparam signed [PARAM_WIDTH-1:0] g6 = ~h1 + 1;
	localparam signed [PARAM_WIDTH-1:0] g7 = h0;

	// Registri per le moltiplicazioni e somma
	(* use_dsp48 = "yes" *) reg signed [TERM_WIDTH-1:0] term_h [0:TAPS-1];
	reg signed [TERM_WIDTH-1:0] term_g [0:TAPS-1];
	reg signed [TERM_WIDTH-1:0] term_h_resc [0:TAPS-1];
	reg signed [TERM_WIDTH-1:0] term_g_resc [0:TAPS-1];
	reg signed [SUM_WIDTH-1:0] cA_temp1 [0:TAPS/2-1];
	reg signed [SUM_WIDTH-1:0] cA_temp2 [0:TAPS/4-1];
	reg signed [SUM_WIDTH-1:0] cD_temp1 [0:TAPS/2-1];
	reg signed [SUM_WIDTH-1:0] cD_temp2 [0:TAPS/4-1];
	reg signed [SUM_WIDTH-1:0] cA_sum, cD_sum;

	// Contatore campioni
	integer i;
	wire in_fire, out_fire;
	
	// Gestione validità 
	reg vld_fifo, vld_conv, vld_resc, vld_sum;
    reg vld_sum1, vld_sum2, vld_sum3;

	// Gestione Axis
	assign in_fire = s_axis_tvalid && m_axis_cA_tready && m_axis_cD_tready;
	assign s_axis_tready = m_axis_cA_tready && m_axis_cD_tready;
	
	/*--- SHIFT FIFO ---*/
	always @(posedge clk or negedge reset_n) begin
		if (!reset_n) begin
			vld_fifo <= 1'b0;
			for (i=0;i<TAPS;i=i+1) begin
			sample[i] <= 0;
			end
		end else begin
			if (in_fire) begin
			
				// Valid fifo 
				vld_fifo <= 1'b1;
				
				// Shift FIFO e carico nuovo campione
				for (i=TAPS-1;i>0;i=i-1)  begin
					sample[i] <= sample[i-1];
				end
					sample[0] <= s_axis_tdata;			
			end else 
				vld_fifo <= 1'b0;
				
		end
	end


	/* --- CONVOLUZIONE --- */
	always @(posedge clk or negedge reset_n) begin
		if (!reset_n) begin
			vld_conv <= 1'b0;
			for (i=0;i<TAPS;i=i+1) begin
			     term_h[i] <= 0;
			     term_g[i] <= 0;
			end
		end else begin
			if(vld_fifo) begin 
			
			// Valid Convolution 
			vld_conv <= 1'b1;
			
			// Calcolo convoluzione H
			term_h[0] <= (h0*sample[0]);
			term_h[1] <= (h1*sample[1]);
			term_h[2] <= (h2*sample[2]);
			term_h[3] <= (h3*sample[3]);
			term_h[4] <= (h4*sample[4]);
			term_h[5] <= (h5*sample[5]);
			term_h[6] <= (h6*sample[6]);
			term_h[7] <= (h7*sample[7]);

			// Calcolo convoluzione G
			term_g[0] <= (g0*sample[0]);
			term_g[1] <= (g1*sample[1]);
			term_g[2] <= (g2*sample[2]);
			term_g[3] <= (g3*sample[3]);
			term_g[4] <= (g4*sample[4]);
			term_g[5] <= (g5*sample[5]);
			term_g[6] <= (g6*sample[6]);
			term_g[7] <= (g7*sample[7]);
			
			end else 
				vld_conv <= 1'b0;
		end
	end
	
	
	/* --- RESCALE  --- */
	always @(posedge clk or negedge reset_n) begin
		if (!reset_n) begin
			vld_resc <= 1'b0;
			for (i=0;i<TAPS;i=i+1) begin
			     term_h_resc[i] <= 0;
			     term_g_resc[i] <= 0;
			end
		end else begin
			if(vld_conv) begin 
			
			// Valid rescale
			vld_resc <= 1'b1;
			
			// Rescale H
			term_h_resc[0] <= term_h[0] >>> 16;
			term_h_resc[1] <= term_h[1] >>> 16;
			term_h_resc[2] <= term_h[2] >>> 16;
			term_h_resc[3] <= term_h[3] >>> 16;
			term_h_resc[4] <= term_h[4] >>> 16;
			term_h_resc[5] <= term_h[5] >>> 16;
			term_h_resc[6] <= term_h[6] >>> 16;
			term_h_resc[7] <= term_h[7] >>> 16;

			// Rescale G
			term_g_resc[0] <= term_g[0] >>> 16;
			term_g_resc[1] <= term_g[1] >>> 16;
			term_g_resc[2] <= term_g[2] >>> 16;
			term_g_resc[3] <= term_g[3] >>> 16;
			term_g_resc[4] <= term_g[4] >>> 16;
			term_g_resc[5] <= term_g[5] >>> 16;
			term_g_resc[6] <= term_g[6] >>> 16;
			term_g_resc[7] <= term_g[7] >>> 16;
			
			end else 
				vld_resc <= 1'b0;
		end
	end
	
	

	/*--- SUMMATION TREE ---*/
	
	//Level 1
	always @(posedge clk or negedge reset_n) begin
		if (!reset_n) begin
			vld_sum1 <= 1'b0;
			
			// Reset lvl 1
			for (i=0;i<TAPS/2;i=i+1) begin
				cA_temp1[i] <= 0;
				cD_temp1[i] <= 0;
			end
			
		end else begin
			if(vld_resc) begin 
				
				// Valid summation  
				vld_sum1 <= 1'b1;
				
				// Summation tree livello 1
				for (i=0;i<TAPS/2;i=i+1) begin
					cA_temp1[i] <= term_h_resc[2*i] + term_h_resc[2*i+1];
					cD_temp1[i] <= term_g_resc[2*i] + term_g_resc[2*i+1];
				end
				
			end else
				vld_sum1 <= 1'b0;
		end
	end
	
	//Level 2
	always @(posedge clk or negedge reset_n) begin
		if (!reset_n) begin
			vld_sum2 <= 1'b0;
			
			// Reset lvl 2
			for (i=0;i<TAPS/4;i=i+1) begin
				cA_temp2[i] <= 0;
				cD_temp2[i] <= 0;
			end
			
		end else begin
			if(vld_sum1) begin 
				
				// Valid summation 
				vld_sum2 <= 1'b1;

				// Summation tree livello 2
				for (i=0;i<TAPS/4;i=i+1) begin
					cA_temp2[i] <= cA_temp1[2*i]+cA_temp1[2*i+1];
					cD_temp2[i] <= cD_temp1[2*i]+cD_temp1[2*i+1];
				end
				
			end else
				vld_sum2 <= 1'b0;
		end
	end
	
	// Level 3
	always @(posedge clk or negedge reset_n) begin
		if (!reset_n) begin
			vld_sum3 <= 1'b0;
			
			// Reset lvl 3
			cA_sum <= 0;
			cD_sum <= 0;
			
		end else begin
			if(vld_sum2) begin 
				
				// Valid summation  ( 1 solo valid anche se potresti usarne uno per livello di somma)
				vld_sum3 <= 1'b1;

				// Summation tree livello 3
				cA_sum <= cA_temp2[0]+cA_temp2[1];
				cD_sum <= cD_temp2[0]+cD_temp2[1];
			end else
				vld_sum3 <= 1'b0;
		end
	end
	
	

	/* --- USCITA DATI AXIS CON DOWNSAMPLE 2---*/
	
	reg down_sample;
	
	always @(posedge clk or negedge reset_n) begin
		if (!reset_n) begin
		    down_sample <= 1'b0;
			m_axis_cA_tdata <= 0;
			m_axis_cD_tdata <= 0;
			m_axis_cA_tvalid <= 0;
			m_axis_cD_tvalid <= 0;
		end else begin
			
			// Uscita con downsample 
			if(vld_sum3) begin 
               
                //Counter 0 o 1 per downsample 2
			    down_sample <= ~down_sample;
			    
                if (down_sample) begin  
				    m_axis_cA_tdata <= cA_sum[DATA_WIDTH-1:0];
				    m_axis_cD_tdata <= cD_sum[DATA_WIDTH-1:0];
				    m_axis_cA_tvalid <= 1;
				    m_axis_cD_tvalid <= 1;
				end else begin
				    m_axis_cA_tvalid <= 0;
				    m_axis_cD_tvalid <= 0;  
				end
				
			end else begin
				m_axis_cA_tvalid <= 0;
				m_axis_cD_tvalid <= 0;        
			end
		end
	end

endmodule