`timescale 1ns/1ps

module rgmii_to_gmii (
    input  wire       rst,
    input  wire       tx_clk,
    input  wire [7:0] gmii_txd,
    input  wire       gmii_tx_en,
    input  wire       gmii_tx_er,
    output wire       rgmii_txc,
    output wire [3:0] rgmii_txd,
    output wire       rgmii_tx_ctl,
    input  wire       rgmii_rxc,
    input  wire [3:0] rgmii_rxd,
    input  wire       rgmii_rx_ctl,
    output reg  [7:0] gmii_rxd,
    output reg        gmii_rx_dv,
    output reg        gmii_rx_er
);
    wire [3:0] rx_rise;
    wire [3:0] rx_fall;
    wire rx_ctl_rise;
    wire rx_ctl_fall;
    genvar bit_index;

    generate
        for (bit_index = 0; bit_index < 4; bit_index = bit_index + 1) begin : gen_rx_iddr
            IDDR #(
                .DDR_CLK_EDGE("SAME_EDGE_PIPELINED"),
                .INIT_Q1(1'b0),
                .INIT_Q2(1'b0),
                .SRTYPE("SYNC")
            ) iddr_rxd (
                .Q1(rx_rise[bit_index]),
                .Q2(rx_fall[bit_index]),
                .C(rgmii_rxc),
                .CE(1'b1),
                .D(rgmii_rxd[bit_index]),
                .R(rst),
                .S(1'b0)
            );
        end
    endgenerate

    IDDR #(
        .DDR_CLK_EDGE("SAME_EDGE_PIPELINED"),
        .INIT_Q1(1'b0),
        .INIT_Q2(1'b0),
        .SRTYPE("SYNC")
    ) iddr_rx_ctl (
        .Q1(rx_ctl_rise),
        .Q2(rx_ctl_fall),
        .C(rgmii_rxc),
        .CE(1'b1),
        .D(rgmii_rx_ctl),
        .R(rst),
        .S(1'b0)
    );

    always @(posedge rgmii_rxc) begin
        if (rst) begin
            gmii_rxd   <= 8'd0;
            gmii_rx_dv <= 1'b0;
            gmii_rx_er <= 1'b0;
        end else begin
            gmii_rxd   <= {rx_fall, rx_rise};
            gmii_rx_dv <= rx_ctl_rise;
            gmii_rx_er <= rx_ctl_rise ^ rx_ctl_fall;
        end
    end

    ODDR #(
        .DDR_CLK_EDGE("SAME_EDGE"),
        .INIT(1'b0),
        .SRTYPE("SYNC")
    ) oddr_txc (
        .Q(rgmii_txc),
        .C(tx_clk),
        .CE(1'b1),
        .D1(1'b1),
        .D2(1'b0),
        .R(rst),
        .S(1'b0)
    );

    generate
        for (bit_index = 0; bit_index < 4; bit_index = bit_index + 1) begin : gen_tx_oddr
            ODDR #(
                .DDR_CLK_EDGE("SAME_EDGE"),
                .INIT(1'b0),
                .SRTYPE("SYNC")
            ) oddr_txd (
                .Q(rgmii_txd[bit_index]),
                .C(tx_clk),
                .CE(1'b1),
                .D1(gmii_txd[bit_index]),
                .D2(gmii_txd[bit_index + 4]),
                .R(rst),
                .S(1'b0)
            );
        end
    endgenerate

    ODDR #(
        .DDR_CLK_EDGE("SAME_EDGE"),
        .INIT(1'b0),
        .SRTYPE("SYNC")
    ) oddr_tx_ctl (
        .Q(rgmii_tx_ctl),
        .C(tx_clk),
        .CE(1'b1),
        .D1(gmii_tx_en),
        .D2(gmii_tx_en ^ gmii_tx_er),
        .R(rst),
        .S(1'b0)
    );
endmodule
