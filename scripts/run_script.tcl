
set start_time [clock seconds]
puts "Start script"
set ::find_text "M"
set ::replace_text "MUX"
set ::scope "selected"

if {[catch {source "D:/py/Git_OrCAD/scripts/simple_replace.tcl"} err]} {
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
if {[info exists ::find_text]} {unset ::find_text}
if {[info exists ::replace_text]} {unset ::replace_text}
if {[info exists ::scope]} {unset ::scope}
