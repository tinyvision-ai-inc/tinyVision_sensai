// UART SPRAM buffer

module lsc_uart_signal_cap(
input		ref_clk    , 
input           clk        , 

input           i_frame_rst,
input		i_req      ,
input   [7:0]   i_amt      ,

// data input 
input	[7:0]	i_din      ,
input		i_valid    ,

// data output
output reg [7:0]o_dout     ,
output reg      o_valid    ,

// UART signals
input		i_rxd      ,
output reg	o_txd      ,

input           resetn
);

parameter [15:0] PERIOD = 16'd867; // 100MHz ref, 115200 baud --> 867

reg		read_mode;  // clk
reg		read_mode_d;
reg		read_mode_ref_clk; // ref_clk;
reg		req_lat;
reg	[7:0]	amt_lat;
wire		read_done;

always @(posedge clk)
begin
    if(i_req) 
	req_lat <= 1'b1;
    else if({read_mode_d, read_mode} == 2'b01)
	req_lat <= 1'b0;
end

always @(posedge clk)
begin
    if(i_req & (!req_lat)) 
	amt_lat <= i_amt;
end

always @(posedge clk)
begin
    if(i_frame_rst & req_lat)
	read_mode <= 1'b1;
    else if(read_done)
	read_mode <= 1'b0;
end

always @(posedge clk)
begin
    read_mode_d <= read_mode;
end

always @(posedge ref_clk)
begin
    read_mode_ref_clk <= read_mode_d;
end

// Tx side {{{
wire		fifo_we;
wire		fifo_we0;
wire		fifo_we1;
wire		fifo_we2;
wire		fifo_we3;
reg		fifo_rd_tg;   // ref_clk
reg	[2:0]	fifo_rd_tg_sync; // clk

reg	[7:0]	fifo_dout;
wire	[15:0]	fifo_rdata;
wire	[15:0]	fifo_rdata0;
wire	[15:0]	fifo_rdata1;
wire	[15:0]	fifo_rdata2;
wire	[15:0]	fifo_rdata3;
wire	[15:0]	fifo_addr;
reg	[16:0]	fifo_waddr;
reg	[16:0]	fifo_raddr;
reg	[1:0]	fifo_raddr_d;
wire	[3:0]	fifo_maskwe;

reg	[15:0]	tx_period_cnt;
reg	[3:0]	tx_bit_cnt;	// 0: IDLE, 1: Start, 2~9: bit0~7, A:Stop
reg		tx_bit_tick;

always @(posedge ref_clk)
begin
    if(resetn == 1'b0)
	tx_bit_cnt <= 4'b0;
    else if((tx_bit_cnt == 4'b0) && (read_mode_ref_clk == 1'b1))
	tx_bit_cnt <= 4'd1;
    else if((tx_bit_cnt == 4'hA) && tx_bit_tick)
	tx_bit_cnt <= 4'd0;
    else if((tx_bit_cnt != 4'b0) && tx_bit_tick)
	tx_bit_cnt <= tx_bit_cnt + 4'd1;
end

always @(posedge ref_clk)
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

always @(posedge ref_clk)
begin
    if(resetn == 1'b0)
	tx_bit_tick <= 1'b0;
    else if(tx_period_cnt == 16'd1)
	tx_bit_tick <= 1'b1;
    else
	tx_bit_tick <= 1'b0;
end

always @(posedge ref_clk)
begin
    if(resetn == 1'b0)
	fifo_rd_tg <= 1'b0;
    else if((tx_bit_cnt == 4'h9) && tx_bit_tick)
	fifo_rd_tg <= ~fifo_rd_tg;
end

always @(posedge ref_clk)
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
	fifo_rd_tg_sync <= 3'b0;
    else 
	fifo_rd_tg_sync <= {fifo_rd_tg_sync[1:0], fifo_rd_tg};
end

always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0)
	fifo_raddr <= 17'b0;
    else if(!read_mode)
	fifo_raddr <= 17'b0;
    else if(fifo_rd_tg_sync[0] != fifo_rd_tg_sync[1])
	fifo_raddr <= fifo_raddr + 17'd1;
end

assign fifo_we = i_valid & (!read_mode);

always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0)
	fifo_dout <= 8'd0;
    else
	fifo_dout <= fifo_raddr[0] ? fifo_rdata[15:8] : fifo_rdata[7:0];
end

always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0)
	fifo_waddr <= 17'b0;
    else if(i_frame_rst)
	fifo_waddr <= 17'b0;
    else if(fifo_we && (fifo_waddr != 17'h1FFFF))
	fifo_waddr <= fifo_waddr + 17'd1;
end

assign fifo_addr = read_mode ? fifo_raddr[16:1] : fifo_waddr[16:1];

assign fifo_maskwe = fifo_waddr[0] ? 4'b1100 : 4'b0011;

assign fifo_rdata = (fifo_raddr[16:15] == 2'b00) ? fifo_rdata0 :
                    (fifo_raddr[16:15] == 2'b01) ? fifo_rdata1 :
                    (fifo_raddr[16:15] == 2'b10) ? fifo_rdata2 :
                                                   fifo_rdata3 ;

assign read_done = (amt_lat == fifo_raddr[16:9]) && (fifo_raddr[8:0] == 9'b0) &&
		    (fifo_rd_tg_sync[1] != fifo_rd_tg_sync[2]);

assign fifo_we0 = fifo_we && (fifo_waddr[16:15] == 2'b00);
assign fifo_we1 = fifo_we && (fifo_waddr[16:15] == 2'b01);
assign fifo_we2 = fifo_we && (fifo_waddr[16:15] == 2'b10);
assign fifo_we3 = fifo_we && (fifo_waddr[16:15] == 2'b11);

SP256K u_spram16k_16_0 (
  .AD       (fifo_addr      ),  // I
  .DI       ({i_din, i_din} ),  // I
  .MASKWE   (fifo_maskwe    ),  // I
  .WE       (fifo_we0       ),  // I
  .CS       (1'b1           ),  // I
  .CK       (clk            ),  // I
  .STDBY    (1'b0           ),  // I
  .SLEEP    (1'b0           ),  // I
  .PWROFF_N (1'b1           ),  // I
  .DO       (fifo_rdata0    )   // O
);

SP256K u_spram16k_16_1 (
  .AD       (fifo_addr      ),  // I
  .DI       ({i_din, i_din} ),  // I
  .MASKWE   (fifo_maskwe    ),  // I
  .WE       (fifo_we1       ),  // I
  .CS       (1'b1           ),  // I
  .CK       (clk            ),  // I
  .STDBY    (1'b0           ),  // I
  .SLEEP    (1'b0           ),  // I
  .PWROFF_N (1'b1           ),  // I
  .DO       (fifo_rdata1    )   // O
);

SP256K u_spram16k_16_2 (
  .AD       (fifo_addr      ),  // I
  .DI       ({i_din, i_din} ),  // I
  .MASKWE   (fifo_maskwe    ),  // I
  .WE       (fifo_we2       ),  // I
  .CS       (1'b1           ),  // I
  .CK       (clk            ),  // I
  .STDBY    (1'b0           ),  // I
  .SLEEP    (1'b0           ),  // I
  .PWROFF_N (1'b1           ),  // I
  .DO       (fifo_rdata2    )   // O
);

SP256K u_spram16k_16_3 (
  .AD       (fifo_addr      ),  // I
  .DI       ({i_din, i_din} ),  // I
  .MASKWE   (fifo_maskwe    ),  // I
  .WE       (fifo_we3       ),  // I
  .CS       (1'b1           ),  // I
  .CK       (clk            ),  // I
  .STDBY    (1'b0           ),  // I
  .SLEEP    (1'b0           ),  // I
  .PWROFF_N (1'b1           ),  // I
  .DO       (fifo_rdata3    )   // O
);

// Tx side }}}

// Rx side {{{

reg	[15:0]	rx_period_cnt;
reg	[3:0]	rx_bit_cnt;	// 0: IDLE, 1: Start, 2~9: bit0~7, A:Stop
reg		rx_bit_tick;
reg		rx_sample_tick;

reg	[1:0]	rxd_lat;
reg	[7:0]	rxd_shift;

reg		rx_valid_tg;
reg	[1:0]	rx_valid_tg_clk;

always @(posedge ref_clk)
begin
    if(resetn == 1'b0)
	rxd_lat <= 2'b0;
    else 
	rxd_lat <= {rxd_lat[0], i_rxd};
end

always @(posedge ref_clk)
begin
    if(resetn == 1'b0)
	rxd_shift <= 8'b0;
    else if(rx_sample_tick)
	rxd_shift <= {rxd_lat[0], rxd_shift[7:1]};
end

always @(posedge ref_clk)
begin
    if(resetn == 1'b0)
	rx_valid_tg <= 1'b0;
    else if(rx_sample_tick & (rx_bit_cnt == 4'hA))
	rx_valid_tg <= !rx_valid_tg;
end

always @(posedge ref_clk)
begin
    if(resetn == 1'b0)
	o_dout <= 8'b0;
    else if(rx_sample_tick & (rx_bit_cnt == 4'hA))
	o_dout <= rxd_shift;
end

always @(posedge ref_clk)
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

always @(posedge ref_clk)
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

always @(posedge ref_clk)
begin
    if(resetn == 1'b0)
	rx_bit_tick <= 1'b0;
    else if(rx_period_cnt == 16'd1)
	rx_bit_tick <= 1'b1;
    else
	rx_bit_tick <= 1'b0;
end

always @(posedge ref_clk)
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
	rx_valid_tg_clk <= 2'b0;
    else 
	rx_valid_tg_clk <= {rx_valid_tg_clk[0], rx_valid_tg};
end

always @(posedge clk)
begin
    if(resetn == 1'b0)
	o_valid <= 1'b0;
    else 
	o_valid <= (rx_valid_tg_clk[0] != rx_valid_tg_clk[1]);
end

// Rx side }}}

endmodule

// vim:foldmethod=marker:
//
