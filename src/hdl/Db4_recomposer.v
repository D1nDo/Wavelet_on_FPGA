`timescale 1ns/1ps

// ==================================================================================
// Modulo: Axis_Db4_reconstruction
// Autore: Ludovico Dindelli
// Data: Gennaio 2026
//
// Descrizione:
// Questo modulo realizza la ricomposizione Wavelet IDWT (Inverse Discrete Wavelet 
// Transform) per la ricostruzione del segnale originale a partire dai coefficienti 
// di approssimazione (`cA`) e dettaglio (`cD`), usando il filtro Daubechies 4.
//
// Funzionamento:
// 1. Upsampling (2x): I flussi in ingresso vengono sovracampionati inserendo un 
//    valore a zero alternato a un campione valido. I dati vengono poi traslati 
//    nelle rispettive FIFO da 8 posizioni.
// 2. Convoluzione Duale: I campioni nelle FIFO vengono moltiplicati in parallelo 
//    per i coefficienti dei filtri di sintesi H e G (8 taps).
// 3. Albero di Somma Pipeline: Un albero di riduzione a 3 stadi somma i prodotti 
//    parziali. Questa struttura a stadi riduce i cammini critici combinatori.
// 4. Uscita Dati: Le due componenti vengono sommate, scalate (shift a destra di 16) 
//    e presentate sull'interfaccia Master AXI-Stream.
//
// Parametri:
// - DATA_WIDTH: Larghezza del bus dati in ingresso e in uscita (default: 20 bit).
// ==================================================================================

module Axis_Db4_reconstruction #(
    parameter DATA_WIDTH = 32,
    parameter LEVEL = 1
)(
    input wire clk,
    input wire reset_n,
    
    // AXI-Stream Master Output
    output reg signed [DATA_WIDTH-1:0] m_axis_tdata,
    output reg m_axis_tvalid,
    input  wire m_axis_tready,
    
    // AXI-Stream Slave Inputs
    input  wire signed [DATA_WIDTH-1:0] s_axis_cA_tdata,
    input  wire s_axis_cA_tvalid,
    output wire s_axis_cA_tready,
    
    input  wire signed [DATA_WIDTH-1:0] s_axis_cD_tdata,
    input  wire s_axis_cD_tvalid,
    output wire s_axis_cD_tready
    );

	// Registri interni per cA e cD
	reg signed [DATA_WIDTH-1:0] cA [0:7];
	reg signed [DATA_WIDTH-1:0] cD [0:7];

	// Parametri per i calcoli
	localparam PARAM_WIDTH = 17;
	localparam TERM_WIDTH = DATA_WIDTH + PARAM_WIDTH;
	localparam SUM_WIDTH = TERM_WIDTH + 3;
	localparam TAPS = 8;

	// Coefficienti FIR Db4 (ricostruzione)
	localparam signed [PARAM_WIDTH-1:0] h0 = 17'b11111110101001010;
	localparam signed [PARAM_WIDTH-1:0] h1 = 17'b00000100001101011;
	localparam signed [PARAM_WIDTH-1:0] h2 = 17'b00000011111100101;
	localparam signed [PARAM_WIDTH-1:0] h3 = 17'b11101000000011111;
	localparam signed [PARAM_WIDTH-1:0] h4 = 17'b11111100011010111;
	localparam signed [PARAM_WIDTH-1:0] h5 = 17'b01010000110000001;
	localparam signed [PARAM_WIDTH-1:0] h6 = 17'b01011011100000000;
	localparam signed [PARAM_WIDTH-1:0] h7 = 17'b00011101011111001;

	localparam signed [PARAM_WIDTH-1:0] g0 = h7;
	localparam signed [PARAM_WIDTH-1:0] g1 = ~h6 + 1;
	localparam signed [PARAM_WIDTH-1:0] g2 = h5;
	localparam signed [PARAM_WIDTH-1:0] g3 = ~h4 + 1;
	localparam signed [PARAM_WIDTH-1:0] g4 = h3;
	localparam signed [PARAM_WIDTH-1:0] g5 = ~h2 + 1;
	localparam signed [PARAM_WIDTH-1:0] g6 = h1;
	localparam signed [PARAM_WIDTH-1:0] g7 = ~h0 + 1;

	// Registri per la convoluzione
	reg signed [SUM_WIDTH-1:0] term_cA [0:TAPS-1];
	reg signed [SUM_WIDTH-1:0] term_cD [0:TAPS-1];
	reg signed [SUM_WIDTH-1:0] term_cA1 [0:TAPS/2-1];
	reg signed [SUM_WIDTH-1:0] term_cD1 [0:TAPS/2-1];
	reg signed [SUM_WIDTH-1:0] term_cA2 [0:TAPS/4-1];
	reg signed [SUM_WIDTH-1:0] term_cD2 [0:TAPS/4-1];
	reg signed [SUM_WIDTH-1:0] sum_cA, sum_cD, sum;

    // Indice cicli for
	integer i;
	
	// Controllo pipeline 
	reg new_data, vld_conv;
	reg vld_sum1, vld_sum2, vld_sum3;

	// Accetto CA e cD solo quando il blocco dopo accetta e i dati in ingresso sono validi 
	wire can_accept_data = m_axis_tready && s_axis_cA_tvalid && s_axis_cD_tvalid ;
	
	// Backpressure
    assign s_axis_cA_tready = m_axis_tready;
    assign s_axis_cD_tready = m_axis_tready;
    
    
    /*--- LOGIA UP-SAMPLE ---*/
    reg [31:0] upsamp_cnt;
    
	always @(posedge clk or negedge reset_n) begin
		if (!reset_n) begin
		  upsamp_cnt = 2**(LEVEL-1);
		end else begin	
            if(can_accept_data) begin
              upsamp_cnt = 0;
            end else begin
              upsamp_cnt <= upsamp_cnt +1;
            end 
       end 
	end
    
	/*--- FIFO DATI INGRESSO ---*/
	always @(posedge clk or negedge reset_n) begin
		if (!reset_n) begin

			// reset controllo dati nuovi
			new_data <= 0;

			// Reset dei registri per convoluzione
			for (i=0;i<TAPS;i=i+1) begin
				cA[i] <= 0;
				cD[i] <= 0;
			end 
			
		end else begin	
             
            // Faccio upsample alternando un dato valido e uno zero
            if (can_accept_data) begin           
                cA[0] <= s_axis_cA_tdata;
                cD[0] <= s_axis_cD_tdata;  
                
                // Aggiorno la FIFO cD e cA 
                for (i=TAPS-1;i>0;i=i-1)begin 
                    cA[i] <= cA[i-1];
                    cD[i] <= cD[i-1];				    
                end   
                
                // Metto nuovo dato 
                new_data <= 1'b1;                       				
            end else if (upsamp_cnt == (2**(LEVEL-1))-1) begin 
                cA[0] <= 1'b0;
                cD[0] <= 1'b0;
                
                // Aggiorno la FIFO con i dati upsamplati
                for (i=TAPS-1;i>0;i=i-1)begin 
                    cA[i] <= cA[i-1];
                    cD[i] <= cD[i-1];				    
                end   
                
                // Metto nuovo dato 
                new_data <= 1'b1;                   
            end else begin 
            
                // NEssun nuovo dato
                new_data <= 1'b0;         
            end 
		end
	end

	/*--- CONVOLUZIONE CON H e G ---*/
	always @(posedge clk or negedge reset_n) begin 
		if (!reset_n) begin 
			
			// Reset resgidtri convoluzione
			for (i=0;i<TAPS/2;i=i+1) begin
				term_cA[i] <= 0;
				term_cD[i] <= 0;
			end

		end else begin 
		
			// Esegui la ricostruzione solo se i dat nuovi sono validi
			if (new_data) begin
				
				// Convoluzione valida
				vld_conv <= 1'b1;
				
				// Moltiplicazioni per H
				term_cA[0] <= cA[0]*h0; 
				term_cA[1] <= cA[1]*h1; 
				term_cA[2] <= cA[2]*h2; 
				term_cA[3] <= cA[3]*h3;
				term_cA[4] <= cA[4]*h4; 
				term_cA[5] <= cA[5]*h5; 
				term_cA[6] <= cA[6]*h6; 
				term_cA[7] <= cA[7]*h7;
                
                // Moltiplicazioni per G
				term_cD[0] <= cD[0]*g0; 
				term_cD[1] <= cD[1]*g1; 
				term_cD[2] <= cD[2]*g2; 
				term_cD[3] <= cD[3]*g3;
				term_cD[4] <= cD[4]*g4; 
				term_cD[5] <= cD[5]*g5; 
				term_cD[6] <= cD[6]*g6; 
				term_cD[7] <= cD[7]*g7;
				
			end else
				vld_conv <= 1'b0;
		end
	end

	/*--- SUMMATION TREE ---*/
	always @(posedge clk or negedge reset_n) begin
		if (!reset_n) begin
		
			// Reset livello 1
			for (i=0;i<TAPS/2;i=i+1) begin
				term_cA1[i] <= 0;
				term_cD1[i] <= 0;
			end

			// Reset livello 2
			for (i=0;i<TAPS/4;i=i+1) begin
				term_cA2[i] <= 0;
				term_cD2[i] <= 0;
			end

			// Reset livello finale
			sum_cA <= 0;
			sum_cD <= 0;
			sum <= 0;

			vld_sum1 <= 1'b0;
			vld_sum2 <= 1'b0;
			vld_sum3 <= 1'b0;
			
		end else begin

		    /* -------- LIVELLO 1 -------- */
		    if (vld_conv) begin 
				vld_sum1 <= 1'b1;
				
				for (i=0;i<TAPS/2;i=i+1) begin
					term_cA1[i] <= term_cA[2*i]+term_cA[2*i+1];
					term_cD1[i] <= term_cD[2*i]+term_cD[2*i+1];
				end
		    end else begin
				vld_sum1 <= 1'b0;
		    end

		    /* -------- LIVELLO 2 -------- */
		    if (vld_sum1) begin
				vld_sum2 <= 1'b1;

				for (i=0;i<TAPS/4;i=i+1) begin
					term_cA2[i] <= term_cA1[2*i]+term_cA1[2*i+1];
					term_cD2[i] <= term_cD1[2*i]+term_cD1[2*i+1];
				end
		    end else begin
				vld_sum2 <= 1'b0;
		    end

		    /* -------- LIVELLO 3 -------- */
		    if (vld_sum2) begin
				vld_sum3 <= 1'b1;

				sum_cA <= term_cA2[0]+term_cA2[1];
				sum_cD <= term_cD2[0]+term_cD2[1];
				sum <= (sum_cA + sum_cD) >>> 16;

		    end else begin
				vld_sum3 <= 1'b0;
		    end

	   end
	end	

	/* USCITA DATI */
	always @(posedge clk or negedge reset_n) begin
		if (!reset_n) begin
			m_axis_tdata <= 0;
			m_axis_tvalid <= 0;
		end else begin
	
			// Output AXI-Stream
			if (m_axis_tready && vld_sum3) begin
				m_axis_tdata <= sum[DATA_WIDTH-1:0];
				m_axis_tvalid <= 1;
			end else begin
				m_axis_tvalid <= 0;
			end
		end
	end

endmodule