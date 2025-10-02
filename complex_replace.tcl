# 2025.06.29
# Enertec systems
# Enhanced text replacement script for OrCAD Capture
# Replaces text in selected objects based on pairs from a CSV file
# CSV format: oldText,newText (one pair per line)
# Replacement occurs only on exact text match
# How to use:
# 1. Create a CSV file with replacement pairs (format: oldText,newText)
# 2. Select objects containing text to replace
# 3. In command window execute:
# source "path_to_script.tcl"

# Procedure to read replacement pairs from a CSV file
proc readCsvFile {csvFile} {
    set replacements {}
    puts "Reading CSV file: '$csvFile'"

    # Check if file exists
    if {![file exists $csvFile]} {
        puts "Error: CSV file '$csvFile' does not exist."
        return $replacements
    }

    # Open and read the CSV file
    if {[catch {open $csvFile r} fid]} {
        puts "Error: Failed to open CSV file '$csvFile': $fid"
        return $replacements
    }

    while {[gets $fid line] >= 0} {
        # Skip empty lines
        if {[string trim $line] eq ""} {
            puts "Skipping empty CSV line"
            continue
        }
        # Split line into fields (assuming comma-separated)
        set fields [split $line ","]
        if {[llength $fields] >= 2} {
            set oldText [string trim [lindex $fields 0]]
            set newText [string trim [lindex $fields 1]]
            if {$oldText ne ""} {
                lappend replacements [list $oldText $newText]
                puts "Read replacement pair: '$oldText' -> '$newText'"
            } else {
                puts "Warning: Skipping invalid CSV line (empty oldText): '$line'"
            }
        } else {
            puts "Warning: Skipping invalid CSV line (insufficient fields): '$line'"
        }
    }
    close $fid

    if {[llength $replacements] == 0} {
        puts "No valid replacement pairs found in '$csvFile'"
    }
    return $replacements
}

