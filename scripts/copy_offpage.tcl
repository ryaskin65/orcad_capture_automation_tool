# RIGa&Grok 02.11.2025
# Script to copy coordinates and names of offPages to CSV file

set DELTA_X 50

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
        SafeLog "ERROR: Error getting rectangle coordinates: $err"
    }

    catch { DboTclHelper_sDeleteCPoint $lUpperLeft }
    catch { DboTclHelper_sDeleteCPoint $lLocation }
    catch { DboTclHelper_sDeleteCRect $lRect }    

    return $result
}

proc getOffPageName {lOffPage} {
    set nameCStr [DboTclHelper_sMakeCString]
    set result ""
    
    if {[catch {
        $lOffPage GetName $nameCStr
        set result [DboTclHelper_sGetConstCharPtr $nameCStr]
    } err]} {
        SafeLog "ERROR in getOffPageName: $err"
        set result ""
    }
    
    catch { DboTclHelper_sDeleteCString $nameCStr }
    return $result
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
            # Sort current group by Y before adding
            set sortedGroup [lsort -command compareByY $currentGroup]
            lappend groups $sortedGroup
            set currentGroup [list $item]
        }
        set lastX $currentX
    }
    
    # Add last group
    if {[llength $currentGroup] > 0} {
        set sortedGroup [lsort -command compareByY $currentGroup]
        lappend groups $sortedGroup
    }
    
    SafeLog "Created [llength $groups] groups, each sorted by Y"
    return $groups
}

proc exportToCsv {csvFile groups} {
    if {[catch {
        set outFile [open $csvFile w]
    } err]} {
        SafeLog "ERROR: Cannot open csv file for writing: $csvFile - $err"
        return
    }
    
    # Write header: X0,Y0,Name0,,X1,Y1,Name1,,...
    set header ""
    for {set i 0} {$i < [llength $groups]} {incr i} {
        append header "X$i,Y$i,Name$i,,"
    }
    set maxItems 0
    if {[catch {
        puts $outFile [string trimright $header ","]
        
        # Find max rows in any group
        foreach group $groups {
            if {[llength $group] > $maxItems} {
                set maxItems [llength $group]
            }
        }
        
        # Write data rows
        for {set rowIndex 0} {$rowIndex < $maxItems} {incr rowIndex} {
            set row ""
            foreach group $groups {
                if {$rowIndex < [llength $group]} {
                    set item [lindex $group $rowIndex]
                    append row "[lindex $item 0],[lindex $item 1],[lindex $item 2],,"
                } else {
                    append row ",,,,"  ;# X,Y,Name + separator
                }
            }
            puts $outFile [string trimright $row ","]
        }
        
        close $outFile
    } err]} {
        SafeLog "ERROR during CSV export: $err"
        catch { close $outFile }
        return
    }        
    SafeLog "CSV exported: [llength $groups] groups, max $maxItems rows"
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

proc exportActivePageOffPages {csvFile} {
    global DELTA_X
	SafeLog "Script started"

    set lSession $::DboSession_s_pDboSession
    DboSession -this $lSession
    set lStatus [DboState]
    set lNullObj NULL
    set result true
    
    set lPage [GetActivePage]
    if {$lPage == $lNullObj} {
        SafeLog "ERROR: No active page found!"
        set result false
    }
    if {$result} {
        SafeLog "Active page: $lPage"
        # Collect all off-page connector data
        set offPageDataList [collectOffPageData $lPage $lStatus]
        
        if {[llength $offPageDataList] == 0} {
            SafeLog "No off-page connectors found on the active page"
			set result false
        }
	}
    if {$result} {
        # Sort data by coordinates (X then Y)
        set sortedData [lsort -command compareCoordinates $offPageDataList]
        
        # Group by X (DELTA_X) and sort each group by Y
        set groupedData [groupAndSortByXCoordinate $sortedData $DELTA_X]
        
        # Export to CSV
        exportToCsv $csvFile $groupedData
        SafeLog "Export completed. [llength $offPageDataList] connectors saved in $csvFile"
	    SafeLog "Script done!"
    }
}

if {[info exists ::path_to_csv_file]} {
	# Get the directory where the script is located
	set scriptDir [file dirname [info script]]
	exportActivePageOffPages $::path_to_csv_file
} else {
	SafeLog "ERROR: Global variables path_to_csv_file not set!"
}
