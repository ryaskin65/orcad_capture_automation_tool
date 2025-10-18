# 2025.10.18
# Replacing the direction of selected Offpages
# Replaces the direction of the Offpages

################################################################################
proc SafeLog {message} {
	global scriptDir
	set timestamp [clock format [clock seconds] -format "%Y.%m.%d %H:%M:%S"]
	set logEntry "$timestamp - $message"
	#puts "LOG: $logEntry"
	catch {
		set logPath [file join $scriptDir "script_safe.log"]
		if {$message == "Script started"} {
			set fileId [open $logPath "w"]
		} else {
			set fileId [open $logPath "a"]
		}
		puts $fileId $logEntry
		close $fileId
	}
}

SafeLog "Script started"

# Initialize status object
set lSession $::DboSession_s_pDboSession
DboSession -this $lSession
set lStatus [DboState]
set lNullObj NULL

set lPage [GetActivePage]
if {$lPage == $lNullObj} {
	puts "No active page found!"
	return -1
}

set executableName [info nameofexecutable]
if {[regexp -nocase {.*(/spb_[^/]+).*} $executableName match fullMatch]} {
	set versionInfo [string trimleft $fullMatch "/"]
	set versionInfo [string toupper $versionInfo]
	set pathLib "C:/CADENCE/$versionInfo/TOOLS/CAPTURE/LIBRARY/CAPSYM.OLB"
} else {
	puts "No library found!"
	return -1
}

# Initialize status object
set lStatus [DboState]

# Get selected objects list
set selectedObjects [GetSelectedObjects]
if {[llength $selectedObjects] == 0} {
	puts "No objects selected for text replacement."
	return
}

# Initialize object type constants
# set objType [[GetSelectedObjects] GetObjectType]
# OffPageConnector type (38)
if {[catch {set offPageIter [$lPage NewOffPageConnectorsIter $lStatus]} err]} {
	puts "Error: Failed to create OffPageConnectors iterator: $err"
} else {
	set offPageInst [$offPageIter NextOffPageConnector $lStatus]
	if {$offPageInst != "NULL"} {
		set TYPE_OFFPAGE_INST [$offPageInst GetObjectType]
		# DisplayProperty type (39)
		set lPropsIter [$offPageInst NewDisplayPropsIter $lStatus]
		set lDProp [$lPropsIter NextProp $lStatus]
		if {$lDProp !=$lNullObj } { 
			set TYPE_DISPLAY_INST [$lDProp GetObjectType]
		}
		delete_DboDisplayPropsIter $lPropsIter
	} else {
		puts "No Offpage selected for direction change."
		return
	}
	if {[catch {delete_DboPageOffPageConnectorsIter $offPageIter} err]} {
		puts "Error: Failed to delete OffPageConnectors iterator: $err"
	}
}

# Replacement counter
set replaceCount 0

