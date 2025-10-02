# 02.10.2025
# The script to copy coordinates and names of offPages on the page in the CSV file
# CSV format: X, Y, NAME in groups with coordinate Xmax-Xmin <= 50

proc compareByTwoIndices {a b} {
    # Extract elements by index 0
    set a0 [lindex $a 0]
    set b0 [lindex $b 0]
    # Compare by first index
    if {$a0 < $b0} {
        return -1
    } elseif {$a0 > $b0} {
        return 1
    }
    # If the first indices are equal, compare by the second index
    set a1 [lindex $a 1]
    set b1 [lindex $b 1]
    if {$a1 < $b1} {
        return -1
    } elseif {$a1 > $b1} {
        return 1
    }
    return 0
}

proc compareByY {a b} {
    # Compare by Y coordinate (index 1)
    set a1 [lindex $a 1]
    set b1 [lindex $b 1]
    if {$a1 < $b1} {
        return -1
    } elseif {$a1 > $b1} {
        return 1
    }
    return 0
}

proc exportActivePageOffPages {csvFile} {
    puts "Starting script"

    set lSession $::DboSession_s_pDboSession
    DboSession -this $lSession
    set lStatus [DboState]
    set lNullObj NULL
    set lPage [GetActivePage]
    if {$lPage == $lNullObj} {
        puts "ERROR: No active page found!"
        return -1
    }

    set lOffPagesIter [$lPage NewOffPageConnectorsIter $lStatus $::IterDefs_ALL]

    # Create a list to store all off-page connector data
    set offPageDataList []

    # Get the first off-page of the page
    set lOffPage [$lOffPagesIter NextOffPageConnector $lStatus]
    while {$lOffPage != $lNullObj} {
        set lRect [$lOffPage GetBoundingBox]
        set lUpperLeft [DboTclHelper_sGetCRectTopLeft $lRect]
        set lrelX [DboTclHelper_sGetCPointX $lUpperLeft]
        set lrelY [DboTclHelper_sGetCPointY $lUpperLeft]

        set nameCStr [DboTclHelper_sMakeCString]
        $lOffPage GetName $nameCStr
        set lName [DboTclHelper_sGetConstCharPtr $nameCStr]

        # Get the location
        set lLocation [$lOffPage GetLocation $lStatus]
        set X [DboTclHelper_sGetCPointX $lLocation]
        set Y [DboTclHelper_sGetCPointY $lLocation]
        set tX [expr $X + $lrelX]
        set tY [expr $Y + $lrelY]
        
        # Store data as a list element
        lappend offPageDataList [list $tX $tY $lName]
        
        # Get the next off-page of the page
        set lOffPage [$lOffPagesIter NextOffPageConnector $lStatus]
    }
    delete_DboPageOffPageConnectorsIter $lOffPagesIter

    # Sort the data by X coordinate
    set sortedData [lsort -command compareByTwoIndices $offPageDataList]

    # Group data by X coordinate (difference <= 50)
    set groups {}
    set currentGroup {}
    set lastX -1000
    foreach item $sortedData {
        set x [lindex $item 0]
        if {$currentGroup == {} || ($x - $lastX) <= 50} {
            lappend currentGroup $item
        } else {
            # Sort the current group by Y coordinate
            set sortedGroup [lsort -command compareByY $currentGroup]
            lappend groups $sortedGroup
            set currentGroup [list $item]
        }
        set lastX $x
    }
    # Append the last group if it exists
    if {$currentGroup != {}} {
        set sortedGroup [lsort -command compareByY $currentGroup]
        lappend groups $sortedGroup
    }

    # Write to CSV file with groups separated by empty columns
    set outFile [open $csvFile w]
    # Write header
    set header ""
    for {set i 0} {$i < [llength $groups]} {incr i} {
        append header "X$i,Y$i,Name$i,,"
    }
    puts $outFile [string trimright $header ","]

    # Find the maximum number of items in any group
    set maxItems 0
    foreach group $groups {
        if {[llength $group] > $maxItems} {
            set maxItems [llength $group]
        }
    }

    # Write data rows
    for {set i 0} {$i < $maxItems} {incr i} {
        set row ""
        foreach group $groups {
            if {$i < [llength $group]} {
                set item [lindex $group $i]
                set x [lindex $item 0]
                set y [lindex $item 1]
                set name [lindex $item 2]
                append row "$x,$y,$name,,"
            } else {
                # Add empty cells for X, Y, Name, and separator
                append row ",,,,"
            }
        }
        puts $outFile [string trimright $row ","]
    }

    close $outFile
    puts "Export completed. Data saved in $csvFile"
}

# Example execution
exportActivePageOffPages D:/py/ORCAD/offpage.csv
