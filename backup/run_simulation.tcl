set PROJECT "D:/assembler/cpu_32bit.xpr"

puts "========================================"
puts "Opening CPU project..."
puts "========================================"

open_project $PROJECT

set_property top cpu_sim_tb [get_filesets sim_1]

update_compile_order -fileset sim_1

puts "========================================"
puts "Starting behavioral simulation..."
puts "========================================"

launch_simulation -simset sim_1 -mode behavioral

puts "========================================"
puts "Running simulation for 5 ms..."
puts "========================================"

run 5 ms

puts "========================================"
puts "Simulation finished."
puts "========================================"

close_sim

close_project

exit