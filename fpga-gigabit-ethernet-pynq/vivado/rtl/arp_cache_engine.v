`timescale 1ns/1ps

module arp_cache_engine #(
    parameter [47:0] BOARD_MAC = 48'h02_00_00_00_00_01,
    parameter [31:0] BOARD_IP  = 32'hC0A8_010A
) (
    input  wire        clk,
    input  wire        rst,
    input  wire [7:0]  rx_data,
    input  wire        rx_dv,
    output reg  [47:0] cached_dest_mac,
    output reg  [31:0] cached_dest_ip,
    output reg         cached_mac_valid,
    output wire        arp_tx_req,
    output reg  [7:0]  arp_tx_data,
    output wire        arp_tx_valid,
    output wire        arp_tx_last,
    input  wire        arp_tx_ready
);
    reg [7:0] frame_index;
    reg [47:0] sender_mac;
    reg [31:0] sender_ip;
    reg [15:0] arp_opcode;
    reg [31:0] target_ip;
    reg [15:0] ether_type;
    reg preamble_valid;
    reg reply_pending;
    reg [5:0] reply_index;

    assign arp_tx_req   = reply_pending;
    assign arp_tx_valid = reply_pending;
    assign arp_tx_last  = reply_pending && (reply_index == 6'd59);

    always @(posedge clk) begin
        if (rst) begin
            frame_index     <= 8'd0;
            sender_mac      <= 48'd0;
            sender_ip       <= 32'd0;
            arp_opcode      <= 16'd0;
            target_ip       <= 32'd0;
            ether_type      <= 16'd0;
            preamble_valid  <= 1'b0;
            cached_dest_mac <= 48'd0;
            cached_dest_ip  <= 32'd0;
            cached_mac_valid <= 1'b0;
            reply_pending   <= 1'b0;
            reply_index     <= 6'd0;
        end else begin
            if (!rx_dv) begin
                frame_index <= 8'd0;
                preamble_valid <= 1'b1;
            end
            else begin
                if (!reply_pending) begin
                    if (frame_index <= 8'd6 && rx_data != 8'h55)
                        preamble_valid <= 1'b0;
                    if (frame_index == 8'd7 &&
                        (!preamble_valid || rx_data != 8'hD5))
                        preamble_valid <= 1'b0;
                    if (frame_index == 8'd20)
                        ether_type[15:8] <= rx_data;
                    if (frame_index == 8'd21)
                        ether_type[7:0] <= rx_data;
                    if (frame_index == 8'd28)
                        arp_opcode[15:8] <= rx_data;
                    if (frame_index == 8'd29)
                        arp_opcode[7:0] <= rx_data;
                    if (frame_index >= 8'd30 && frame_index <= 8'd35)
                        sender_mac[47 - ((frame_index - 8'd30) * 8) -: 8] <= rx_data;
                    if (frame_index >= 8'd36 && frame_index <= 8'd39)
                        sender_ip[31 - ((frame_index - 8'd36) * 8) -: 8] <= rx_data;
                    if (frame_index >= 8'd46 && frame_index <= 8'd49)
                        target_ip[31 - ((frame_index - 8'd46) * 8) -: 8] <= rx_data;
                    if (frame_index == 8'd49 &&
                        preamble_valid &&
                        ether_type == 16'h0806 &&
                        arp_opcode == 16'h0001 &&
                        {target_ip[31:8], rx_data} == BOARD_IP &&
                        sender_ip != 32'd0 &&
                        sender_mac != 48'd0) begin
                        cached_dest_mac  <= sender_mac;
                        cached_dest_ip   <= sender_ip;
                        cached_mac_valid <= 1'b1;
                        reply_pending    <= 1'b1;
                        reply_index      <= 6'd0;
                    end
                end
                if (frame_index != 8'hFF)
                    frame_index <= frame_index + 1'b1;
            end

            if (reply_pending && arp_tx_ready) begin
                if (reply_index == 6'd59) begin
                    reply_pending <= 1'b0;
                    reply_index   <= 6'd0;
                end else begin
                    reply_index <= reply_index + 1'b1;
                end
            end
        end
    end

    always @* begin
        arp_tx_data = 8'd0;
        case (reply_index)
            0:  arp_tx_data = sender_mac[47:40];
            1:  arp_tx_data = sender_mac[39:32];
            2:  arp_tx_data = sender_mac[31:24];
            3:  arp_tx_data = sender_mac[23:16];
            4:  arp_tx_data = sender_mac[15:8];
            5:  arp_tx_data = sender_mac[7:0];
            6:  arp_tx_data = BOARD_MAC[47:40];
            7:  arp_tx_data = BOARD_MAC[39:32];
            8:  arp_tx_data = BOARD_MAC[31:24];
            9:  arp_tx_data = BOARD_MAC[23:16];
            10: arp_tx_data = BOARD_MAC[15:8];
            11: arp_tx_data = BOARD_MAC[7:0];
            12: arp_tx_data = 8'h08;
            13: arp_tx_data = 8'h06;
            14: arp_tx_data = 8'h00;
            15: arp_tx_data = 8'h01;
            16: arp_tx_data = 8'h08;
            17: arp_tx_data = 8'h00;
            18: arp_tx_data = 8'h06;
            19: arp_tx_data = 8'h04;
            20: arp_tx_data = 8'h00;
            21: arp_tx_data = 8'h02;
            22: arp_tx_data = BOARD_MAC[47:40];
            23: arp_tx_data = BOARD_MAC[39:32];
            24: arp_tx_data = BOARD_MAC[31:24];
            25: arp_tx_data = BOARD_MAC[23:16];
            26: arp_tx_data = BOARD_MAC[15:8];
            27: arp_tx_data = BOARD_MAC[7:0];
            28: arp_tx_data = BOARD_IP[31:24];
            29: arp_tx_data = BOARD_IP[23:16];
            30: arp_tx_data = BOARD_IP[15:8];
            31: arp_tx_data = BOARD_IP[7:0];
            32: arp_tx_data = sender_mac[47:40];
            33: arp_tx_data = sender_mac[39:32];
            34: arp_tx_data = sender_mac[31:24];
            35: arp_tx_data = sender_mac[23:16];
            36: arp_tx_data = sender_mac[15:8];
            37: arp_tx_data = sender_mac[7:0];
            38: arp_tx_data = sender_ip[31:24];
            39: arp_tx_data = sender_ip[23:16];
            40: arp_tx_data = sender_ip[15:8];
            41: arp_tx_data = sender_ip[7:0];
            default: arp_tx_data = 8'd0;
        endcase
    end
endmodule
