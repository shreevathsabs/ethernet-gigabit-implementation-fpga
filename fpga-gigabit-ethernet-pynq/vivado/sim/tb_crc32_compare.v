`timescale 1ns/1ps

module tb_crc32_compare;
    reg clk;
    reg rst;
    reg init;
    reg calc_en;
    reg [7:0] data_in;
    wire [31:0] crc_baseline;
    wire [31:0] crc_parallel;
    integer i;
    reg [31:0] expected_crc;

    crc32_d8 baseline (
        .clk(clk),
        .rst(rst),
        .init(init),
        .calc_en(calc_en),
        .data_in(data_in),
        .crc_out(crc_baseline)
    );

    crc32_d8_parallel parallel (
        .clk(clk),
        .rst(rst),
        .init(init),
        .calc_en(calc_en),
        .data_in(data_in),
        .crc_out(crc_parallel)
    );

    initial begin
        clk = 1'b0;
        forever #4 clk = ~clk;
    end

    initial begin
        rst = 1'b1;
        init = 1'b0;
        calc_en = 1'b0;
        data_in = 8'd0;
        expected_crc = 32'hFFFFFFFF;
        repeat (2) @(posedge clk);
        #1;
        rst = 1'b0;

        send_byte(8'h31);
        send_byte(8'h32);
        send_byte(8'h33);
        send_byte(8'h34);
        send_byte(8'h35);
        send_byte(8'h36);
        send_byte(8'h37);
        send_byte(8'h38);
        send_byte(8'h39);
        if (crc_baseline !== 32'hCBF43926 ||
            crc_parallel !== 32'hCBF43926)
            fail("CRC-32/IEEE check vector 123456789 failed");

        @(negedge clk);
        init = 1'b1;
        @(posedge clk);
        #1;
        init = 1'b0;
        expected_crc = 32'hFFFFFFFF;

        for (i = 0; i < 1024; i = i + 1) begin
            if ((i % 7) == 0) begin
                @(negedge clk);
                calc_en = 1'b0;
                @(posedge clk);
                #1;
            end
            send_byte((i * 73 + 19) & 8'hFF);
        end

        $display("PASS: baseline and parallel CRC agree over 1033 bytes");
        $finish;
    end

    task send_byte;
        input [7:0] value;
        reg [31:0] next_expected;
        integer bit_index;
        begin
            @(negedge clk);
            data_in = value;
            calc_en = 1'b1;
            next_expected = expected_crc ^ {24'd0, value};
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                if (next_expected[0])
                    next_expected = (next_expected >> 1) ^ 32'hEDB88320;
                else
                    next_expected = next_expected >> 1;
            end
            expected_crc = next_expected;
            @(posedge clk);
            #1;
            if (crc_baseline !== ~expected_crc)
                fail("baseline CRC disagrees with reference calculation");
            if (crc_parallel !== ~expected_crc)
                fail("parallel CRC disagrees with reference calculation");
        end
    endtask

    task fail;
        input [8*80-1:0] message;
        begin
            $display("FAIL: %0s", message);
            $stop;
        end
    endtask

    initial begin
        #200000;
        $display("FAIL: CRC comparison timeout");
        $stop;
    end
endmodule
