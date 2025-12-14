# RIGa&DeepSeek 14.12.2025
# Replacing the direction of selected Offpage connectors in OrCAD Capture

# Safe deletion procedures for C++ objects
proc SafeDeleteCString {cstrVar} {
    upvar $cstrVar cstr
    if {[info exists cstr] && $cstr != ""} {
        catch {DboTclHelper_sDeleteCString $cstr}
        set cstr ""
    }
}

proc SafeDeleteCPoint {pointVar} {
    upvar $pointVar point
    if {[info exists point] && $point != ""} {
        catch {DboTclHelper_sDeleteCPoint $point}
        set point ""
    }
}

proc SafeDeleteCRect {rectVar} {
    upvar $rectVar rect
    if {[info exists rect] && $rect != ""} {
        catch {DboTclHelper_sDeleteCRect $rect}
        set rect ""
    }
}

proc SafeDeleteIter {iterVar iterType} {
    upvar $iterVar iter
    if {[info exists iter] && $iter != ""} {
        catch [list delete_$iterType $iter]
        set iter ""
    }
}

# Safe logging with timestamp and file output
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

# Main procedure to change OffPage directions
proc changeOffPageDirections {} {
    SafeLog "Script started"

    # Initialize session and status
    set lSession $::DboSession_s_pDboSession
    if {$lSession == ""} {
        SafeLog "ERROR: No DboSession available"
        return false
    }
    
    DboSession -this $lSession
    set lStatus [DboState]
    set lNullObj NULL
    set result true
    set offPageIter ""
    set lPropsIter ""

    # Get active page
    set lPage ""
    if {[catch {set lPage [GetActivePage]} err]} {
        SafeLog "ERROR: Failed to get active page: $err"
        return false
    }
    
    if {$lPage == $lNullObj} {
        SafeLog "ERROR: No active page found!"
        return false
    }

    # Determine library path from executable
    set executableName [info nameofexecutable]
    if {[regexp -nocase {.*(/spb_[^/]+).*} $executableName match fullMatch]} {
        set versionInfo [string trimleft $fullMatch "/"]
        set versionInfo [string toupper $versionInfo]
        set pathLib "C:/CADENCE/$versionInfo/TOOLS/CAPTURE/LIBRARY/CAPSYM.OLB"
        SafeLog "Using library: $pathLib"
    } else {
        SafeLog "ERROR: Could not determine library path from executable: $executableName"
        return false
    }

    # Get selected objects
    set selectedObjects [GetSelectedObjects]
    if {[llength $selectedObjects] == 0} {
        SafeLog "No objects selected for direction change."
        return false
    }

    SafeLog "Processing [llength $selectedObjects] selected objects"

    # Initialize object type constants
    set TYPE_OFFPAGE_INST ""
    
    # Get object types from first available offpage connector
    if {[catch {
        set offPageIter [$lPage NewOffPageConnectorsIter $lStatus]
        set offPageInst [$offPageIter NextOffPageConnector $lStatus]
        if {$offPageInst != $lNullObj} {
            set TYPE_OFFPAGE_INST [$offPageInst GetObjectType]
            SafeLog "Detected OffPage object type: $TYPE_OFFPAGE_INST"
        } else {
            SafeLog "WARNING: No offpage connectors found on page to determine types"
        }
    } err]} {
        SafeLog "WARNING: Failed to determine object types: $err"
    }

    # Cleanup temporary iterator
    SafeDeleteIter offPageIter DboPageOffPageConnectorsIter

    if {$TYPE_OFFPAGE_INST == ""} {
        SafeLog "ERROR: Could not determine OffPage object type"
        return false
    }

    # Process selected objects
    set replaceCount 0
    set processedCount 0

    foreach obj $selectedObjects {
        set lRect ""
        set lUpperLeft ""
        set lLocation ""
        set nameCStr ""

        if {[catch {
            set objType [$obj GetObjectType]
            if {$objType != $TYPE_OFFPAGE_INST} {
                SafeLog "Skipping non-OffPage object (type: $objType)"
                continue
            }

            incr processedCount

            # Get connector name
            set nameCStr [DboTclHelper_sMakeCString]
            $obj GetName $nameCStr
            set lName [DboTclHelper_sGetConstCharPtr $nameCStr]
            SafeLog "Processing OffPage connector: $lName"

            # Get bounding box coordinates
            set lRect [$obj GetBoundingBox]
            set lUpperLeft [DboTclHelper_sGetCRectTopLeft $lRect]
            set lrelX [DboTclHelper_sGetCPointX $lUpperLeft]
            set lrelY [DboTclHelper_sGetCPointY $lUpperLeft]

            # Get connector location
            set lLocation [$obj GetLocation $lStatus]
            set X [DboTclHelper_sGetCPointX $lLocation]
            set Y [DboTclHelper_sGetCPointY $lLocation]

            set textWidth [expr {$X - $lrelX}]

            # Get current symbol name
            set symbol [$obj GetSymbol $lStatus]
            $symbol GetName $nameCStr
            set symbolName [DboTclHelper_sGetConstCharPtr $nameCStr]

            # Get mirror state
            set symb_mirror [$obj GetMirror $lStatus]

            # Convert to UI units (1 unit = 3.937 internal units)
            set ui_x [expr {$X / 3.937}]
            set ui_y [expr {$Y / 3.937}]
            set ui_x [expr {round($ui_x / 2.54) * 2.54}]
            set ui_y [expr {round($ui_y / 2.54) * 2.54}]
            set ui_x [format "%.2f" $ui_x]
            set ui_y [format "%.2f" $ui_y]

            SafeLog "Connector at: ($ui_x, $ui_y), Symbol: $symbolName, Mirror: $symb_mirror"

            # Delete current OffPage connector
            if {[catch {
                SelectObject $ui_x $ui_y FALSE
                Menu "Edit::Delete"
            } err]} {
                SafeLog "ERROR: Failed to delete OffPage connector $lName: $err"
                continue
            }

            # Place new OffPage connector with opposite direction
            if {[catch {
                # Use the working algorithm from change_dir.tcl
                if {($symbolName == "OFFPAGELEFT-R") && ($symb_mirror == 0)} {
                    PlaceOffPage $ui_x $ui_y $pathLib "OFFPAGELEFT-L" "OFFPAGELEFT-L"
                    MirrorHorizontal
                    SetProperty {Name} $lName
                    # Reposition text for left connector
                    set selTextX [expr {$ui_x - 7 * 2.54}]
                    set selTextX [format "%.2f" $selTextX]
                    set selTextY [expr {$ui_y + 2.54}]
                    set selTextY [format "%.2f" $selTextY]
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
                    }
                    
                } elseif {($symbolName == "OFFPAGELEFT-L") && ($symb_mirror == 1)} {
                    PlaceOffPage $ui_x $ui_y $pathLib "OFFPAGELEFT-R" "OFFPAGELEFT-R"
                    SetProperty {Name} $lName
                    # Reposition text for right connector
                    set selTextX [expr {$ui_x - 7 * 2.54}]
                    set selTextX [format "%.2f" $selTextX]
                    set selTextY [expr {$ui_y + 2.54}]
                    set selTextY [format "%.2f" $selTextY]
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
                    }
                    
                } elseif {($symbolName == "OFFPAGELEFT-R") && ($symb_mirror == 1)} {
                    PlaceOffPage $ui_x $ui_y $pathLib "OFFPAGELEFT-L" "OFFPAGELEFT-L"
                    SetProperty {Name} $lName
                    # No text repositioning needed for this case
                    
                } elseif {($symbolName == "OFFPAGELEFT-L") && ($symb_mirror == 0)} {
                    PlaceOffPage $ui_x $ui_y $pathLib "OFFPAGELEFT-R" "OFFPAGELEFT-R"
                    MirrorHorizontal
                    SetProperty {Name} $lName
                    # No text repositioning needed for this case
                    
                } elseif {($symbolName == "OFFPAGERIGHT-R") && ($symb_mirror == 0)} {
                    PlaceOffPage $ui_x $ui_y $pathLib "OFFPAGELEFT-R" "OFFPAGELEFT-R"
                    MirrorHorizontal
                    SetProperty {Name} $lName
                    MirrorHorizontal
                    # No text repositioning needed for this case
                    
                } elseif {($symbolName == "OFFPAGERIGHT-L") && ($symb_mirror == 0)} {
                    PlaceOffPage $ui_x $ui_y $pathLib "OFFPAGELEFT-L" "OFFPAGELEFT-L"
                    MirrorHorizontal
                    SetProperty {Name} $lName
                    MirrorHorizontal
                    # No text repositioning needed for this case
                    
                } else {
                    SafeLog "WARNING: Unknown symbol $symbolName for OffPage $lName"
                    PlaceOffPage $ui_x $ui_y $pathLib "OFFPAGELEFT-R" "OFFPAGELEFT-R"
                    MirrorHorizontal
                    SetProperty {Name} $lName
                    MirrorHorizontal
                    # No text repositioning needed for this case
                }
                
                incr replaceCount
                SafeLog "Successfully changed direction for: $lName"

            } err]} {
                SafeLog "ERROR: Failed to place new OffPage connector $lName: $err"
                continue
            }

        } err]} {
            SafeLog "ERROR: Failed to process object: $err"
        }

        # Cleanup resources for this object
        SafeDeleteCString nameCStr
        SafeDeleteCPoint lUpperLeft
        SafeDeleteCPoint lLocation
        SafeDeleteCRect lRect
    }

    # Final operations
    SafeLog "Script done!"
    if {$processedCount > 0} {
        catch {$lPage MarkModified}
        catch {UnSelectAll}
        SafeLog "SUMMARY: Successfully changed direction for $replaceCount of $processedCount OffPage connectors"
    } else {
        SafeLog "No OffPage connectors were processed"
    }

    SafeLog "Script completed successfully"
    return [expr {$replaceCount > 0}]
}

# Execute the script
set scriptDir [file dirname [info script]]
changeOffPageDirections