set root [file normalize [file join [file dirname [info script]] ../..]]
set output [file join $root orb_test_output system_single_[clock format [clock seconds] -format %Y%m%d_%H%M%S]]
file mkdir $output
create_project -in_memory -part xc7a100tcsg324-1
set_property XPM_LIBRARIES {XPM_CDC XPM_MEMORY XPM_FIFO} [current_project]
foreach directory {common system_top system_top/orb system_top/orb/brief system_top/orb/fast system_top/orb/orientation} {
    foreach source [glob [file join $root orb_hardware rtl $directory *.sv]] {
        read_verilog -sv $source
    }
}
synth_design -top system_top -generic ORB_LEVELS=1 -part xc7a100tcsg324-1 -mode out_of_context
create_clock -name clk -period 10.000 [get_ports clk]
# Provisional 24 MHz camera PCLK; replace with the configured sensor clock.
create_clock -name cam_pclk -period 41.667 [get_ports cam_pclk]
set_clock_groups -asynchronous -group [get_clocks clk] -group [get_clocks cam_pclk]
set camera_inputs [get_ports {cam_data[*] cam_href cam_vsync}]
set_input_delay -clock cam_pclk -max 2.000 $camera_inputs
set_input_delay -clock cam_pclk -min 0.000 $camera_inputs
set system_inputs [get_ports -filter {DIRECTION == IN && NAME != clk && NAME !~ cam_*}]
set_input_delay -clock clk -max 2.000 $system_inputs
set_input_delay -clock clk -min 0.000 $system_inputs
set_output_delay -clock clk -max 2.000 [all_outputs]
set_output_delay -clock clk -min 0.000 [all_outputs]
write_xdc -force [file join $output timing.xdc]
report_utilization -file [file join $output utilization_synth.rpt]
report_utilization -hierarchical -file [file join $output hierarchy_synth.rpt]
opt_design
place_design
route_design
report_utilization -file [file join $output utilization_routed.rpt]
report_timing_summary -delay_type min_max -report_unconstrained -file [file join $output timing_routed.rpt]
report_cdc -file [file join $output cdc.rpt]
report_bus_skew -file [file join $output bus_skew.rpt]
report_timing -delay_type min -from [all_registers] -to [all_registers] -max_paths 10 -file [file join $output register_hold.rpt]
report_timing -delay_type max -from [all_registers] -to [all_registers] -max_paths 10 -file [file join $output register_setup.rpt]
report_route_status -file [file join $output route_status.rpt]
write_checkpoint -force [file join $output routed.dcp]
puts "REPORT_DIRECTORY: $output"
