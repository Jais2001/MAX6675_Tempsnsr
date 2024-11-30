module MAX6675_Tempsnsr(
    input wire i_clk, // 100MHz clock
    input wire i_reset,

    // output wire [15:0]o_data, // data o/p of module to ext intrfce

    //control signals
    output wire o_CS,
    output wire o_SPI_CLk,
    input wire i_SPI_MISO,

    output wire o_tx_Serial
);

reg r_CS;
reg [15:0]r_o_data;
reg [15:0]r_op_data;
reg r_TX_Dev;

wire w_RX_DV;
wire[7:0] w_op_data; // 1 byte data form SPI master
wire w_Tx_Ready;

reg r_tx_ready;
reg[1:0] r_temp_count;  // a counter for storing 2 bytes

reg[4:0]  MAX6675_State;

localparam initial_state = 5'd0;
localparam control_state = 5'd1;
localparam Start_SPI_clock = 5'd2;
localparam wait_TX_ready = 5'd3;
localparam get_data      = 5'd4;
localparam send_data     = 5'd5;
localparam stop_read     = 5'd6;


SPI_Master #(.SPI_MODE(0),.CLKS_PER_HALF_BIT(13)) spi( // o_SPI_CLk - 3.8MHz
    .i_Rst_L(i_reset),
    .i_Clk (i_clk),
    .i_TX_Byte(),
    .i_TX_DV(r_TX_Dev),
    .o_TX_Ready(w_Tx_Ready),
    .o_RX_DV(w_RX_DV),
    .o_RX_Byte(w_op_data),
    .o_SPI_Clk(o_SPI_CLk),
    .i_SPI_MISO(i_SPI_MISO)
);

// CLKS_PER_BIT = (Frequency of i_Clock)/(Frequency of UART)
// Example: 10 MHz Clock, 115200 baud UART
// (10000000)/(115200) = 87

localparam CLOCK_FREQ = 3000000; // 3MHz - maintaining SPI clock for sending UART
localparam BAUD_RATE = 115200;
localparam CLKS_PER_BIT = CLOCK_FREQ/BAUD_RATE;

reg i_Tx_DV = 0;
reg [7:0] i_Tx_Byte = 0;
wire w_Tx_Active;
wire w_Tx_Serial;
wire w_Tx_Done;

reg r_op_dv;

uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) uart_tx_inst(

    .i_Clock(i_clk),
    .i_Tx_DV(i_Tx_DV),
    .i_Tx_Byte(i_Tx_Byte),
    .o_Tx_Active(w_Tx_Active),
    .o_Tx_Serial(w_Tx_Serial),
    .o_Tx_Done(w_Tx_Done)
);

reg[2:0] r_power_up_counter;

// Purpose : Main FSM for SPI data
always @(posedge i_clk or negedge i_reset) begin
    if (~i_reset) begin
        r_CS <= 1;
        r_o_data <= 0;
        r_power_up_counter <= 0;
        r_temp_count <= 0;
        MAX6675_State <= initial_state;
        r_op_dv <= 0;
    end else begin
        r_TX_Dev <= 0;
        r_op_dv <= 0;
        case (MAX6675_State) 
            initial_state:begin // waiting for 100ns(10 clock) just to boot up the sensor
                if (r_power_up_counter < 3'd5) begin
                    MAX6675_State <= initial_state;
                    r_power_up_counter <= r_power_up_counter + 1;
                end
                else begin
                    r_power_up_counter <= 0;
                    r_temp_count <= 0;
                    MAX6675_State <= control_state;
                end
            end 
            control_state : begin  // make CS pin low
                r_CS <= 0;
                MAX6675_State <= Start_SPI_clock;
            end
            Start_SPI_clock : begin
                r_TX_Dev <= 1;
                MAX6675_State <= wait_TX_ready;
            end
            wait_TX_ready : begin 
                if (~w_Tx_Ready) begin
                    MAX6675_State <= get_data;
                end
                else begin
                    MAX6675_State <= wait_TX_ready;
                end
            end
            get_data : begin
                if (w_RX_DV) begin
                    if (r_temp_count < 2'd2) begin
                        r_o_data <= (r_o_data << 8) | w_op_data;
                        MAX6675_State <= Start_SPI_clock;
                        r_temp_count <= r_temp_count + 1;
                    end else begin
                        MAX6675_State <= send_data;
                    end
                end
                else begin
                    MAX6675_State <= get_data;
                end
                end
            send_data : begin
                r_temp_count <= 0;
                r_op_data <= r_o_data;
                MAX6675_State <= stop_read;
            end
            stop_read : begin
                r_CS <= 1;
                r_op_dv <= 1;
                MAX6675_State <= control_state;
            end
            default: begin
                MAX6675_State <= initial_state;
            end
        endcase
    end
end  

reg [2:0] Uart_state;
localparam wait_state = 3'd0;
localparam send_state1 = 3'd1;
localparam send_state2 = 3'd2;


// Purpose : Uart Tx FSM
always @(posedge i_clk or negedge i_reset) begin
    if (~i_reset) begin
        Uart_state <= wait_state;
        i_Tx_DV <= 0;
    end else begin
        i_Tx_DV <= 0;
        if (~w_Tx_Active) begin
            case (Uart_state)
                wait_state: begin
                    if (r_op_dv) begin
                        Uart_state <= send_state1;
                    end else begin
                        Uart_state <= wait_state;
                    end
                end
                send_state1: begin
                    i_Tx_Byte <= r_op_data[7:0];
                    i_Tx_DV <= 1;
                    Uart_state <= send_state2;
                end
                send_state2: begin
                    i_Tx_Byte <= r_op_data[15:8];
                    i_Tx_DV <= 1;
                    Uart_state <= wait_state;
                end
                default: begin
                    Uart_state <= wait_state;
                end
        endcase
        end
    end
end

assign o_tx_Serial  = w_Tx_Serial;
assign o_CS         = r_CS;
// assign o_data       = r_op_data;

endmodule