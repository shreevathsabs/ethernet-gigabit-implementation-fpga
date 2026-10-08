`timescale 1ns/1ps

module udp_ip_rx #(
    parameter [47:0] BOARD_MAC = 48'h02_00_00_00_00_01,
    parameter [31:0] BOARD_IP  = 32'hC0A8_010A
) (
    input  wire        clk,
    input  wire        rst,
    input  wire [7:0]  rx_data,
    input  wire        rx_dv,
    output reg  [7:0]  payload_byte,
    output reg         payload_valid,
    output reg  [10:0] payload_len,
    output reg  [31:0] src_ip,
    output reg  [15:0] src_port
);
    reg [7:0] frame_index;
    reg [47:0] dst_mac;
    reg [15:0] ether_type;
    reg [7:0] ip_protocol;
    reg [31:0] dst_ip;
    reg [31:0] source_ip;
    reg [15:0] udp_length;
    reg [15:0] udp_source_port;
    reg preamble_valid;
    reg destination_valid;
    reg ether_valid;
    reg protocol_valid;
    reg ip_valid;
    reg [10:0] payload_remaining;
    reg payload_active;

    always @(posedge clk) begin
        if (rst) begin
            frame_index       <= 8'd0;
            dst_mac           <= 48'd0;
            ether_type        <= 16'd0;
            ip_protocol       <= 8'd0;
            dst_ip            <= 32'd0;
            source_ip         <= 32'd0;
            udp_length         <= 16'd0;
            udp_source_port   <= 16'd0;
            preamble_valid    <= 1'b0;
            destination_valid <= 1'b0;
            ether_valid       <= 1'b0;
            protocol_valid    <= 1'b0;
            ip_valid          <= 1'b0;
            payload_remaining <= 11'd0;
            payload_active    <= 1'b0;
            payload_byte      <= 8'd0;
            payload_valid     <= 1'b0;
            payload_len       <= 11'd0;
            src_ip            <= 32'd0;
            src_port          <= 16'd0;
        end else begin
            payload_valid <= 1'b0;
            if (!rx_dv) begin
                frame_index <= 8'd0;
                preamble_valid <= 1'b1;
                payload_active <= 1'b0;
                payload_remaining <= 11'd0;
                destination_valid <= 1'b0;
                ether_valid <= 1'b0;
                protocol_valid <= 1'b0;
                ip_valid <= 1'b0;
            end else begin
                if (frame_index <= 8'd6 && rx_data != 8'h55)
                    preamble_valid <= 1'b0;
                if (frame_index == 8'd7 &&
                    (!preamble_valid || rx_data != 8'hD5))
                    preamble_valid <= 1'b0;
                if (frame_index >= 8'd8 && frame_index <= 8'd13)
                    dst_mac[47 - ((frame_index - 8'd8) * 8) -: 8] <= rx_data;
                if (frame_index == 8'd13)
                    destination_valid <=
                        preamble_valid &&
                        (({dst_mac[47:8], rx_data} == BOARD_MAC) ||
                         ({dst_mac[47:8], rx_data} == 48'hFF_FF_FF_FF_FF_FF));
                if (frame_index == 8'd20)
                    ether_type[15:8] <= rx_data;
                if (frame_index == 8'd21) begin
                    ether_type[7:0] <= rx_data;
                    ether_valid <= (ether_type[15:8] == 8'h08 && rx_data == 8'h00);
                end
                if (frame_index == 8'd31) begin
                    ip_protocol <= rx_data;
                    protocol_valid <= (rx_data == 8'h11);
                end
                if (frame_index >= 8'd34 && frame_index <= 8'd37)
                    source_ip[31 - ((frame_index - 8'd34) * 8) -: 8] <= rx_data;
                if (frame_index >= 8'd38 && frame_index <= 8'd41)
                    dst_ip[31 - ((frame_index - 8'd38) * 8) -: 8] <= rx_data;
                if (frame_index == 8'd41) begin
                    ip_valid <= (dst_ip[31:8] == BOARD_IP[31:8] &&
                                 rx_data == BOARD_IP[7:0]);
                end
                if (frame_index == 8'd42)
                    udp_source_port[15:8] <= rx_data;
                if (frame_index == 8'd43)
                    udp_source_port[7:0] <= rx_data;
                if (frame_index == 8'd46)
                    udp_length[15:8] <= rx_data;
                if (frame_index == 8'd47) begin
                    udp_length[7:0] <= rx_data;
                    if (udp_length[15:8] == 0 && rx_data >= 8'd8)
                        payload_len <= rx_data - 8;
                    else
                        payload_len <= {udp_length[15:8], rx_data} - 16'd8;
                end
                if (frame_index == 8'd49) begin
                    if (destination_valid && ether_valid && protocol_valid &&
                        ip_valid && udp_length >= 16'd8 &&
                        udp_length <= 16'd1480) begin
                        payload_remaining <= udp_length[10:0] - 11'd8;
                        src_ip <= source_ip;
                        src_port <= udp_source_port;
                        payload_active <= (udp_length > 16'd8);
                    end
                end
                if (frame_index >= 8'd50 && payload_active &&
                    payload_remaining != 0) begin
                    payload_byte <= rx_data;
                    payload_valid <= 1'b1;
                    payload_remaining <= payload_remaining - 1'b1;
                    if (payload_remaining == 1)
                        payload_active <= 1'b0;
                end
                if (frame_index != 8'hFF)
                    frame_index <= frame_index + 1'b1;
            end
        end
    end
endmodule