# Procedure to replace a single text pair in selected objects (exact match)
proc replaceSingleText {oldText newText selectedObjects activePage} {
    set replaceCount 0
    puts "Processing replacement: '$oldText' -> '$newText'"

    # Process selected objects
    foreach obj $selectedObjects {
        set objType [$obj GetObjectType]
        set currentText ""
        set newTextValue ""

        # Handle different object types
        if {[info exists ::DboBaseObject_GRAPHIC_COMMENTTEXT_INST] && $objType == $::DboBaseObject_GRAPHIC_COMMENTTEXT_INST} {
            # Regular text object
            set textInst [DboGraphicInstanceToDboGraphicCommentTextInst $obj]
            set textDef [$textInst GetDboCommentText]
            
            if {$textDef != "NULL"} {
                set textCStr [DboTclHelper_sMakeCString]
                if {[catch {$textDef GetText $textCStr} err]} {
                    puts "Error: Failed to get text for GraphicCommentText: $err"
                    continue
                }
                set currentText [DboTclHelper_sGetConstCharPtr $textCStr]
                
                # Perform text replacement on exact match
                if {[string equal $currentText $oldText]} {
                    set newTextValue $newText
                    set newTextCStr [DboTclHelper_sMakeCString $newTextValue]
                    if {[catch {$textDef SetText $newTextCStr} err]} {
                        puts "Error: Failed to set text for GraphicCommentText: $err"
                        continue
                    }
                    incr replaceCount
                    puts "Text replaced: '$currentText' -> '$newTextValue'"
                #} else {
                #    puts "No match: '$currentText' does not exactly match '$oldText'"
                }
            } else {
                puts "Warning: Null text definition for GraphicCommentText"
            }
        } elseif {[info exists ::DboBaseObject_PORT_INST] && $objType == $::DboBaseObject_PORT_INST} {
            # Port object
            set portInst [DboGraphicInstanceToDboPortInst $obj]
            set nameCStr [DboTclHelper_sMakeCString]
            if {[catch {$portInst GetName $nameCStr} err]} {
                puts "Error: Failed to get name for Port: $err"
                continue
            }
            set currentText [DboTclHelper_sGetConstCharPtr $nameCStr]
            
            if {[string equal $currentText $oldText]} {
                set newTextValue $newText
                set newNameCStr [DboTclHelper_sMakeCString $newTextValue]
                if {[catch {$portInst SetName $newNameCStr} err]} {
                    puts "Error: Failed to set name for Port: $err"
                    continue
                }
                incr replaceCount
                puts "Port name replaced: '$currentText' -> '$newTextValue'"
            #} else {
            #    puts "No match: '$currentText' does not exactly match '$oldText'"
            }
        } elseif {[info exists ::DboBaseObject_POWER_INST] && $objType == $::DboBaseObject_POWER_INST} {
            # Power object
            set powerInst [DboGraphicInstanceToDboGlobal $obj]
            set nameCStr [DboTclHelper_sMakeCString]
            if {[catch {$powerInst GetName $nameCStr} err]} {
                puts "Error: Failed to get name for Power: $err"
                continue
            }
            set currentText [DboTclHelper_sGetConstCharPtr $nameCStr]
            
            if {[string equal $currentText $oldText]} {
                set newTextValue $newText
                set newNameCStr [DboTclHelper_sMakeCString $newTextValue]
                if {[catch {$powerInst SetName $newNameCStr} err]} {
                    puts "Error: Failed to set name for Power: $err"
                    continue
                }
                incr replaceCount
                puts "Power name replaced: '$currentText' -> '$newTextValue'"
            #} else {
            #    puts "No match: '$currentText' does not exactly match '$oldText'"
            }
        } elseif {[info exists ::DboBaseObject_PART_INST] && $objType == $::DboBaseObject_PART_INST} {
            # Part (RefDes or Value)
            set partInst $obj
            
            # Check RefDes
            set refDesCStr [DboTclHelper_sMakeCString]
            if {[catch {$partInst GetReferenceDesignator $refDesCStr} err]} {
                puts "Error: Failed to get ReferenceDesignator for Part: $err"
                continue
            }
            set currentRefDes [DboTclHelper_sGetConstCharPtr $refDesCStr]
            
            if {[string equal $currentRefDes $oldText]} {
                set newRefDes $newText
                set newRefDesCStr [DboTclHelper_sMakeCString $newRefDes]
                if {[catch {$partInst SetReferenceDesignator $newRefDesCStr} err]} {
                    puts "Error: Failed to set ReferenceDesignator for Part: $err"
                    continue
                }
                incr replaceCount
                puts "RefDes replaced: '$currentRefDes' -> '$newRefDes'"
            #} else {
            #    puts "No match: '$currentRefDes' does not exactly match '$oldText' (RefDes)"
            }
            
            # Check Value
            set valueCStr [DboTclHelper_sMakeCString]
            if {[catch {$partInst GetPartValue $valueCStr} err]} {
                puts "Error: Failed to get PartValue for Part: $err"
                continue
            }
            set currentValue [DboTclHelper_sGetConstCharPtr $valueCStr]
            
            if {[string equal $currentValue $oldText]} {
                set newValue $newText
                set newValueCStr [DboTclHelper_sMakeCString $newValue]
                if {[catch {$partInst SetPartValue $newValueCStr} err]} {
                    puts "Error: Failed to set PartValue for Part: $err"
                    continue
                }
                incr replaceCount
                puts "Part value replaced: '$currentValue' -> '$newValue'"
            #} else {
            #    puts "No match: '$currentValue' does not exactly match '$oldText' (PartValue)"
            }
        } elseif {[info exists ::DboBaseObject_OFFPAGE_INST] && $objType == $::DboBaseObject_OFFPAGE_INST} {
            # OffPage connector
            set offPageInst $obj
            set nameCStr [DboTclHelper_sMakeCString]
            if {[catch {$offPageInst GetName $nameCStr} err]} {
                puts "Error: Failed to get name for OffPageConnector: $err"
                continue
            }
            set currentText [DboTclHelper_sGetConstCharPtr $nameCStr]
            
            if {[string equal $currentText $oldText]} {
                set newTextValue $newText
                set newNameCStr [DboTclHelper_sMakeCString $newTextValue]
                if {[catch {$offPageInst SetName $newNameCStr} err]} {
                    puts "Error: Failed to set name for OffPageConnector: $err"
                    continue
                }
                incr replaceCount
                puts "OffPage connector name replaced: '$currentText' -> '$newTextValue'"
            #} else {
            #    puts "No match: '$currentText' does not exactly match '$oldText'"
            }
        } else {
            puts "Unknown object type: $objType"
        }
        
        # Mark page as modified if replacement occurred
        if {$newTextValue ne ""} {
            if {[catch {$activePage MarkModified} err]} {
                puts "Error: Failed to mark page as modified: $err"
            }
        }
    }

    return $replaceCount
}

