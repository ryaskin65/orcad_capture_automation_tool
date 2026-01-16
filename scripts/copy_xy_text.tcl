# RIGa&AI 16.01.2026
# Text extraction script for OrCAD Capture
# Saves text with coordinates from selected objects to CSV
# Groups by X coordinate (delta <= 50), sorts within group by Y
# Output: X0,Y0,Text0,,X1,Y1,Text1,,... with empty columns between groups

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

# Get absolute coordinates for any placed object - FIXED VERSION
proc getObjectAbsoluteCoords {obj lStatus} {
    set lRect ""
    set lCenter ""
    set result {0 0}
    
    if {[catch {
        # Get bounding box of the object
        set lRect [$obj GetBoundingBox]
        
        # Get center point of the bounding box for absolute position
        set lCenter [DboTclHelper_sGetCRectCenter $lRect]
        set absX [DboTclHelper_sGetCPointX $lCenter]
        set absY [DboTclHelper_sGetCPointY $lCenter]
        
        set result [list $absX $absY]
        
    } err]} {
        SafeLog "Warning: Failed to get absolute coordinates: $err"
        # Fallback: try to get location directly
        if {[catch {
            set lLocation [$obj GetLocation $lStatus]
            set absX [DboTclHelper_sGetCPointX $lLocation]
            set absY [DboTclHelper_sGetCPointY $lLocation]
            set result [list $absX $absY]
            SafeDeleteCPoint lLocation
        } err2]} {
            SafeLog "Error: Fallback coordinate method also failed: $err2"
        }
    }

    SafeDeleteCPoint lCenter
    SafeDeleteCRect lRect
    
    return $result
}

# Alternative method for text objects - get exact text position
proc getTextObjectCoords {obj lStatus} {
    set result {0 0}
    
    if {[catch {
        # For text objects, use GetLocation directly
        set lLocation [$obj GetLocation $lStatus]
        set absX [DboTclHelper_sGetCPointX $lLocation]
        set absY [DboTclHelper_sGetCPointY $lLocation]
        set result [list $absX $absY]
        SafeDeleteCPoint lLocation
    } err]} {
        SafeLog "Warning: Failed to get text coordinates: $err"
    }
    
    return $result
}

# Get text content from different object types
proc getObjectText {obj objType objectTypes lStatus} {
    array set typesArr $objectTypes
    set result ""
    set nameCStr ""
    
    if {[catch {
        if {[info exists typesArr(COMMENT_TEXT)] && $objType == $typesArr(COMMENT_TEXT)} {
            # Graphic Comment Text
            set textInst [DboGraphicInstanceToDboGraphicCommentTextInst $obj]
            set textDef [$textInst GetDboCommentText]
            if {$textDef != "NULL"} {
                set nameCStr [DboTclHelper_sMakeCString]
                $textDef GetText $nameCStr
                set result [DboTclHelper_sGetConstCharPtr $nameCStr]
            }
            
        } elseif {[info exists typesArr(PORT)] && $objType == $typesArr(PORT)} {
            # Port object
            set portInst [DboGraphicInstanceToDboPortInst $obj]
            set nameCStr [DboTclHelper_sMakeCString]
            $portInst GetName $nameCStr
            set result [DboTclHelper_sGetConstCharPtr $nameCStr]
            
        } elseif {[info exists typesArr(PART)] && $objType == $typesArr(PART)} {
            # Part object (RefDes and Value)
            set partInst $obj
            set refDesCStr [DboTclHelper_sMakeCString]
            set valueCStr [DboTclHelper_sMakeCString]
            
            $partInst GetReferenceDesignator $refDesCStr
            set refDes [DboTclHelper_sGetConstCharPtr $refDesCStr]
            
            $partInst GetPartValue $valueCStr
            set value [DboTclHelper_sGetConstCharPtr $valueCStr]
            
            # Combine RefDes and Value
            if {$refDes ne "" && $value ne ""} {
                set result "$refDes ($value)"
            } elseif {$refDes ne ""} {
                set result $refDes
            } else {
                set result $value
            }
            
            SafeDeleteCString refDesCStr
            SafeDeleteCString valueCStr
            
        } elseif {[info exists typesArr(OFFPAGE)] && $objType == $typesArr(OFFPAGE)} {
            # OffPage connector
            set offPageInst $obj
            set nameCStr [DboTclHelper_sMakeCString]
            $offPageInst GetName $nameCStr
            set result [DboTclHelper_sGetConstCharPtr $nameCStr]
            
        } elseif {[info exists typesArr(DISPLAY)] && $objType == $typesArr(DISPLAY)} {
            # Display Property
            set displayInst $obj
            set nameCStr [DboTclHelper_sMakeCString]
            set owner [$displayInst GetParentObj]
            $displayInst GetActualValueString $owner $nameCStr
            set result [DboTclHelper_sGetConstCharPtr $nameCStr]
            
        } elseif {[info exists typesArr(WIRE_SCALAR)] && $objType == $typesArr(WIRE_SCALAR)} {
            # Wire
            set wireInst $obj
            set nameCStr [DboTclHelper_sMakeCString]
            $wireInst GetNetName $nameCStr
            set result [DboTclHelper_sGetConstCharPtr $nameCStr]
            
        } elseif {[info exists typesArr(WIRE_ALIAS)] && $objType == $typesArr(WIRE_ALIAS)} {
            # Wire Alias
            set aliasInst $obj
            set nameCStr [DboTclHelper_sMakeCString]
            $aliasInst GetName $nameCStr
            set result [DboTclHelper_sGetConstCharPtr $nameCStr]
        }
    } err]} {
        SafeLog "Error getting text for object type $objType: $err"
    }
    
    SafeDeleteCString nameCStr
    return $result
}

