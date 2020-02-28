
`timescale 1ns/10ps

module spi_fifo (
input           clk2x       , // SPI I/O clock
input           clk         , // FIFO interface clock

input           i_en        ,

// FIFO interface
input           i_fill      ,
output          o_fifo_empty,
output reg      o_fifo_low  ,
input           i_fifo_rd   ,
output [31:0]   o_fifo_dout ,

output          SPI_CSS     , //
output          SPI_CLK     , // 
inout           SPI_MISO    , // 
inout           SPI_MOSI    , // 

input		resetn      
);

parameter [23:0] C_BASEADDR = 24'h020000;
parameter FIFO_SIZE = "1024";
parameter C_FIFO_TH = 11'd250;

// state machine
parameter [3:0] 
	S_IDLE  = 4'b0000,
	S_CMD   = 4'b0001,
	S_ADDR0 = 4'b0010,
	S_ADDR1 = 4'b0011,
	S_ADDR2 = 4'b0111,
	S_DUMMY = 4'b0110,
	S_WRTD0 = 4'b0100,
	S_WRTD1 = 4'b1100,
	S_FILL  = 4'b1110,
	S_WAIT  = 4'b1010,
	S_LAST  = 4'b1111;

reg     [3:0]   state;
reg     [3:0]   nstate;

reg	[2:0]	bit_cnt;
reg	[1:0]	byte_cnt;

reg	[7:0]	byte_out;

reg	[1:0]	fill_d;
reg		st_fill_d;
reg		init_req;
reg		enable;
wire		byte_tick;
reg	     	word_tick;

reg	[7:0]	byte_shift_reg_dual;
reg	[31:0]	word_shift_reg;

reg	[9:0]	fifo_waddr;
reg	[9:0]	fifo_raddr;
reg	[9:0]	fifo_raddr_clk2x;
reg	[9:0]	fifo_raddr_clk2x_d;
reg	[9:0]	fifo_raddr_lat;
wire	[9:0]	fifo_waddr_p1;
reg	[9:0]	fifo_waddr_clk;
reg	[9:0]	fifo_waddr_clk_d;
reg	[9:0]	fifo_waddr_lat;
reg             fifo_valid;
wire		fifo_empty;

wire		w_csb;
wire	[1:0]	w_clk;
reg		r_do_o;
wire		w_do_z;
wire		w_di_o;
wire		w_di_z;

wire	[1:0]	w_do_i;
wire	[1:0]	w_di_i;

always @(posedge clk2x or negedge resetn)
begin
    if(resetn == 1'b0) 
	fill_d <= 2'b0;
    else 
	fill_d <= {fill_d[0], i_fill};
end

always @(posedge clk2x or negedge resetn)
begin
    if(resetn == 1'b0) 
	init_req <= 1'b0;
    else if(fill_d == 2'b10)
	init_req <= 1'b1;
    else if(state == S_LAST)
	init_req <= 1'b0;
end

always @(posedge clk2x or negedge resetn)
begin
    if(resetn == 1'b0) 
	enable <= 1'b0;
    else
	enable <= i_en;
end

always @(posedge clk2x or negedge resetn)
begin
    if(resetn == 1'b0) 
	state <= S_IDLE;
    else
	state <= nstate;
end

always @(*)
begin
    case(state)
	S_IDLE :
	    nstate <= enable ? S_CMD : S_IDLE;
	S_CMD:
	    nstate <= byte_tick ? S_ADDR0 : S_CMD;
	S_ADDR0:
	    nstate <= byte_tick ? S_ADDR1 : S_ADDR0;
	S_ADDR1:
	    nstate <= byte_tick ? S_ADDR2 : S_ADDR1;
	S_ADDR2:
	    nstate <= byte_tick ? S_DUMMY : S_ADDR2;
	S_DUMMY:
	    nstate <= byte_tick ? S_WRTD0 : S_DUMMY; 
	S_WRTD0:
	    nstate <= S_WRTD1;
	S_WRTD1:
	    nstate <= S_FILL;
	S_FILL:
	    nstate <= byte_tick ? (init_req ? S_LAST : (fifo_full ? S_WAIT : S_FILL)) : S_FILL;
	S_WAIT:
	    nstate <= fifo_full ? S_WAIT : S_FILL;
	S_LAST:
	    nstate <= S_IDLE;
	default:
	    nstate <= S_IDLE ;
    endcase
end

always @(posedge clk2x or negedge resetn)
begin
    if(resetn == 1'b0) 
	byte_out <= 8'b0;
    else if(state == S_IDLE)
	byte_out <= 8'h3B; // fast read, dual output
    else if(byte_tick)
	case(state)
	    S_CMD  : byte_out <= C_BASEADDR[23:16];
	    S_ADDR0: byte_out <= C_BASEADDR[15: 8];
	    S_ADDR1: byte_out <= C_BASEADDR[7 : 0];
	    default: byte_out <= 8'b0;
	endcase
end

assign w_csb  = (state == S_IDLE);
assign w_clk  = ((state == S_IDLE) || (state == S_LAST) || (state == S_WAIT)) ? 2'b00 : 2'b01;
assign w_do_z = (state == S_DUMMY) || (state == S_FILL) || (state == S_WAIT);
assign w_di_z = 1'b1;
assign w_di_o = 1'b0;

always @(*)
begin
    case(bit_cnt)
	3'd0   : r_do_o = byte_out[7];
	3'd1   : r_do_o = byte_out[6];
	3'd2   : r_do_o = byte_out[5];
	3'd3   : r_do_o = byte_out[4];
	3'd4   : r_do_o = byte_out[3];
	3'd5   : r_do_o = byte_out[2];
	3'd6   : r_do_o = byte_out[1];
	default: r_do_o = byte_out[0];
    endcase
end

always @(posedge clk2x or negedge resetn)
begin
    if(resetn == 1'b0) 
	bit_cnt <= 3'b0;
    else if((state == S_IDLE) || (state == S_WRTD0) || (state == S_WRTD1))
	bit_cnt <= 3'b0;
    else if(state != S_WAIT)
	bit_cnt <= (bit_cnt + 3'd1) | {(state == S_FILL), 2'b00}; // Use Dual Output mode for fill
end

assign byte_tick = (bit_cnt == 3'd7);

always @(posedge clk2x or negedge resetn)
begin
    if(resetn == 1'b0) 
	byte_cnt <= 2'b0;
    else if((state != S_FILL) && (state != S_WAIT))
	byte_cnt <= 2'b0;
    else if(byte_tick)
	byte_cnt <= byte_cnt + 2'd1;
end

always @(posedge clk2x or negedge resetn)
begin
    if(resetn == 1'b0) 
	word_tick <= 2'b0;
    else
	word_tick <= byte_tick && (byte_cnt == 2'd3);
end

always @(posedge clk2x or negedge resetn)
begin
    if(resetn == 1'b0) 
	st_fill_d <= 1'b0;
    else 
	st_fill_d <= (state == S_FILL) || (state ==S_WRTD0) || (state ==S_WRTD1);
end

always @(posedge clk2x or negedge resetn)
begin
    if(resetn == 1'b0) 
	byte_shift_reg_dual <= 8'b0;
    else if(st_fill_d)
	byte_shift_reg_dual <= {byte_shift_reg_dual[5:0], w_di_i[0], w_do_i[0]};
end

always @(posedge clk2x or negedge resetn)
begin
    if(resetn == 1'b0) 
	word_shift_reg <= 32'b0;
    else if((state == S_FILL) && byte_tick)
	word_shift_reg <= {byte_shift_reg_dual, word_shift_reg[31:8]};
end

assign fifo_we = word_tick;

assign fifo_waddr_p1 = fifo_waddr + 10'd1;

always @(posedge clk2x or negedge resetn)
begin
    if(resetn == 1'b0) 
	fifo_waddr <= 10'b0;
    else if(state == S_IDLE)
	fifo_waddr <= 10'b0;
    else if(fifo_we)
	fifo_waddr <= fifo_waddr_p1;
end

assign fifo_full = (FIFO_SIZE == "256") ?  (fifo_waddr_p1[7:0] == fifo_raddr_lat[7:0]) :
                   (FIFO_SIZE == "512") ?  (fifo_waddr_p1[8:0] == fifo_raddr_lat[8:0]) :
					   (fifo_waddr_p1 == fifo_raddr_lat);

always @(posedge clk2x or negedge resetn)
begin
    if(resetn == 1'b0) begin
	fifo_raddr_clk2x   <= 10'b0;
	fifo_raddr_clk2x_d <= 10'b0;
    end else begin
	fifo_raddr_clk2x   <= fifo_raddr;
	fifo_raddr_clk2x_d <= fifo_raddr_clk2x;
    end
end

always @(posedge clk2x or negedge resetn)
begin
    if(resetn == 1'b0) 
	fifo_raddr_lat <= 10'd0;
    else if(fifo_raddr_clk2x[9:1] == fifo_raddr_clk2x_d[9:1])
	fifo_raddr_lat <= fifo_raddr_clk2x_d;
end

always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0)  begin
	fifo_waddr_clk   <= 10'b0;
	fifo_waddr_clk_d <= 10'b0;
    end else begin
	fifo_waddr_clk   <= fifo_waddr;
	fifo_waddr_clk_d <= fifo_waddr_clk;
    end
end

always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0) 
	fifo_waddr_lat <= 10'd0;
    else if(fifo_waddr_clk == fifo_waddr_clk_d)
	fifo_waddr_lat <= fifo_waddr_clk_d;
end

assign fifo_empty = (FIFO_SIZE == "256") ?  (fifo_raddr[7:0] == fifo_waddr_lat[7:0]) :
                    (FIFO_SIZE == "512") ?  (fifo_raddr[8:0] == fifo_waddr_lat[8:0]) :
					    (fifo_raddr == fifo_waddr_lat);

always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0) 
	o_fifo_low <= 1'b1;
    else
	o_fifo_low <= ({fifo_waddr_lat < fifo_raddr, fifo_waddr_lat} - {1'b0, fifo_raddr}) < C_FIFO_TH;
end

always @(posedge clk)
begin
    if(i_fill == 1'b0)
	fifo_raddr <= 10'd0;
    else if(fifo_re)
	fifo_raddr <= fifo_raddr + 10'd1;
end

always @(posedge clk)
begin
    if(i_fill == 1'b0)
	fifo_valid <= 1'b0;
    else if(fifo_re)
	fifo_valid <= 1'b1;
end

assign o_fifo_empty = (!fifo_valid);
assign fifo_re = (i_fifo_rd || (!fifo_valid)) && (!fifo_empty) && (i_fill);


generate if(FIFO_SIZE == "512")
begin: g_on_fifo_512
    dpram512x32 u_ram512x32 (
	.wr_clk_i   (clk2x           ),
	.rd_clk_i   (clk             ),
	.wr_clk_en_i(1'b1            ),
	.rd_en_i    (fifo_re         ),
	.rd_clk_en_i(1'b1            ),
	.wr_en_i    (fifo_we         ),
	.wr_data_i  (word_shift_reg  ),
	.wr_addr_i  (fifo_waddr[8:0] ),
	.rd_addr_i  (fifo_raddr[8:0] ),
	.rd_data_o  (o_fifo_dout     )
    );
end else if(FIFO_SIZE == "1024")
begin: g_on_fifo_1024
//    dpram1024x32 u_ram1024x32 (
    dpram1024x8 u_ram1024x8_x[3:0] (
	.wr_clk_i   (clk2x           ),
	.rd_clk_i   (clk             ),
	.wr_clk_en_i(1'b1            ),
	.rd_en_i    (fifo_re         ),
	.rd_clk_en_i(1'b1            ),
	.wr_en_i    (fifo_we         ),
	.wr_data_i  (word_shift_reg  ),
	.wr_addr_i  (fifo_waddr[9:0] ),
	.rd_addr_i  (fifo_raddr[9:0] ),
	.rd_data_o  (o_fifo_dout     )
    );
end
else begin // default minimum size
    dpram256x32 u_ram256x32 (
	.wr_clk_i   (clk2x           ),
	.rd_clk_i   (clk             ),
	.wr_clk_en_i(1'b1            ),
	.rd_en_i    (fifo_re         ),
	.rd_clk_en_i(1'b1            ),
	.wr_en_i    (fifo_we         ),
	.wr_data_i  (word_shift_reg  ),
	.wr_addr_i  (fifo_waddr[7:0] ),
	.rd_addr_i  (fifo_raddr[7:0] ),
	.rd_data_o  (o_fifo_dout     )
    );
end
endgenerate

// IO {{{

IOL_B #( .LATCHIN ("NONE_DDR"), .DDROUT  ("YES")) u_io_clk (
    .PADDI  (        ),  // I
    .DO1    (w_clk[1]),  // I
    .DO0    (w_clk[0]),  // I
    .CE     (1'b1    ),  // I
    .IOLTO  (1'b0    ),  // I
    .HOLD   (1'b0    ),  // I
    .INCLK  (clk2x   ),  // I
    .OUTCLK (clk2x   ),  // I
    .PADDO  (SPI_CLK ),  // O
    .PADDT  (        ),  // O
    .DI1    (        ),  // O
    .DI0    (        )   // O
);

IOL_B #(.LATCHIN ("NONE_DDR"), .DDROUT  ("YES")) u_io_csb (
    .PADDI  (        ),  // I
    .DO1    (w_csb   ),  // I
    .DO0    (w_csb   ),  // I
    .CE     (1'b1    ),  // I
    .IOLTO  (1'b0    ),  // I
    .HOLD   (1'b0    ),  // I
    .INCLK  (clk2x   ),  // I
    .OUTCLK (clk2x   ),  // I
    .PADDO  (SPI_CSS ),  // O
    .PADDT  (        ),  // O
    .DI1    (        ),  // O
    .DI0    (        )   // O
);

wire	     	do_t;
wire	     	do_i;
wire	     	do_o;

BB_B u_BB_do (
    .T_N(do_t    ), 
    .I  (do_o    ), 
    .O  (do_i    ), 
    .B  (SPI_MOSI)
); 

IOL_B #( .LATCHIN ("LATCH_REG"), .DDROUT  ("YES")) u_io_mosi (
    .PADDI  (do_i     ),  // I
    .DO1    (r_do_o   ),  // I
    .DO0    (r_do_o   ),  // I
    .CE     (1'b1     ),  // I
    .IOLTO  (!w_do_z  ),  // I
    .HOLD   (1'b0     ),  // I
    .INCLK  (clk2x    ),  // I
    .OUTCLK (clk2x    ),  // I
    .PADDO  (do_o     ),  // O
    .PADDT  (do_t     ),  // O
    .DI1    (w_do_i[1]),  // O
    .DI0    (w_do_i[0])   // O
);

wire	     	di_t;
wire	     	di_i;
wire	     	di_o;

BB_B u_BB_di (
    .T_N(di_t    ), 
    .I  (di_o    ), 
    .O  (di_i    ), 
    .B  (SPI_MISO)
); 

IOL_B #( .LATCHIN ("LATCH_REG"), .DDROUT  ("YES")) u_io_miso (
    .PADDI  (di_i     ),  // I
    .DO1    (w_di_o   ),  // I
    .DO0    (w_di_o   ),  // I
    .CE     (1'b1     ),  // I
    .IOLTO  (!w_di_z  ),  // I
    .HOLD   (1'b0     ),  // I
    .INCLK  (clk2x    ),  // I
    .OUTCLK (clk2x    ),  // I
    .PADDO  (di_o     ),  // O
    .PADDT  (di_t     ),  // O
    .DI1    (w_di_i[1]),  // O
    .DI0    (w_di_i[0])   // O
);

// IO }}}

endmodule

// vim:foldmethod=marker:
// vim: ts=8 sw=4
