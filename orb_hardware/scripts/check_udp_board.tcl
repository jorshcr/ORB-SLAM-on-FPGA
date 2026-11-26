set root [file normalize [file join [file dirname [info script]] ../..]]
set output [file join $root orb_test_output udp_board_[clock format [clock seconds] -format %Y%m%d_%H%M%S]]
file mkdir $output
create_project -in_memory -part xc7a100tcsg324-1
set_property XPM_LIBRARIES {XPM_CDC XPM_MEMORY XPM_FIFO} [current_project]
foreach directory {common system_top system_top/orb system_top/orb/brief system_top/orb/fast system_top/orb/orientation network} {
    foreach source [glob -nocomplain [file join $root orb_hardware rtl $directory *.sv]] { read_verilog -sv $source }
    foreach source [glob -nocomplain [file join $root orb_hardware rtl $directory *.v]] { read_verilog $source }
}
set vendor [file join $root orb_hardware third_party verilog-ethernet]
foreach directory {rtl lib/axis/rtl} {
    foreach source [glob [file join $vendor $directory *.v]] { read_verilog $source }
}
read_xdc [file join $root orb_hardware constraints orb_board.xdc]
read_xdc [file join $root orb_hardware constraints orb_udp.xdc]
synth_design -top orb_udp_board_top -part xc7a100tcsg324-1
source [file join $root orb_hardware constraints orb_rmii_cdc.tcl]
foreach constraint {lib/axis/syn/vivado/axis_async_fifo.tcl lib/axis/syn/vivado/sync_reset.tcl} {
    source [file join $vendor $constraint]
}
report_utilization -file [file join $output utilization_synth.rpt]
write_checkpoint -force [file join $output synthesized.dcp]
if {[lsearch -exact $argv --route] >= 0} {
    opt_design
    place_design
    route_design
    phys_opt_design -directive AggressiveExplore
    route_design -directive Explore
    phys_opt_design -hold_fix
    route_design -preserve
    report_utilization -file [file join $output utilization_routed.rpt]
    report_timing_summary -delay_type min_max -report_unconstrained -file [file join $output timing_routed.rpt]
    report_cdc -file [file join $output cdc.rpt]
    report_bus_skew -file [file join $output bus_skew.rpt]
    report_drc -file [file join $output drc.rpt]
    write_checkpoint -force [file join $output routed.dcp]
}
puts "REPORT_DIRECTORY: $output"
