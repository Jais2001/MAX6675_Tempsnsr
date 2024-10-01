`timescale 1ns/1ps
module MAX6675_tb();

logic i_clk = 0;
logic i_reset;

bit [15:0]o_data;
bit o_CS;
bit o_SPI_CLk;
bit i_SPI_MISO;

MAX6675_Tempsnsr DUT(
    .i_clk(i_clk),
    .i_reset(i_reset),
    .o_data(o_data),
    .o_CS(o_CS),
    .o_SPI_CLk(o_SPI_CLk),
    .i_SPI_MISO(i_SPI_MISO)
);

always
    #10 i_clk <= ~i_clk;
    
initial begin
    i_reset = 0;
    #1000;
    i_reset = 1;
    #1000;
end
endmodule