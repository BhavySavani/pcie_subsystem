if { [llength $argv] < 3 } {
    error "Usage: vivado -mode batch -source generate_tb_deps.tcl -tclargs <PROJECT_NAME> <OUTPUT> \"<SIM_FILES>\""
}

set PROJECT_NAME [lindex $argv 0]
set OUTPUT       [lindex $argv 1]
set SIM_FILES    [split [lindex $argv 2] " "]

open_project project/${PROJECT_NAME}.xpr

set fout [open $OUTPUT w]

foreach file $SIM_FILES {
    set top_module [file rootname [file tail $file]]

    set_property top $top_module [get_filesets sim_1]
    update_compile_order -fileset sim_1

    set line $top_module

    foreach f [get_files -compile_order sources -used_in simulation -of_objects [get_filesets sim_1]] {
        set rel [string map "[pwd]/ {}" $f]
        append line " $rel"
    }

    puts $fout $line
}

close $fout
puts "Written to $OUTPUT"