# Main procedure to replace texts based on CSV file
proc replaceSelectedTexts {csvFile} {
    puts "Starting text replacement with CSV file: '$csvFile'"

    # Get active page
    set activePage [GetActivePage]
    if {$activePage == "NULL"} {
        puts "Error: Failed to get active page."
        return
    }
    puts "Active page retrieved successfully"

    # Initialize status object
    if {[catch {set lStatus [DboState]} err]} {
        puts "Error: Failed to initialize DboState: $err"
        return
    }

    # Get selected objects list
    if {[catch {set selectedObjects [GetSelectedObjects]} err]} {
        puts "Error: Failed to get selected objects: $err"
        return
    }
    if {[llength $selectedObjects] == 0} {
        puts "Error: No objects selected for text replacement."
        return
    }
    puts "Selected objects: [llength $selectedObjects]"

    # Initialize object type constants dynamically
    # OffPageConnector type
    if {![info exists ::DboBaseObject_OFFPAGE_INST]} {
        if {[catch {set offPageIter [$activePage NewOffPageConnectorsIter $lStatus]} err]} {
            puts "Error: Failed to create OffPageConnectors iterator: $err"
        } else {
            set offPageInst [$offPageIter NextOffPageConnector $lStatus]
            if {$offPageInst != "NULL"} {
                set ::DboBaseObject_OFFPAGE_INST [$offPageInst GetObjectType]
                puts "Constant ::DboBaseObject_OFFPAGE_INST set to [$offPageInst GetObjectType]"
            #} else {
            #    puts "No OffPageConnector found on page"
            }
            delete_DboPageOffPageConnectorsIter $offPageIter
        }
    }

    # Port type
    if {![info exists ::DboBaseObject_PORT_INST]} {
        if {[catch {set portIter [$activePage NewPortsIter $lStatus]} err]} {
            puts "Error: Failed to create Ports iterator: $err"
        } else {
            set portInst [$portIter NextPort $lStatus]
            if {$portInst != "NULL"} {
                set ::DboBaseObject_PORT_INST [$portInst GetObjectType]
                puts "Constant ::DboBaseObject_PORT_INST set to [$portInst GetObjectType]"
            #} else {
            #    puts "No Port found on page"
            }
            delete_DboPagePortsIter $portIter
        }
    }

    # Power type
    if {![info exists ::DboBaseObject_POWER_INST]} {
        if {[catch {set globalIter [$activePage NewGlobalsIter $lStatus]} err]} {
            puts "Error: Failed to create Globals iterator: $err"
        } else {
            set globalInst [$globalIter NextGlobal $lStatus]
            if {$globalInst != "NULL"} {
                set ::DboBaseObject_POWER_INST [$globalInst GetObjectType]
                puts "Constant ::DboBaseObject_POWER_INST set to [$globalInst GetObjectType]"
            #} else {
            #    puts "No Power object found on page"
            }
            delete_DboPageGlobalsIter $globalIter
        }
    }

    # Part type (use selected objects since NewPartsIter is not available)
    if {![info exists ::DboBaseObject_PART_INST]} {
        foreach obj $selectedObjects {
            set objType [$obj GetObjectType]
            if {![catch {$obj GetReferenceDesignator [DboTclHelper_sMakeCString]}]} {
                set ::DboBaseObject_PART_INST $objType
                puts "Constant ::DboBaseObject_PART_INST set to $objType"
                break
            }
        }
        #if {![info exists ::DboBaseObject_PART_INST]} {
        #    puts "No Part found in selected objects"
        #}
    }

    # Graphic Comment Text type (no iterator available, use selected objects)
    if {![info exists ::DboBaseObject_GRAPHIC_COMMENTTEXT_INST]} {
        foreach obj $selectedObjects {
            set objType [$obj GetObjectType]
            if {![catch {DboGraphicInstanceToDboGraphicCommentTextInst $obj}]} {
                set ::DboBaseObject_GRAPHIC_COMMENTTEXT_INST $objType
                puts "Constant ::DboBaseObject_GRAPHIC_COMMENTTEXT_INST set to $objType"
                break
            }
        }
        #if {![info exists ::DboBaseObject_GRAPHIC_COMMENTTEXT_INST]} {
        #    puts "No GraphicCommentText found in selected objects"
        #}
    }

    # Read replacement pairs from CSV
    set replacements [readCsvFile $csvFile]
    if {[llength $replacements] == 0} {
        puts "Error: No valid replacement pairs to process."
        return
    }

    # Total replacement counter
    set totalReplaceCount 0

    # Process each replacement pair
    foreach pair $replacements {
        set oldText [lindex $pair 0]
        set newText [lindex $pair 1]
        set count [replaceSingleText $oldText $newText $selectedObjects $activePage]
        incr totalReplaceCount $count
    }

    # Print summary
    if {$totalReplaceCount > 0} {
        # Mark page as modified if replacement occurred
        $activePage MarkModified
        puts "Total replacements made: $totalReplaceCount"
		UnSelectAll
    } else {
        puts "No replacements were made."
    }
    puts "Text replacement completed"
}

# Example execution
# replaceSelectedTexts "path_to_csv_file"
replaceSelectedTexts "D:/Py_Proj/ORCAD/complex_replace.csv"
