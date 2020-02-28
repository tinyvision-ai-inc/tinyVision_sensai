
module lsc_i2cm_himax(
input             clk    , // 48MHz clk
input             init   ,

input             scl_in ,
input             sda_in ,
output            scl_out,
output            sda_out,
output reg	  init_done,
input             resetn
);

parameter [6:0]	NUM_CMD = 7'd80;
parameter EN_ALT = 1;
parameter CONF_SEL = "QVGA";

// state machine
parameter [2:0] 
	S_IDLE  = 3'b000,
	S_RDOFF = 3'b001,
	S_RDDAT = 3'b010,
	S_RUN   = 3'b011,
	S_WAIT  = 3'b111;

reg     [2:0]   state;
reg     [2:0]   nstate;

reg	[6:0]	i2c_cnt;
wire		lsb_addr;
wire	[15:0]	i2c_cmd;
wire		i2c_set;
wire		i2c_done;
wire    [7:0]   i2c_rd_data;
wire            i2c_running;

reg		init_req;
reg	[1:0]	init_d;

reg	[15:0]	ofs_addr;

always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0) 
	init_d <= 2'b0;
    else               
	init_d <= {init_d[0], init};
end

always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0)             
	init_req <= 1'b1;
    else if(init_d == 2'b01)       
	init_req <= 1'b1;
    else if(state == S_IDLE)       
	init_req <= 1'b0;
end

always @(posedge clk or negedge resetn)
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
	    nstate <= init_req ? S_RDOFF : S_IDLE;
	S_RDOFF:
	    nstate <= S_RDDAT;
	S_RDDAT:
	    nstate <= S_RUN;
	S_RUN:
	    nstate <= S_WAIT;
	S_WAIT:
	    nstate <= i2c_running ? S_WAIT : ((i2c_cnt == NUM_CMD) ? S_IDLE : S_RDOFF);
	default:
	    nstate <= S_IDLE ;
    endcase
end

assign i2c_set = (state == S_RUN);

always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0)     
	i2c_cnt <= 7'd0;
    else if(state == S_IDLE) 
	i2c_cnt <= 7'd0;
    else if(i2c_done)
	i2c_cnt <= i2c_cnt + 7'd1;
end

assign lsb_addr = (state == S_RDDAT);

always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0) 
	init_done <= 1'b0;
    else if(init_req == 1'b1)
	init_done <= 1'b0;
    else if(i2c_cnt == NUM_CMD)
	init_done <= 1'b1;
end

always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0) 
	ofs_addr <= 16'b0;
    else if(state == S_RDDAT)
	ofs_addr <= i2c_cmd;
end

