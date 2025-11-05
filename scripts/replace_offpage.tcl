# RIGa&DeepSeek 04.11.2025
# Script to replace names of offPages for OrCAD Capture with text positioning

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

proc SafeDeleteIter {iterVar} {
    upvar $iterVar iter
    if {[info exists iter] && $iter != ""} {
        catch {delete_DboPageOffPageConnectorsIter $iter}
        set iter ""
    }
}

proc optimizeTextPosition {lOffPage lStatus} {
    if {[catch {
        $lOffPage SetBoundingBoxDirty 1
    } err]} {
        SafeLog "Warning: Failed to update bounding box"
    }
    return true
}

# proc optimizeTextPosition {lOffPage lStatus} {
#     set lLocation ""
#     set nameCStr ""
#     set newLocation ""

#      if {[catch {
#         # Get current location
#         set lLocation [$lOffPage GetLocation $lStatus]
#         set currentX [DboTclHelper_sGetCPointX $lLocation]
#         set currentY [DboTclHelper_sGetCPointY $lLocation]
        
#         # Get text name to estimate length
#         set nameCStr [DboTclHelper_sMakeCString]
#         $lOffPage GetName $nameCStr
#         set textName [DboTclHelper_sGetConstCharPtr $nameCStr]
        
#         # Simple text positioning based on current location
#         # Move text slightly to avoid overlap with symbol
#         set textLength [string length $textName]
        
#         # Use fixed offsets based on text length
#         if {$textLength <= 4} {
#             set offsetX 60
#         } elseif {$textLength <= 8} {
#             set offsetX 80
#         } else {
#             set offsetX 100
#         }
        
#         # Create new position with offset
#         set newX [expr $currentX + $offsetX]
#         set newY [expr $currentY - 10] ;# Small vertical adjustment
        
#         # Set new location - use correct method signature
#         # For off-page connectors, we may need to use Move method instead of SetLocation
#         set newLocation [DboTclHelper_sMakeCPoint $newX $newY]
# #        $lOffPage Move $newLocation $lStatus
        
#         # Alternative approach if Move doesn't work - use SetLocation with correct arguments
#         # $lOffPage SetLocation $newX $newY $lStatus
        
#         # Force update
#         $lOffPage SetBoundingBoxDirty 1
#     } err]} {
#         SafeLog "Error optimizing text position: $err"
#     }
#     if {$lLocation != ""} { catch {DboTclHelper_sDeleteCPoint $lLocation} }
#     if {$nameCStr != ""} { catch {DboTclHelper_sDeleteCString $nameCStr} }
#     if {$newLocation != ""} { catch {DboTclHelper_sDeleteCPoint $newLocation} }
# }

proc getOffPageAbsoluteCoords {lOffPage lStatus} {
    set lRect ""
    set lUpperLeft ""
    set lLocation ""
    set result [list 0 0]
    
    if {[catch {
        set lRect [$lOffPage GetBoundingBox]
        set lUpperLeft [DboTclHelper_sGetCRectTopLeft $lRect]
        set lrelX [DboTclHelper_sGetCPointX $lUpperLeft]
        set lrelY [DboTclHelper_sGetCPointY $lUpperLeft]
        
        set lLocation [$lOffPage GetLocation $lStatus]
        set X [DboTclHelper_sGetCPointX $lLocation]
        set Y [DboTclHelper_sGetCPointY $lLocation]

        set result [list [expr $X + $lrelX] [expr $Y + $lrelY]]
    } err]} {
        SafeLog "Error getting offpage coordinates: $err"
    }    

    SafeDeleteCPoint lUpperLeft
    SafeDeleteCPoint lLocation
    SafeDeleteCRect lRect

    return $result
}

proc getOffPageName {lOffPage} {
    set nameCStr ""
    set result ""
    
    if {[catch {
        set nameCStr [DboTclHelper_sMakeCString]
        $lOffPage GetName $nameCStr
        set result [DboTclHelper_sGetConstCharPtr $nameCStr]
    } err]} {
        SafeLog "Error getting offpage name: $err"
        set result ""
    }
    
    SafeDeleteCString nameCStr
    return $result
}

