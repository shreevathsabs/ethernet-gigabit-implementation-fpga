`timescale 1ns/1ps

module udp_ip_tx #(
    parameter [47:0] BOARD_MAC = 48'h02_00_00_00_00_01,
    parameter [31:0] BOARD_IP  = 32'hC0A8_010A
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire [47:0] dest_mac,
    input  wire [31:0] dest_ip,
    input  wire [15:0] src_port,
    input  wire [15:0] dest_port,
    input  wire [10:0] payload_len,
    output wire [10:0] payload_addr,
    input  wire [7:0]  payload_data,
    output wire [7:0]  tx_data,
    output wire        tx_valid,
    output wire        tx_last,
    input  wire        tx_ready,
    output wire        busy,
    output reg         done
);
    reg active;
    reg [10:0] index;
    reg [10:0] payload_length;
    reg [47:0] dst_mac_latched;
    reg [31:0] dst_ip_latched;
    reg [15:0] src_port_latched;
    reg [15:0] dst_port_latched;
    reg [15:0] ip_checksum;
    reg [15:0] ip_total_length;
    reg [15:0] udp_total_length;
    reg [10:0] frame_length;
    reg [7:0] frame_byte;

    function [15:0] calc_ip_checksum;
        input [15:0] ip_total_length;
        input [31:0] source_ip;
        input [31:0] destination_ip;
        reg [31:0] checksum_sum;
        begin
            checksum_sum = 32'h4500 + ip_total_length + 32'h4000 +
                           32'h4011 + source_ip[31:16] + source_ip[15:0] +
                           destination_ip[31:16] + destination_ip[15:0];
            checksum_sum = (checksum_sum & 32'h0000FFFF) +
                           (checksum_sum >> 16);
            checksum_sum = (checksum_sum & 32'h0000FFFF) +
                           (checksum_sum >> 16);
            calc_ip_checksum = ~checksum_sum[15:0];
        end
    endfunction

    assign busy = active;
    assign tx_valid = active;
    assign tx_last = active && (index == frame_length - 1'b1);
    assign tx_data = frame_byte;
    assign payload_addr = index - 11'd42;

    always @* begin
        frame_byte = 8'd0;
        if (index < 11'd6)
            frame_byte = dst_mac_latched[47 - (index * 8) -: 8];
        else if (index < 11'd12)
            frame_byte = BOARD_MAC[47 - ((index - 11'd6) * 8) -: 8];
        else if (index == 11'd12)
            frame_byte = 8'h08;
        else if (index == 11'd13)
            frame_byte = 8'h00;
        else if (index == 11'd14)
            frame_byte = 8'h45;
        else if (index == 11'd15)
            frame_byte = 8'h00;
        else if (index == 11'd16)
            frame_byte = ip_total_length[15:8];
        else if (index == 11'd17)
            frame_byte = ip_total_length[7:0];
        else if (index == 11'd18 || index == 11'd19)
            frame_byte = 8'd0;
        else if (index == 11'd20)
            frame_byte = 8'h40;
        else if (index == 11'd21)
            frame_byte = 8'd0;
        else if (index == 11'd22)
            frame_byte = 8'h40;
        else if (index == 11'd23)
            frame_byte = 8'h11;
        else if (index == 11'd24)
            frame_byte = ip_checksum[15:8];
        else if (index == 11'd25)
            frame_byte = ip_checksum[7:0];
        else if (index >= 11'd26 && index < 11'd30)
            frame_byte = BOARD_IP[31 - ((index - 11'd26) * 8) -: 8];
        else if (index >= 11'd30 && index < 11'd34)
            frame_byte = dst_ip_latched[31 - ((index - 11'd30) * 8) -: 8];
        else if (index == 11'd34)
            frame_byte = src_port_latched[15:8];
        else if (index == 11'd35)
            frame_byte = src_port_latched[7:0];
        else if (index == 11'd36)
            frame_byte = dst_port_latched[15:8];
        else if (index == 11'd37)
            frame_byte = dst_port_latched[7:0];
        else if (index == 11'd38)
            frame_byte = udp_total_length[15:8];
        else if (index == 11'd39)
            frame_byte = udp_total_length[7:0];
        else if (index >= 11'd42 && index < 11'd42 + payload_length)
            frame_byte = payload_data;
    end

    always @(posedge clk) begin
        if (rst) begin
            active          <= 1'b0;
            index           <= 11'd0;
            payload_length  <= 11'd0;
            dst_mac_latched <= 48'd0;
            dst_ip_latched  <= 32'd0;
            src_port_latched <= 16'd0;
            dst_port_latched <= 16'd0;
            ip_checksum     <= 16'd0;
            ip_total_length <= 16'd0;
            udp_total_length <= 16'd0;
            frame_length    <= 11'd0;
            done            <= 1'b0;
        end else begin
            done <= 1'b0;
            if (start && !active && payload_len <= 11'd1472) begin
                active           <= 1'b1;
                index            <= 11'd0;
                payload_length   <= payload_len;
                dst_mac_latched  <= dest_mac;
                dst_ip_latched   <= dest_ip;
                src_port_latched <= src_port;
                dst_port_latched <= dest_port;
                ip_total_length  <= 16'd28 + payload_len;
                udp_total_length <= 16'd8 + payload_len;
                ip_checksum      <= calc_ip_checksum(16'd28 + payload_len,
                                                       BOARD_IP, dest_ip);
                if (payload_len + 16'd42 < 16'd60)
                    frame_length <= 11'd60;
                else
                    frame_length <= payload_len + 11'd42;
            end else if (active && tx_ready) begin
                if (index == frame_length - 1'b1) begin
                    active <= 1'b0;
                    index <= 11'd0;
                    done <= 1'b1;
                end else begin
                    index <= index + 1'b1;
                end
            end
        end
    end
endmodule
