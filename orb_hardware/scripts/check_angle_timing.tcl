set root [file normalize [file join [file dirname [info script]] ../..]]
set output [file join $root orb_test_output quadrant_angle_compute_[clock format [clock seconds] -format %Y%m%d_%H%M%S]]
file mkdir $output
set_part xc7a100tcsg324-1
read_verilog -sv [file join $root orb_hardware rtl system_top orb orientation quadrant_angle_compute.sv]
read_verilog -sv [file join $root orb_hardware rtl system_top orb orientation tan_multiply.sv]
synth_design -top quadrant_angle_compute -part xc7a100tcsg324-1 -mode out_of_context
create_clock -name clk -period 10.000 [get_ports clk]
set_input_delay -clock clk -max 2.000 [get_ports {reset in_valid m10[*] m01[*] in_tag[*]}]
set_input_delay -clock clk -min 0.000 [get_ports {reset in_valid m10[*] m01[*] in_tag[*]}]
set_output_delay -clock clk -max 2.000 [get_ports {out_quadrant[*] out_sector[*] out_valid out_tag[*]}]
set_output_delay -clock clk -min 0.000 [get_ports {out_quadrant[*] out_sector[*] out_valid out_tag[*]}]
report_utilization -file [file join $output utilization_synth.rpt]
report_timing_summary -file [file join $output timing_synth.rpt]
opt_design
place_design
route_design
report_utilization -file [file join $output utilization_routed.rpt]
report_timing_summary -delay_type min_max -report_unconstrained -file [file join $output timing_routed.rpt]
report_timing -from [all_registers -clock clk] -to [all_registers -clock clk] -max_paths 5 -file [file join $output register_paths.rpt]
puts "REPORT_DIRECTORY: $output"