proc readStructuredCsvFile {csvFile} {
    set data {}
    if {![file exists $csvFile]} {
        SafeLog "ERROR: File not found: $csvFile"
        return $data
    }
    
    set fp ""
    if {[catch {
        set fp [open $csvFile r]
        gets $fp ;# Skip header
        
        while {[gets $fp line] >= 0} {
            set cleanLine [string map {\" {}} [string trim $line]]
            set fields [split $cleanLine ","]
            
            # Process groups of 3 columns (X,Y,Name) separated by empty columns
            for {set i 0} {$i < [llength $fields]} {incr i 4} {
                if {$i + 2 < [llength $fields]} {
                    set x [string trim [lindex $fields $i]]
                    set y [string trim [lindex $fields [expr $i+1]]]
                    set name [string trim [lindex $fields [expr $i+2]]]
                    
                    if {[string is integer -strict $x] && [string is integer -strict $y] && $name ne ""} {
                        lappend data [list $x $y $name]
                    }
                }
            }
        }
    } error]} {
        SafeLog "Error reading CSV file: $error"
    }
    
    if {$fp != ""} {
        catch {close $fp}
    }

    SafeLog "Loaded [llength $data] valid coordinate records"
    return $data
}

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

proc replaceOffPageNamesByCoordinates {csvFile} {
    SafeLog "Script started"

    set lSession $::DboSession_s_pDboSession
    if {$lSession == ""} {
        SafeLog "ERROR: No DboSession available"
        return false
    }
    
    DboSession -this $lSession
    set lStatus [DboState]
    set lNullObj NULL
    set result true
    set lOffPagesIter ""

    # Get active page with error handling
    set lPage ""
    if {[catch {set lPage [GetActivePage]} err]} {
        SafeLog "ERROR: Failed to get active page: $err"
        return false
    }
    
    if {$lPage == $lNullObj} {
        SafeLog "ERROR: No active page found!"
        return false
    }

    SafeLog "Active page obtained successfully"

    # Read CSV data
    SafeLog "Reading CSV file $csvFile..."
    set coordData [readStructuredCsvFile $csvFile]
    if {[llength $coordData] == 0} {
        SafeLog "ERROR: No valid data loaded from CSV!"
        return false
    }
    
    SafeLog "Loaded [llength $coordData] coordinate records from CSV"

    # Create iterator with error handling
    if {[catch {
        set lOffPagesIter [$lPage NewOffPageConnectorsIter $lStatus $::IterDefs_ALL]
    } err]} {
        SafeLog "ERROR: Failed to create OffPage iterator: $err"
        return false
    }

    set renamedCount 0
    set lOffPage [$lOffPagesIter NextOffPageConnector $lStatus]
    
    # Process each off-page connector
    while {$lOffPage != $lNullObj} {
        set newNameCStr ""
        if {[catch {
            # Calculate absolute coordinates
            set coords [getOffPageAbsoluteCoords $lOffPage $lStatus]
            set tX [lindex $coords 0]
            set tY [lindex $coords 1]
            
            # Get current name
            set currentName [getOffPageName $lOffPage]
            
            if {$currentName == ""} {
                SafeLog "Warning: Empty name for connector at X=$tX, Y=$tY"
                set lOffPage [$lOffPagesIter NextOffPageConnector $lStatus]
                continue
            }
            
            # Find matching coordinate in CSV data
            foreach record $coordData {
                set csvX [lindex $record 0]
                set csvY [lindex $record 1]
                set newName [lindex $record 2]
                
                # Use exact coordinate matching
                if {$tX == $csvX && $tY == $csvY && $newName != $currentName} {
                    # Set new name
                    set newNameCStr [DboTclHelper_sMakeCString $newName]
                    $lOffPage SetName $newNameCStr
                    
                    # Optimize text position
                    optimizeTextPosition $lOffPage $lStatus
                    
                    SafeLog "Renamed connector at X=$tX, Y=$tY from '$currentName' to '$newName'"
                    incr renamedCount
                    break
                }
            }
        } err]} {
            SafeLog "Error processing offpage connector: $err"
        }
        
        SafeDeleteCString newNameCStr
        set lOffPage [$lOffPagesIter NextOffPageConnector $lStatus]
    }

    # Cleanup
    SafeDeleteIter lOffPagesIter
    # NOTE: lStatus is a system object - do NOT delete it!

    SafeLog "SUMMARY: Successfully renamed $renamedCount offpage connectors"
    
    if {$renamedCount > 0} {
        catch {$lPage MarkModified}
        catch {UnSelectAll}
        catch {ZoomIn}
        catch {ZoomOut}
    }
    
    SafeLog "Script done!"
    return true
}

if {[info exists ::path_to_csv_file]} {
    set scriptDir [file dirname [info script]]
    replaceOffPageNamesByCoordinates $::path_to_csv_file
} else {
    SafeLog "ERROR: Global variable path_to_csv_file not set!"
}