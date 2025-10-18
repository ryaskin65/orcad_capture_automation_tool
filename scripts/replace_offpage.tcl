# 2025.10.18
# Script to replace names of offPages for OrCAD Capture with text positioning

################################################################################
proc optimizeTextPosition {lOffPage lStatus} {
    # Get current location
    set lLocation [$lOffPage GetLocation $lStatus]
    set currentX [DboTclHelper_sGetCPointX $lLocation]
    set currentY [DboTclHelper_sGetCPointY $lLocation]
    
    # Get text name to estimate length
    set nameCStr [DboTclHelper_sMakeCString]
    $lOffPage GetName $nameCStr
    set textName [DboTclHelper_sGetConstCharPtr $nameCStr]
    
    # Simple text positioning based on current location
    # Move text slightly to avoid overlap with symbol
    set textLength [string length $textName]
    
    # Use fixed offsets based on text length
    if {$textLength <= 4} {
        set offsetX 60
    } elseif {$textLength <= 8} {
        set offsetX 80
    } else {
        set offsetX 100
    }
    
    # Create new position with offset
    set newX [expr $currentX + $offsetX]
    set newY [expr $currentY - 10] ;# Small vertical adjustment
    
    # Set new location - use correct method signature
    # For off-page connectors, we may need to use Move method instead of SetLocation
    set newLocation [DboTclHelper_sMakeCPoint $newX $newY]
#    $lOffPage Move $newLocation $lStatus
    
    # Alternative approach if Move doesn't work - use SetLocation with correct arguments
    # $lOffPage SetLocation $newX $newY $lStatus
    
    # Force update
    $lOffPage SetBoundingBoxDirty 1
}

proc _optimizeTextPosition {lOffPage lStatus newName} {
    # Get current text properties
    set nameCStr [DboTclHelper_sMakeCString]
    $lOffPage GetName $nameCStr
    set currentName [DboTclHelper_sGetConstCharPtr $nameCStr]
    
    # Calculate offset based on text length difference
    set currentLength [string length $currentName]
    set newLength [string length $newName]
    set lengthDiff [expr $newLength - $currentLength]
    
    # Adjust horizontal offset based on text length change
    if {$lengthDiff < -2} {
        # New text is much shorter - move text closer
        set offsetX -20
    } elseif {$lengthDiff > 2} {
        # New text is much longer - move text further
        set offsetX 20
    } else {
        # Similar length - keep current position
        set offsetX 0
    }
    
    if {$offsetX != 0} {
        # Get current text location and apply offset
        set textLocation [$lOffPage GetNameLocation]
        set currentX [DboTclHelper_sGetCPointX $textLocation]
        set currentY [DboTclHelper_sGetCPointY $textLocation]
        
        set newX [expr $currentX + $offsetX]
        set newLocation [DboTclHelper_sMakeCPoint $newX $currentY]
        
        # Set new text location
        $lOffPage SetNameLocation $newLocation
    }
}

################################################################################
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

################################################################################
proc getOffPageName {lOffPage} {
    set nameCStr [DboTclHelper_sMakeCString]
    $lOffPage GetName $nameCStr
    return [DboTclHelper_sGetConstCharPtr $nameCStr]
}

################################################################################
proc readStructuredCsvFile {csvFile} {
    set data []
    if {![file exists $csvFile]} {
        puts "ERROR: File not found: $csvFile"
        return $data
    }
    
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
    close $fp
    
    puts "Loaded [llength $data] valid coordinate records"
    return $data
}

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

################################################################################
proc replaceOffPageNamesByCoordinates {csvFile} {
	SafeLog "Script started"

    set lSession $::DboSession_s_pDboSession
    DboSession -this $lSession
    set lStatus [DboState]
    set lNullObj NULL

    puts "Get active page."
    set lPage [GetActivePage]
    if {$lPage == $lNullObj} {
        puts "ERROR: No active page found!"
        return -1
    }

    # Read CSV data with improved parser
    puts "Reading CSV file $csvFile..."
    set coordData [readStructuredCsvFile $csvFile]
    if {[llength $coordData] == 0} {
        puts "ERROR: No valid data loaded from CSV!"
        return -1
    }
    puts "Loaded [llength $coordData] coordinate records from CSV"
    
    set lOffPagesIter [$lPage NewOffPageConnectorsIter $lStatus $::IterDefs_ALL]
    set renamedCount 0
    
    # Process each off-page connector
    set lOffPage [$lOffPagesIter NextOffPageConnector $lStatus]
    while {$lOffPage != $lNullObj} {
        # Calculate absolute coordinates
        set coords [getOffPageAbsoluteCoords $lOffPage $lStatus]
        set tX [lindex $coords 0]
        set tY [lindex $coords 1]
        
        # Get current name
        set currentName [getOffPageName $lOffPage]
        
        # Find matching coordinate in CSV data
        foreach record $coordData {
            set csvX [lindex $record 0]
            set csvY [lindex $record 1]
            set newName [lindex $record 2]
            
            if {$tX == $csvX && $tY == $csvY && $newName != $currentName} {
                # Set new name and optimize text position
                set newNameCStr [DboTclHelper_sMakeCString $newName]
                $lOffPage SetName $newNameCStr
                
                # Optimize text position relative to graphic symbol
                optimizeTextPosition $lOffPage $lStatus
                
                puts "Renamed connector at X=$tX, Y=$tY from '$currentName' to '$newName'"
                incr renamedCount
                break
            }
        }
        
        set lOffPage [$lOffPagesIter NextOffPageConnector $lStatus]
    }
    delete_DboPageOffPageConnectorsIter $lOffPagesIter

    if {$renamedCount > 0} {
        $lPage MarkModified
        UnSelectAll
		ZoomIn
		ZoomOut
    }
    puts "\nSUMMARY: Successfully renamed $renamedCount offpage connectors"
	SafeLog "Script done!"
}

################################################################################
if {[info exists ::path_to_csv_file]} {
	replaceOffPageNamesByCoordinates $::path_to_csv_file
} else {
	puts "ERROR: Global variables path_to_csv_file not set!"
}
