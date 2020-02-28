
module spi_lcd_tx (
input		clk        ,
input           wclk       ,    // data input clock
input		resetn     ,

input           i_en       ,    // enable

input           i_we       ,	// single pulse, wclk
input           i_mode     ,    // wclk
input	[15:0]	i_data     ,    // wclk i_mode == 0: bit[15:8] is valid command/data, bit[0] is GPO
                                //      i_mode == 1: bit[15:0] is valid data

output reg      o_init_done,
output reg      o_running  ,

output reg      SPI_GPO    ,
output reg	SPI_CLK    ,
output reg	SPI_CSS    ,
output reg	SPI_MOSI
);

parameter ECP5_DEBUG = 1'b0;
parameter TYPE       = "LCD";

reg	     	clk_phase;

reg	[3:0]	bit_cnt;
reg	[9:0]	raddr;
reg	[9:0]	waddr;
reg	[9:0]	waddr_clk;
reg	[9:0]	waddr_clk_d;

wire		empty;
wire		rd;

wire	[15:0]	rdata;

reg	[14:0]	rdata_shift;

always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0)
	clk_phase <= 1'b0;
    else
	clk_phase <= ~clk_phase;
end

always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0)
	o_running <= 1'b0;
    else if(i_en == 1'b0)
	o_running <= 1'b0;
    else if(clk_phase) begin
	if(!empty)
	    o_running <= 1'b1;
	else if(bit_cnt == 4'hf)
	    o_running <= 1'b0;
    end
end

always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0)
	bit_cnt <= 4'd0;
    else if(!o_running)
	bit_cnt <= 4'd0;
    else if(clk_phase == 1'b1)
	bit_cnt <= (bit_cnt + 4'd1) | {(~i_mode) | (~o_init_done), 3'b0};
end

always @(posedge wclk or negedge resetn)
begin
    if(resetn == 1'b0)
	waddr <= 10'h100; // Use initial 256 data for initialization
    else if(i_en == 1'b0)
	waddr <= 10'h100;
    else if(i_we)
	waddr <= waddr + 10'd1;
end

always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0)
	o_init_done <= 1'b0;
    else if(i_en == 1'b0)
	o_init_done <= 1'b0;
    else if(empty)
	o_init_done <= 1'b1;
end

always @(posedge clk)
begin
    waddr_clk   <= waddr;
    waddr_clk_d <= waddr_clk;
end

assign empty = (waddr_clk_d == waddr_clk) && (waddr_clk_d == raddr);

assign rd = clk_phase && (!empty) && ((bit_cnt == 4'hf) || (!o_running));

always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0)
	raddr <= 10'd0;
    else if(i_en == 1'b0)
	raddr <= 10'd0;
    else if(rd)
	raddr <= raddr + 10'd1;
end

// Memory instantation
generate if(ECP5_DEBUG == 1'b1)
begin: g_on_ecp5_debug
    dpram1k_16 u_dpram1k_16 (
	.WrAddress(waddr     ),
	.RdAddress(raddr     ),
	.Data     (i_data    ),
	.WE       (i_we      ),
	.RdClock  (clk       ),
	.RdClockEn(1'b1      ),
	.Reset    (!resetn   ),
	.WrClock  (wclk      ),
	.WrClockEn(1'b1      ),
	.Q        (rdata     )
    );
end
else if(TYPE == "OLED")
begin // ICE40_UP
`ifdef ICECUBE
    SB_RAM256x16 u_dpram_oled_fifo (
	.RDATA (rdata     ),
	.RADDR (raddr[7:0]),
	.RCLK  (clk       ),
	.RCLKE (1'b1      ),
	.RE    (1'b1      ),
	.WADDR (waddr[7:0]),
	.WCLK  (wclk      ),
	.WCLKE (1'b1      ),
	.WDATA (i_data    ),
	.WE    (i_we      ),
	.MASK  (16'h0000  )
    );

    defparam u_dpram_oled_fifo.INIT_0 = 256'hB100_0101_AB00_0001_B500_0001_A200_7F01_CA00_F101_B300_AE00_B101_FD00_1201_FD00;
    defparam u_dpram_oled_fifo.INIT_1 = 256'h0101_B600_5501_B501_A001_B400_0F01_C700_C801_8001_C801_C100_A600_0501_BE00_3201;
    defparam u_dpram_oled_fifo.INIT_2 = 256'hAD00_AD00_AD00_AD00_AD00_AF00_8001_A100_3401_A000_7F01_0001_7500_7F01_0001_1500;
    defparam u_dpram_oled_fifo.INIT_3 = 256'hAD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00;
    defparam u_dpram_oled_fifo.INIT_4 = 256'hAD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00;
    defparam u_dpram_oled_fifo.INIT_5 = 256'hAD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00;
    defparam u_dpram_oled_fifo.INIT_6 = 256'hAD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00;
    defparam u_dpram_oled_fifo.INIT_7 = 256'hAD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00;
    defparam u_dpram_oled_fifo.INIT_8 = 256'hAD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00;
    defparam u_dpram_oled_fifo.INIT_9 = 256'hAD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00;
    defparam u_dpram_oled_fifo.INIT_A = 256'hAD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00;
    defparam u_dpram_oled_fifo.INIT_B = 256'hAD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00;
    defparam u_dpram_oled_fifo.INIT_C = 256'hAD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00;
    defparam u_dpram_oled_fifo.INIT_D = 256'hAD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00;
    defparam u_dpram_oled_fifo.INIT_E = 256'hAD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00;
    defparam u_dpram_oled_fifo.INIT_F = 256'hAD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00_AD00;

`else
    dpram_oled_fifo u_dpram_oled_fifo (
	.wr_clk_i   (wclk         ),
	.rd_clk_i   (clk          ),
	.wr_clk_en_i(1'b1         ),
	.rd_en_i    (1'b1         ),
	.rd_clk_en_i(1'b1         ),
	.wr_en_i    (i_we         ),
	.wr_data_i  (i_data       ),
	.wr_addr_i  (waddr[7:0]   ),
	.rd_addr_i  (raddr[7:0]   ),
	.rd_data_o  (rdata        )
    );
`endif
end
else
begin // ICE40_UP
`ifdef ICECUBE
    SB_RAM256x16 u_dpram_lcd_fifo (
	.RDATA (rdata     ),
	.RADDR (raddr[7:0]),
	.RCLK  (clk       ),
	.RCLKE (1'b1      ),
	.RE    (1'b1      ),
	.WADDR (waddr[7:0]),
	.WCLK  (wclk      ),
	.WCLKE (1'b1      ),
	.WDATA (i_data    ),
	.WE    (i_we      ),
	.MASK  (16'h0000  )
    );

    defparam u_dpram_lcd_fifo.INIT_0 = 256'h2C01_0101_2D01_2C01_0101_B300_2D01_2C01_0101_B200_2D01_2C01_0101_B100_1100_0100;
    defparam u_dpram_lcd_fifo.INIT_1 = 256'hC300_0001_0A01_C200_C501_C100_8401_0201_A201_C000_0701_B400_0201_1501_B600_2D01;
    defparam u_dpram_lcd_fifo.INIT_2 = 256'h0001_0201_0001_2A00_0501_3A00_C801_3600_2000_0E01_C500_EE01_8A01_C400_2A01_8A01;
    defparam u_dpram_lcd_fifo.INIT_3 = 256'h2900_2900_2900_2900_2900_2900_2900_2900_2900_1300_8201_0001_0301_0001_2B00_8101;
    defparam u_dpram_lcd_fifo.INIT_4 = 256'h2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900;
    defparam u_dpram_lcd_fifo.INIT_5 = 256'h2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900;
    defparam u_dpram_lcd_fifo.INIT_6 = 256'h2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900;
    defparam u_dpram_lcd_fifo.INIT_7 = 256'h2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900;
    defparam u_dpram_lcd_fifo.INIT_8 = 256'h2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900;
    defparam u_dpram_lcd_fifo.INIT_9 = 256'h2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900;
    defparam u_dpram_lcd_fifo.INIT_A = 256'h2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900;
    defparam u_dpram_lcd_fifo.INIT_B = 256'h2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900;
    defparam u_dpram_lcd_fifo.INIT_C = 256'h2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900;
    defparam u_dpram_lcd_fifo.INIT_D = 256'h2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900;
    defparam u_dpram_lcd_fifo.INIT_E = 256'h2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900;
    defparam u_dpram_lcd_fifo.INIT_F = 256'h2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900_2900;
`else
    dpram_lcd_fifo u_dpram_lcd_fifo (
	.wr_clk_i   (wclk         ),
	.rd_clk_i   (clk          ),
	.wr_clk_en_i(1'b1         ),
	.rd_en_i    (1'b1         ),
	.rd_clk_en_i(1'b1         ),
	.wr_en_i    (i_we         ),
	.wr_data_i  (i_data       ),
	.wr_addr_i  (waddr[7:0]   ),
	.rd_addr_i  (raddr[7:0]   ),
	.rd_data_o  (rdata        )
    );
`endif
end
endgenerate

// I/O drive
always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0)
	SPI_CLK <= 1'b1;
    else
	SPI_CLK <= (clk_phase == 1'b0);
end

always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0)
	SPI_CSS <= 1'b1;
    else if(i_en == 1'b0)
	SPI_CSS <= 1'b1;
    else if(clk_phase) begin
	if(!empty)
	    SPI_CSS <= 1'b0;
	else if(bit_cnt == 4'hf)
	    SPI_CSS <= 1'b1;
    end
end

always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0)
	SPI_MOSI <= 1'b1;
    else if(i_en == 1'b0)
	SPI_MOSI <= 1'b1;
    else if(rd)
	SPI_MOSI <= rdata[15];
    else if(clk_phase == 1'b1)
	SPI_MOSI <= rdata_shift[14];
end

always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0)
	rdata_shift <= 15'b0;
    else if(rd)
	rdata_shift <= rdata[14:0];
    else if(clk_phase == 1'b1)
	rdata_shift <= {rdata_shift[13:0], 1'b0};
end

always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0)
	SPI_GPO <= 1'b0;
    else if(rd)
	SPI_GPO <= (o_init_done & i_mode) | rdata[0] ;
end

endmodule
