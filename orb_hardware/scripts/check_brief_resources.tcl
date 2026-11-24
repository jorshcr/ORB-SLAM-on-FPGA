set root [file normalize [file join [file dirname [info script]] ../..]]
set output [file join $root orb_test_output brief_resources_[clock format [clock seconds] -format %Y%m%d_%H%M%S]]
file mkdir $output
set variants [list dsp]
if {[llength $argv] > 0} { set variants [list baseline dsp] }
foreach variant $variants {
    create_project -in_memory -part xc7a100tcsg324-1
    read_verilog -sv [file join $root orb_hardware rtl common brief_pattern.sv]
    if {$variant eq "baseline"} {
        read_verilog -sv [lindex $argv 0]
    } else {
        read_verilog -sv [file join $root orb_hardware rtl system_top orb brief brief_engine.sv]
    }
    synth_design -top brief_engine -part xc7a100tcsg324-1 -mode out_of_context
    report_utilization -file [file join $output ${variant}_synth.rpt]
    opt_design
    report_utilization -file [file join $output ${variant}_optimized.rpt]
    report_utilization -hierarchical -file [file join $output ${variant}_hierarchy.rpt]
    close_project
}
puts "REPORT_DIRECTORY: $output"
