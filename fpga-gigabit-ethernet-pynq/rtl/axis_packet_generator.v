`timescale 1ns/1ps

module axis_packet_generator (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire [10:0] payload_length,
    output reg  [7:0]  m_axis_tdata,
    output reg         m_axis_tvalid,
    output wire        m_axis_tlast,
    input  wire        m_axis_tready,
    output wire        busy
);
    reg [10:0] byte_count;
    reg [10:0] length_latched;

    assign busy = m_axis_tvalid;
    assign m_axis_tlast = m_axis_tvalid &&
                          (byte_count == length_latched - 1'b1);

    always @(posedge clk) begin
        if (rst) begin
            byte_count     <= 11'd0;
            length_latched <= 11'd0;
            m_axis_tdata   <= 8'd0;
            m_axis_tvalid  <= 1'b0;
        end else if (!m_axis_tvalid) begin
            if (start && payload_length != 0 && payload_length <= 11'd1472) begin
                length_latched <= payload_length;
                byte_count     <= 11'd0;
                m_axis_tdata   <= 8'd0;
                m_axis_tvalid  <= 1'b1;
            end
        end else if (m_axis_tready) begin
            if (byte_count + 1'b1 >= length_latched) begin
                m_axis_tvalid <= 1'b0;
            end else begin
                byte_count   <= byte_count + 1'b1;
                m_axis_tdata <= m_axis_tdata + 1'b1;
            end
        end
    end
endmodule
