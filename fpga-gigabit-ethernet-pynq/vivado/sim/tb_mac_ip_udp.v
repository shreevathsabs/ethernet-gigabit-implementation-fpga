`timescale 1ns/1ps

module tb_mac_ip_udp;
    reg clk;
    reg rst;
    reg rgmii_rxc;
    reg [3:0] rgmii_rxd;
    reg rgmii_rx_ctl;
    wire rgmii_txc;
    wire [3:0] rgmii_txd;
    wire rgmii_tx_ctl;
    reg [7:0] s_axis_tx_tdata;
    reg s_axis_tx_tvalid;
    reg s_axis_tx_tlast;
    wire s_axis_tx_tready;
    wire [7:0] m_axis_rx_tdata;
    wire m_axis_rx_tvalid;
    wire m_axis_rx_tlast;
    reg m_axis_rx_tready;
    reg [3:0] tx_low_nibble;
    reg tx_ctl_rise;
    reg rx_byte_started;
    reg [7:0] tx_capture [0:8191];
    integer tx_capture_count;
    reg [7:0] arp_frame [0:59];
    integer i;
    integer frame_start;
    integer body_start;
    integer frame_end;
    integer found;
    reg [31:0] crc_value;
    reg [7:0] payload_value;

    localparam [47:0] PEER_MAC = 48'h02_11_22_33_44_55;
    localparam [31:0] PEER_IP = 32'hC0A8_0101;
    localparam [31:0] BOARD_IP = 32'hC0A8_010A;

    mac_ip_udp_axis_top #(
        .BOARD_MAC(48'h02_00_00_00_00_01),
        .BOARD_IP(BOARD_IP),
        .UDP_PORT(16'd5001)
    ) dut (
        .clk(clk),
        .rst(rst),
        .rgmii_rxc(rgmii_rxc),
        .rgmii_rxd(rgmii_rxd),
        .rgmii_rx_ctl(rgmii_rx_ctl),
        .rgmii_txc(rgmii_txc),
        .rgmii_txd(rgmii_txd),
        .rgmii_tx_ctl(rgmii_tx_ctl),
        .s_axis_tx_tdata(s_axis_tx_tdata),
        .s_axis_tx_tvalid(s_axis_tx_tvalid),
        .s_axis_tx_tlast(s_axis_tx_tlast),
        .s_axis_tx_tready(s_axis_tx_tready),
        .m_axis_rx_tdata(m_axis_rx_tdata),
        .m_axis_rx_tvalid(m_axis_rx_tvalid),
        .m_axis_rx_tlast(m_axis_rx_tlast),
        .m_axis_rx_tready(m_axis_rx_tready)
    );

    initial begin
        clk = 1'b0;
        forever #4 clk = ~clk;
    end

    initial begin
        rgmii_rxc = 1'b0;
        forever #4 rgmii_rxc = ~rgmii_rxc;
    end

    initial begin
        tx_capture_count = 0;
        tx_low_nibble = 4'd0;
        tx_ctl_rise = 1'b0;
        rx_byte_started = 1'b0;
    end

    always @(posedge rgmii_txc) begin
        #1;
        tx_low_nibble = rgmii_txd;
        tx_ctl_rise = rgmii_tx_ctl;
    end

    always @(negedge rgmii_txc) begin
        #1;
        if (tx_ctl_rise && rgmii_tx_ctl && tx_capture_count < 8192) begin
            tx_capture[tx_capture_count] = {rgmii_txd, tx_low_nibble};
            tx_capture_count = tx_capture_count + 1;
        end
    end

    task send_rgmii_byte;
        input [7:0] value;
        begin
            if (!rx_byte_started) begin
                @(negedge rgmii_rxc);
                rx_byte_started = 1'b1;
            end
            rgmii_rxd = value[3:0];
            rgmii_rx_ctl = 1'b1;
            @(posedge rgmii_rxc);
            #1;
            rgmii_rxd = value[7:4];
            @(negedge rgmii_rxc);
            #1;
        end
    endtask

    function [31:0] crc_byte;
        input [31:0] crc_in;
        input [7:0] data;
        reg [31:0] c;
        integer b;
        begin
            c = crc_in ^ data;
            for (b = 0; b < 8; b = b + 1) begin
                if (c[0])
                    c = (c >> 1) ^ 32'hEDB88320;
                else
                    c = c >> 1;
            end
            crc_byte = c;
        end
    endfunction

    task locate_and_check_frame;
        input integer from_index;
        input [15:0] expected_type;
        input integer data_length;
        output integer frame_index;
        integer scan;
        integer b;
        reg matched;
        begin
            frame_index = -1;
            for (scan = from_index; scan + 8 + data_length + 4 <= tx_capture_count;
                 scan = scan + 1) begin
                matched = 1'b1;
                for (b = 0; b < 7; b = b + 1)
                    if (tx_capture[scan + b] != 8'h55)
                        matched = 1'b0;
                if (tx_capture[scan + 7] != 8'hD5)
                    matched = 1'b0;
                if (tx_capture[scan + 8 + 12] != expected_type[15:8] ||
                    tx_capture[scan + 8 + 13] != expected_type[7:0])
                    matched = 1'b0;
                if (matched && frame_index == -1)
                    frame_index = scan;
            end
            if (frame_index < 0)
                begin
                    $display("FAIL: frame type %04x not observed", expected_type);
                    $stop;
                end
            body_start = frame_index + 8;
            frame_end = body_start + data_length;
            crc_value = 32'hFFFFFFFF;
            for (b = body_start; b < frame_end; b = b + 1)
                crc_value = crc_byte(crc_value, tx_capture[b]);
            crc_value = ~crc_value;
            if (tx_capture[frame_end] != crc_value[7:0] ||
                tx_capture[frame_end + 1] != crc_value[15:8] ||
                tx_capture[frame_end + 2] != crc_value[23:16] ||
                tx_capture[frame_end + 3] != crc_value[31:24])
                begin
                    $display("FAIL: bad FCS on frame type %04x", expected_type);
                    $stop;
                end
        end
    endtask

    initial begin
        rst = 1'b1;
        rgmii_rxd = 4'd0;
        rgmii_rx_ctl = 1'b0;
        s_axis_tx_tdata = 8'd0;
        s_axis_tx_tvalid = 1'b0;
        s_axis_tx_tlast = 1'b0;
        m_axis_rx_tready = 1'b1;
        repeat (10) @(posedge clk);
        rst = 1'b0;

        for (i = 0; i < 60; i = i + 1)
            arp_frame[i] = 8'd0;
        arp_frame[0] = 8'hFF; arp_frame[1] = 8'hFF; arp_frame[2] = 8'hFF;
        arp_frame[3] = 8'hFF; arp_frame[4] = 8'hFF; arp_frame[5] = 8'hFF;
        arp_frame[6] = PEER_MAC[47:40]; arp_frame[7] = PEER_MAC[39:32];
        arp_frame[8] = PEER_MAC[31:24]; arp_frame[9] = PEER_MAC[23:16];
        arp_frame[10] = PEER_MAC[15:8]; arp_frame[11] = PEER_MAC[7:0];
        arp_frame[12] = 8'h08; arp_frame[13] = 8'h06;
        arp_frame[14] = 8'h00; arp_frame[15] = 8'h01;
        arp_frame[16] = 8'h08; arp_frame[17] = 8'h00;
        arp_frame[18] = 8'h06; arp_frame[19] = 8'h04;
        arp_frame[20] = 8'h00; arp_frame[21] = 8'h01;
        arp_frame[22] = PEER_MAC[47:40]; arp_frame[23] = PEER_MAC[39:32];
        arp_frame[24] = PEER_MAC[31:24]; arp_frame[25] = PEER_MAC[23:16];
        arp_frame[26] = PEER_MAC[15:8]; arp_frame[27] = PEER_MAC[7:0];
        arp_frame[28] = PEER_IP[31:24]; arp_frame[29] = PEER_IP[23:16];
        arp_frame[30] = PEER_IP[15:8]; arp_frame[31] = PEER_IP[7:0];
        arp_frame[32] = 8'h00; arp_frame[33] = 8'h00;
        arp_frame[34] = 8'h00; arp_frame[35] = 8'h00;
        arp_frame[36] = 8'h00; arp_frame[37] = 8'h00;
        arp_frame[38] = BOARD_IP[31:24]; arp_frame[39] = BOARD_IP[23:16];
        arp_frame[40] = BOARD_IP[15:8]; arp_frame[41] = BOARD_IP[7:0];

        for (i = 0; i < 7; i = i + 1)
            send_rgmii_byte(8'h55);
        send_rgmii_byte(8'hD5);
        for (i = 0; i < 60; i = i + 1)
            send_rgmii_byte(arp_frame[i]);
        rgmii_rx_ctl = 1'b0;
        repeat (20) @(posedge clk);
        if (!dut.cached_valid)
            begin
                $display("FAIL: ARP request did not populate the cache");
                $stop;
            end

        wait (tx_capture_count >= 72);
        locate_and_check_frame(0, 16'h0806, 60, frame_start);
        if (tx_capture[frame_start + 8 + 21] != 8'h02)
            begin
                $display("FAIL: ARP reply opcode is not 2");
                $stop;
            end
        if (tx_capture[frame_start + 8] != PEER_MAC[47:40])
            begin
                $display("FAIL: ARP reply destination MAC is incorrect");
                $stop;
            end

        for (i = 0; i < 32; i = i + 1) begin
            @(negedge clk);
            s_axis_tx_tdata = i[7:0];
            s_axis_tx_tvalid = 1'b1;
            s_axis_tx_tlast = (i == 31);
            do @(posedge clk); while (!s_axis_tx_tready);
        end
        @(negedge clk);
        s_axis_tx_tvalid = 1'b0;
        s_axis_tx_tlast = 1'b0;

        wait (tx_capture_count >= 72 + 8 + 74 + 4);
        locate_and_check_frame(72, 16'h0800, 74, frame_start);
        if (tx_capture[frame_start + 8 + 42] != 8'h00 ||
            tx_capture[frame_start + 8 + 43] != 8'h01 ||
            tx_capture[frame_start + 8 + 73] != 8'h1F)
            begin
                $display("FAIL: UDP payload bytes are incorrect");
                $stop;
            end

        $display("PASS: ARP reply and UDP frame FCS verified");
        $finish;
    end

    initial begin
        #2000000;
        $display("FAIL: testbench timeout");
        $stop;
    end
endmodule
