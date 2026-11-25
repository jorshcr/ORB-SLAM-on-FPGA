set root [file normalize [file join [file dirname [info script]] ../..]]
set levels 1
if {[llength $argv] > 0} { set levels [lindex $argv 0] }
if {$levels < 1 || $levels > 4} { error "ORB levels must be 1..4" }
set output [file join $root orb_test_output board_${levels}level_[clock format [clock seconds] -format %Y%m%d_%H%M%S]]
file mkdir $output
create_project -in_memory -part xc7a100tcsg324-1
set_property XPM_LIBRARIES {XPM_CDC XPM_MEMORY XPM_FIFO} [current_project]
foreach directory {common system_top system_top/orb system_top/orb/brief system_top/orb/fast system_top/orb/orientation} {
    foreach source [glob [file join $root orb_hardware rtl $directory *.sv]] {
        read_verilog -sv $source
    }
}
read_xdc [file join $root orb_hardware constraints orb_board.xdc]
synth_design -top orb_board_top -generic ORB_LEVELS=$levels -part xc7a100tcsg324-1
write_checkpoint -force [file join $output synthesized.dcp]
report_utilization -file [file join $output utilization_synth.rpt]
opt_design
place_design
route_design
phys_opt_design -directive AggressiveExplore
route_design -directive Explore
report_utilization -file [file join $output utilization_routed.rpt]
report_timing_summary -delay_type min_max -report_unconstrained -file [file join $output timing_routed.rpt]
report_timing -delay_type min -from [all_registers] -to [all_registers] -max_paths 10 -file [file join $output register_hold.rpt]
report_cdc -file [file join $output cdc.rpt]
report_bus_skew -file [file join $output bus_skew.rpt]
report_drc -file [file join $output drc.rpt]
report_route_status -file [file join $output route_status.rpt]
write_xdc -force [file join $output timing.xdc]
write_checkpoint -force [file join $output routed.dcp]
puts "REPORT_DIRECTORY: $output"
