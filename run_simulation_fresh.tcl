# Batch Vivado simulation for the assembler GUI.
# The testbench reads D:/cpu_32bit/program.hex and writes
# D:/cpu_32bit/simulation_result.json. It terminates itself on HLT or timeout.

set PROJECT "D:/cpu_32bit/cpu_32bit.xpr"

puts "============================================================"
puts " CPU GUI SIMULATION: HEX -> UART -> CPU -> JSON"
puts "============================================================"

if {![file exists $PROJECT]} {
    error "Vivado project not found: $PROJECT"
}
if {![file exists "D:/cpu_32bit/program.hex"]} {
    error "program.hex not found: D:/cpu_32bit/program.hex"
}

open_project $PROJECT
set_property top cpu_sim_tb [get_filesets sim_1]
update_compile_order -fileset sim_1

# Make sure the output from a previous run cannot be mistaken for this run.
catch {file delete -force "D:/cpu_32bit/simulation_result.json"}

launch_simulation -simset sim_1 -mode behavioral
puts "CPU GUI SIMULATION: Running until testbench finishes..."
run all

close_sim
close_project
puts "CPU GUI SIMULATION: Vivado simulation finished."
exit
