`timescale 1ns/1ps

module crc32_d8 (
    input  wire        clk,
    input  wire        rst,
    input  wire        init,
    input  wire        calc_en,
    input  wire [7:0]  data_in,
    output wire [31:0] crc_out
);
    reg [31:0] crc_reg;
    reg [31:0] crc_next;
    integer i;

    always @* begin
        crc_next = crc_reg ^ {24'd0, data_in};
        for (i = 0; i < 8; i = i + 1) begin
            if (crc_next[0])
                crc_next = (crc_next >> 1) ^ 32'hEDB88320;
            else
                crc_next = crc_next >> 1;
        end
    end

    always @(posedge clk) begin
        if (rst)
            crc_reg <= 32'hFFFFFFFF;
        else if (init)
            crc_reg <= 32'hFFFFFFFF;
        else if (calc_en)
            crc_reg <= crc_next;
    end

    assign crc_out = ~crc_reg;
endmodule
