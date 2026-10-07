`timescale 1ns/1ps

module crc32_d8_parallel (
    input  wire        clk,
    input  wire        rst,
    input  wire        init,
    input  wire        calc_en,
    input  wire [7:0]  data_in,
    output wire [31:0] crc_out
);
    reg [31:0] crc_reg;
    wire [39:0] state_vector;
    reg [31:0] crc_next;

    assign state_vector = {crc_reg, data_in};

    always @* begin
        crc_next[0]  = ^(state_vector & 40'h0000010404);
        crc_next[1]  = ^(state_vector & 40'h0000020909);
        crc_next[2]  = ^(state_vector & 40'h0000041313);
        crc_next[3]  = ^(state_vector & 40'h0000082626);
        crc_next[4]  = ^(state_vector & 40'h0000104D4D);
        crc_next[5]  = ^(state_vector & 40'h0000209A9A);
        crc_next[6]  = ^(state_vector & 40'h0000403030);
        crc_next[7]  = ^(state_vector & 40'h0000806161);
        crc_next[8]  = ^(state_vector & 40'h000100C2C2);
        crc_next[9]  = ^(state_vector & 40'h0002008080);
        crc_next[10] = ^(state_vector & 40'h0004000404);
        crc_next[11] = ^(state_vector & 40'h0008000808);
        crc_next[12] = ^(state_vector & 40'h0010001111);
        crc_next[13] = ^(state_vector & 40'h0020002323);
        crc_next[14] = ^(state_vector & 40'h0040004646);
        crc_next[15] = ^(state_vector & 40'h0080008C8C);
        crc_next[16] = ^(state_vector & 40'h0100001D1D);
        crc_next[17] = ^(state_vector & 40'h0200003B3B);
        crc_next[18] = ^(state_vector & 40'h0400007777);
        crc_next[19] = ^(state_vector & 40'h080000EEEE);
        crc_next[20] = ^(state_vector & 40'h100000D8D8);
        crc_next[21] = ^(state_vector & 40'h200000B4B4);
        crc_next[22] = ^(state_vector & 40'h4000006C6C);
        crc_next[23] = ^(state_vector & 40'h800000D8D8);
        crc_next[24] = ^(state_vector & 40'h000000B5B5);
        crc_next[25] = ^(state_vector & 40'h0000006F6F);
        crc_next[26] = ^(state_vector & 40'h000000DFDF);
        crc_next[27] = ^(state_vector & 40'h000000BABA);
        crc_next[28] = ^(state_vector & 40'h0000007171);
        crc_next[29] = ^(state_vector & 40'h000000E3E3);
        crc_next[30] = ^(state_vector & 40'h000000C3C3);
        crc_next[31] = ^(state_vector & 40'h0000008282);
    end

    always @(posedge clk) begin
        if (rst || init)
            crc_reg <= 32'hFFFFFFFF;
        else if (calc_en)
            crc_reg <= crc_next;
    end

    assign crc_out = ~crc_reg;
endmodule
