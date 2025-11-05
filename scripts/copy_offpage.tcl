# RIGa&Grok 03.11.2025
# Script to export off-page connector coordinates and names to CSV
# Groups connectors by X (delta <= 50), sorts within group by Y
# Output: X0,Y0,Name0,,X1,Y1,Name1,,... with empty columns between groups

set DELTA_X 50

# Compare two items: first by X, then by Y
proc compareCoordinates {a b} {
    set aX [lindex $a 0]
    set bX [lindex $b 0]
    
    if {$aX < $bX} { return -1 }
    if {$aX > $bX} { return 1 }
    
    set aY [lindex $a 1]
    set bY [lindex $b 1]
    if {$aY < $bY} { return -1 }
    if {$aY > $bY} { return 1 }
    return 0
}

# Compare two items by Y coordinate only
proc compareByY {a b} {
    set aY [lindex $a 1]
    set bY [lindex $b 1]
    if {$aY < $bY} { return -1 }
    if {$aY > $bY} { return 1 }
    return 0
}

# Collect all off-page connectors from the given page
proc collectOffPageData {lPage lStatus} {
    set offPageDataList []
    set lOffPagesIter NULL
    set lNullObj NULL

    # Create iterator safely
    if {[catch {
        set lOffPagesIter [$lPage NewOffPageConnectorsIter $lStatus $::IterDefs_ALL]
    } err]} {
        SafeLog "ERROR: Failed to create OffPage iterator: $err"
        return {}
    }

    # Iterate through all off-page connectors
    set lOffPage [$lOffPagesIter NextOffPageConnector $lStatus]
    while {$lOffPage != $lNullObj} {
        set coords [getOffPageAbsoluteCoords $lOffPage $lStatus]
        set tX [lindex $coords 0]
        set tY [lindex $coords 1]
        set name [getOffPageName $lOffPage]
        lappend offPageDataList [list $tX $tY $name]
        set lOffPage [$lOffPagesIter NextOffPageConnector $lStatus]
    }
    
    # Always delete iterator to prevent memory leak
    catch { delete_DboPageOffPageConnectorsIter $lOffPagesIter }
    return $offPageDataList
}

# Get absolute coordinates (location + bounding box offset)
proc getOffPageAbsoluteCoords {lOffPage lStatus} {
    set lRect [$lOffPage GetBoundingBox]
    set lUpperLeft NULL
    set lLocation NULL
    set result {0 0}
        
    if {[catch {
        set lUpperLeft [DboTclHelper_sGetCRectTopLeft $lRect]
        set lrelX [DboTclHelper_sGetCPointX $lUpperLeft]
        set lrelY [DboTclHelper_sGetCPointY $lUpperLeft]
        
        set lLocation [$lOffPage GetLocation $lStatus]
        set X [DboTclHelper_sGetCPointX $lLocation]
        set Y [DboTclHelper_sGetCPointY $lLocation]
        
        set result [list [expr {$X + $lrelX}] [expr {$Y + $lrelY}]]
    } err]} {
        SafeLog "ERROR: Failed to get absolute coordinates: $err"
    }

    # Clean up C++ objects even if error occurred
    catch { DboTclHelper_sDeleteCPoint $lUpperLeft }
    catch { DboTclHelper_sDeleteCPoint $lLocation }
    catch { DboTclHelper_sDeleteCRect $lRect }    
    return $result
}

# Get connector name as Tcl string
proc getOffPageName {lOffPage} {
    set nameCStr [DboTclHelper_sMakeCString]
    set result ""
    
    if {[catch {
        $lOffPage GetName $nameCStr
        set result [DboTclHelper_sGetConstCharPtr $nameCStr]
    } err]} {
        SafeLog "ERROR in getOffPageName: $err"
    }
    
    catch { DboTclHelper_sDeleteCString $nameCStr }
    return $result
}

# Group connectors by X coordinate (max difference = maxXDifference)
# Each group is sorted by Y
proc groupAndSortByXCoordinate {sortedData maxXDifference} {
    set groups {}
    set currentGroup {}
    set lastX -10000
    
    foreach item $sortedData {
        set currentX [lindex $item 0]
        
        # Start new group if X difference exceeds threshold
        if {[llength $currentGroup] == 0 || ($currentX - $lastX) <= $maxXDifference} {
            lappend currentGroup $item
        } else {
            set sortedGroup [lsort -command compareByY $currentGroup]
            lappend groups $sortedGroup
            set currentGroup [list $item]
        }
        set lastX $currentX
    }
    
    # Add the final group
    if {[llength $currentGroup] > 0} {
        set sortedGroup [lsort -command compareByY $currentGroup]
        lappend groups $sortedGroup
    }
    
    SafeLog "Created [llength $groups] groups, each sorted by Y"
    return $groups
}

# Export grouped data to CSV with empty columns between groups
proc exportToCsv {csvFile groups} {
    # Open file safely
    if {[catch { set outFile [open $csvFile w] } err]} {
        SafeLog "ERROR: Cannot open CSV file for writing: $csvFile - $err"
        return
    }
    
    # Build header: X0,Y0,Name0,,X1,Y1,Name1,,...
    set header ""
    for {set i 0} {$i < [llength $groups]} {incr i} {
        append header "X$i,Y$i,Name$i,,"
    }
    
    # Find maximum number of rows in any group
    set maxItems 0
    foreach group $groups {
        if {[llength $group] > $maxItems} {
            set maxItems [llength $group]
        }
    }
    
    # Write CSV safely
    if {[catch {
        puts $outFile [string trimright $header ","]
        
        for {set rowIndex 0} {$rowIndex < $maxItems} {incr rowIndex} {
            set row ""
            foreach group $groups {
                if {$rowIndex < [llength $group]} {
                    set item [lindex $group $rowIndex]
                    append row "[lindex $item 0],[lindex $item 1],[lindex $item 2],,"
                } else {
                    append row ",,,,"  ;# Empty X,Y,Name + separator
                }
            }
            puts $outFile [string trimright $row ","]
        }
        close $outFile
    } err]} {
        SafeLog "ERROR during CSV write: $err"
        catch { close $outFile }
    } else {
        SafeLog "CSV exported: [llength $groups] groups, max $maxItems rows"
    }
}

# Safe logging with timestamp and file output
proc SafeLog {message} {
    global scriptDir
    if {![info exists scriptDir]} {
        set scriptDir [pwd]
    }
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

# Main export function
proc exportActivePageOffPages {csvFile} {
    global DELTA_X
    SafeLog "Script started"

    set lSession $::DboSession_s_pDboSession
    DboSession -this $lSession
    set lStatus [DboState]
    set lNullObj NULL
    
    # Get active page
    set lPage [GetActivePage]
    if {$lPage == $lNullObj} {
        SafeLog "ERROR: No active page found!"
        return
    }
    
    # Collect data
    set offPageDataList [collectOffPageData $lPage $lStatus]
    if {[llength $offPageDataList] == 0} {
        SafeLog "No off-page connectors found on the active page"
        return
    }
    
    # Sort, group, export
    set sortedData [lsort -command compareCoordinates $offPageDataList]
    set groupedData [groupAndSortByXCoordinate $sortedData $DELTA_X]
    exportToCsv $csvFile $groupedData
    
    SafeLog "Export completed: [llength $offPageDataList] connectors → $csvFile"
    SafeLog "Script done!"
}

# Entry point
if {[info exists ::path_to_csv_file]} {
    set scriptDir [file dirname [info script]]
    exportActivePageOffPages $::path_to_csv_file
} else {
    SafeLog "ERROR: Global variable ::path_to_csv_file not set"
}