`timescale 1ns/1ps

module mac_ip_udp_axis_top #(
    parameter [47:0] BOARD_MAC = 48'h02_00_00_00_00_01,
    parameter [31:0] BOARD_IP = 32'hC0A8_010A,
    parameter [15:0] UDP_PORT = 16'd5001
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        rgmii_rxc,
    input  wire [3:0]  rgmii_rxd,
    input  wire        rgmii_rx_ctl,
    output wire        rgmii_txc,
    output wire [3:0]  rgmii_txd,
    output wire        rgmii_tx_ctl,
    input  wire [7:0]  s_axis_tx_tdata,
    input  wire        s_axis_tx_tvalid,
    input  wire        s_axis_tx_tlast,
    output wire        s_axis_tx_tready,
    output wire [7:0]  m_axis_rx_tdata,
    output wire        m_axis_rx_tvalid,
    output wire        m_axis_rx_tlast,
    input  wire        m_axis_rx_tready
);
    localparam [2:0] TX_IDLE = 3'd0;
    localparam [2:0] TX_PREAMBLE = 3'd1;
    localparam [2:0] TX_BODY = 3'd2;
    localparam [2:0] TX_FCS = 3'd3;
    localparam [2:0] TX_IFG = 3'd4;

    reg [7:0] tx_packet_mem [0:2047];
    reg [11:0] tx_write_count;
    reg [10:0] tx_packet_length;
    reg tx_packet_pending;
    wire tx_packet_start;
    wire [10:0] udp_payload_addr;
    wire [7:0] udp_payload_data;
    wire [7:0] udp_data;
    wire udp_valid;
    wire udp_last;
    wire udp_busy;
    wire udp_done;
    wire [7:0] arp_data;
    wire arp_req;
    wire arp_valid;
    wire arp_last;
    wire [47:0] cached_mac;
    wire [31:0] cached_ip;
    wire cached_valid;
    wire [7:0] gmii_rxd;
    wire gmii_rx_dv;
    wire gmii_rx_er;
    wire [7:0] gmii_txd;
    wire gmii_tx_en;
    wire [7:0] rx_payload;
    wire rx_payload_valid;
    wire [10:0] rx_payload_len;
    wire [31:0] rx_src_ip;
    wire [15:0] rx_src_port;
    wire [31:0] crc_out;
    wire crc_init;
    wire crc_calc_en;
    wire [7:0] crc_data;
    reg [2:0] tx_state;
    reg [3:0] preamble_count;
    reg [3:0] ifg_count;
    reg [2:0] fcs_count;
    reg selected_arp;
    reg udp_start_reg;
    reg [7:0] gmii_tx_byte;
    wire udp_ready;
    wire arp_ready;
    wire body_transfer;

    reg [7:0] rx_fifo_data [0:2047];
    reg rx_fifo_last [0:2047];
    reg [10:0] rx_write_ptr;
    reg [10:0] rx_read_ptr;
    reg [11:0] rx_fifo_count;
    reg [10:0] rx_remaining;
    reg rx_length_loaded;
    wire rx_push;
    wire rx_pop;

    assign s_axis_tx_tready = !tx_packet_pending &&
                              (tx_write_count < 12'd2048);
    assign udp_payload_data = tx_packet_mem[udp_payload_addr];
    assign tx_packet_start = (tx_state == TX_IDLE) && !arp_req &&
                             tx_packet_pending && cached_valid && !udp_busy;
    assign udp_ready = (tx_state == TX_BODY) && !selected_arp;
    assign arp_ready = (tx_state == TX_BODY) && selected_arp;
    assign body_transfer = (tx_state == TX_BODY) &&
                           ((selected_arp && arp_valid) ||
                            (!selected_arp && udp_valid));
    assign crc_init = (tx_state == TX_PREAMBLE && preamble_count == 4'd7);
    assign crc_calc_en = body_transfer;
    assign crc_data = selected_arp ? arp_data : udp_data;
    assign gmii_tx_en = (tx_state == TX_PREAMBLE) ||
                        (tx_state == TX_BODY) || (tx_state == TX_FCS);
    assign gmii_txd = gmii_tx_byte;

    always @* begin
        gmii_tx_byte = 8'h00;
        case (tx_state)
            TX_PREAMBLE:
                if (preamble_count == 4'd7)
                    gmii_tx_byte = 8'hD5;
                else
                    gmii_tx_byte = 8'h55;
            TX_BODY:
                gmii_tx_byte = crc_data;
            TX_FCS:
                case (fcs_count)
                    3'd0: gmii_tx_byte = crc_out[7:0];
                    3'd1: gmii_tx_byte = crc_out[15:8];
                    3'd2: gmii_tx_byte = crc_out[23:16];
                    default: gmii_tx_byte = crc_out[31:24];
                endcase
            default:
                gmii_tx_byte = 8'h00;
        endcase
    end

    rgmii_to_gmii rgmii_bridge (
        .rst(rst),
        .tx_clk(clk),
        .gmii_txd(gmii_txd),
        .gmii_tx_en(gmii_tx_en),
        .gmii_tx_er(1'b0),
        .rgmii_txc(rgmii_txc),
        .rgmii_txd(rgmii_txd),
        .rgmii_tx_ctl(rgmii_tx_ctl),
        .rgmii_rxc(rgmii_rxc),
        .rgmii_rxd(rgmii_rxd),
        .rgmii_rx_ctl(rgmii_rx_ctl),
        .gmii_rxd(gmii_rxd),
        .gmii_rx_dv(gmii_rx_dv),
        .gmii_rx_er(gmii_rx_er)
    );

    crc32_d8 tx_crc (
        .clk(clk),
        .rst(rst),
        .init(crc_init),
        .calc_en(crc_calc_en),
        .data_in(crc_data),
        .crc_out(crc_out)
    );

    arp_cache_engine #(
        .BOARD_MAC(BOARD_MAC),
        .BOARD_IP(BOARD_IP)
    ) arp_engine (
        .clk(clk),
        .rst(rst),
        .rx_data(gmii_rxd),
        .rx_dv(gmii_rx_dv),
        .cached_dest_mac(cached_mac),
        .cached_dest_ip(cached_ip),
        .cached_mac_valid(cached_valid),
        .arp_tx_req(arp_req),
        .arp_tx_data(arp_data),
        .arp_tx_valid(arp_valid),
        .arp_tx_last(arp_last),
        .arp_tx_ready(arp_ready)
    );

    udp_ip_tx #(
        .BOARD_MAC(BOARD_MAC),
        .BOARD_IP(BOARD_IP)
    ) udp_tx (
        .clk(clk),
        .rst(rst),
        .start(udp_start_reg),
        .dest_mac(cached_mac),
        .dest_ip(cached_ip),
        .src_port(UDP_PORT),
        .dest_port(UDP_PORT),
        .payload_len(tx_packet_length),
        .payload_addr(udp_payload_addr),
        .payload_data(udp_payload_data),
        .tx_data(udp_data),
        .tx_valid(udp_valid),
        .tx_last(udp_last),
        .tx_ready(udp_ready),
        .busy(udp_busy),
        .done(udp_done)
    );

    udp_ip_rx #(
        .BOARD_MAC(BOARD_MAC),
        .BOARD_IP(BOARD_IP)
    ) udp_rx (
        .clk(clk),
        .rst(rst),
        .rx_data(gmii_rxd),
        .rx_dv(gmii_rx_dv && !gmii_rx_er),
        .payload_byte(rx_payload),
        .payload_valid(rx_payload_valid),
        .payload_len(rx_payload_len),
        .src_ip(rx_src_ip),
        .src_port(rx_src_port)
    );

    assign rx_push = rx_payload_valid && (rx_fifo_count < 12'd2048);
    assign rx_pop = m_axis_rx_tvalid && m_axis_rx_tready;
    assign m_axis_rx_tvalid = (rx_fifo_count != 0);
    assign m_axis_rx_tdata = rx_fifo_data[rx_read_ptr];
    assign m_axis_rx_tlast = rx_fifo_last[rx_read_ptr];

    always @(posedge clk) begin
        if (rst) begin
            tx_write_count   <= 11'd0;
            tx_packet_length <= 11'd0;
            tx_packet_pending <= 1'b0;
            tx_state         <= TX_IDLE;
            preamble_count   <= 4'd0;
            ifg_count        <= 4'd0;
            fcs_count        <= 3'd0;
            selected_arp     <= 1'b0;
            udp_start_reg    <= 1'b0;
        end else begin
            udp_start_reg <= 1'b0;
            if (s_axis_tx_tvalid && s_axis_tx_tready) begin
                tx_packet_mem[tx_write_count[10:0]] <= s_axis_tx_tdata;
                if (tx_write_count < 12'd2048)
                    tx_write_count <= tx_write_count + 1'b1;
                if (s_axis_tx_tlast) begin
                    tx_packet_length <= tx_write_count + 1'b1;
                    tx_packet_pending <= (tx_write_count < 12'd1472);
                    tx_write_count <= 12'd0;
                end
            end

            case (tx_state)
                TX_IDLE: begin
                    if (arp_req) begin
                        selected_arp <= 1'b1;
                        preamble_count <= 4'd0;
                        tx_state <= TX_PREAMBLE;
                    end else if (tx_packet_start) begin
                        selected_arp <= 1'b0;
                        udp_start_reg <= 1'b1;
                        preamble_count <= 4'd0;
                        tx_state <= TX_PREAMBLE;
                    end
                end
                TX_PREAMBLE: begin
                    if (preamble_count == 4'd7) begin
                        preamble_count <= 4'd0;
                        tx_state <= TX_BODY;
                    end else begin
                        preamble_count <= preamble_count + 1'b1;
                    end
                end
                TX_BODY: begin
                    if (body_transfer &&
                        ((selected_arp && arp_last) ||
                         (!selected_arp && udp_last))) begin
                        fcs_count <= 3'd0;
                        tx_state <= TX_FCS;
                    end
                end
                TX_FCS: begin
                    if (fcs_count == 3'd3) begin
                        ifg_count <= 4'd0;
                        tx_state <= TX_IFG;
                    end else begin
                        fcs_count <= fcs_count + 1'b1;
                    end
                end
                TX_IFG: begin
                    if (ifg_count == 4'd11) begin
                        ifg_count <= 4'd0;
                        tx_state <= TX_IDLE;
                    end else begin
                        ifg_count <= ifg_count + 1'b1;
                    end
                end
                default: tx_state <= TX_IDLE;
            endcase

            if (udp_done) begin
                tx_packet_pending <= 1'b0;
                tx_packet_length <= 11'd0;
            end
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            rx_write_ptr <= 11'd0;
            rx_read_ptr <= 11'd0;
            rx_fifo_count <= 12'd0;
            rx_remaining <= 11'd0;
            rx_length_loaded <= 1'b0;
        end else begin
            if (rx_payload_valid && !rx_length_loaded) begin
                rx_length_loaded <= 1'b1;
            end
            if (!gmii_rx_dv)
                rx_length_loaded <= 1'b0;

            if (rx_push) begin
                rx_fifo_data[rx_write_ptr] <= rx_payload;
                rx_fifo_last[rx_write_ptr] <= rx_length_loaded ?
                                               (rx_remaining == 11'd1) :
                                               (rx_payload_len == 11'd1);
                rx_write_ptr <= rx_write_ptr + 1'b1;
                if (!rx_length_loaded && rx_payload_len != 0)
                    rx_remaining <= rx_payload_len - 1'b1;
                else if (rx_remaining != 0)
                    rx_remaining <= rx_remaining - 1'b1;
            end
            if (rx_pop)
                rx_read_ptr <= rx_read_ptr + 1'b1;

            case ({rx_push, rx_pop})
                2'b10: rx_fifo_count <= rx_fifo_count + 1'b1;
                2'b01: rx_fifo_count <= rx_fifo_count - 1'b1;
                default: rx_fifo_count <= rx_fifo_count;
            endcase
        end
    end
endmodule
