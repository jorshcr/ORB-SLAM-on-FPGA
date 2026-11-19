set root [file normalize [file join [file dirname [info script]] ../..]]
set output [file join $root orb_test_output orb_[clock format [clock seconds] -format %Y%m%d_%H%M%S]]
file mkdir $output
set_part xc7a100tcsg324-1
read_verilog -sv [file join $root orb_hardware rtl common line_window.sv]
read_verilog -sv [file join $root orb_hardware rtl orb fast fast_nms.sv]
read_verilog -sv [file join $root orb_hardware rtl orb fast fast_score.sv]
read_verilog -sv [file join $root orb_hardware rtl orb fast fast_top.sv]
read_verilog -sv [file join $root orb_hardware rtl orb gaussian_blur.sv]
read_verilog -sv [file join $root orb_hardware rtl orb orb_engine_top.sv]
read_verilog -sv [file join $root orb_hardware rtl orb orientation column_sum.sv]
read_verilog -sv [file join $root orb_hardware rtl orb orientation moment_compute.sv]
read_verilog -sv [file join $root orb_hardware rtl orb orientation orientation_top.sv]
read_verilog -sv [file join $root orb_hardware rtl orb orientation quadrant_angle_compute.sv]
read_verilog -sv [file join $root orb_hardware rtl orb orientation tan_multiply.sv]
read_verilog -sv [file join $root orb_hardware rtl orb orientation x_moment.sv]
read_verilog -sv [file join $root orb_hardware rtl orb orientation y_moment.sv]
read_verilog -sv [file join $root orb_hardware rtl orb orientation y_moment_sum.sv]
synth_design -top orb_pyramid_level -part xc7a100tcsg324-1 -mode out_of_context
create_clock -name clk -period 10.000 [get_ports clk]
set data_inputs [get_ports -filter {DIRECTION == IN && NAME != clk}]
set_input_delay -clock clk -max 2.000 $data_inputs
set_input_delay -clock clk -min 0.000 $data_inputs
set_output_delay -clock clk -max 2.000 [all_outputs]
set_output_delay -clock clk -min 0.000 [all_outputs]
report_utilization -file [file join $output utilization_synth.rpt]
report_utilization -hierarchical -file [file join $output hierarchy_synth.rpt]
report_timing_summary -file [file join $output timing_synth.rpt]
opt_design
place_design
route_design
report_utilization -file [file join $output utilization_routed.rpt]
report_utilization -hierarchical -file [file join $output hierarchy_routed.rpt]
report_timing_summary -delay_type min_max -report_unconstrained -file [file join $output timing_routed.rpt]
report_timing -from [all_registers -clock clk] -to [all_registers -clock clk] -max_paths 5 -file [file join $output register_paths.rpt]
report_route_status -file [file join $output route_status.rpt]
puts "REPORT_DIRECTORY: $output"
