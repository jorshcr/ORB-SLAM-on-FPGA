set root [file normalize [file join [file dirname [info script]] ../..]]
set output [file join $root orb_test_output y_moment_sum_[clock format [clock seconds] -format %Y%m%d_%H%M%S]]
file mkdir $output
set_part xc7a100tcsg324-1
read_verilog -sv [file join $root orb_hardware rtl system_top orb orientation y_moment_sum.sv]
synth_design -top y_moment_sum -part xc7a100tcsg324-1 -mode out_of_context
create_clock -name clk -period 10.000 [get_ports clk]
set_input_delay -clock clk -max 2.000 [get_ports {reset in_valid in_col*}]
set_input_delay -clock clk -min 0.000 [get_ports {reset in_valid in_col*}]
set_output_delay -clock clk -max 2.000 [get_ports {out_sum[*] out_valid}]
set_output_delay -clock clk -min 0.000 [get_ports {out_sum[*] out_valid}]
report_utilization -file [file join $output utilization_synth.rpt]
report_timing_summary -file [file join $output timing_synth.rpt]
set dsp_file [open [file join $output dsp_mapping.rpt] w]
foreach cell [get_cells -hier -filter {REF_NAME == DSP48E1}] {
    puts $dsp_file "DSP: $cell"
    foreach prop {USE_DPORT AREG BREG DREG ADREG MREG PREG} {
        puts $dsp_file "$prop: [get_property $prop $cell]"
    }
    foreach pin [get_pins -of_objects $cell -filter {REF_PIN_NAME =~ INMODE*}] {
        puts $dsp_file "$pin: [get_nets -of_objects $pin]"
    }
}
close $dsp_file
opt_design
place_design
route_design
report_utilization -file [file join $output utilization_routed.rpt]
report_timing_summary -delay_type min_max -report_unconstrained -file [file join $output timing_routed.rpt]
report_timing -from [all_registers -clock clk] -to [all_registers -clock clk] -max_paths 5 -file [file join $output register_paths.rpt]
puts "REPORT_DIRECTORY: $output"
