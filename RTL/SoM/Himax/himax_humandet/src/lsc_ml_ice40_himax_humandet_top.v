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

//`define USE_LCD
`define SOM

module lsc_ml_ice40_himax_humandet_top (
        //input		clk_in        ,  // 27MHz oscillator

        // Camera interface
        input		cam_pclk      ,
        input           cam_hsync     ,
        input           cam_vsync     ,
        input  [3:0]    cam_data      ,
        output          cam_trig      ,

        output          cam_mclk      ,

        inout           cam_scl       ,
        inout           cam_sda       ,

        inout           debug_scl     ,
        inout           debug_sda     ,

        // Debug for seeing the frames
        input           uart_rxd      ,
        output          uart_txd      ,

        // SPI
        output    	spi_css       ,
        inout    	spi_clk       ,
        inout     	spi_miso      ,
        inout    	spi_mosi      ,

        // LCD
        `ifdef USE_LCD

            output          lcd_spi_gpo   ,
            output          lcd_spi_clk   ,
            output          lcd_spi_css   ,
            output          lcd_spi_mosi  ,
            output          lcd_resetn    ,
        `endif

        // Color LED
        output          REDn          ,
        output          BLUn          ,
        output          GRNn          ,

    `ifdef SOM

        output host_intr,
        input host_sck,
        input host_ssn,
        input host_mosi,
        output host_miso,
        output i2s_sck,
        output i2s_ws,
        input i2s_dat,
        output imager_ssn,
        output sram_ssn,
        input imu_intr,
        input sensor_miso,
        inout mem_sio2,
        inout mem_sio3

    `else
        output          standby       ,

        // audio result in
        input           aux_det       ,
        input  [1:0]    aux_idx       ,
        output  [5:0]   oled
    `endif
            );

        // Parameters {{{
        parameter ML_TYPE       = "CNN"; // ML engine type
        // CNN
        // BNN
        // BWN
        parameter USE_ML        = 1'b1; // instantate ML engine or not
        parameter MEM_TYPE      = "SINGLE_SPRAM"; 
        // EBRAM: use EBR for active memory storage (valid only when EN_SINGLE_CLK == 1) 
        // DUAL_SPRAM: use Dual SPRAM for active memory storage
        // otherwise: use single SPRAM for active memory storage
        parameter BNN_ONEZERO   = 1'b1; // 1: 1,0 activation instead of 1, -1
        parameter BYTE_MODE     = "UNSIGNED"; // DISABLE
        // SIGNED
        // UNSIGNED
        parameter EN_SINGLE_CLK = 1'b0; // 1: single clock mode (core clk == pclk) 0: independent clock mode (core clk != pclk)

        parameter EN_I2CS       = 1'b0; // 1: instantiate i2c slave for control & debugging, EN_CAPTURE and EN_DEBUG are valid only when EN_I2CS == 1
        parameter EN_CAPTURE    = 1'b0; // 1: enable frame capture feature
        parameter EN_DEBUG      = 1'b0; // 1: enable debug capture feature

        parameter EN_UART       = 1'b1; // 1: instantiate UART for video output
        parameter EN_DUAL_UART  = 1'b1; // 1: wired AND connection for uart signal
        parameter EN_CLKMASK    = 1'b0; // 1: instantiate clock masking block: no effect on power
        parameter EN_SEQ        = 1'b0; // 1: sequence mode
        parameter MIRROR_MODE   = 1'b1; // 1: for fixed (no scan) and GPIO output for mirror demo
        parameter FUSION_MODE   = 1'b0; // 1: for fusion (human + voice) mode
        parameter EN_UPDUINO2   = 1'b1; // 1: for upduino2 board (no dip_sw)
        parameter CODE_MEM      = "TRI_SPRAM";
        // EBRAM
        // SINGLE_SPRAM
        // DUAL_SPRAM
        // TRI_SPRAM
        // QUAD_SPRAM
        // EXTERNAL
        parameter LCD_TYPE      = "NONE"; // LCD
        // OLED
        // NONE

        // Parameters }}}

        // platform signals {{{
        // Clocks
        wire		clk;		// core clock
        wire		clk2x;		// 2x clock for external SPI
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
        reg		r_rd_rdy_con;
        wire		w_rd_done;
        reg	[1:0]	r_rd_done_d;
        wire		w_we;
        wire	[15:0]	w_waddr;
        wire	[15:0]	w_dout;

        wire	        w_running;
        wire	[7:0]	ml_status;

        wire	[31:0]	w_cycles;
        wire	[31:0]	w_commands;
        wire	[31:0]	w_fc_cycles;

        wire		w_result_en;
        wire	[15:0]	w_result;

        reg		r_det;
        reg		r_det_filter;
        reg	[4:0]	r_det_histo;

        reg	[5:0]	r_det_vec;

        reg	[7:0]	r_comp_done_d;
        wire	[15:0]	w_class0;
        reg	[15:0]	r_class0;
        reg	[15:0]	r_class1;
        reg	[15:0]	r_class2;
        reg	[15:0]	r_class3;
        reg	[15:0]	r_class4;
        reg	[15:0]	r_class5;

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

        wire		w_lcd_init_done;
        wire		w_lcd_running;
        wire		w_lcd_mode   ;
        wire		w_pix_we     ;
        wire	[15:0]	w_pix        ;

        wire	[7:0]	w_osd_addr;
        wire	     	w_osd_wr;
        wire	[7:0]	w_osd_data;

        wire		quad_on;
        wire	[3:0]	quad_section;
        wire	[2:0]	quad_color; // {intensity, color_code} 00: red, 01: green, 10: blue, 11: white

        wire	[1:0]	w_debug_prob;

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

        IOL_B
            #(
                .LATCHIN ("NONE_REG"),
                .DDROUT  ("NO")
            ) u_io_cam_vsync (
                .PADDI  (cam_vsync),  // I
                .DO1    (1'b0),  // I
                .DO0    (1'b0),  // I
                .CE     (1'b1),  // I - clock enabled
                .IOLTO  (1'b1),  // I - tristate enabled
                .HOLD   (1'b0),  // I - hold disabled
                .INCLK  (pclk),  // I
                .OUTCLK (pclk),  // I
                .PADDO  (),  // O
                .PADDT  (),  // O
                .DI1    (cam_vsync_n),  // O
                .DI0    (cam_vsync_p)   // O
            );

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
        wire	[7:0]	w_config_01;
        wire	[7:0]	w_config_02;
        wire	[7:0]	w_config_03;
        wire	[7:0]	w_config_04;
        wire	[7:0]	w_status_00;
        wire	[7:0]	w_status_01;
        wire	[7:0]	w_status_02;
        wire	[7:0]	w_status_03;
        wire	[7:0]	w_status_04;
        wire	[7:0]	w_status_05;
        wire	[7:0]	w_status_06;
        wire	[7:0]	w_status_07;
        wire	[7:0]	w_status_08;
        wire	[7:0]	w_status_09;
        wire	[7:0]	w_status_0a;
        wire	[7:0]	w_status_0b;
        wire		debug_o_sda;

        wire		w_we2;
        wire	[7:0]	w_waddr2;
        wire	[31:0]	w_wdata2;

        reg	[2:0]	r_frame_sel ;
        wire		w_frame_req ;

        wire		w_uart_empty;
        wire		w_debug_vld ;

        wire		w_uart_req;

        // debug signals }}}

        // Platform block {{{

        generate if(CODE_MEM == "EXTERNAL")
            begin: g_on_clk2x
                HSOSC # (.CLKHF_DIV("0b00")) u_hfosc (
                        .CLKHFEN   (1'b1 ),
                        .CLKHFPU   (1'b1 ),
                        .CLKHF     (clk2x )
                    );

                reg	clk_div;

                always @(posedge clk2x) clk_div <= !clk_div;

                assign oclk_in = clk_div;

            end
            else begin
                HSOSC # (.CLKHF_DIV("0b01")) u_hfosc (
                        .CLKHFEN   (1'b1 ),
                        .CLKHFPU   (1'b1 ),
                        .CLKHF     (oclk_in )
                    );
            end
        endgenerate


        ice40_himax_humandet_clkgen #(.EN_CLKMASK(EN_CLKMASK), .EN_SINGLE_CLK(EN_SINGLE_CLK)) u_ice40_humandet_clkgen (
                .i_oclk_in   (oclk_in     ),
                .i_pclk_in   (pclk_in     ),

                .i_init_done (w_init_done ),
                .i_cam_vsync (cam_vsync_p ),
                .i_load_done (w_load_done ),
                .i_ml_rdy    (r_rd_rdy_con),
                .i_vid_rdy   (w_rd_done   ),
                .i_mask_ovr  (1'b0        ),
                //.i_mask_ovr  (debug_scl        ),

                .o_init      (w_init      ),
                .o_oclk      (oclk        ), // oscillator clock (always live)
                .o_clk       (clk         ), // core clock
                .o_pclk      (pclk        ), // video clock
                .o_clk_init  (clk_init    ),

                .o_debug     (w_debug_prob ),

                .resetn      (resetn      )
            );

        ice40_resetn u_resetn(
                .clk    (oclk  ),
                .resetn (resetn)
            );

        assign cam_mclk = w_init_done ? 1'b0 : oclk;

        lsc_i2cm_himax #(.EN_ALT(1'b0), .CONF_SEL(MIRROR_MODE ? "324x324_dim" : "324x324_dim_maxfps")) u_lsc_i2cm_himax(
        //lsc_i2cm_himax #(.EN_ALT(1'b0), .CONF_SEL("324x324_seq_fps")) u_lsc_i2cm_himax(
        //lsc_i2cm_himax #(.EN_ALT(1'b0), .CONF_SEL("324x324_dim_maxfps")) u_lsc_i2cm_himax(
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
        reg	debug_tgl;

        generate if(EN_I2CS)
            begin: g_on_en_i2cs
                lsc_i2cs_local # (.EN_CAPTURE(EN_CAPTURE), .EN_DEBUG(EN_DEBUG)) u_lsc_i2cs_local (
                        .clk        (clk        ),     // 
                        .resetn     (resetn     ),     // 

                        .o_config_00(w_config_00),
                        .o_config_01(w_config_01),
                        .o_config_02(w_config_02),
                        .o_config_03(w_config_03),
                        .o_config_04(w_config_04),
                        .i_status_00(w_status_00),
                        .i_status_01(w_status_01),
                        .i_status_02(w_status_02),
                        .i_status_03(w_status_03),
                        .i_status_04(w_status_04),
                        .i_status_05(w_status_05),
                        .i_status_06(w_status_06),
                        .i_status_07(w_status_07),
                        .i_status_08(w_status_08),
                        .i_status_09(w_status_09),
                        .i_status_0a(w_status_0a),
                        .i_status_0b(w_status_0b),
    
                        .i_we       (w_we       ),
                        .i_waddr    (w_waddr[13:0]),
                        .i_din      (w_dout[15:8] ),

                        .i_we2      (w_we2      ),
                        .i_waddr2   (w_waddr2   ),
                        .i_din2     (w_wdata2   ),

                        .i_scl      (debug_scl  ),     // 
                        .i_sda      (debug_sda  ),     // 
                        .o_sda      (debug_o_sda)      // 
                    );

                assign debug_sda = debug_o_sda ? 1'bz : 1'b0;
            end
            else
            begin
                //assign debug_scl = MIRROR_MODE ? r_det_filter  : 1'bz;
                //assign debug_sda = MIRROR_MODE ? !r_det_filter : 1'bz;
                //assign debug_scl = debug_tgl;//1'bz; //w_debug_prob[0];
                //assign debug_sda = w_rd_rdy  ;//1'b0;//1'bz;//w_debug_prob[1];
            end
        endgenerate

        reg		frame_reading;
        generate if(EN_UART && (CODE_MEM != "EXTERNAL"))
            begin: g_on_en_uart
                wire	[7:0]	w_uart_dout;
                wire	[7:0]	w_uart_din;

                reg		frame_req_lat;
                wire	w_uart_vld; 
                //reg		frame_reading;
                reg	[2:0]	frame_req_sel;

                reg		result_reading;

                always @(posedge clk or negedge resetn)
                begin
                    if(resetn == 1'b0)
                        frame_req_lat <= 1'b0;
                    else if(w_frame_req && ((MIRROR_MODE != 1'b1) || (w_uart_dout[2:0] == 3'h0))) // character 'h'(0x68)
                        frame_req_lat <= 1'b1;
                    else if(w_rd_done && (frame_req_sel == r_frame_sel))
                        frame_req_lat <= 1'b0;
                end

                always @(posedge clk or negedge resetn)
                begin
                    if(resetn == 1'b0)
                        result_reading <= 1'b0;
                    else if(w_frame_req && (MIRROR_MODE == 1'b1) && (w_uart_dout[2:0] == 3'h1)) // character 'i'(0x69)
                        result_reading <= 1'b1;
                    else if(r_comp_done_d[7] == 1'b1)
                        result_reading <= 1'b0;
                end

                always @(posedge clk or negedge resetn)
                begin
                    if(resetn == 1'b0)
                        frame_reading <= 1'b0;
                    else if(frame_req_lat  && w_rd_done && (frame_req_sel == r_frame_sel))
                        frame_reading <= 1'b1;
                    else if(r_comp_done_d[7] == 1'b1)
                        frame_reading <= 1'b0;
                end

                //assign w_uart_vld = (w_debug_vld | ((|r_comp_done_d[7:6]))) & frame_reading;
                assign w_uart_vld = (w_debug_vld & frame_reading) | ((|r_comp_done_d[7:6]) & result_reading);

                assign w_uart_req = frame_req_lat;

                assign w_uart_din = (r_comp_done_d[7] == 1'b1) ? w_class0[15:8] :
                    (r_comp_done_d[6] == 1'b1) ? w_class0[ 7:0] : w_result[10:3]; //w_result[11:4];


                lsc_uart #(.PERIOD(16'd103), .BUFFER_SIZE("512")) u_lsc_uart(
                        .ref_clk(clk         ),
                        .clk    (clk         ),
                        .i_din  (w_uart_din  ),
                        .i_valid(w_uart_vld  ),

                        .o_dout (w_uart_dout ),
                        .o_valid(w_frame_req ),
                        .o_empty(w_uart_empty),

                        .i_rxd  (w_uart_rxd  ), 
                        .o_txd  (w_uart_txd  ),
                        .resetn (resetn      )
                    );

                //assign standby = 1'b1;

                always @(posedge clk)
                begin
                    if(w_frame_req)
                        if((MIRROR_MODE == 1'b1) || (EN_SEQ == 1'b1))
                            frame_req_sel <= 3'b101;
                        else case(w_uart_dout[2:0])
                                3'b000 : frame_req_sel <= 3'b000;
                                3'b001 : frame_req_sel <= 3'b001;
                                3'b010 : frame_req_sel <= 3'b010;
                                3'b011 : frame_req_sel <= 3'b011;
                                3'b100 : frame_req_sel <= 3'b100;
                                default: frame_req_sel <= 3'b101;
                            endcase
                end

                assign uart_txd = EN_DUAL_UART ? w_uart_txd : 1'bz;
            end
            else
            begin
                assign uart_txd = EN_UPDUINO2 ? 1'b1 : uart_rxd; // loopback
                assign w_uart_req = 1'b1;
                assign w_uart_empty = 1'b1;
            end
        endgenerate


        // Debug block }}}

        // Code memory {{{
        generate if(CODE_MEM == "EXTERNAL")
            begin: g_on_use_spi_fifo
                spi_fifo #(.FIFO_SIZE("256")) u_spi_fifo(
                        .clk2x        (clk2x        ),
                        .clk          (clk          ),
                        .resetn       (resetn       ),

                        .i_en         (w_load_done  ),

                        .i_fill       (w_fill       ),
                        .o_fifo_empty (w_fifo_empty ),
                        .o_fifo_low   (w_fifo_low   ),
                        .i_fifo_rd    (w_fifo_rd    ),
                        .o_fifo_dout  (w_fifo_dout  ),

                        .SPI_CLK      (spi_clk      ),
                        .SPI_CSS      (spi_css      ),
                        .SPI_MISO     (spi_miso     ),
                        .SPI_MOSI     (spi_mosi     )
                    );

                assign w_uart_rxd = 1'b0;


                reg [23:0]	load_done_delay_cnt;

                always @(posedge clk or negedge resetn)
                begin
                    if(resetn == 1'b0)
                        load_done_delay_cnt <= 24'b0;
                    else if(load_done_delay_cnt[23] == 1'b0)
                        load_done_delay_cnt <= load_done_delay_cnt + 24'd1;

                end

                assign w_load_done = load_done_delay_cnt[23];

            end else begin
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
                assign w_uart_rxd = EN_UPDUINO2 ? ((spi_clk & w_load_done) & ((EN_DUAL_UART == 1'b0) | uart_rxd)) : uart_rxd;
                assign spi_mosi = w_load_done ? (EN_UPDUINO2 ? w_uart_txd : 1'bz) : w_spi_mosi;
            end
        endgenerate

        // Code memory }}}

        // Video processing {{{

        reg		r_lcd_running;

        generate if((EN_SEQ == 1) && (LCD_TYPE != "NONE"))
            begin: g_on_seq
                ice40_himax_video_process_128_seq #(.SUBPIX("NONE"), .BYTE_MODE(BYTE_MODE), .LCD_TYPE(LCD_TYPE)) u_ice40_himax_video_process_128 (
                        .clk         (clk         ),
                        .pclk        (pclk        ),
                        .resetn      (resetn      ),
             
                        .i_cam_de    (cam_de_p    ),
                        .i_cam_vsync (cam_vsync_p ),
                        .i_cam_data  (cam_data_p  ),

                        .o_width     (),
                        .o_height    (),

                        .i_frame_sel (r_frame_sel ),
                        .i_frame_req (1'b0        ),
                        .o_subpix_vld(            ),
                        .o_subpix_out(            ),

                        .i_rd_rdy    (w_rd_rdy_con),
                        .o_rd_done   (w_rd_done   ),

                        .i_detect    (r_det       ),
                        .i_lcd_running(r_lcd_running),
                        .o_lcd_mode  (w_lcd_mode  ),
                        .o_pix_we    (w_pix_we    ),
                        .o_pix       (w_pix       ),
             
                        .o_we        (w_we        ),
                        .o_waddr     (w_waddr     ),
                        .o_dout      (w_dout      )
                    );
            end
            else if(LCD_TYPE != "NONE") // normal
            begin
                ice40_himax_video_process_128 #(.SUBPIX("NONE"), .BYTE_MODE(BYTE_MODE), .LCD_TYPE(LCD_TYPE)) u_ice40_himax_video_process_128 (
                        .clk         (clk         ),
                        .pclk        (pclk        ),
                        .resetn      (resetn      ),
             
                        .i_cam_de    (cam_de_p    ),
                        .i_cam_vsync (cam_vsync_p ),
                        .i_cam_data  (cam_data_p  ),

                        .o_width     (),
                        .o_height    (),

                        .i_frame_sel (r_frame_sel ),
                        .i_frame_req (1'b0        ),
                        .o_subpix_vld(            ),
                        .o_subpix_out(            ),

                        .i_rd_rdy    (w_rd_rdy_con),
                        .o_rd_done   (w_rd_done   ),

                        .i_detect    (r_det       ),
                        .i_quad_on   (quad_on     ),
                        .i_quad_sec  (quad_section),
                        .i_quad_color(quad_color  ),
                        .i_lcd_running(r_lcd_running),
                        .o_lcd_mode  (w_lcd_mode  ),
                        .o_pix_we    (w_pix_we    ),
                        .o_pix       (w_pix       ),
             
                        .o_we        (w_we        ),
                        .o_waddr     (w_waddr     ),
                        .o_dout      (w_dout      )
                    );
            end
            else begin // NO LCD
                ice40_himax_video_process_64 #(.SUBPIX("NONE"), .BYTE_MODE(BYTE_MODE)) u_ice40_himax_video_process_64 (
                        .clk         (clk         ),
                        .pclk        (pclk        ),
                        .resetn      (resetn      ),
             
                        .i_cam_de    (cam_de_p    ),
                        .i_cam_vsync (cam_vsync_p ),
                        .i_cam_data  (cam_data_p  ),

                        .o_width     (),
                        .o_height    (),

                        .i_frame_sel (r_frame_sel ),
                        .i_frame_req (1'b0        ),
                        .o_subpix_vld(            ),
                        .o_subpix_out(            ),

                        .i_rd_rdy    (w_rd_rdy_con),
                        .o_rd_done   (w_rd_done   ),

                        .o_we        (w_we        ),
                        .o_waddr     (w_waddr     ),
                        .o_dout      (w_dout      )
                    );
            end
        endgenerate

        always @(posedge clk)
        begin
            r_rd_done_d <= {r_rd_done_d[0], w_rd_done};
        end

        always @(posedge clk or negedge resetn)
        begin
            if(resetn == 1'b0)
                r_frame_sel <= 3'd0;
            else if((MIRROR_MODE == 1'b1) || (EN_SEQ == 1) || (FUSION_MODE == 1'b1))
                r_frame_sel <= 3'b101;
            else if(r_rd_done_d == 2'b10)
                r_frame_sel <= (r_frame_sel == 3'b101) ? 3'd0 : (r_frame_sel + 3'd1);
        end

        assign cam_trig = !w_config_01[0];

        // Video processing }}}

        // Result handling {{{

        wire	[15:0]	w_offset;
        assign w_offset = EN_SEQ ? 16'hfc00 : 16'd0;

        humandet_post u_speedsignal_post(
                .clk        (clk        ),        
                .init       (w_rd_done  ),      
                .i_we       (w_result_en),       
                .i_dout     (w_result   ),     
                .i_offset   (w_offset   ),
                .comp_done  (           ),  
                .max_val    (w_class0   ),
                .cnt_val    (           )
            );

        reg	r_result_en_d;

        always @(posedge clk)
        begin
            r_result_en_d <= w_result_en;
            r_comp_done_d <= {r_comp_done_d[6:0], ({r_result_en_d, w_result_en} == 2'b10)};
        end

        always @(posedge clk)
        begin
            if(r_comp_done_d[7] == 1'b1)
                case(r_frame_sel)
                    3'd0:    r_class5 <= w_class0;
                    3'd1:    r_class0 <= w_class0;
                    3'd2:    r_class1 <= w_class0;
                    3'd3:    r_class2 <= w_class0;
                    3'd4:    r_class3 <= w_class0;
                    default: r_class4 <= w_class0;
                endcase
        end

        always @(posedge clk)
        begin
            if(r_comp_done_d[7] == 1'b1) begin
                if(MIRROR_MODE == 1'b1) 
                    r_det_vec<= {1'b0, !w_class0[15], 4'b0};
                else case(r_frame_sel)
                        3'd0 :   r_det_vec[5] <= !w_class0[15];
                        3'd1 :   r_det_vec[0] <= !w_class0[15];
                        3'd2 :   r_det_vec[1] <= !w_class0[15];
                        3'd3 :   r_det_vec[2] <= !w_class0[15];
                        3'd4 :   r_det_vec[3] <= !w_class0[15];
                        default: r_det_vec[4] <= !w_class0[15];
                    endcase
            end
        end

        always @(posedge clk)
        begin
            if(r_comp_done_d[7] == 1'b1)
                r_det_histo <= {r_det_histo[3:0], !w_class0[15]};
        end

        always @(posedge clk or negedge resetn)
        begin
            if(resetn == 1'b0)
                r_det_filter <= 1'b0;
            else if(r_det_histo[1:0] == 2'b11)
                r_det_filter <= 1'b1;
            else if(r_det_histo[3:0] == 4'b0000)
                r_det_filter <= 1'b0;
        end


        // Result handling }}}

        // NN block {{{

        /*
reg	[2:0]	r_rd_rdy_d;

always @(posedge clk or negedge resetn) 
begin
    if(resetn == 1'b0)
	r_rd_rdy_d <= 3'b0;
    else
	r_rd_rdy_d <= {r_rd_rdy_d[1:0], w_rd_rdy };
end

always @(posedge clk or negedge resetn) 
begin
    if(resetn == 1'b0)
	debug_tgl <= 1'b0;
    else if(r_rd_rdy_d[2:1] == 2'b01)
	debug_tgl <= ~debug_tgl;
end
         */

        generate if(USE_ML == 1'b1)
            begin: g_use_ml_on
                compact_cnn (
                        .clk         (clk         ),
                        .resetn      (resetn      ),
                  
                        .o_rd_rdy    (w_rd_rdy    ),
                        //.i_start     (r_rd_rdy_d[2]),// cont run
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

                assign w_status_00 = w_commands[7:0];
                assign w_status_01 = w_commands[15:8];

                assign w_status_02 = w_cycles[ 7: 0]; // r_class0[ 7:0];
                assign w_status_03 = w_cycles[15: 8]; // r_class0[15:8];
                assign w_status_04 = w_cycles[23:16]; // r_class1[ 7:0];
                assign w_status_05 = w_cycles[31:24]; // r_class1[15:8];
                assign w_status_06 = r_class2[ 7:0];
                assign w_status_07 = r_class2[15:8];
                assign w_status_08 = r_class3[ 7:0];
                assign w_status_09 = r_class3[15:8];
                assign w_status_0a = r_class4[ 7:0];
                assign w_status_0b = r_class4[15:8];

                assign w_rd_rdy_con = w_rd_rdy & (!w_config_00[0]);

                always @(posedge clk or negedge resetn)
                begin
                    if(resetn == 1'b0)
                        r_rd_rdy_con <= 1'b1;
                    else if(r_comp_done_d[7])
                        r_rd_rdy_con <= 1'b1;
                    else if(w_rd_rdy == 1'b0)
                        r_rd_rdy_con <= 1'b0;
                end

                always @(posedge clk)
                begin
                    r_det <= |r_det_vec;
                end
            end
            else
            begin
                assign w_fill    = w_config_00[4];
                assign w_fifo_rd = w_config_00[5];
                assign w_rd_rdy  = w_config_00[6];
                assign w_rd_rdy_con = (!w_config_00[0]);
                assign w_result_en = 1'b0;

                assign w_status_00 = {7'b0, w_load_done};

                assign w_status_02 = w_fifo_dout[ 7: 0];
                assign w_status_03 = w_fifo_dout[15: 8];
                assign w_status_04 = w_fifo_dout[23:16];
                assign w_status_05 = w_fifo_dout[31:24];

                always @(posedge clk)
                begin
                    r_det <= !w_fifo_empty;
                    r_rd_rdy_con <= 1'b1;

                end
            end
        endgenerate

        // NN block }}}

        // LEDs {{{

        generate if(FUSION_MODE)
            begin: g_on_fusion
                //assign oled[5:0] = 6'bzzzzzz;

                reg	[1:0]	r_quad_on_lat;
                reg	[3:0]	r_quad_sec_lat;
                reg	[2:0]	r_quad_color_lat;

                reg	[25:0]	key_flag_cnt;
                reg		marvin_det;
                reg		on_det;
                reg		off_det;

                always @(posedge clk)
                begin
                    r_quad_on_lat <= {r_quad_on_lat[0], aux_det};
                end

                always @(posedge clk)
                begin
                    if(on_det || off_det)
                        r_quad_sec_lat <= 4'b1111;
                    else if(r_quad_on_lat == 2'b01)
                        /*
	    r_quad_sec_lat   <= {2'b0,
                           (aux_idx == 2'b10) || (aux_idx == 2'b11), 
	                   (aux_idx == 2'b00) || (aux_idx == 2'b01)};
                         */
                        r_quad_sec_lat   <= {
                                (aux_idx == 2'b11), (aux_idx == 2'b10), 
                                (aux_idx == 2'b01), (aux_idx == 2'b00)};
                end

                always @(posedge clk or negedge resetn)
                begin
                    if(resetn == 1'b0)
                        key_flag_cnt <= 26'b0;
                    else if(r_quad_on_lat == 2'b01) begin
                        if((aux_idx == 2'b01) && r_det) // marvin
                            key_flag_cnt <= 26'd40000000;
                        else if(((aux_idx == 2'b10) || (aux_idx == 2'b11)) && r_det) // on/off
                            key_flag_cnt <= 26'd12000000; // 0.5 sec
                        else // otherwise, reset cnt
                            key_flag_cnt <= 26'b0;
                    end else if((|key_flag_cnt) != 1'b0)
                        key_flag_cnt <= key_flag_cnt - 26'd1;
                end

                always @(posedge clk or negedge resetn)
                begin
                    if(resetn == 1'b0)
                        marvin_det <= 1'b0;
                    else if((r_quad_on_lat == 2'b01) && r_det)
                        marvin_det <= (aux_idx == 2'b01);
                    else if((r_quad_on_lat == 2'b01) || ((|key_flag_cnt) == 1'b0))
                        marvin_det <= 1'b0;
                end

                always @(posedge clk or negedge resetn)
                begin
                    if(resetn == 1'b0)
                        on_det <= 1'b0;
                    else if((r_quad_on_lat == 2'b01) && (marvin_det == 1'b1) && (aux_idx == 2'b10) && r_det)
                        on_det <= 1'b1;
                    else if((r_quad_on_lat == 2'b01) || ((|key_flag_cnt) == 1'b0))
                        on_det <= 1'b0;
                end

                always @(posedge clk or negedge resetn)
                begin
                    if(resetn == 1'b0)
                        off_det <= 1'b0;
                    else if((r_quad_on_lat == 2'b01) && (marvin_det == 1'b1) && (aux_idx == 2'b11) && r_det)
                        off_det <= 1'b1;
                    else if((r_quad_on_lat == 2'b01) || ((|key_flag_cnt) == 1'b0))
                        off_det <= 1'b0;
                end

                always @(posedge clk)
                begin
                    if(on_det) 
                        r_quad_color_lat <= 3'b101;
                    else if(off_det)
                        r_quad_color_lat <= 3'b110;
                    else if(r_quad_on_lat == 2'b01)
                        case(aux_idx)
                            2'b00  : r_quad_color_lat <= 3'b000;
                            2'b01  : r_quad_color_lat <= 3'b010;
                            2'b10  : r_quad_color_lat <= 3'b001;
                            default: r_quad_color_lat <= 3'b010;
                        endcase
                end

                assign quad_on = r_quad_on_lat | on_det | off_det;

                assign quad_section = r_quad_sec_lat;
                assign quad_color   = r_quad_color_lat;
                // {intensity, color_code} 00: red, 01: green, 10: blue, 11: white

            end else if(EN_UPDUINO2)
            begin: g_on_upduino2
                //    /* UL     */ assign oled[0] = r_det_vec[0] ? 1'bz : 1'b0;
                //    /* UR     */ assign oled[1] = r_det_vec[1] ? 1'bz : 1'b0;
                //    /* LL     */ assign oled[2] = r_det_vec[2] ? 1'bz : 1'b0;
                //    /* LR     */ assign oled[3] = r_det_vec[3] ? 1'bz : 1'b0;
                //    /* CZ     */ assign oled[4] = r_det_vec[4] ? 1'bz : 1'b0;
                //    /* FULL   */ assign oled[5] = r_det_vec[5] ? 1'bz : 1'b0;
                assign quad_on      = 1'b0;
                assign quad_section = 4'b0;
                assign quad_color   = 3'b0;
            end else 
            begin: g_on_himax_only_board
                //    /* DOWN   */ assign oled[0] = r_det_vec[2] ? 1'bz : 1'b0;
                //    /* UP     */ assign oled[1] = r_det_vec[1] ? 1'bz : 1'b0;
                //    /* CENTER */ assign oled[2] = r_det_vec[4] ? 1'bz : 1'b0;
                //    /* RIGHT  */ assign oled[4] = r_det_vec[3] ? 1'bz : 1'b0;
                //    /* LEFT   */ assign oled[5] = r_det_vec[0] ? 1'bz : 1'b0;

                //    /* AWAY   */ assign oled[3] = r_det_vec[5] ? 1'bz : 1'b0;

                assign quad_on      = 1'b0;
                assign quad_section = 4'b0;
                assign quad_color   = 3'b0;
            end
        endgenerate

        reg	[3:0]	pwm_cnt;

        reg		obj_det;

        always @(posedge oclk)
        begin
            pwm_cnt <= pwm_cnt + 4'd1;
        end

        wire	w_red;
        wire	w_green;
        wire	w_blue;

        assign w_red   = r_det;
        assign w_green = w_load_done & (pwm_cnt[3:0] == 4'd0) & cam_vsync_p;
        assign w_blue  = 1'b0;

        RGB RGB_DRIVER ( 
                .RGBLEDEN (1'b1    ),
                .RGB0PWM  (w_red   ),
                .RGB1PWM  (w_green ), 
                .RGB2PWM  (w_blue  ),
                .CURREN   (1'b1    ), 
                .RGB0     (REDn    ),
                .RGB1     (GRNn    ),
                .RGB2     (BLUn    )
            );
        defparam RGB_DRIVER.RGB0_CURRENT = "0b000001";
        defparam RGB_DRIVER.RGB1_CURRENT = "0b000001";
        defparam RGB_DRIVER.RGB2_CURRENT = "0b000001";


        // LEDs }}}

    `ifdef SOM
        assign host_intr = cam_vsync_p;
        assign host_miso = 1'b0;
        assign i2s_sck = 1'b0;
        assign i2s_ws = 1'b0;
        assign imager_ssn = 1'b1;
        assign sram_ssn = 1'b1;
        assign mem_sio2 = 1'bz;
        assign mem_sio3 = 1'bz;
        /*
        input host_sck,
            input host_ssn,
            input host_mosi,
            input i2s_dat,
            input imu_intr,
            input sensor_miso,
        */
        `endif
        // TFT LCD out {{{

        `ifdef USE_LCD

            always @(posedge clk)
            begin
                r_lcd_running <= (w_lcd_running | (!w_lcd_init_done));
            end

            spi_lcd_tx #(.TYPE(LCD_TYPE)) u_spi_lcd_tx (
                    .clk        (clk         ),
                    .wclk       (pclk        ),
                    .resetn     (resetn      ),

                    .i_en       (w_load_done ),
                             
                    .i_we       (w_pix_we    ),
                    .i_mode     (w_lcd_mode  ),
                    .i_data     (w_pix       ),

                    .o_init_done(w_lcd_init_done),
                    .o_running  (w_lcd_running),

                    .SPI_GPO    (lcd_spi_gpo ),
                    .SPI_CLK    (lcd_spi_clk ),
                    .SPI_CSS    (lcd_spi_css ),
                    .SPI_MOSI   (lcd_spi_mosi)
                );

            assign lcd_resetn = resetn;
        `endif


        // TFT LCD out }}}

    endmodule

    // vim:foldmethod=marker:
    //
