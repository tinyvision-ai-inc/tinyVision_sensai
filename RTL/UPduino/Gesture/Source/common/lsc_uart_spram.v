// UART SPRAM buffer (single clk)

module lsc_uart_spram(
input		clk,
// data input
input	[7:0]	i_din,
input		i_valid,
output          o_empty,

// data output
output reg [7:0]o_dout,
output reg      o_valid,

// UART signals
input		i_rxd,
output reg	o_txd,

input           resetn
);

parameter [15:0] PERIOD = 16'd867; // 100MHz ref, 115200 baud --> 867
parameter ECP5_DEBUG = 1'b0;

// Tx side {{{

wire		fifo_we;
wire		fifo_rd;
reg		fifo_we_d;
wire	[7:0]	fifo_dout;
wire	[15:0]	fifo_rdata;
reg	[15:0]	fifo_rdata_l;
reg		fifo_empty;
wire	[13:0]	fifo_addr;
reg	[14:0]	fifo_waddr;
reg	[14:0]	fifo_raddr;
wire	[3:0]	fifo_maskwe;
reg		r_fifo_empty;
wire		fifo_full;
wire	[14:0]	fifo_waddr_p1;

reg	[15:0]	tx_period_cnt;
reg	[3:0]	tx_bit_cnt;	// 0: IDLE, 1: Start, 2~9: bit0~7, A:Stop
reg		tx_bit_tick;

