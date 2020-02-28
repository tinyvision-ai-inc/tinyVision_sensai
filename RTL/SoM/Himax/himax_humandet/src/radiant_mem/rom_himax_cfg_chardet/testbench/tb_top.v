// =============================================================================
// >>>>>>>>>>>>>>>>>>>>>>>>> COPYRIGHT NOTICE <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
// -----------------------------------------------------------------------------
//   Copyright (c) 2018 by Lattice Semiconductor Corporation
//   ALL RIGHTS RESERVED
// --------------------------------------------------------------------
//
//   Permission:
//
//      Lattice SG Pte. Ltd. grants permission to use this code
//      pursuant to the terms of the Lattice Reference Design License Agreement.
//
//
//   Disclaimer:
//
//      This VHDL or Verilog source code is intended as a design reference
//      which illustrates how these types of functions can be implemented.
//      It is the user's responsibility to verify their design for
//      consistency and functionality through the use of formal
//      verification methods.  Lattice provides no warranty
//      regarding the use or functionality of this code.
//
// -----------------------------------------------------------------------------
//
//                  Lattice SG Pte. Ltd.
//                  101 Thomson Road, United Square #07-02
//                  Singapore 307591
//
//
//                  TEL: 1-800-Lattice (USA and Canada)
//                       +65-6631-2000 (Singapore)
//                       +1-503-268-8001 (other locations)
//
//                  web: http://www.latticesemi.com/
//                  email: techsupport@latticesemi.com
//
// -----------------------------------------------------------------------------
//
// =============================================================================
//                         FILE DETAILS
// Project               :
// File                  : tb_top.v
// Title                 : Testbench for rom.
// Dependencies          : 1.
//                       : 2.
// Description           :
// =============================================================================
//                        REVISION HISTORY
// Version               : 1.0.1
// Author(s)             :
// Mod. Date             : 03/05/2018
// Changes Made          : Initial version of testbench for rom
// =============================================================================

`ifndef TB_TOP
`define TB_TOP

//==========================================================================
// Module : tb_top
//==========================================================================

`timescale 1ns/1ps

module tb_top();

`include "dut_params.v"

reg                         rd_clk_i;
reg                         rst_i;
reg                         rd_clk_en_i;
reg                         rd_out_clk_en_i;

reg 						rd_en_i;
reg [RADDR_WIDTH-1:0]       rd_addr_i;

wire [RDATA_WIDTH-1:0] 	    rd_data_o;

integer i1;

reg chk = 1'b1;

`include "dut_inst.v"

initial begin
	rst_i = 1'b1;
	#15;
	rst_i = 1'b0;
end

initial begin
	rd_clk_i = 1'b0;
	forever #10 rd_clk_i = ~rd_clk_i;
end

localparam TARGET_READ = RADDR_DEPTH;

initial begin
	rd_en_i <= 1'b0;
	rd_clk_en_i <= 1'b0;
	rd_out_clk_en_i <= 1'b0;
	rd_addr_i <= {RADDR_WIDTH{1'b0}};
    @(negedge rst_i);
	rd_en_i <= 1'b1;
	rd_clk_en_i <= 1'b1;
	rd_out_clk_en_i <= 1'b1;
	@(posedge rd_clk_i);
	for(i1 = 0; i1 < TARGET_READ; i1 = i1 + 1) begin
		@(posedge rd_clk_i);
		rd_addr_i <= rd_addr_i + 1;
	end
    if(REGMODE == "reg") @(posedge rd_clk_i);
    if(chk == 1'b1) begin
        $display("-----------------------------------------------------");
        $display("----------------- SIMULATION PASSED -----------------");
        $display("-----------------------------------------------------");
    end
    else begin
        $display("-----------------------------------------------------");
        $display("!!!!!!!!!!!!!!!!! SIMULATION FAILED !!!!!!!!!!!!!!!!!");
        $display("-----------------------------------------------------");
    end
	$finish;
end

reg [RDATA_WIDTH-1:0]        mem[2 ** RADDR_WIDTH-1:0];

initial begin
    if (INIT_MODE == "mem_file" && INIT_FILE != "none") begin
      if (INIT_FILE_FORMAT == "hex") begin
        $readmemh(INIT_FILE, mem, 0, RADDR_DEPTH-1);
      end
      else begin
        $readmemb(INIT_FILE, mem, 0, RADDR_DEPTH-1);
      end
    end
end

wire 						rd_en_w = rd_en_i & rd_clk_en_i & rd_out_clk_en_i;
reg [RADDR_WIDTH-1:0]       rd_addr_p_r = {RADDR_WIDTH{1'b0}};

always @ (posedge rd_clk_i, posedge rst_i) begin
    if(rst_i == 1'b1) begin
        rd_addr_p_r <= {RADDR_WIDTH{1'b0}};
    end
    else begin
        rd_addr_p_r <= rd_addr_i;
    end
end

if(REGMODE == "noreg") begin
    always @ (posedge rd_clk_i) begin
        if(rd_en_w == 1'b1) begin
            if(mem[rd_addr_p_r] != rd_data_o) begin
                chk = 1'b0;
                $display("Expected DATA = %h, Read DATA = %h", mem[rd_addr_p_r], rd_data_o);
            end
        end
    end
end
else begin
    reg rd_en_p_r = 1'b0;
    reg [RADDR_WIDTH-1:0]       rd_addr_mem_r = {RADDR_WIDTH{1'b0}};
    always @ (posedge rd_clk_i) begin
        rd_en_p_r <= rd_en_w;
        rd_addr_mem_r <= rd_addr_p_r;
    end
    always @ (posedge rd_clk_i) begin
        if(rd_en_p_r == 1'b1) begin
            if(mem[rd_addr_mem_r] != rd_data_o) begin
                chk = 1'b0;
                $display("Expected DATA = %h, Read DATA = %h", mem[rd_addr_mem_r], rd_data_o);
            end
        end
    end
end

endmodule
`endif
