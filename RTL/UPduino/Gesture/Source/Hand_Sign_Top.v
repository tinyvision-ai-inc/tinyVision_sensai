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

//`define CNN_LEGACY 1

module Hand_Sign_Top (
// Camera interface
input		cam_pclk      ,
input           cam_hsync     ,
input           cam_vsync     ,
input  [3:0]    cam_data      ,
output          cam_trig      ,

output          cam_mclk      ,

inout           cam_scl       ,
inout           cam_sda       ,

input           uart_rxd      ,
output          uart_txd      ,

// SPI
output    	spi_css       ,
inout    	spi_clk       ,
input     	spi_miso      ,
output    	spi_mosi      ,

output  [5:0]   oled        
);

// Parameters {{{

parameter EN_SINGLE_CLK = 1'b0; // 1: single clock mode (core clk == pclk) 0: independent clock mode (core clk != pclk)
parameter EN_UART       = 1'b1; // 1: instantiate UART for video output. EN_CLKMASK must be 0 in order to enable EN_UART
parameter EN_CLKMASK    = 1'b0; // 1: instantiate clock masking block
parameter CODE_MEM      = "DUAL_SPRAM";
                                // EBRAM
				// SINGLE_SPRAM
				// DUAL_SPRAM
// Parameters }}}

// platform signals {{{
// Clocks
wire		clk;		// core clock
wire		oclk_in;	// internal oscillator clock input
wire		oclk;		// internal oscillator clock (global)
wire		pclk_in;
wire		pclk;		// pixel clock
wire		clk_init;	// initialize clock (based on oclk)
wire		resetn;
wire		w_init;
wire		w_init_done;

// SPI loader
wire		w_fill      ;
wire		w_fifo_empty;
wire		w_fifo_low  ;
wire		w_fifo_rd   ;
wire	[31:0]	w_fifo_dout ;
wire		w_load_done ;

wire		w_rd_rdy;
wire		w_rd_rdy_con;
wire		w_rd_req;
wire		w_rd_done;
wire		w_we;
wire	[15:0]	w_waddr;
wire	[15:0]	w_dout;

wire	        w_running;
wire	[7:0]	ml_status;

wire	[31:0]	w_cycles;
wire	[31:0]	w_commands;
wire	[31:0]	w_fc_cycles;

wire		w_result_en;
reg	[1:0]	r_result_en_d;
wire	[15:0]	w_result;

reg	[15:0]	result0;
reg	[15:0]	result1;
reg	[15:0]	result2;
reg	[15:0]	result3;

reg	[3:0]	r_max;
wire	[3:0]	w_max;

reg	[3:0]	r_max_lat;
reg	[3:0]	r_max_filter;

reg	[3:0]	r_stable_cnt;

// video related signals
wire	[3:0]	cam_data_p;
wire		cam_de_p;
wire		cam_vsync_p;
wire	[3:0]	cam_data_n;
wire		cam_de_n;
wire		cam_vsync_n;

// camera configuration
wire		w_scl_out;
wire		w_sda_out;

// internal UART & SPI
wire		w_uart_txd;
wire		w_uart_rxd;

wire		w_spi_clk;
wire		w_spi_mosi;

// platform signals }}}

// I/O cell instantation {{{

assign pclk_in = cam_pclk;

