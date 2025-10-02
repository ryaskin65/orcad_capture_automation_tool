# 2025.06.29
# Enertec systems
# Text extraction script for OrCAD Capture
# Saves text from selected objects to a CSV file
# CSV format: Text (one text value per line)
# How to use:
# 1. Select objects containing text to extract
# 2. In command window execute:
# source "path_to_script.tcl"
# saveSelectedText "path_to_csv_file"

proc appendText {varName text debug} {
    set text [DboTclHelper_sGetConstCharPtr $text]
    if {[string trim $text] ne ""} {
        upvar $varName list
        lappend list $text
        if {$debug} { puts "Extracted text: '$text'" }
    }
}

proc getObjectName {obj} {
    set cstr [DboTclHelper_sMakeCString]
    if {[catch {$obj GetName $cstr}]} {
        return ""
    }
    return [DboTclHelper_sGetConstCharPtr $cstr]
}

# Procedure to save texts from selected objects to a CSV file
proc saveSelectedText {csvFile} {
    puts "Starting script text extraction to CSV file: '$csvFile'"
    set lNullObj NULL
    set Debug False

    # Get active page
    if {[catch {set activePage [GetActivePage]} err]} {
        puts "Error: Failed to get active page: $err"
        return
    }
    if {$activePage == "NULL"} {
        puts "Error: No active page found."
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
        puts "Error: No objects selected for text extraction."
        return
    }
    puts "Selected objects: [llength $selectedObjects]"

    # Initialize object type constants
    # set objType [[GetSelectedObjects] GetObjectType]
    # OffPageConnector type (38)
    if {[catch {set offPageIter [$activePage NewOffPageConnectorsIter $lStatus]} err]} {
        puts "Error: Failed to create OffPageConnectors iterator: $err"
    } else {
        set offPageInst [$offPageIter NextOffPageConnector $lStatus]
        if {$offPageInst != "NULL"} {
            set TYPE_OFFPAGE_INST [$offPageInst GetObjectType]
            if {$Debug} { puts "TYPE_OFFPAGE_INST: $TYPE_OFFPAGE_INST" }
            # DisplayProperty type (39)
            set lPropsIter [$offPageInst NewDisplayPropsIter $lStatus]
            set lDProp [$lPropsIter NextProp $lStatus]
            if {$lDProp !=$lNullObj } { 
                set TYPE_DISPLAY_INST [$lDProp GetObjectType]
                if {$Debug} { puts "TYPE_DISPLAY_INST: $TYPE_DISPLAY_INST" }
            }
            delete_DboDisplayPropsIter $lPropsIter
        }
        if {[catch {delete_DboPageOffPageConnectorsIter $offPageIter} err]} {
            puts "Error: Failed to delete OffPageConnectors iterator: $err"
        }
    }

    # Port type
    if {[catch {set portIter [$activePage NewPortsIter $lStatus]} err]} {
        puts "Error: Failed to create Ports iterator: $err"
    } else {
        set portInst [$portIter NextPort $lStatus]
        if {$portInst != "NULL"} {
            set TYPE_PORT_INST [$portInst GetObjectType]
            if {$Debug} { puts "TYPE_PORT_INST: $TYPE_PORT_INST" }
        }
        if {[catch {delete_DboPagePortsIter $portIter} err]} {
            puts "Error: Failed to delete Ports iterator: $err"
        }
    }

    # Power type (37)
    if {[catch {set globalIter [$activePage NewGlobalsIter $lStatus]} err]} {
        puts "Error: Failed to create Globals iterator: $err"
    } else {
        set globalInst [$globalIter NextGlobal $lStatus]
        if {$globalInst != "NULL"} {
            set TYPE_POWER_INST [$globalInst GetObjectType]
            if {$Debug} { puts "TYPE_POWER_INST: $TYPE_POWER_INST" }
        }
        if {[catch {delete_DboPageGlobalsIter $globalIter} err]} {
            puts "Error: Failed to delete Globals iterator: $err"
        }
    }

    # Wire type (20)
    set lWiresIter [$activePage NewWiresIter $lStatus]
    #get the first wire
    set lWire [$lWiresIter NextWire $lStatus]
    while {$lWire != $lNullObj} {
        set lObjectType [$lWire GetObjectType]
        if {$lObjectType == $::DboBaseObject_WIRE_SCALAR} {
            # Wire type
            if {![info exists TYPE_WIRE_SCALAR_INST]} {
                set TYPE_WIRE_SCALAR_INST $lObjectType
                if {$Debug} { puts "TYPE_WIRE_SCALAR_INST: $TYPE_WIRE_SCALAR_INST" }
            }
            # Alias type (49)
            set lAliasIter [$lWire NewAliasesIter $lStatus]
            set lAlias [$lAliasIter NextAlias $lStatus]
            if {$lAlias!=$lNullObj} {
                set TYPE_ALIAS_INST [$lAlias GetObjectType]
                if {$Debug} { puts "TYPE_ALIAS_INST: $TYPE_ALIAS_INST" }
            }
            delete_DboWireAliasesIter $lAliasIter 
        } elseif {$lObjectType == $::DboBaseObject_WIRE_BUS} {
            # Wire Bus type
        }
        if {[info exists TYPE_WIRE_SCALAR_INST] && [info exists TYPE_ALIAS_INST]} {
            break
        }
        # get the next wire
        set lWire [$lWiresIter NextWire $lStatus]
    }
    delete_DboPageWiresIter $lWiresIter

    # Part type (13)
    set lPartInstsIter [$activePage NewPartInstsIter $lStatus]
    #get the first part inst
    set lInst [$lPartInstsIter NextPartInst $lStatus]
    if {$lInst!=$lNullObj} {
        set lObjectType [$lInst GetObjectType]
        #dynamic cast from DboPartInst to DboPlacedInst
        set lPlacedInst [DboPartInstToDboPlacedInst $lInst]
        if {$lPlacedInst != $lNullObj} {
            set TYPE_PART_INST $lObjectType
            if {$Debug} { puts "TYPE_PART_INST: $TYPE_PART_INST" }
        }
        # DisplayProperty type (39)
        if {![info exists TYPE_DISPLAY_INST]} {
            set lPropsIter [$lPlacedInst NewDisplayPropsIter $lStatus]
            set lDProp [$lPropsIter NextProp $lStatus]
            if {$lDProp !=$lNullObj } { 
                set TYPE_DISPLAY_INST [$lDProp GetObjectType]
                if {$Debug} { puts "TYPE_DISPLAY_INST: $TYPE_DISPLAY_INST" }
            }
            delete_DboDisplayPropsIter $lPropsIter
        }
        # #get the next part inst
        # set lInst [$lPartInstsIter NextPartInst $lStatus]
    }
    delete_DboPagePartInstsIter $lPartInstsIter

    # Graphic Comment Text type (61)
    set TYPE_GRAPHIC_COMMENTTEXT_INST $::DboBaseObject_GRAPHIC_COMMENTTEXT_INST
    if {$Debug} { puts "TYPE_GRAPHIC_COMMENTTEXT_INST: $TYPE_GRAPHIC_COMMENTTEXT_INST" }

    # Collect texts from selected objects
    set textList {}

    foreach obj $selectedObjects {
        set objType [$obj GetObjectType]
        set currentText ""

        # Handle different object types
        if {[info exists TYPE_GRAPHIC_COMMENTTEXT_INST] && $objType == $TYPE_GRAPHIC_COMMENTTEXT_INST} {
            # Regular text object
            set textInst [DboGraphicInstanceToDboGraphicCommentTextInst $obj]
            set textDef [$textInst GetDboCommentText]
            
            if {$textDef != "NULL"} {
                set nameCStr [DboTclHelper_sMakeCString]
                if {[catch {$textDef GetText $nameCStr} err]} {
                    puts "Error: Failed to get text for GraphicCommentText: $err"
                    continue
                }
                appendText textList $nameCStr $Debug
            } else {
                puts "Warning: Null text definition for GraphicCommentText"
            }
        } elseif {[info exists TYPE_PORT_INST] && $objType == $TYPE_PORT_INST} {
            # Port object
            set portInst [DboGraphicInstanceToDboPortInst $obj]
            set nameCStr [DboTclHelper_sMakeCString]
            if {[catch {$portInst GetName $nameCStr} err]} {
                puts "Error: Failed to get name for Port: $err"
                continue
            }
            appendText textList $nameCStr $Debug
        # } elseif {[info exists TYPE_POWER_INST] && $objType == $TYPE_POWER_INST} {
        #     # Power object
        #     set powerInst [DboGraphicInstanceToDboGlobal $obj]
        #     set nameCStr [DboTclHelper_sMakeCString]
        #     if {[catch {$powerInst GetName $nameCStr} err]} {
        #         puts "Error: Failed to get name for Power: $err"
        #         continue
        #     }
        #     set currentText [DboTclHelper_sGetConstCharPtr $nameCStr]
        #     if {$currentText ne ""} {
        #         lappend textList $currentText
        #         incr textCount
        #         puts "Extracted Power name: '$currentText'"
        #     }
        } elseif {[info exists TYPE_PART_INST] && $objType == $TYPE_PART_INST} {
            # Part (RefDes and Value)
            set partInst $obj
            # Check RefDes
            set refDesCStr [DboTclHelper_sMakeCString]
            if {[catch {$partInst GetReferenceDesignator $refDesCStr} err]} {
                puts "Error: Failed to get ReferenceDesignator for Part: $err"
            } else {
                appendText textList $refDesCStr $Debug
            }
            # Check Value
            set valueCStr [DboTclHelper_sMakeCString]
            if {[catch {$partInst GetPartValue $valueCStr} err]} {
                puts "Error: Failed to get PartValue for Part: $err"
            } else {
                appendText textList $valueCStr $Debug
            }
        } elseif {[info exists TYPE_OFFPAGE_INST] && $objType == $TYPE_OFFPAGE_INST} {
            # OffPage connector (38)
            set offPageInst $obj
            set nameCStr [DboTclHelper_sMakeCString]
            if {[catch {$offPageInst GetName $nameCStr} err]} {
                puts "Error: Failed to get name for OffPageConnector: $err"
                continue
            }
            appendText textList $nameCStr $Debug
        } elseif {[info exists TYPE_DISPLAY_INST] && $objType == $TYPE_DISPLAY_INST} {
            # Value of Display Property (39)
            set displayInst $obj
            set nameCStr [DboTclHelper_sMakeCString]
            if {[catch {set owner [$displayInst GetParentObj]} err]} {
                continue
            }
            if {[catch {$displayInst GetActualValueString $owner $nameCStr} err]} {
                puts "Error: Failed to get Value for Display Property: $err"
                continue
            }
            appendText textList $nameCStr $Debug
        } elseif {[info exists TYPE_WIRE_SCALAR_INST] && $objType == $TYPE_WIRE_SCALAR_INST} {
            # Wire (20)
            set wireInst $obj
            # get the net name
            set nameCStr [DboTclHelper_sMakeCString]
            if {[catch {$wireInst GetNetName $nameCStr} err]} {
                puts "Error: Failed to get Net Name for Wire: $err"
                continue
            }
            appendText textList $nameCStr $Debug
        } elseif {[info exists TYPE_ALIAS_INST] && $objType == $TYPE_ALIAS_INST} {
            # Alias (49)
            set aliasInst $obj
            set nameCStr [DboTclHelper_sMakeCString]
            # set netOwner [$aliasInst GetOwner]
            if {[catch {$aliasInst GetName $nameCStr} err]} {
                puts "Error: Failed to get Name for Wire Alias: $err"
                continue
            }
            appendText textList $nameCStr $Debug
        } else {
            puts "Unknown object type: $objType"
        }
    }

    # Write texts to CSV file
    if {[catch {open $csvFile w} fid]} {
        puts "Error: Failed to open CSV file for writing: '$csvFile': $fid"
        return
    }
    # Write each text, escaping commas with quotes
    set writeCount 0
    foreach text $textList {
        # Escape text containing commas
        if {[string first "," $text] != -1} {
            set text "\"$text\""
        }
        puts $fid $text
        incr writeCount
        # puts "Wrote to CSV: '$text'"
    }

    close $fid
    puts "Total texts written to CSV: $writeCount"
    puts "Script done."
}

# Example: saveSelectedText "d:/tcl/selected_text.csv"
saveSelectedText "D:/py/ORCAD/selected_text.csv"
