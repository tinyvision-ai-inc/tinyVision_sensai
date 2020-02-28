#-- Lattice Semiconductor Corporation Ltd.
#-- Synplify OEM project file

#device options
set_option -technology SBTICE40UP
set_option -part iCE40UP5K
set_option -package SG48
#compilation/mapping options
set_option -symbolic_fsm_compiler true
set_option -resource_sharing true

#use verilog 2001 standard option
set_option -vlog_std v2001

#map options
set_option -frequency auto
set_option -maxfan 1000
set_option -auto_constrain_io 0
set_option -retiming false; set_option -pipe true
set_option -force_gsr false
set_option -compiler_compatible 0

set_option -default_enum_encoding default

#timing analysis options



#automatic place and route (vendor) options
set_option -write_apr_constraint 1

#synplifyPro options
set_option -fix_gated_and_generated_clocks 0
set_option -update_models_cp 0
set_option -resolve_multiple_driver 0

#-- set any command lines input by customer

set_option -dup false
set_option -disable_io_insertion false
add_file -verilog {C:/lscc/radiant/1.1/ip/pmi/pmi_iCE40UP.v}
add_file -vhdl -lib pmi {C:/lscc/radiant/1.1/ip/pmi/pmi_iCE40UP.vhd}
add_file -verilog {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/humandet_post.v}
add_file -verilog {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/ice40_himax_humandet_clkgen.v}
add_file -verilog {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/ice40_himax_video_process_64.v}
add_file -verilog {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/ice40_himax_video_process_128.v}
add_file -verilog {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/ice40_himax_video_process_128_seq.v}
add_file -verilog {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/common/spi_lcd_tx.v}
add_file -verilog {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/lsc_ml_ice40_himax_humandet_top.v}
add_file -verilog {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/common/ice40_resetn.v}
add_file -verilog {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/common/lsc_i2cm.v}
add_file -verilog {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/common/lsc_i2cm_16.v}
add_file -verilog {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/common/lsc_i2cm_himax.v}
add_file -verilog {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/common/lsc_uart.v}
add_file -verilog {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/common/spi_loader_tri_spram.v}
add_file -verilog {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/common/spi_loader_spram.v}
add_file -verilog {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/common/spi_loader_wrap.v}
add_file -verilog {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/common/spi_fifo.v}
add_file -verilog {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/radiant_mem/rom_himax_cfg_324/rtl/rom_himax_cfg_324.v}
add_file -verilog {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/radiant_mem/rom_himax_cfg_324_dim/rtl/rom_himax_cfg_324_dim.v}
add_file -verilog {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/radiant_mem/rom_himax_cfg_324_dim_maxfps/rtl/rom_himax_cfg_324_dim_maxfps.v}
add_file -verilog {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/radiant_mem/dpram256x32/rtl/dpram256x32.v}
add_file -verilog {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/radiant_mem/dpram512x8/rtl/dpram512x8.v}
add_file -verilog {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/radiant_mem/dpram_lcd_fifo/rtl/dpram_lcd_fifo.v}
add_file -verilog {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/radiant_mem/rom_himax_cfg_324_faceid/rtl/rom_himax_cfg_324_faceid.v}
add_file -verilog {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/radiant_mem/rom_himax_cfg_lcd/rtl/rom_himax_cfg_lcd.v}
add_file -verilog {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/radiant_mem/rom_himax_cfg_seq/rtl/rom_himax_cfg_seq.v}
add_file -verilog {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/radiant_mem/dpram_oled_fifo/rtl/dpram_oled_fifo.v}
add_file -verilog {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/radiant_mem/rom_himax_cfg_1fps/rtl/rom_himax_cfg_1fps.v}
add_file -verilog {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/ice40_himax_upduino2_humandet/compact_cnn/rtl/compact_cnn.v}
#-- top module name
set_option -top_module lsc_ml_ice40_himax_humandet_top
set_option -include_path {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/ice40_himax_upduino2_humandet}
set_option -include_path {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/ice40_himax_upduino2_humandet/compact_cnn}
set_option -include_path {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/radiant_mem/dpram256x32}
set_option -include_path {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/radiant_mem/dpram512x8}
set_option -include_path {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/radiant_mem/dpram_lcd_fifo}
set_option -include_path {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/radiant_mem/dpram_oled_fifo}
set_option -include_path {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/radiant_mem/rom_himax_cfg_1fps}
set_option -include_path {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/radiant_mem/rom_himax_cfg_324}
set_option -include_path {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/radiant_mem/rom_himax_cfg_324_dim}
set_option -include_path {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/radiant_mem/rom_himax_cfg_324_dim_maxfps}
set_option -include_path {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/radiant_mem/rom_himax_cfg_324_faceid}
set_option -include_path {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/radiant_mem/rom_himax_cfg_lcd}
set_option -include_path {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/src/radiant_mem/rom_himax_cfg_seq}

#-- set result format/file last
project -result_format "vm"
project -result_file {C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/ice40_himax_upduino2_humandet/impl_1/ice40_himax_upduino2_humandet_impl_1.vm}

#-- error message log file
project -log_file {ice40_himax_upduino2_humandet_impl_1.srf}
project -run -clean