IOL_B
#(
  .LATCHIN ("NONE_DDR"),
  .DDROUT  ("NO")
) u_io_cam_data[3:0] (
  .PADDI  (cam_data[3:0]),  // I
  .DO1    (1'b0),  // I
  .DO0    (1'b0),  // I
  .CE     (1'b1),  // I - clock enabled
  .IOLTO  (1'b1),  // I - tristate enabled
  .HOLD   (1'b0),  // I - hold disabled
  .INCLK  (pclk),  // I
  .OUTCLK (pclk),  // I
  .PADDO  (),  // O
  .PADDT  (),  // O
  .DI1    (cam_data_n[3:0]),  // O
  .DI0    (cam_data_p[3:0])   // O
);

assign cam_vsync_p = cam_vsync;

IOL_B
#(
  .LATCHIN ("NONE_DDR"),
  .DDROUT  ("NO")
) u_io_cam_de (
  .PADDI  (cam_hsync),  // I
  .DO1    (1'b0),  // I
  .DO0    (1'b0),  // I
  .CE     (1'b1),  // I - clock enabled
  .IOLTO  (1'b1),  // I - tristate enabled
  .HOLD   (1'b0),  // I - hold disabled
  .INCLK  (pclk),  // I
  .OUTCLK (pclk),  // I
  .PADDO  (),  // O
  .PADDT  (),  // O
  .DI1    (cam_de_n),  // O
  .DI0    (cam_de_p)   // O
);

// I/O cell instantation }}}

// debug signals {{{

wire	[7:0]	w_config_00;
wire			w_frame_req ;
wire			w_subpix_vld;
wire	[7:0]	w_subpix_out;

wire		w_uart_empty;
wire	      	w_debug_vld;

// debug signals }}}

// Platform block {{{

HSOSC # (.CLKHF_DIV("0b01")) u_hfosc (
    .CLKHFEN   (1'b1 ),
    .CLKHFPU   (1'b1 ),
    .CLKHF     (oclk_in )
);
    

ice40_himax_signdet_clkgen #(.EN_CLKMASK(EN_CLKMASK), .EN_SINGLE_CLK(EN_SINGLE_CLK)) u_ice40_facedet_clkgen (
    .i_oclk_in   (oclk_in     ),
    .i_pclk_in   (pclk_in     ),

    .i_init_done (w_init_done ),
    .i_cam_vsync (cam_vsync_p ),
    .i_load_done (w_load_done ),
    .i_ml_rdy    (w_rd_rdy_con),
    .i_vid_rdy   (w_rd_done   ),
    .i_rd_req    (w_rd_req    ),

    .o_init      (w_init      ),
    .o_oclk      (oclk        ), // oscillator clock (always live)
    .o_clk       (clk         ), // core clock
    .o_pclk      (pclk        ), // video clock
    .o_clk_init  (clk_init    ),

    .resetn      (resetn      )
);

ice40_resetn u_resetn(
    .clk    (oclk  ),
    .resetn (resetn)
);

assign cam_mclk = w_init_done ? 1'b0 : oclk;

lsc_i2cm_himax #(.EN_ALT(0), .CONF_SEL("QVGA_fixed")) u_lsc_i2cm_himax(
    .clk      (clk_init   ),
    .init     (w_init     ),
    .init_done(w_init_done),
    .scl_in   (cam_scl    ),
    .sda_in   (cam_sda    ),
    .scl_out  (w_scl_out  ),
    .sda_out  (w_sda_out  ),
    .resetn   (resetn     )
);

assign cam_scl = w_scl_out ? 1'bz : 1'b0;
assign cam_sda = w_sda_out ? 1'bz : 1'b0;

// Platform block }}}

// Debug block {{{

generate if(EN_UART)
begin: g_on_en_uart

    lsc_uart #(.PERIOD(16'd103), .BUFFER_SIZE("1K")) u_lsc_uart(
	.ref_clk(clk         ),
	.clk    (clk         ),
	.i_din  (w_subpix_out),
	.i_valid(w_subpix_vld), 
	.o_dout (),
	.o_valid(w_frame_req ),
	.o_empty(),
	.i_rxd  (w_uart_rxd  ), 
	.o_txd  (w_uart_txd  ),
	.resetn (resetn      )
    );

	assign uart_txd =  1'b1; // power on for UPDUINO2
    assign w_uart_empty = 1'b1;
end
else
begin
	assign uart_txd = 1'b1;
    assign w_uart_empty = 1'b1;

end
endgenerate

// Debug block }}}

// Code memory {{{
spi_loader_wrap #(.MEM_TYPE(CODE_MEM)) u_spi_loader(
    .clk          (clk          ),
    .resetn       (resetn       ),

    .o_load_done  (w_load_done  ),

    .i_fill       (w_fill       ),
    .i_init       (w_init       ),
    .o_fifo_empty (w_fifo_empty ),
    .o_fifo_low   (w_fifo_low   ),
    .i_fifo_rd    (w_fifo_rd    ),
    .o_fifo_dout  (w_fifo_dout  ),

    .SPI_CLK      (w_spi_clk    ),
    .SPI_CSS      (spi_css      ),
    .SPI_MISO     (spi_miso     ),
    .SPI_MOSI     (w_spi_mosi   )
);

assign spi_clk = w_load_done ? 1'bz : w_spi_clk;
assign w_uart_rxd = spi_clk & w_load_done;
assign spi_mosi = w_load_done ? w_uart_txd : w_spi_mosi;
// Code memory }}}

// Video processing {{{

ice40_himax_video_process_fb_gray #(.EN_WIDE(1'b0), .EN_GRAY(1'b1), .SUBPIX("GRAY")) u_ice40_himax_video_process_fb_gray (
    .clk         (clk         ),
    .pclk        (pclk        ),
    .resetn      (resetn      ),

    .i_cam_de    (cam_de_p    ),
    .i_cam_vsync (cam_vsync_p ),
    .i_cam_data  (cam_data_p  ),

    .o_width     (),
    .o_height    (),

    .i_frame_req (w_frame_req ),
    .o_subpix_vld(w_subpix_vld),
    .o_subpix_out(w_subpix_out),

    .i_rd_rdy    (w_rd_rdy_con),
    .o_rd_req    (w_rd_req    ),
    .o_rd_done   (w_rd_done   ),

    .o_we        (w_we        ),
    .o_waddr     (w_waddr     ),
    .o_dout      (w_dout      )
);

assign cam_trig = 1'b1;

// Video processing }}}

// Result handling {{{
always @(posedge clk)
begin
    if(w_result_en) begin
	result3 <= w_result;
	result2 <= result3;
	result1 <= result2;
	result0 <= result1;
    end
end

always @(posedge clk)
begin
    r_result_en_d <= {r_result_en_d[0], w_result_en};
end

always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0)
	r_max_lat <= 4'b0;
    else if(r_result_en_d == 2'b10) 
	r_max_lat <= r_max;
end

always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0)
	r_stable_cnt <= 4'b0;
    else if(r_result_en_d == 2'b10) 
	r_stable_cnt <= (r_max != r_max_lat) ? 4'd0 : (r_stable_cnt + ((r_stable_cnt != 4'hf) ? 4'd1 : 4'd0));
end

always @(posedge clk or negedge resetn)
begin
    if(resetn == 1'b0)
	r_max_filter <= 4'b0;
	else if((r_stable_cnt == 4'd3) || (r_stable_cnt == 4'd2))
	r_max_filter <= r_max_lat;
end

assign w_max =  r_max_filter;

// Result handling }}}


    lsc_ml_ice40_cnn u_lsc_ml (
	.clk         (clk         ),
	.resetn      (resetn      ),
				  
	.o_rd_rdy    (w_rd_rdy    ),
	.i_start     (w_rd_done   ),

	.o_cycles    (w_cycles    ),
	.o_commands  (w_commands  ),
	.o_fc_cycles (w_fc_cycles ),
				  
	.i_we        (w_we        ),
	.i_waddr     (w_waddr     ),
	.i_din       (w_dout      ),

	.o_we        (w_result_en ),
	.o_dout      (w_result    ),
	
	.i_debug_rdy (w_uart_empty),
	.o_debug_vld (w_debug_vld ),

	.o_fill      (w_fill      ),
	.i_fifo_empty(w_fifo_empty),
	.i_fifo_low  (w_fifo_low  ),
	.o_fifo_rd   (w_fifo_rd   ),
	.i_fifo_dout (w_fifo_dout ),

	.o_status    (ml_status   )
    );

    assign w_rd_rdy_con = w_rd_rdy & (!w_config_00[0]);


    always @(posedge clk)
    begin
	r_max <= {(~result3[15]) & (result0[15] || (result3 > result0))
	                         & (result1[15] || (result3 > result1))
	                         & (result2[15] || (result3 > result2)),
	          (~result2[15]) & (result0[15] || (result2 > result0))
	                         & (result1[15] || (result2 > result1))
	                         & (result3[15] || (result2 > result3)),
	          (~result1[15]) & (result0[15] || (result1 > result0))
	                         & (result2[15] || (result1 > result2))
	                         & (result3[15] || (result1 > result3)),
	          (~result0[15]) & (result1[15] || (result0 > result1))
	                         & (result2[15] || (result0 > result2))
	                         & (result3[15] || (result0 > result3))};
    end
// NN block }}}

// LEDs {{{

    assign oled[0] = w_max[3] ? 1'bz : 1'b0; // OTHERS
    assign oled[1] = w_max[0] ? 1'bz : 1'b0; // NULL
    assign oled[2] = 1'b0;
    assign oled[3] = w_max[2] ? 1'bz : 1'b0; // CLOSE
    assign oled[4] = 1'b0;
    assign oled[5] = w_max[1] ? 1'bz : 1'b0; // OPEN
 
// LEDs }}}


endmodule

// vim:foldmethod=marker:
//
