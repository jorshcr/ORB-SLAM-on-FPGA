set root [file normalize [file join [file dirname [info script]] ../..]]
set output [file join $root orb_test_output udp_phase_repaired_[clock format [clock seconds] -format %Y%m%d_%H%M%S]]
file mkdir $output
open_checkpoint [file join $root orb_test_output udp_phase_final_20261125_091730 routed.dcp]
phys_opt_design -hold_fix
route_design -preserve
report_timing_summary -delay_type min_max -report_unconstrained -file [file join $output timing_routed.rpt]
report_timing -delay_type min -from [get_ports {ETH_RXD[*] ETH_CRS_DV ETH_RX_ER}] -max_paths 4 -file [file join $output rmii_hold.rpt]
report_utilization -file [file join $output utilization_routed.rpt]
report_bus_skew -file [file join $output bus_skew.rpt]
report_drc -file [file join $output drc.rpt]
write_checkpoint -force [file join $output routed.dcp]
puts "REPORT_DIRECTORY: $output"
