set root [file normalize [file join [file dirname [info script]] ../..]]
if {[llength $argv] != 1} { error "Pass the routed checkpoint to refine" }
set output [file join $root orb_test_output board_refined_[clock format [clock seconds] -format %Y%m%d_%H%M%S]]
file mkdir $output
open_checkpoint [lindex $argv 0]
phys_opt_design -directive AggressiveExplore
route_design -directive Explore
report_utilization -file [file join $output utilization_routed.rpt]
report_timing_summary -delay_type min_max -report_unconstrained -file [file join $output timing_routed.rpt]
report_cdc -file [file join $output cdc.rpt]
report_bus_skew -file [file join $output bus_skew.rpt]
report_route_status -file [file join $output route_status.rpt]
write_checkpoint -force [file join $output routed.dcp]
puts "REPORT_DIRECTORY: $output"
