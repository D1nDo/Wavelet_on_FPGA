
module axis_combiner_32to32_lsb (
    input  wire        clk,
    input  wire        rst_n,   

    // Ingresso 0
    input  wire [31:0] s0_tdata,
    input  wire        s0_tvalid,
    output wire        s0_tready,

    // Ingresso 1
    input  wire [31:0] s1_tdata,
    input  wire        s1_tvalid,
    output wire        s1_tready,

    // Uscita
    output wire [31:0] m_tdata,
    output wire        m_tvalid,
    input  wire        m_tready
);

    reg [31:0] m_tdata_reg;
    reg        m_tvalid_reg;

    wire both_valid = s0_tvalid & s1_tvalid;
    
    wire accept = both_valid & (~m_tvalid_reg | m_tready);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_tdata_reg  <= 32'd0;
            m_tvalid_reg <= 1'b0;
        end else begin
            if (accept) begin
                m_tdata_reg  <= {s1_tdata[15:0], s0_tdata[15:0]};
                m_tvalid_reg <= 1'b1;
            end else if (m_tready) begin
                m_tvalid_reg <= 1'b0;
            end
        end
    end

    assign m_tdata  = m_tdata_reg;
    assign m_tvalid = m_tvalid_reg;

    assign s0_tready = accept;
    assign s1_tready = accept;

endmodule