if {[catch {

# define run engine funtion
source [file join {C:/lscc/radiant/1.1} scripts tcl flow run_engine.tcl]
# define global variables
global para
set para(gui_mode) 1
set para(prj_dir) "C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/ice40_himax_upduino2_humandet"
# synthesize IPs
# synthesize VMs
# synthesize top design
file delete -force -- ice40_himax_upduino2_humandet_impl_1.vm ice40_himax_upduino2_humandet_impl_1.ldc
run_engine synpwrap -prj "ice40_himax_upduino2_humandet_impl_1_synplify.tcl" -log "ice40_himax_upduino2_humandet_impl_1.srf"
run_postsyn [list -a iCE40UP -p iCE40UP5K -t SG48 -sp High-Performance_1.2V -oc Industrial -top -w -o ice40_himax_upduino2_humandet_impl_1.udb ice40_himax_upduino2_humandet_impl_1.vm] "C:/Users/vrang/Documents/GitHub/senseai/SoM/Himax/himax_humandet/ice40_himax_upduino2_humandet/impl_1/ice40_himax_upduino2_humandet_impl_1.ldc"

} out]} {
   runtime_log $out
   exit 1
}
