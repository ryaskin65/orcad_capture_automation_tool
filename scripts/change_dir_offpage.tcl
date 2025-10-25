# RIGa&DeepSeek 25.10.2025
# Replacing the direction of selected Offpages

proc SafeLog {message} {
	global scriptDir
	set timestamp [clock format [clock seconds] -format "%Y.%m.%d %H:%M:%S"]
	set logEntry "$timestamp - $message"
	puts $message
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
set result true

set lPage [GetActivePage]
if {$lPage == $lNullObj} {
	SafeLog "No active page found!"
	set result false
}
if {$result} {
	SafeLog "Active page: $lPage"
	set executableName [info nameofexecutable]
	if {[regexp -nocase {.*(/spb_[^/]+).*} $executableName match fullMatch]} {
		set versionInfo [string trimleft $fullMatch "/"]
		set versionInfo [string toupper $versionInfo]
		set pathLib "C:/CADENCE/$versionInfo/TOOLS/CAPTURE/LIBRARY/CAPSYM.OLB"
	} else {
		SafeLog "No library found!"
		set result false
	}
}
if {$result} {
	# Get selected objects list
	set selectedObjects [GetSelectedObjects]
	if {[llength $selectedObjects] == 0} {
		SafeLog "No objects selected for text replacement."
		set result false
	}
}
if {$result} {
	# Initialize object type constants
	# set objType [[GetSelectedObjects] GetObjectType]
	# OffPageConnector type (38)
	set lPropsIter ""
	if {[catch {set offPageIter [$lPage NewOffPageConnectorsIter $lStatus]} err]} {
		SafeLog "Error: Failed to create OffPageConnectors iterator: $err"
		set result false
	} else {
		set offPageInst [$offPageIter NextOffPageConnector $lStatus]
		if {$offPageInst != $lNullObj} {
			set TYPE_OFFPAGE_INST [$offPageInst GetObjectType]
			# DisplayProperty type (39)
			set lPropsIter [$offPageInst NewDisplayPropsIter $lStatus]
			set lDProp [$lPropsIter NextProp $lStatus]
			if {$lDProp !=$lNullObj } { 
				set TYPE_DISPLAY_INST [$lDProp GetObjectType]
				# catch {$lDProp -delete}  ??? !!!
				# catch {DboDisplayProperty -delete $lDProp}
				# catch {delete_DboDisplayProperty $lDProp}
			}
		} else {
			SafeLog "No Offpage selected for direction change."
			set result false
		}
		if {$offPageIter != ""} {
			catch {delete_DboPageOffPageConnectorsIter $offPageIter}
		}
	}
	if {$lPropsIter != ""} {
		delete_DboDisplayPropsIter $lPropsIter
	}
}
if {$result} {
	# Replacement counter
	set replaceCount 0

	# Process selected objects
	foreach obj $selectedObjects {
		set lRect ""
		set lUpperLeft ""
		set lLocation ""

		set objType [$obj GetObjectType]
		if {$objType == $TYPE_OFFPAGE_INST} {

			# Get the name
			set nameCStr [DboTclHelper_sMakeCString]
			$obj GetName $nameCStr
			set lName [DboTclHelper_sGetConstCharPtr $nameCStr]
			if {$nameCStr != ""} {
				DboTclHelper_sDeleteCString $nameCStr
			}
			# SafeLog "Name $lName"

			# Get the real location (left side)
			set lRect [$obj GetBoundingBox]
			set lUpperLeft [DboTclHelper_sGetCRectTopLeft $lRect]
			set lrelX [DboTclHelper_sGetCPointX $lUpperLeft]
			set lrelY [DboTclHelper_sGetCPointY $lUpperLeft]
			SafeLog "rel X: $lrelX Y: $lrelY"

			# Get the location (right side)
			set lLocation [$obj GetLocation $lStatus]
			set X [DboTclHelper_sGetCPointX $lLocation]
			set Y [DboTclHelper_sGetCPointY $lLocation]
			SafeLog "X: $X Y: $Y"

			set textWidth [expr {$X - $lrelX}]

			# Get current SymbolName
			set nameCStr [DboTclHelper_sMakeCString]
			set symbol [$obj GetSymbol $lStatus]
			$symbol GetName $nameCStr
			set symbolName [DboTclHelper_sGetConstCharPtr $nameCStr]
			if {$nameCStr != ""} {
				DboTclHelper_sDeleteCString $nameCStr
			}
			# SafeLog "Current SymbolName: $symbolName"

			# Get rotation and mirror state of the instance offpage
			set symb_rotation [$obj GetRotation $lStatus]
			set symb_mirror [$obj GetMirror $lStatus]
			# SafeLog $symb_mirror

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
			SafeLog "UI Position: ($ui_x, $ui_y)"

			# Delete current OffPage connector
			if {[catch {
				SelectObject $ui_x $ui_y FALSE
				Menu "Edit::Delete"
			} err]} {
				SafeLog "Error: Failed to delete OffPage connector: $err"
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
					SafeLog "-1- selText X: $selTextX Y: $selTextY"
					SelectObject $selTextX $selTextY FALSE
					set selObj [GetSelectedObjects]
					if {[llength $selObj] > 0} {
						set selObj [lindex $selObj 0]
						if {[catch {
							set offsetX -$textWidth
							$selObj SetLocation [DboTclHelper_sMakeCPoint $offsetX 5]
						} err]} {
							SafeLog "Warning: Failed to reposition name: $err"
						}
					} else {
						SafeLog "Warning: Failed to select name text at ($selTextX, $selTextY)"
					}
				} elseif {($symbolName == "OFFPAGELEFT-L") & ($symb_mirror == 1)} {
					PlaceOffPage $ui_x $ui_y $pathLib "OFFPAGELEFT-R" "OFFPAGELEFT-R"
					SetProperty {Name} $lName
					# Select and reposition name
					set selTextX [expr {$ui_x - 7 * 2.54}]
					set selTextX [format "%.2f" $selTextX]
					set selTextY [expr {$ui_y + 2.54}]
					set selTextY [format "%.2f" $selTextY]
					SafeLog "-2- selText X: $selTextX Y: $selTextY"
					SelectObject $selTextX $selTextY FALSE
					set selObj [GetSelectedObjects]
					if {[llength $selObj] > 0} {
						set selObj [lindex $selObj 0]
						if {[catch {
							set offsetX -$textWidth
							set pointObj [DboTclHelper_sMakeCPoint $offsetX 5]
							$selObj SetLocation $pointObj
							if {$pointObj != ""} {
								DboTclHelper_sDeleteCPoint $pointObj
							}
						} err]} {
							SafeLog "Warning: Failed to reposition name: $err"
						}
					} else {
						SafeLog "Warning: Failed to select name text at ($selTextX, $selTextY)"
					}
				} elseif {($symbolName == "OFFPAGELEFT-R") & ($symb_mirror == 1)} {
					PlaceOffPage $ui_x $ui_y $pathLib "OFFPAGELEFT-L" "OFFPAGELEFT-L"
					SetProperty {Name} $lName
				} elseif {($symbolName == "OFFPAGELEFT-L") & ($symb_mirror == 0)} {
					PlaceOffPage $ui_x $ui_y $pathLib "OFFPAGELEFT-R" "OFFPAGELEFT-R"
					MirrorHorizontal
					SetProperty {Name} $lName
				} else {
					SafeLog "Unknown Symbo lName $symbolName for OffPage connector $lName"
					continue
				}
				incr replaceCount
				SafeLog "Placed OffPage connector $lName"
			} err]} {
				SafeLog "Error: Failed to place OffPage connector $lName: $err"
				continue
			}

		}
		if {$lUpperLeft != ""} { catch {DboTclHelper_sDeleteCPoint $lUpperLeft} }
		if {$lLocation != ""} { catch {DboTclHelper_sDeleteCPoint $lLocation} }
		if {$lRect != ""} { catch {DboTclHelper_sDeleteCRect $lRect} }
	}
}

# Clean up
$lStatus -delete    

# Mark page as modified if replacement occurred
$lPage MarkModified

# Print summary
SafeLog "Total replacements made: $replaceCount"
UnSelectAll
SafeLog "Script done!"