# Group text data by X coordinate (max difference = maxXDifference)
# Each group is sorted by Y
proc groupAndSortByXCoordinate {sortedData maxXDifference} {
    if {[llength $sortedData] == 0} {
        SafeLog "Warning: No data to group"
        return {}
    }
    
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
    
    # Build header: X0,Y0,Text0,,X1,Y1,Text1,,...
    set header ""
    for {set i 0} {$i < [llength $groups]} {incr i} {
        append header "X$i,Y$i,Text$i,,"
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
                    append row ",,,,"  ;# Empty X,Y,Text + separator
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

# Initialize object types from active page
proc initObjectTypes {activePage lStatus} {
    array set types {}
    set lNullObj NULL
    
    # Declare all iterators for guaranteed cleanup
    set offPageIter ""
    set portIter ""
    set lPartInstsIter ""
    set lPropsIter ""
    set lWiresIter ""
    set lAliasIter ""
    
    # OffPageConnector type (38)
    if {[catch {
        set offPageIter [$activePage NewOffPageConnectorsIter $lStatus]
        set offPageInst [$offPageIter NextOffPageConnector $lStatus]
        if {$offPageInst != $lNullObj} {
            set types(OFFPAGE) [$offPageInst GetObjectType]
        }
    } err]} {
        SafeLog "Warning: Failed to create OffPageConnectors iterator: $err"
    }
    SafeDeleteIter offPageIter DboPageOffPageConnectorsIter

    # Port type (36)
    if {[catch {
        set portIter [$activePage NewPortsIter $lStatus]
        set portInst [$portIter NextPort $lStatus]
        if {$portInst != $lNullObj} {
            set types(PORT) [$portInst GetObjectType]
        }
    } err]} {
        SafeLog "Warning: Failed to create Ports iterator: $err"
    }
    SafeDeleteIter portIter DboPagePortsIter

    # Part type (13)
    set lInst ""
    set lPlacedInst ""
    if {[catch {
        set lPartInstsIter [$activePage NewPartInstsIter $lStatus]
        set lInst [$lPartInstsIter NextPartInst $lStatus]
        if {$lInst != $lNullObj} {
            set lPlacedInst [DboPartInstToDboPlacedInst $lInst]
            if {$lPlacedInst != $lNullObj} {
                set types(PART) [$lPlacedInst GetObjectType]
            }
        }
    } err]} {
        SafeLog "Warning: Failed to process PartInsts: $err"
    }
    SafeDeleteIter lPartInstsIter DboPagePartInstsIter

    # DisplayProperty type (39)
    if {![info exists types(DISPLAY)]} {
        if {[info exists offPageInst] && $offPageInst != $lNullObj} {
            if {[catch {
                set lPropsIter [$offPageInst NewDisplayPropsIter $lStatus]
                set lDProp [$lPropsIter NextProp $lStatus]
                if {$lDProp != $lNullObj} { 
                    set types(DISPLAY) [$lDProp GetObjectType]
                }
            } err]} {
                SafeLog "Warning: Failed to process DisplayProps: $err"
            }
            SafeDeleteIter lPropsIter DboDisplayPropsIter
        }
    }

    # Wire Scalar type (20) and Wire Alias type (49)
    set wireScalarFound false
    set wireAliasFound false
    
    if {[catch {
        set lWiresIter [$activePage NewWiresIter $lStatus]
        set lWire [$lWiresIter NextWire $lStatus]
        
        while {$lWire != $lNullObj && (!$wireScalarFound || !$wireAliasFound)} {
            if {[$lWire GetObjectType] == $::DboBaseObject_WIRE_SCALAR} {
                if {!$wireScalarFound} {
                    set types(WIRE_SCALAR) [$lWire GetObjectType]
                    set wireScalarFound true
                }
                
                if {!$wireAliasFound} {
                    set lAliasIter ""
                    if {[catch {
                        set lAliasIter [$lWire NewAliasesIter $lStatus]
                        set lAlias [$lAliasIter NextAlias $lStatus]
                        if {$lAlias != $lNullObj} {
                            set types(WIRE_ALIAS) [$lAlias GetObjectType]
                            set wireAliasFound true
                        }
                    } err]} {
                        SafeLog "Warning: Failed to process Wire Aliases: $err"
                    }
                    SafeDeleteIter lAliasIter DboWireAliasesIter
                }
            }
            set lWire [$lWiresIter NextWire $lStatus]
        }
    } err]} {
        SafeLog "Warning: Failed to process Wires: $err"
    }
    SafeDeleteIter lWiresIter DboPageWiresIter

    # Graphic Comment Text type (61)
    if {[info exists ::DboBaseObject_GRAPHIC_COMMENTTEXT_INST]} {
        set types(COMMENT_TEXT) $::DboBaseObject_GRAPHIC_COMMENTTEXT_INST
    }

    return [array get types]
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

# Main procedure to save texts with coordinates from selected objects to CSV
proc saveSelectedTextWithCoords {csvFile} {
    global DELTA_X
    SafeLog "Script started"

    set lSession $::DboSession_s_pDboSession
    if {$lSession == ""} {
        SafeLog "ERROR: No DboSession available"
        return false
    }
    
    DboSession -this $lSession
    set lStatus [DboState]
    set lNullObj NULL

    # Get active page
    set activePage ""
    if {[catch {set activePage [GetActivePage]} err]} {
        SafeLog "ERROR: Failed to get active page: $err"
        return false
    }
    
    if {$activePage == $lNullObj} {
        SafeLog "ERROR: No active page found!"
        return false
    }

    # Get selected objects
    set selectedObjects [GetSelectedObjects]
    if {[llength $selectedObjects] == 0} {
        SafeLog "No objects selected for text extraction."
        return false
    }

    SafeLog "Processing [llength $selectedObjects] selected objects"

    # Initialize object types
    set objectTypes [initObjectTypes $activePage $lStatus]
    if {[llength $objectTypes] == 0} {
        SafeLog "ERROR: No object types could be determined"
        return false
    }

    # Collect text data with coordinates
    set textDataList {}
    set processedCount 0

    foreach obj $selectedObjects {
        if {[catch {
            set objType [$obj GetObjectType]
            
            # Get text content
            set textContent [getObjectText $obj $objType $objectTypes $lStatus]
            if {$textContent eq ""} {
                continue
            }
            
            # Get coordinates - use appropriate method based on object type
            array set typesArr $objectTypes
            if {[info exists typesArr(COMMENT_TEXT)] && $objType == $typesArr(COMMENT_TEXT)} {
                # For text objects, use direct location
                set coords [getTextObjectCoords $obj $lStatus]
            } else {
                # For other objects, use bounding box center
                set coords [getObjectAbsoluteCoords $obj $lStatus]
            }
            
            set tX [lindex $coords 0]
            set tY [lindex $coords 1]
            
            # Log coordinates for debugging
            SafeLog "Object '$textContent' at coordinates: X=$tX, Y=$tY"
            
            # Add to data list
            lappend textDataList [list $tX $tY $textContent]
            incr processedCount
            
        } err]} {
            SafeLog "Error processing object: $err"
        }
    }

    if {[llength $textDataList] == 0} {
        SafeLog "No text data collected from selected objects"
        return false
    }

    SafeLog "Collected $processedCount text items with coordinates"

    # Sort, group, and export data
    set sortedData [lsort -command compareCoordinates $textDataList]
    set groupedData [groupAndSortByXCoordinate $sortedData $DELTA_X]
    exportToCsv $csvFile $groupedData
    
    SafeLog "Export completed: [llength $textDataList] text items → $csvFile"
    SafeLog "Script done!"
    return true
}

# Example usage
if {[info exists ::path_to_csv_file]} {
    set scriptDir [file dirname [info script]]
    saveSelectedTextWithCoords $::path_to_csv_file
} else {
    SafeLog "ERROR: Global variable ::path_to_csv_file not set"
}