# Process selected objects
foreach obj $selectedObjects {
	set objType [$obj GetObjectType]
	if {$objType == $TYPE_OFFPAGE_INST} {

		# Get the name
		set nameCStr [DboTclHelper_sMakeCString]
		$obj GetName $nameCStr
		set lName [DboTclHelper_sGetConstCharPtr $nameCStr]
		# puts "Name $lName"

		# Get the real location (left side)
		set lRect [$obj GetBoundingBox]
		set lUpperLeft [DboTclHelper_sGetCRectTopLeft $lRect]
		set lrelX [DboTclHelper_sGetCPointX $lUpperLeft]
		set lrelY [DboTclHelper_sGetCPointY $lUpperLeft]
		puts "rel X: $lrelX Y: $lrelY"

		# Get the location (right side)
		set lLocation [$obj GetLocation $lStatus]
		set X [DboTclHelper_sGetCPointX $lLocation]
		set Y [DboTclHelper_sGetCPointY $lLocation]
		puts "X: $X Y: $Y"

		set textWidth [expr {$X - $lrelX}]

		# Get current SymbolName
		set nameCStr [DboTclHelper_sMakeCString]
		set symbol [$obj GetSymbol $lStatus]
		$symbol GetName $nameCStr
		set symbolName [DboTclHelper_sGetConstCharPtr $nameCStr]
		# puts "Current SymbolName: $symbolName"

		# Get rotation and mirror state of the instance offpage
		set symb_rotation [$obj GetRotation $lStatus]
		set symb_mirror [$obj GetMirror $lStatus]
		# puts $symb_mirror

		# Convert coordinates to UI units (assuming 1 unit = 3.937 internal units)
		set ui_x [expr {$X / 3.937}]
		set ui_y [expr {$Y / 3.937}]
		# Adjust to nearest value divisible by 2.54
		# set ui_x [expr {(round($ui_x / 2.54) + 1) * 2.54}]
		# set ui_y [expr {(round($ui_y / 2.54) + 1) * 2.54}]
		set ui_x [expr {round($ui_x / 2.54) * 2.54}]
		set ui_y [expr {round($ui_y / 2.54) * 2.54}]
		# Ensure 2 decimal places after adjustment
		set ui_x [format "%.2f" $ui_x]
		set ui_y [format "%.2f" $ui_y]
		puts "UI Position: ($ui_x, $ui_y)"

		# Delete current OffPage connector
		if {[catch {
			SelectObject $ui_x $ui_y FALSE
			Menu "Edit::Delete"
		} err]} {
			puts "Error: Failed to delete OffPage connector: $err"
			continue
		}

		# Place new OffPage connector
		if {[catch {
			if {($symbolName == "OFFPAGELEFT-R") & ($symb_mirror == 0)} {
				PlaceOffPage $ui_x $ui_y $pathLib "OFFPAGELEFT-L" "OFFPAGELEFT-L"
				MirrorHorizontal
				SetProperty {Name} $lName
				set selTextX [expr {$ui_x - 7 * 2.54}]
				set selTextX [format "%.2f" $selTextX]
				set selTextY [expr {$ui_y + 2.54}]
				set selTextY [format "%.2f" $selTextY]
				puts "-1- selText X: $selTextX Y: $selTextY"
				SelectObject $selTextX $selTextY FALSE
				set selObj [GetSelectedObjects]
				if {[llength $selObj] > 0} {
					set selObj [lindex $selObj 0]
					if {[catch {
						set offsetX -$textWidth
						$selObj SetLocation [DboTclHelper_sMakeCPoint $offsetX 5]
					} err]} {
						puts "Warning: Failed to reposition name: $err"
					}
				} else {
					puts "Warning: Failed to select name text at ($selTextX, $selTextY)"
				}
			} elseif {($symbolName == "OFFPAGELEFT-L") & ($symb_mirror == 1)} {
				PlaceOffPage $ui_x $ui_y $pathLib "OFFPAGELEFT-R" "OFFPAGELEFT-R"
				SetProperty {Name} $lName
				# Select and reposition name
				set selTextX [expr {$ui_x - 7 * 2.54}]
				set selTextX [format "%.2f" $selTextX]
				set selTextY [expr {$ui_y + 2.54}]
				set selTextY [format "%.2f" $selTextY]
				puts "-2- selText X: $selTextX Y: $selTextY"
				SelectObject $selTextX $selTextY FALSE
				set selObj [GetSelectedObjects]
				if {[llength $selObj] > 0} {
					set selObj [lindex $selObj 0]
					if {[catch {
						set offsetX -$textWidth
						$selObj SetLocation [DboTclHelper_sMakeCPoint $offsetX 5]
					} err]} {
						puts "Warning: Failed to reposition name: $err"
					}
				} else {
					puts "Warning: Failed to select name text at ($selTextX, $selTextY)"
				}
			} elseif {($symbolName == "OFFPAGELEFT-R") & ($symb_mirror == 1)} {
				PlaceOffPage $ui_x $ui_y $pathLib "OFFPAGELEFT-L" "OFFPAGELEFT-L"
				SetProperty {Name} $lName
			} elseif {($symbolName == "OFFPAGELEFT-L") & ($symb_mirror == 0)} {
				PlaceOffPage $ui_x $ui_y $pathLib "OFFPAGELEFT-R" "OFFPAGELEFT-R"
				MirrorHorizontal
				SetProperty {Name} $lName
			} else {
				puts "Unknown Symbo lName $symbolName for OffPage connector $lName"
				continue
			}
			incr replaceCount
			puts "Placed OffPage connector $lName"
		} err]} {
			puts "Error: Failed to place OffPage connector $lName: $err"
			continue
		}

	}
}

# Clean up
$lStatus -delete    

# Mark page as modified if replacement occurred
$lPage MarkModified

# Print summary
puts "Total replacements made: $replaceCount"
UnSelectAll
SafeLog "Script done!"