always @(posedge clk)
begin
    if(resetn == 1'b0)
	tx_bit_cnt <= 4'b0;
    else if((tx_bit_cnt == 4'b0) && (fifo_empty == 1'b0))
	tx_bit_cnt <= 4'd1;
    else if((tx_bit_cnt == 4'hA) && tx_bit_tick)
	tx_bit_cnt <= 4'd0;
    else if((tx_bit_cnt != 4'b0) && tx_bit_tick)
	tx_bit_cnt <= tx_bit_cnt + 4'd1;
end

always @(posedge clk)
begin
    if(resetn == 1'b0)
	tx_period_cnt <= 16'b0;
    else if(tx_bit_cnt == 4'b0)
	tx_period_cnt <= 16'b0;
    else if(tx_period_cnt == 16'b0)
	tx_period_cnt <= PERIOD;
    else
	tx_period_cnt <= tx_period_cnt - 16'd1;
end

always @(posedge clk)
begin
    if(resetn == 1'b0)
	tx_bit_tick <= 1'b0;
    else if(tx_period_cnt == 16'd1)
	tx_bit_tick <= 1'b1;
    else
	tx_bit_tick <= 1'b0;
end

//assign fifo_rd = ((tx_bit_cnt == 4'hA) && (tx_period_cnt == 16'd1));
assign fifo_rd = ((tx_bit_cnt == 4'h9) && tx_bit_tick);

always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0)
	fifo_raddr <= 15'b0;
    else if(fifo_rd)
	fifo_raddr <= fifo_raddr + 15'd1;
end

always @(posedge clk)
begin
    if(resetn == 1'b0)
	o_txd <= 1'b0;
    else case(tx_bit_cnt)
	4'd1: // start
	    o_txd <= 1'b0;
	4'd2:
	    o_txd <= fifo_dout[0];
	4'd3:
	    o_txd <= fifo_dout[1];
	4'd4:
	    o_txd <= fifo_dout[2];
	4'd5:
	    o_txd <= fifo_dout[3];
	4'd6:
	    o_txd <= fifo_dout[4];
	4'd7:
	    o_txd <= fifo_dout[5];
	4'd8:
	    o_txd <= fifo_dout[6];
	4'd9:
	    o_txd <= fifo_dout[7];
	default: // stop & idle
	    o_txd <= 1'b1;
    endcase
end

always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0)
	r_fifo_empty <= 1'b1;
    else 
	r_fifo_empty <= (fifo_raddr == fifo_waddr);
end

assign o_empty = r_fifo_empty;

assign fifo_waddr_p1 = fifo_waddr + 15'd1;

assign fifo_we = ((!fifo_full) && i_valid);

always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0)
	fifo_we_d <= 1'b0;
    else
	fifo_we_d <= fifo_we;
end

always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0)
	fifo_rdata_l <= 16'b0;
    else if(!fifo_we_d)
	fifo_rdata_l <= fifo_rdata;
end

assign fifo_dout = fifo_raddr[0] ? fifo_rdata_l[15:8] : fifo_rdata_l[7:0];

always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0)
	fifo_waddr <= 15'b0;
    else if(fifo_we)
	fifo_waddr <= fifo_waddr_p1;
end

always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0)
	fifo_empty <= 1'b1;
    else
	fifo_empty <= r_fifo_empty;
end

assign fifo_full = (fifo_raddr == fifo_waddr_p1);

assign fifo_addr = fifo_we ? fifo_waddr[14:1] : fifo_raddr[14:1];

assign fifo_maskwe = fifo_waddr[0] ? 4'b1100 : 4'b0011;

SP256K u_spram16k_16_0 (
  .AD       (fifo_addr      ),  // I
  .DI       ({i_din, i_din} ),  // I
  .MASKWE   (fifo_maskwe    ),  // I
  .WE       (fifo_we        ),  // I
  .CS       (1'b1           ),  // I
  .CK       (clk            ),  // I
  .STDBY    (1'b0           ),  // I
  .SLEEP    (1'b0           ),  // I
  .PWROFF_N (1'b1           ),  // I
  .DO       (fifo_rdata     )   // O
);

// Tx side }}}

// Rx side {{{

reg	[15:0]	rx_period_cnt;
reg	[3:0]	rx_bit_cnt;	// 0: IDLE, 1: Start, 2~9: bit0~7, A:Stop
reg		rx_bit_tick;
reg		rx_sample_tick;

reg	[1:0]	rxd_lat;
reg	[7:0]	rxd_shift;

always @(posedge clk)
begin
    if(resetn == 1'b0)
	rxd_lat <= 2'b0;
    else 
	rxd_lat <= {rxd_lat[0], i_rxd};
end

always @(posedge clk)
begin
    if(resetn == 1'b0)
	rxd_shift <= 8'b0;
    else if(rx_sample_tick)
	rxd_shift <= {rxd_lat[0], rxd_shift[7:1]};
end

always @(posedge clk)
begin
    if(resetn == 1'b0)
	o_dout <= 8'b0;
    else if(rx_sample_tick & (rx_bit_cnt == 4'hA))
	o_dout <= rxd_shift;
end

always @(posedge clk)
begin
    if(resetn == 1'b0)
	rx_bit_cnt <= 4'b0;
    else if((rx_bit_cnt == 4'b0) && (rxd_lat == 2'b10))
	rx_bit_cnt <= 4'd1;
    else if((rx_bit_cnt == 4'hA) && rx_bit_tick)
	rx_bit_cnt <= 4'd0;
    else if((rx_bit_cnt != 4'b0) && rx_bit_tick)
	rx_bit_cnt <= rx_bit_cnt + 4'd1;
end

always @(posedge clk)
begin
    if(resetn == 1'b0)
	rx_period_cnt <= 16'b0;
    else if(rx_bit_cnt == 4'b0)
	rx_period_cnt <= 16'b0;
    else if(rx_period_cnt == 16'b0)
	rx_period_cnt <= PERIOD;
    else
	rx_period_cnt <= rx_period_cnt - 16'd1;
end

always @(posedge clk)
begin
    if(resetn == 1'b0)
	rx_bit_tick <= 1'b0;
    else if(rx_period_cnt == 16'd1)
	rx_bit_tick <= 1'b1;
    else
	rx_bit_tick <= 1'b0;
end

always @(posedge clk)
begin
    if(resetn == 1'b0)
	rx_sample_tick <= 1'b0;
    else if(rx_period_cnt == {1'b0, PERIOD[15:1]})
	rx_sample_tick <= 1'b1;
    else
	rx_sample_tick <= 1'b0;
end

always @(posedge clk)
begin
    if(resetn == 1'b0)
	o_valid <= 1'b0;
    else 
	o_valid <= (rx_sample_tick & (rx_bit_cnt == 4'hA));
end

// Rx side }}}

endmodule

// vim:foldmethod=marker:
//