lsc_i2cm_16 u_lsc_i2cm(
    .clk     (clk           ),
    .enable  (1'b1          ),
    .rw      (1'b0          ),
    .run     (i2c_set       ),
    .interval(6'd30         ),
    .dev_addr(7'h24         ),
    .ofs_addr(ofs_addr      ),
    .wr_data (i2c_cmd[ 7: 0]),
    .scl_in  (scl_in        ),
    .sda_in  (sda_in        ),
    .scl_out (scl_out       ),
    .sda_out (sda_out       ),
    .running (i2c_running   ),
    .done    (i2c_done      ),
    .rd_data (i2c_rd_data   ),
    .resetn  (resetn        )
);

`ifdef ICECUBE
SB_RAM256x16 u_ram256x16_himax (
    .RDATA (i2c_cmd ),
    .RADDR ({i2c_cnt, lsb_addr}),
    .RCLK  (clk     ),
    .RCLKE (1'b1    ),
    .RE    (1'b1    ),
    .WADDR (8'b0    ),
    .WCLK  (clk     ),
    .WCLKE (1'b0    ),
    .WDATA (16'b0   ),
    .WE    (1'b0    ),
    .MASK  (16'hffff)
);

defparam u_ram256x16_himax.INIT_0 = 256'h00C0_3050__000A_3047__0000_3045__000A_3044__0008_1007__0008_1003__0000_0100__0000_0103; // 8
defparam u_ram256x16_himax.INIT_1 = 256'h001F_3058__0029_3057__00F8_3056__00F7_3055__0003_3054__0000_3053__0050_3052__0042_3051; // 16
defparam u_ram256x16_himax.INIT_2 = 256'h0001_1006__007F_0350__0032_1002__0040_1001__0043_1000__0004_3065__0000_3064__001E_3059; // 24
defparam u_ram256x16_himax.INIT_3 = 256'h0000_2003__0007_2000__0000_1012__0040_100C__0090_100B__0060_100A__00A0_1009__0000_1008; // 32
defparam u_ram256x16_himax.INIT_4 = 256'h0000_2013__00B8_2010__0000_200F__007A_200C__0000_200B__0058_2008__0000_2007__001C_2004; // 40
defparam u_ram256x16_himax.INIT_5 = 256'h0033_2108__00A4_2106__0003_2105__0007_2104__0001_2100__009B_2018__0000_2017__0058_2014; // 48
defparam u_ram256x16_himax.INIT_6 = 256'h000C_0340__0003_2150__0017_2112__0001_2111__00E9_2110__0000_210F__0080_210B__0000_210A; // 56
defparam u_ram256x16_himax.INIT_7 = 256'h0042_3059__0000_0390__0000_0387__0000_0383__0001_3010__0078_0343__0001_0342__005C_0341; // 64
defparam u_ram256x16_himax.INIT_8 = 256'h0001_3067__0020_3061__0000_020F__0040_2102__0080_2101__0005_0100__0000_0101__0051_3060; // 72
defparam u_ram256x16_himax.INIT_9 = 256'h0000_0000__0000_0000__0000_0000__0000_0000__0000_0000__0000_0000__0000_0000__0000_0104; // 80
defparam u_ram256x16_himax.INIT_A = 256'h0000_0000__0000_0000__0000_0000__0000_0000__0000_0000__0000_0000__0000_0000__0000_0000; // 88
defparam u_ram256x16_himax.INIT_B = 256'h0000_0000__0000_0000__0000_0000__0000_0000__0000_0000__0000_0000__0000_0000__0000_0000; // 96
defparam u_ram256x16_himax.INIT_C = 256'h0000_0000__0000_0000__0000_0000__0000_0000__0000_0000__0000_0000__0000_0000__0000_0000; // 104
defparam u_ram256x16_himax.INIT_D = 256'h0000_0000__0000_0000__0000_0000__0000_0000__0000_0000__0000_0000__0000_0000__0000_0000; // 112
defparam u_ram256x16_himax.INIT_E = 256'h0000_0000__0000_0000__0000_0000__0000_0000__0000_0000__0000_0000__0000_0000__0000_0000; // 120
defparam u_ram256x16_himax.INIT_F = 256'h0000_0000__0000_0000__0000_0000__0000_0000__0000_0000__0000_0000__0000_0000__0000_0000; // 128
`else // Radiant
generate if(EN_ALT == 1)
begin: g_on_en_alt
    rom_himax_cfg u_rom_himax_cfg (
	.clk_i     (clk     ),
	.clk_en_i  (1'b1    ),
	.wr_en_i   (1'b0    ),
	.wr_data_i (16'b0   ),
	.addr_i    ({i2c_cnt, lsb_addr}),
	.rd_data_o (i2c_cmd )
    );
end
else if(CONF_SEL == "QVGA")
begin
    sbram_256x16_himax u_ram256x16_himax (
	.wr_clk_i   (clk     ),
	.rd_clk_i   (clk     ),
	.wr_clk_en_i(1'b0    ),
	.rd_en_i    (1'b1    ),
	.rd_clk_en_i(1'b1    ),
	.wr_en_i    (1'b0    ),
	.wr_data_i  (16'b0   ),
	.wr_addr_i  (8'b0    ),
	.rd_addr_i  ({i2c_cnt, lsb_addr}),
	.rd_data_o  (i2c_cmd )
    );
end
else if(CONF_SEL == "QVGA_fixed")
begin
    rom_himax_cfg_qvga_fixed u_rom_himax_cfg (
	.clk_i     (clk     ),
	.clk_en_i  (1'b1    ),
	.wr_en_i   (1'b0    ),
	.wr_data_i (16'b0   ),
	.addr_i    ({i2c_cnt, lsb_addr}),
	.rd_data_o (i2c_cmd )
    );
end
else if(CONF_SEL == "QVGA_fixed_maxfps")
begin
    rom_himax_cfg_qvga_fixed_maxfps u_rom_himax_cfg (
	.clk_i     (clk     ),
	.clk_en_i  (1'b1    ),
	.wr_en_i   (1'b0    ),
	.wr_data_i (16'b0   ),
	.addr_i    ({i2c_cnt, lsb_addr}),
	.rd_data_o (i2c_cmd )
    );
end
else if(CONF_SEL == "324x324_dim")
begin
    rom_himax_cfg_324_dim u_rom_himax_cfg (
	.clk_i     (clk     ),
	.clk_en_i  (1'b1    ),
	.wr_en_i   (1'b0    ),
	.wr_data_i (16'b0   ),
	.addr_i    ({i2c_cnt, lsb_addr}),
	.rd_data_o (i2c_cmd )
    );
end
else if(CONF_SEL == "324x324_dim_maxfps")
begin
    rom_himax_cfg_324_dim_maxfps u_rom_himax_cfg (
	.clk_i     (clk     ),
	.clk_en_i  (1'b1    ),
	.wr_en_i   (1'b0    ),
	.wr_data_i (16'b0   ),
	.addr_i    ({i2c_cnt, lsb_addr}),
	.rd_data_o (i2c_cmd )
    );
end
else if(CONF_SEL == "324x324_faceid")
begin
    rom_himax_cfg_324_faceid u_rom_himax_cfg (
	.clk_i     (clk     ),
	.clk_en_i  (1'b1    ),
	.wr_en_i   (1'b0    ),
	.wr_data_i (16'b0   ),
	.addr_i    ({i2c_cnt, lsb_addr}),
	.rd_data_o (i2c_cmd )
    );
end
else if(CONF_SEL == "324x324_lcd_fps")
begin
    rom_himax_cfg_lcd u_rom_himax_cfg (
	.clk_i     (clk     ),
	.clk_en_i  (1'b1    ),
	.wr_en_i   (1'b0    ),
	.wr_data_i (16'b0   ),
	.addr_i    ({i2c_cnt, lsb_addr}),
	.rd_data_o (i2c_cmd )
    );
end
else if(CONF_SEL == "324x324_seq_fps")
begin
    rom_himax_cfg_seq u_rom_himax_cfg (
	.clk_i     (clk     ),
	.clk_en_i  (1'b1    ),
	.wr_en_i   (1'b0    ),
	.wr_data_i (16'b0   ),
	.addr_i    ({i2c_cnt, lsb_addr}),
	.rd_data_o (i2c_cmd )
    );
end
else if(CONF_SEL == "324x324_1fps")
begin
    rom_himax_cfg_1fps u_rom_himax_cfg (
	.rd_clk_i   (clk     ),
	.rd_clk_en_i(1'b1    ),
	.rd_en_i    (1'b1    ),
	.rd_addr_i  ({i2c_cnt, lsb_addr}),
	.rd_data_o  (i2c_cmd )
    );
end
else if(CONF_SEL == "324x324_chardet")
begin
    rom_himax_cfg_chardet u_rom_himax_cfg (
	.rd_clk_i   (clk     ),
	.rd_clk_en_i(1'b1    ),
	.rd_en_i    (1'b1    ),
	.rd_addr_i  ({i2c_cnt, lsb_addr}),
	.rd_data_o  (i2c_cmd )
    );
end
else // 324x324
begin
    rom_himax_cfg_324 u_rom_himax_cfg (
	.clk_i     (clk     ),
	.clk_en_i  (1'b1    ),
	.wr_en_i   (1'b0    ),
	.wr_data_i (16'b0   ),
	.addr_i    ({i2c_cnt, lsb_addr}),
	.rd_data_o (i2c_cmd )
    );
end
endgenerate

`endif

endmodule
