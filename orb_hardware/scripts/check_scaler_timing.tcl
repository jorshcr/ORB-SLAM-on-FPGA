set root [file normalize [file join [file dirname [info script]] ../..]]
set mode [lindex $argv 0]
if {$mode ni {yes no}} {error "Pass yes (DSP) or no (LUT)"}
set output [file join $root orb_test_output scaler_${mode}_[clock format [clock seconds] -format %Y%m%d_%H%M%S]]
file mkdir $output
create_project -in_memory -part xc7a100tcsg324-1
read_verilog -sv [file join $root orb_hardware rtl system_top image_scaler.sv]
set xdc [file join $output timing.xdc]
set f [open $xdc w]
puts $f {create_clock -name clk -period 10.000 [get_ports clk]}
puts $f {set_input_delay -clock clk -max 2.000 [get_ports {reset in_valid in_gray* in_x* in_y*}]}
puts $f {set_input_delay -clock clk -min 0.000 [get_ports {reset in_valid in_gray* in_x* in_y*}]}
puts $f {set_output_delay -clock clk -max 2.000 [get_ports {out_gray* out_x* out_y* out_valid}]}
puts $f {set_output_delay -clock clk -min 0.000 [get_ports {out_gray* out_x* out_y* out_valid}]}
close $f
read_xdc $xdc
synth_design -top image_scaler -part xc7a100tcsg324-1 -mode out_of_context -generic DSP_MODE=$mode
set dsp_count [llength [get_cells -hier -filter {REF_NAME == DSP48E1}]]
puts "MAPPED_DSP_COUNT: $dsp_count"
if {$mode eq "yes" && $dsp_count != 4} {error "Expected four pixel-weight DSP multipliers"}
if {$mode eq "no" && $dsp_count != 0} {error "Expected LUT-only arithmetic"}
opt_design
place_design
route_design
report_utilization -file [file join $output utilization_routed.rpt]
report_timing_summary -delay_type min_max -report_unconstrained -file [file join $output timing_routed.rpt]
report_timing -from [all_registers -clock clk] -to [all_registers -clock clk] -max_paths 5 -file [file join $output register_paths.rpt]
report_route_status -file [file join $output route_status.rpt]
puts "REPORT_DIRECTORY: $output"
