# 02.10.2025
# Improved script to copy coordinates and names of offPages to CSV file

proc compareCoordinates {a b} {
    # Compare by X coordinate (index 0), then by Y coordinate (index 1)
    set aX [lindex $a 0]
    set bX [lindex $b 0]
    
    if {$aX < $bX} {
        return -1
    } elseif {$aX > $bX} {
        return 1
    }
    
    # If X coordinates are equal, compare by Y
    set aY [lindex $a 1]
    set bY [lindex $b 1]
    if {$aY < $bY} {
        return -1
    } elseif {$aY > $bY} {
        return 1
    }
    
    return 0
}

proc compareByY {a b} {
    # Compare by Y coordinate only
    set aY [lindex $a 1]
    set bY [lindex $b 1]
    if {$aY < $bY} {
        return -1
    } elseif {$aY > $bY} {
        return 1
    }
    return 0
}

proc exportActivePageOffPages {csvFile} {
    puts "Starting export script"

    set lSession $::DboSession_s_pDboSession
    DboSession -this $lSession
    set lStatus [DboState]
    set lNullObj NULL
    
    set lPage [GetActivePage]
    if {$lPage == $lNullObj} {
        puts "ERROR: No active page found!"
        return -1
    }

    # Collect all off-page connector data
    set offPageDataList [collectOffPageData $lPage $lStatus]
    
    if {[llength $offPageDataList] == 0} {
        puts "No off-page connectors found on the active page"
        return 0
    }

    # Sort data by coordinates (X then Y)
    set sortedData [lsort -command compareCoordinates $offPageDataList]
    
    # Group by X coordinate (difference <= 50) and sort each group by Y
    set groupedData [groupAndSortByXCoordinate $sortedData 50]
    
    # Export to CSV
    exportToCsv $csvFile $groupedData
    
    puts "Export completed. [llength $offPageDataList] connectors saved in $csvFile"
    return [llength $offPageDataList]
}

proc collectOffPageData {lPage lStatus} {
    set offPageDataList []
    set lOffPagesIter [$lPage NewOffPageConnectorsIter $lStatus $::IterDefs_ALL]
    set lNullObj NULL

    set lOffPage [$lOffPagesIter NextOffPageConnector $lStatus]
    while {$lOffPage != $lNullObj} {
        # Get absolute coordinates
        set coords [getOffPageAbsoluteCoords $lOffPage $lStatus]
        set tX [lindex $coords 0]
        set tY [lindex $coords 1]
        
        # Get name
        set name [getOffPageName $lOffPage]
        
        # Store data
        lappend offPageDataList [list $tX $tY $name]
        
        set lOffPage [$lOffPagesIter NextOffPageConnector $lStatus]
    }
    
    delete_DboPageOffPageConnectorsIter $lOffPagesIter
    return $offPageDataList
}

proc getOffPageAbsoluteCoords {lOffPage lStatus} {
    set lRect [$lOffPage GetBoundingBox]
    set lUpperLeft [DboTclHelper_sGetCRectTopLeft $lRect]
    set lrelX [DboTclHelper_sGetCPointX $lUpperLeft]
    set lrelY [DboTclHelper_sGetCPointY $lUpperLeft]
    
    set lLocation [$lOffPage GetLocation $lStatus]
    set X [DboTclHelper_sGetCPointX $lLocation]
    set Y [DboTclHelper_sGetCPointY $lLocation]
    
    return [list [expr $X + $lrelX] [expr $Y + $lrelY]]
}

proc getOffPageName {lOffPage} {
    set nameCStr [DboTclHelper_sMakeCString]
    $lOffPage GetName $nameCStr
    return [DboTclHelper_sGetConstCharPtr $nameCStr]
}

proc groupAndSortByXCoordinate {sortedData maxXDifference} {
    set groups {}
    set currentGroup {}
    set lastX -10000
    
    foreach item $sortedData {
        set currentX [lindex $item 0]
        
        if {[llength $currentGroup] == 0 || ($currentX - $lastX) <= $maxXDifference} {
            lappend currentGroup $item
        } else {
            # Sort current group by Y coordinate before adding to groups
            set sortedGroup [lsort -command compareByY $currentGroup]
            lappend groups $sortedGroup
            set currentGroup [list $item]
        }
        set lastX $currentX
    }
    
    # Add the last group after sorting by Y
    if {[llength $currentGroup] > 0} {
        set sortedGroup [lsort -command compareByY $currentGroup]
        lappend groups $sortedGroup
    }
    
    puts "Created [llength $groups] groups, each sorted by Y coordinate"
    return $groups
}

proc exportToCsv {csvFile groups} {
    set outFile [open $csvFile w]
    
    # Write header with empty columns between groups
    set header ""
    for {set i 0} {$i < [llength $groups]} {incr i} {
        append header "X$i,Y$i,Name$i,,"
    }
    puts $outFile [string trimright $header ","]
    
    # Find maximum number of items in any group
    set maxItems 0
    foreach group $groups {
        if {[llength $group] > $maxItems} {
            set maxItems [llength $group]
        }
    }
    
    # Write data rows with empty columns between groups
    for {set rowIndex 0} {$rowIndex < $maxItems} {incr rowIndex} {
        set row ""
        foreach group $groups {
            if {$rowIndex < [llength $group]} {
                set item [lindex $group $rowIndex]
                append row "[lindex $item 0],[lindex $item 1],[lindex $item 2],,"
            } else {
                append row ",,,,"
            }
        }
        puts $outFile [string trimright $row ","]
    }
    
    close $outFile
    puts "Exported [llength $groups] groups with [llength $groups] empty separator columns"
}

# Example execution
exportActivePageOffPages D:/py/ORCAD/offpage.csv
