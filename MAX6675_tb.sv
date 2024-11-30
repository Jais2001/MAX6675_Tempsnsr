`timescale 1ns/1ps
module MAX6675_tb();

logic i_clk = 0;
logic i_reset;

// bit [15:0]o_data;
bit o_CS;
bit o_SPI_CLk;
bit i_SPI_MISO;
bit o_tx_Serial;

MAX6675_Tempsnsr DUT(
    .i_clk(i_clk),
    .i_reset(i_reset),
    // .o_data(o_data),
    .o_CS(o_CS),
    .o_SPI_CLk(o_SPI_CLk),
    .i_SPI_MISO(i_SPI_MISO),
    .o_tx_Serial(o_tx_Serial)
);
    
task  Send_DATA;
    integer i;
    begin
        for (i=0;i<10000;i=i+1) begin
            i_SPI_MISO <= i % 2;
            #263; // 3.8Mhz delay for sending 1 bit in SPI clock domain
        end
    end
endtask 

initial begin
    i_reset = 0;
    #1000;
    i_reset = 1;
    #1000;
    Send_DATA;
end

always
    #5 i_clk <= ~i_clk; // 100MHz
endmodule
