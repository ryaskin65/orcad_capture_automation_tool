
set start_time [clock seconds]
puts "Start script"
set ::path_to_csv_file "D:/py/Git_OrCAD/data/offpage.csv"
if {[catch {source "D:/py/Git_OrCAD/scripts/replace_offpage.tcl"} err]} {
    puts $err
} else {
    puts "Script done!"
    set end_time [clock seconds]
    set execution_time [expr {$end_time - $start_time}]
    puts "EXECUTION_TIME:$execution_time sec"
}
set safeVars {start_time end_time execution_time err}
foreach var $safeVars {
    if {[info exists $var]} {unset $var}
}
if {[info exists ::path_to_csv_file]} {unset ::path_to_csv_file}
if {[info exists ::path_to_csv_file]} {unset ::path_to_csv_file}
