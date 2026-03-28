if { [llength $argv] < 2 } {
    error "Usage: vivado -mode tcl run_sim.tcl --tclargs <PROJECT_NAME> <TEST_MODULE>"
}

set PROJECT_NAME [lindex $argv 0]
set TEST_MODULE [lindex $argv 1]

open_project project/${PROJECT_NAME}.xpr

set_property top $TEST_MODULE [get_filesets sim_1]

puts "INFO: Launching simulation..."
launch_simulation

puts "INFO: Running simulation..."
run all

close_sim -force

puts "INFO: Simulation completed"
