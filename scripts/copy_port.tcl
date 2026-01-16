# RIGa&AI 16.01.2026
# Script to export port page, coordinates and names to CSV
# Groups ports by X (delta <= 50), sorts within group by Y
# Output: Page,X0,Y0,Name0,,X1,Y1,Name1,,... with empty columns between groups

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

# Collect all ports from the given page
proc collectPortData {lPage lStatus} {
    set portDataList []
    set lPortsIter NULL
    set lNullObj NULL

    # Create iterator safely
    if {[catch {
        set lPortsIter [$lPage NewPortsIter $lStatus $::IterDefs_ALL]
    } err]} {
        SafeLog "ERROR: Failed to create Port iterator: $err"
        return {}
    }

    # Iterate through all ports
    set lPort [$lPortsIter NextPort $lStatus]
    while {$lPort != $lNullObj} {
        set coords [getPortAbsoluteCoords $lPort $lStatus]
        set tX [lindex $coords 0]
        set tY [lindex $coords 1]
        set name [getPortName $lPort]
        lappend portDataList [list $tX $tY $name]
        set lPort [$lPortsIter NextPort $lStatus]
    }

    # Always delete iterator to prevent memory leak
    catch { delete_DboPagePortsIter $lPortsIter }
    return $portDataList
}

# Get absolute coordinates (location + bounding box offset)
proc getPortAbsoluteCoords {lPort lStatus} {
    set lRect [$lPort GetBoundingBox]
    set lUpperLeft NULL
    set lLocation NULL
    set result {0 0}

    if {[catch {
        set lUpperLeft [DboTclHelper_sGetCRectTopLeft $lRect]
        set lrelX [DboTclHelper_sGetCPointX $lUpperLeft]
        set lrelY [DboTclHelper_sGetCPointY $lUpperLeft]

        set lLocation [$lPort GetLocation $lStatus]
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

# Get port name as Tcl string
proc getPortName {lPort} {
    set nameCStr [DboTclHelper_sMakeCString]
    set result ""

    if {[catch {
        $lPort GetName $nameCStr
        set result [DboTclHelper_sGetConstCharPtr $nameCStr]
    } err]} {
        SafeLog "ERROR in getPortName: $err"
    }

    catch { DboTclHelper_sDeleteCString $nameCStr }
    return $result
}

# Group ports by X coordinate (max difference = maxXDifference)
# Each group is sorted by Y
proc groupAndSortByXCoordinate {sortedData maxXDifference} {
    set groups {}
    set currentGroup {}
    set lastX -10000

    foreach item $sortedData {
        set currentX [lindex $item 0]

        # Start new group if X difference exceeds threshold
        if {[llength $currentGroup] == 0 || abs($currentX - $lastX) <= $maxXDifference} {
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

    SafeLog "Created [llength $groups] groups"
    return $groups
}

# Export grouped data to CSV with empty columns between groups
proc exportToCsv {csvFile groups pName} {
    # Open file safely
    if {[catch { set outFile [open $csvFile a] } err]} {
        SafeLog "ERROR: Cannot open CSV file for writing: $csvFile - $err"
        return
    }

    # Write page name
    if {$pName ne "" && [string length $pName] > 0} {
        puts $outFile "\n>>> PAGE: $pName\n"
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
        SafeLog "CSV exported: [llength $groups] groups, $maxItems rows"
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

# Main export function for single page
proc processSinglePage {lPage csvFile lStatus pName} {
    global DELTA_X

    # Collect data
    set portDataList [collectPortData $lPage $lStatus]
    if {[llength $portDataList] == 0} {
        SafeLog "No Ports found on page $pName"
        return
    }

    # Sort, group, export
    set sortedData [lsort -command compareCoordinates $portDataList]
    set groupedData [groupAndSortByXCoordinate $sortedData $DELTA_X]
    exportToCsv $csvFile $groupedData $pName
}

# Get page name
proc getPageName {lPage} {
    set pNameStr [DboTclHelper_sMakeCString]
    set result ""
    if {[catch {
        $lPage GetName $pNameStr
        set result [DboTclHelper_sGetConstCharPtr $pNameStr]
    } err]} {
        SafeLog "ERROR getting page name: $err"
    }
    catch { DboTclHelper_sDeleteCString $pNameStr }
    return $result
}

# Entry Point update
if {![info exists ::path_to_csv_file]} {
    SafeLog "ERROR: Global variable ::path_to_csv_file not set"
} else {
    set csvFile $::path_to_csv_file
    set scriptDir [file dirname [info script]]

    # Delete the file if it already exists to start fresh
    if {[file exists $csvFile]} {
        if {[catch {file delete -force $csvFile} err]} {
            SafeLog "WARNING: Could not delete file $csvFile: $err"
        }
    }
    SafeLog "Script started"

    set lSession $::DboSession_s_pDboSession
    DboSession -this $lSession
    set lStatus [DboState]
    set lNullObj NULL

    if {[info exists ::EXPORT_SCOPE] && $::EXPORT_SCOPE == "ALL"} {

        set lDesign [$lSession GetActiveDesign]

        # Use Views iterator for this version (Type 9 = Schematic)
        set lViewsIter [$lDesign NewViewsIter $lStatus]
        set lView [$lViewsIter NextView $lStatus]

        while {$lView != $lNullObj} {
            # Verify if it is a Schematic (Type 9) before processing
            if {[$lView GetObjectType] == $::DboBaseObject_SCHEMATIC} {

                # TYPE CASTING: convert View to Schematic to access pages
                set lSchematic [DboViewToDboSchematic $lView]

                set lPageIter [$lSchematic NewPagesIter $lStatus]
                set lPage [$lPageIter NextPage $lStatus]

                while {$lPage != $lNullObj} {

                    set pName [getPageName $lPage]
                    SafeLog ">>> PAGE: $pName"

                    # Process page data
                    processSinglePage $lPage $csvFile $lStatus $pName

                    set lPage [$lPageIter NextPage $lStatus]
                }

                # Clean up pages iterator
                delete_DboSchematicPagesIter $lPageIter
            }

            # Move to the next schematic (View)
            set lView [$lViewsIter NextView $lStatus]
        }

        # Clean up schematics iterator
        delete_DboLibViewsIter $lViewsIter

    } elseif {[info exists ::EXPORT_SCOPE] && $::EXPORT_SCOPE == "PAGE"} {

        # Get active page
        set lPage [GetActivePage]
        if {$lPage == $lNullObj} {
            SafeLog "ERROR: No active page found!"
        } else {
            set pName [getPageName $lPage]
            SafeLog ">>> PAGE: $pName"
            processSinglePage $lPage $csvFile $lStatus $pName
        }
    }
    SafeLog "Export completed to $csvFile"
    SafeLog "Script done!"
}

