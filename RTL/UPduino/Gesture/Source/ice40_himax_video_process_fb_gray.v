// =============================================================================
//                           COPYRIGHT NOTICE
// Copyright 2011 (c) Lattice Semiconductor Corporation
// ALL RIGHTS RESERVED
// This confidential and proprietary software may be used only as authorised by
// a licensing agreement from Lattice Semiconductor Corporation.
// The entire notice above must be reproduced on all authorized copies and
// copies may only be made to the extent permitted by a licensing agreement from
// Lattice Semiconductor Corporation.
//
// Lattice Semiconductor Corporation        TEL : 1-800-Lattice (USA and Canada)
// 5555 NE Moore Court                            408-826-6000 (other locations)
// Hillsboro, OR 97124                     web  : http://www.latticesemi.com/
// U.S.A                                   email: techsupport@lscc.com
// =============================================================================

`timescale 1 ns / 100 ps

module ice40_himax_video_process_fb_gray (
input		clk           , 
input		pclk          , 
input		resetn        , 

// Camera interface
input           i_cam_de      ,
input           i_cam_vsync   ,
input  [3:0]    i_cam_data    ,

output reg[7:0]	o_width       ,
output reg[7:0]	o_height      ,

// video out for debugging (clk domain)
input           i_frame_req   ,
output          o_subpix_vld  ,
output    [7:0] o_subpix_out  ,

// ML engine interface
input           i_rd_rdy      ,
output reg      o_rd_req      ,
output reg      o_rd_done     ,

output reg	o_we          ,
output reg[15:0]o_waddr       ,
output reg[15:0]o_dout        
);

parameter SUBPIX     = "GRAY";
parameter EN_WIDE    = 1'b1;
parameter EN_GRAY    = 1'b1;
parameter EN_FREERUN = 1'b0;

// dynamic parameter {{{
wire	[9:0]	sb_l;
wire	[9:0]	sb_r;
wire	[8:0]	vb_u;
wire	[8:0]	vb_b;

assign sb_l = EN_WIDE ? 10'd71  : 10'd195;
assign sb_r = EN_WIDE ? 10'd583 : 10'd451;
assign vb_u = EN_WIDE ? 9'd32   : 9'd96;
assign vb_b = EN_WIDE ? 9'd288  : 9'd224;

// parameter }}}

// counters & masks {{{
reg		de_d;
reg	[3:0]	vsync_d;

reg	[9:0]	pcnt; // bit[0] indicate upper/lower nibble (0: upper nibble, 1: lower nibble) (max: 324 * 2 = 648)
reg	[8:0]	lcnt; // line counter (max: 324)

reg	[2:0]	bpcnt; // block pixel counter
wire	[2:0]	blcnt; // block line counter

reg	[5:0]	rbcnt; // read block counter (block index)
wire	[5:0]	wbcnt; // write block counter (block index)

reg		hmask;
reg		vmask;

wire	[2:0]	bmask;

reg	[3:0]	cam_data_d;
reg	[3:0]	cam_data_d2;

wire	[7:0]	raw_l; // latch R/G/B component value

wire	[7:0]	r_l; // masked value of raw_l during red time
wire	[7:0]	g_l; // masked value of raw_l during green time
wire	[7:0]	b_l; // masked value of raw_l during blue time

reg		vsync_re;
reg	[9:0]	ro_waddr;

reg		reading; // clk
reg		rd_done_pclk;
reg		rd_rdy_pclk;

assign bmask = EN_WIDE ? 3'b111 : 3'b011;

always @(posedge pclk)
begin
    de_d         <= i_cam_de;
    vsync_d      <= {vsync_d[2:0], !i_cam_vsync};
    cam_data_d   <= i_cam_data;
    cam_data_d2  <= cam_data_d;
    rd_done_pclk <= o_rd_done;
    rd_rdy_pclk  <= i_rd_rdy;
    vsync_re     <= vsync_d[3];//(vsync_d[3:2] == 2'b01);
end

always @(posedge pclk or negedge resetn)
begin
    if(resetn == 1'b0)
	o_rd_req <= 1'b0;
    else if(rd_done_pclk)
	o_rd_req <= 1'b0;
    else if((lcnt == 9'd230) && rd_rdy_pclk)
	o_rd_req <= 1'b1;
end

always @(posedge pclk)
begin
    if(i_cam_de)
	pcnt <= pcnt + 10'd1;
    else 
	pcnt <= 10'd0;
end

always @(posedge pclk or negedge resetn)
begin
    if(resetn == 1'b0)
	hmask <= 1'b0;
    else if(pcnt == sb_l)
	hmask <= 1'b1;
    else if(pcnt == sb_r)
	hmask <= 1'b0;
end

always @(posedge pclk or negedge resetn)
begin
    if(resetn == 1'b0)
	vmask <= 1'b0;
    else if(lcnt == vb_u)
	vmask <= 1'b1;
    else if(lcnt == vb_b)
	vmask <= 1'b0;
end

always @(posedge pclk)
begin
    if({de_d, i_cam_de} == 2'b10)
	o_width <= pcnt[7:0];
end

always @(posedge pclk)
begin
    if({de_d, i_cam_de} == 2'b10)
	lcnt <= lcnt + 9'd1;
    else if(vsync_re)
	lcnt <= 9'b0;
end

always @(posedge pclk)
begin
    if(vsync_d[3:2] == 2'b01)
	o_height <= lcnt[7:0];
end

always @(posedge pclk or negedge resetn)
begin
    if(resetn == 1'b0)
	bpcnt <= 3'd0;
    else if(vsync_re || (!hmask) || (!vmask))
	bpcnt <= 3'd0;
    else if(pcnt[0])
	bpcnt <= bpcnt + 3'd1;
end

always @(posedge pclk or negedge resetn)
begin
    if(resetn == 1'b0)
	rbcnt <= 6'b0;
    else if((!hmask) || (!vmask) || vsync_re)
	rbcnt <= 6'b0;
    else if(((bpcnt & bmask) == 3'd0) && pcnt[0])
	rbcnt <= rbcnt + 6'd1;
end

assign wbcnt = rbcnt - 6'd1;

assign blcnt = lcnt[2:0];

// counters & masks }}}

// downscale {{{

wire		c_we ;

wire	[11:0]	r_rdata;
reg	[11:0]	r_accu; 

wire	[12:0]	g_rdata;
reg	[12:0]	g_accu; 

wire	[11:0]	b_rdata;
reg	[11:0]	b_accu;

wire	[7:0]	r_mod;
wire	[7:0]	g_mod;
wire	[7:0]	b_mod;

wire	[15:0]	rdata0;
wire	[15:0]	rdata1;
wire	[15:0]	rdata2;

assign wdata0 = {r_accu[9:0], g_accu[10:5]};
assign wdata1 = {1'b0, b_accu[9:0], g_accu[4:0]};

assign r_rdata = rdata0[11:0];
assign g_rdata = rdata1[12:0];
assign b_rdata = rdata2[11:0];

// accumulator buffer
dpram256x16 u_ram256x16_accu0 (
    .wr_clk_i   (pclk          ),
    .rd_clk_i   (pclk          ),
    .wr_clk_en_i(1'b1          ),
    .rd_en_i    (1'b1          ),
    .rd_clk_en_i(1'b1          ),
    .wr_en_i    (c_we          ),
    .wr_data_i  ({4'b0, r_accu}),
    .wr_addr_i  ({2'b0, wbcnt} ),
    .rd_addr_i  ({2'b0, rbcnt} ),
    .rd_data_o  (rdata0        )
);

dpram256x16 u_ram256x16_accu1 (
    .wr_clk_i   (pclk          ),
    .rd_clk_i   (pclk          ),
    .wr_clk_en_i(1'b1          ),
    .rd_en_i    (1'b1          ),
    .rd_clk_en_i(1'b1          ),
    .wr_en_i    (c_we          ),
    .wr_data_i  ({3'b0, g_accu}),
    .wr_addr_i  ({2'b0, wbcnt} ),
    .rd_addr_i  ({2'b0, rbcnt} ),
    .rd_data_o  (rdata1        )
);

dpram256x16 u_ram256x16_accu2 (
    .wr_clk_i   (pclk          ),
    .rd_clk_i   (pclk          ),
    .wr_clk_en_i(1'b1          ),
    .rd_en_i    (1'b1          ),
    .rd_clk_en_i(1'b1          ),
    .wr_en_i    (c_we          ),
    .wr_data_i  ({4'b0, b_accu}),
    .wr_addr_i  ({2'b0, wbcnt} ),
    .rd_addr_i  ({2'b0, rbcnt} ),
    .rd_data_o  (rdata2        )
);

always @(posedge pclk or negedge resetn)
begin
    if(resetn == 1'b0) begin
	r_accu <= 12'b0;
	g_accu <= 13'b0;
	b_accu <= 12'b0;
    end else if(hmask && vmask && ((bpcnt & bmask) == 3'd0) && (!pcnt[0])) begin // first horizontal pixel
	r_accu <= (((blcnt & bmask) == 3'd0) ? 12'b0 : r_rdata);
	g_accu <= (((blcnt & bmask) == 3'd0) ? 13'b0 : g_rdata);
	b_accu <= (((blcnt & bmask) == 3'd0) ? 12'b0 : b_rdata);
    end else if(pcnt[0] && hmask && vmask) begin
	r_accu <= r_accu + {2'b0, r_l};
	g_accu <= g_accu + {3'b0, g_l};
	b_accu <= b_accu + {2'b0, b_l};
    end
end

assign raw_l = {cam_data_d, cam_data_d2};

assign r_l = ({pcnt[1],lcnt[0]} == 2'b11) ? raw_l : 8'b0;
assign g_l = (({pcnt[1],lcnt[0]} == 2'b10) || ({pcnt[1],lcnt[0]} == 2'b01)) ? raw_l : 8'b0;
assign b_l = ({pcnt[1],lcnt[0]} == 2'b00) ? raw_l : 8'b0;

wire	pix_wr;

assign c_we = (wbcnt != 6'h3f) && ((bpcnt & bmask) == 3'd0) && (!pcnt[0]);
assign pix_wr = (blcnt[1:0] == 2'b11) && c_we && ((!EN_WIDE) | blcnt[2]);

always @(posedge pclk or negedge resetn)
begin
    if(resetn == 1'b0)
	ro_waddr <= 10'd0;
    else if(vsync_re)
	ro_waddr <= 10'd0;
    else if(pix_wr && (ro_waddr != 10'h3ff))
	ro_waddr <= ro_waddr + 10'd1;
end

// downscale }}}

// readout {{{
wire	[23:0]	rd_pixel;
reg	[11:0]	rd_addr; // use bit[11:10] as channel index

reg		rd_rdy_clk;
reg		safe_zone_clk;

reg	[1:0]	do_d;
reg	[1:0]	rd_addr_d;

reg	[9:0]	sel_channel;

assign r_mod = EN_WIDE ? r_accu[11:4] : r_accu[9:2] ;
assign g_mod = EN_WIDE ? g_accu[12:5] : g_accu[10:3];
assign b_mod = EN_WIDE ? (b_accu[11] ? 8'hff : b_accu[10:3]) : (b_accu[9] ? 8'hff : b_accu[8:1]);

dpram1024x24 u_ram1024x24 (
    .wr_clk_i   (pclk        ),
    .rd_clk_i   (clk         ),
    .wr_clk_en_i(1'b1        ),
    .rd_en_i    (1'b1        ),
    .rd_clk_en_i(1'b1        ),
    .wr_en_i    (pix_wr      ),
    .wr_data_i  ({r_mod, g_mod, b_mod}),
    .wr_addr_i  (ro_waddr    ),
    .rd_addr_i  (rd_addr[9:0]),
    .rd_data_o  (rd_pixel    )
);

always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0) begin
	rd_rdy_clk    <= 1'b0;
	safe_zone_clk <= 1'b0;
    end else begin
	rd_rdy_clk    <= i_rd_rdy;
	safe_zone_clk <= o_rd_req;
    end
end

always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0)
	do_d <= 2'b0;
    else 
	do_d <= {do_d[0], (rd_rdy_clk & (safe_zone_clk | EN_FREERUN))};
end

always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0)
	reading <= 1'b0;
    else if(do_d == 2'b01)
	reading <= 1'b1;
    else if(rd_addr == ((EN_GRAY == 1'b1) ? 12'h3ff : 12'hbff))
	reading <= 1'b0;
end

always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0)
	o_we <= 1'b0;
    else if(rd_addr == 16'h001) // read latency
	o_we <= 1'b1;
    else if(o_waddr == ((EN_GRAY == 1'b1) ? 16'h3ff : 16'hbff))
	o_we <= 1'b0;
end

always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0)
	rd_addr <= 12'b0;
    else if(reading)
	rd_addr <= rd_addr + 12'd1;
    else
	rd_addr <= 12'b0;
end

always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0) begin
	rd_addr_d <= 2'b0;
    end else begin
	rd_addr_d <= rd_addr[11:10];
    end
end


always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0)
	o_waddr <= 16'b0;
    else if(o_we)
	o_waddr <= o_waddr + 16'd1;
    else
	o_waddr <= 16'b0;
end


always @(*)
begin
    if(EN_GRAY == 1'b1)
	sel_channel = {1'b0, rd_pixel[15: 8], 1'b0} + {2'b0, rd_pixel[ 7: 0]} + {2'b0, rd_pixel[23:16]};
    else case(rd_addr_d)
	2'b01:
	    sel_channel = {rd_pixel[15: 8], 2'b0};
	2'b10:
	    sel_channel = {rd_pixel[23:16], 2'b0};
	default: // blue
	    sel_channel = {rd_pixel[ 7: 0], 2'b0};
    endcase
end


always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0)
	o_dout <= 16'b0;
    else 
	o_dout <= {6'b0, sel_channel} - 16'h0200 ;
end

always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0)
	o_rd_done <= 1'b0;
    else if(o_waddr == ((EN_GRAY == 1'b1) ? 16'h3ff : 16'hbff))
	o_rd_done <= 1'b1;
    else if(!rd_rdy_clk)
	o_rd_done <= 1'b0;
end

// readout }}}

// frame out {{{

generate if(SUBPIX != "NONE")
begin: g_on_frame_out
    reg		frame_req_l;
    reg	[2:0]	vsync_clk;
    reg		vsync_re_clk;
    reg		vsync_fe_clk;
    reg		frame_reading;
    reg		pix_vld_tg_pclk;
    reg	[23:0]	pix_lat_pclk;

    reg	[2:0]	pix_vld_tg_clk;
    reg	[23:0]	pix_lat_clk;

    reg	[1:0]	sub_pix_cnt;

    reg		r_subpix_vld;
    reg	[7:0]	r_subpix_out;

    always @(posedge clk or negedge resetn)
    begin
	if(resetn == 1'b0)
	    frame_req_l <= 1'b0;
	else if(i_frame_req)
	    frame_req_l <= 1'b1;
	else if(frame_reading)
	    frame_req_l <= 1'b0;
    end

    always @(posedge clk)
    begin
	vsync_clk <= {vsync_clk[1:0], !i_cam_vsync};

	vsync_re_clk <= (vsync_clk[2:1] == 2'b01);
	vsync_fe_clk <= (vsync_clk[2:1] == 2'b10);
    end

    always @(posedge clk or negedge resetn)
    begin
	if(resetn == 1'b0)
	    frame_reading <= 1'b0;
	else if(vsync_fe_clk && frame_req_l)
	    frame_reading <= 1'b1;
	else if(vsync_re_clk)
	    frame_reading <= 1'b0;
    end

    always @(posedge pclk or negedge resetn)
    begin
	if(resetn == 1'b0)
	    pix_vld_tg_pclk <= 1'b0;
	else if(pix_wr)
	    pix_vld_tg_pclk <= ~pix_vld_tg_pclk;
    end

    always @(posedge pclk)
    begin
	if(pix_wr)
	    pix_lat_pclk <= {r_mod, g_mod, b_mod};
    end

    always @(posedge clk or negedge resetn)
    begin
	if(resetn == 1'b0)
	    pix_vld_tg_clk <= 3'b0;
	else 
	    pix_vld_tg_clk <= {pix_vld_tg_clk[1:0], pix_vld_tg_pclk};
    end

    always @(posedge clk or negedge resetn)
    begin
	if(resetn == 1'b0)
	    sub_pix_cnt <= 2'b0;
	else if(pix_vld_tg_clk[2] != pix_vld_tg_clk[1])
	    sub_pix_cnt <= (SUBPIX == "888") ? 2'd3 : (SUBPIX == "565") ? 2'd2 : 2'd1;
	else if(sub_pix_cnt != 2'b0)
	    sub_pix_cnt <= sub_pix_cnt - 2'd1;
    end

    wire	[9:0]	gray;

    assign gray = {1'b0, pix_lat_pclk[15: 8], 1'b0} + {2'b0, pix_lat_pclk[ 7: 0]} + {2'b0, pix_lat_pclk[23:16]};

    always @(posedge clk or negedge resetn)
    begin
	if(resetn == 1'b0)
	    pix_lat_clk <= 24'b0;
	else if(pix_vld_tg_clk[2] != pix_vld_tg_clk[1])
	    pix_lat_clk <= (SUBPIX == "GRAY") ? {gray[9:2], gray[9:2], gray[9:2]} : pix_lat_pclk;
	else if((sub_pix_cnt != 2'b0) && (SUBPIX != "565"))
	    pix_lat_clk <= {8'b0, pix_lat_clk[23:8]};
    end

    always @(posedge clk or negedge resetn)
    begin
	if(resetn == 1'b0)
	    r_subpix_vld <= 1'b0;
	else if(frame_reading)
	    r_subpix_vld <= (sub_pix_cnt != 2'b0);
	else
	    r_subpix_vld <= 1'b0;
    end

    always @(posedge clk or negedge resetn)
    begin
	if(resetn == 1'b0)
	    r_subpix_out <= 8'b0;
	else
	    r_subpix_out <= (SUBPIX != "565") ? pix_lat_clk[7:0]  - 8'd128:
			    (sub_pix_cnt == 2'd1) ? {pix_lat_clk[23:19], pix_lat_clk[15:13]} : 
						    {pix_lat_clk[12:10], pix_lat_clk[ 7: 3]};
    end

    assign o_subpix_vld = r_subpix_vld;
    assign o_subpix_out = r_subpix_out;
end
else
begin
    assign o_subpix_vld = 1'b0;
    assign o_subpix_out = 8'b0;
end
endgenerate

// frame out }}}

endmodule

// vim:foldmethod=marker:
//
