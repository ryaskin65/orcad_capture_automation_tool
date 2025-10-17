# 16.10.2025
# Script to find and replace text for OrCAD Capture
# Replaces specified text in selected objects

proc initObjectTypes {activePage} {
    set types [dict create]
    set lNullObj NULL
    set lStatus [DboState]
    
    # OffPageConnector type (38) - from original code
    if {[catch {set offPageIter [$activePage NewOffPageConnectorsIter $lStatus]} err]} {
        puts "Warning: Failed to create OffPageConnectors iterator: $err"
    } else {
        set offPageInst [$offPageIter NextOffPageConnector $lStatus]
        if {$offPageInst != "NULL"} {
            dict set types OFFPAGE [$offPageInst GetObjectType]
            #puts "OFFPAGE type: [dict get $types OFFPAGE]"
        }
        catch {delete_DboPageOffPageConnectorsIter $offPageIter}
    }

    # Port type (36) - from original code
    if {[catch {set portIter [$activePage NewPortsIter $lStatus]} err]} {
        puts "Warning: Failed to create Ports iterator: $err"
    } else {
        set portInst [$portIter NextPort $lStatus]
        if {$portInst != "NULL"} {
            dict set types PORT [$portInst GetObjectType]
            #puts "PORT type: [dict get $types PORT]"
        }
        catch {delete_DboPagePortsIter $portIter}
    }

    # Part type (13) - from original code
    set lPartInstsIter [$activePage NewPartInstsIter $lStatus]
    set lInst [$lPartInstsIter NextPartInst $lStatus]
    if {$lInst != $lNullObj} {
        set lPlacedInst [DboPartInstToDboPlacedInst $lInst]
        if {$lPlacedInst != $lNullObj} {
            dict set types PART [$lPlacedInst GetObjectType]
            #puts "PART type: [dict get $types PART]"
        }
    }
    delete_DboPagePartInstsIter $lPartInstsIter

    # DisplayProperty type (39) - from original code
    if {![dict exists $types DISPLAY]} {
        if {[info exists offPageInst] && $offPageInst != "NULL"} {
            set lPropsIter [$offPageInst NewDisplayPropsIter $lStatus]
            set lDProp [$lPropsIter NextProp $lStatus]
            if {$lDProp != $lNullObj} { 
                dict set types DISPLAY [$lDProp GetObjectType]
                #puts "DISPLAY type: [dict get $types DISPLAY]"
            }
            delete_DboDisplayPropsIter $lPropsIter
        }
    }

    # Wire Scalar type (20) and Wire Alias type (49) - from original code
    set lWiresIter [$activePage NewWiresIter $lStatus]
    set lWire [$lWiresIter NextWire $lStatus]
    set wireScalarFound false
    set wireAliasFound false
    
    while {$lWire != $lNullObj && (!$wireScalarFound || !$wireAliasFound)} {
        if {[$lWire GetObjectType] == $::DboBaseObject_WIRE_SCALAR} {
            # Store Wire Scalar type (20) only once
            if {!$wireScalarFound} {
                dict set types WIRE_SCALAR [$lWire GetObjectType]
                #puts "WIRE_SCALAR type: [dict get $types WIRE_SCALAR]"
                set wireScalarFound true
            }
            
            # Get Wire Alias type (49) from first alias
            if {!$wireAliasFound} {
                set lAliasIter [$lWire NewAliasesIter $lStatus]
                set lAlias [$lAliasIter NextAlias $lStatus]
                if {$lAlias != $lNullObj} {
                    dict set types WIRE_ALIAS [$lAlias GetObjectType]
                    #puts "WIRE_ALIAS type: [dict get $types WIRE_ALIAS]"
                    set wireAliasFound true
                }
                delete_DboWireAliasesIter $lAliasIter
            }
        }
        set lWire [$lWiresIter NextWire $lStatus]
    }
    delete_DboPageWiresIter $lWiresIter

    # Graphic Comment Text type (61) - standard constant
    dict set types COMMENT_TEXT $::DboBaseObject_GRAPHIC_COMMENTTEXT_INST
    #puts "COMMENT_TEXT type: [dict get $types COMMENT_TEXT]"

    return $types
}

proc updateObjectBoundingBox {obj objType objectTypes activePage} {
    # Universal bounding box update using dynamically determined types
    
    if {[dict exists $objectTypes COMMENT_TEXT] && $objType == [dict get $objectTypes COMMENT_TEXT]} {
        # For text objects, use SetRecalBoundingBox on the text definition
        set textInst [DboGraphicInstanceToDboGraphicCommentTextInst $obj]
        set textDef [$textInst GetDboCommentText]
        if {$textDef != "NULL"} {
            if {[catch {$textDef SetRecalBoundingBox} err]} {
                puts "Warning: SetRecalBoundingBox failed for CommentText: $err"
                $textInst MarkModified
            } else {
                $textInst MarkModified
            }
        }
	} elseif {[dict exists $objectTypes PORT] && $objType == [dict get $objectTypes PORT]} {
		set portInst $obj
		if {[catch {$portInst SetBoundingBoxDirty 1} err]} {
			puts "Warning: SetBoundingBoxDirty failed for Port: $err"
			$portInst MarkModified
		} else {
			$portInst MarkModified
		}
    } elseif {[dict exists $objectTypes PART] && $objType == [dict get $objectTypes PART]} {
        if {[catch {$obj SetRecalBoundingBox} err]} {
            puts "Warning: SetRecalBoundingBox failed for Part: $err"
            $obj MarkModified
        }
    } elseif {[dict exists $objectTypes OFFPAGE] && $objType == [dict get $objectTypes OFFPAGE]} {
        # For OffPage Connector, use SetBoundingBoxDirty with argument 1
        if {[catch {$obj SetBoundingBoxDirty 1} err]} {
            puts "Warning: SetBoundingBoxDirty failed for OffPage: $err"
            $obj MarkModified
        } else {
            $obj MarkModified
        }
    } elseif {[dict exists $objectTypes DISPLAY] && $objType == [dict get $objectTypes DISPLAY]} {
        if {[catch {$obj SetRecalBoundingBox} err]} {
            puts "Warning: SetRecalBoundingBox failed for Display: $err"
            $obj MarkModified
        }
    } elseif {[dict exists $objectTypes WIRE_ALIAS] && $objType == [dict get $objectTypes WIRE_ALIAS]} {
        # For Wire Alias, only use MarkModified as SetRecalBoundingBox is not supported
        $obj MarkModified
    } else {
        puts "Warning: Unknown object type for bounding box update: $objType"
        catch {$obj MarkModified}
    }
    
    $activePage MarkModified
    return true
}

proc adjustPortTextPosition {portInst oldText newText} {
    set lStatus [DboState]
    
    # Get port display properties
    if {[catch {set propsIter [$portInst NewDisplayPropsIter $lStatus]} err]} {
        puts "Warning: Cannot get display properties for port: $err"
        return false
    }
    
    set textAdjusted false
    set prop [$propsIter NextProp $lStatus]
    
    while {$prop != "NULL"} {
        set propType [$prop GetObjectType]
        
        if {$propType == 39} {
            # Простое перемещение на фиксированное расстояние для теста
            set newLocation [DboTclHelper_sMakeCPoint 1 1]
            $prop SetLocation $newLocation
            set textAdjusted true
            puts "Port text moved to (1, 1)"
        }
        
        set prop [$propsIter NextProp $lStatus]
    }
    
    delete_DboDisplayPropsIter $propsIter
    return $textAdjusted
}

proc replaceTextInObject {obj objectTypes oldText newText activePage} {
    set currentText ""
    set newTextValue ""
    
    set objType [$obj GetObjectType]
    
    # Handle different object types with text replacement
    if {[dict exists $objectTypes COMMENT_TEXT] && $objType == [dict get $objectTypes COMMENT_TEXT]} {
        set textInst [DboGraphicInstanceToDboGraphicCommentTextInst $obj]
        set textDef [$textInst GetDboCommentText]
        
        if {$textDef != "NULL"} {
            set textCStr [DboTclHelper_sMakeCString]
            $textDef GetText $textCStr
            set currentText [DboTclHelper_sGetConstCharPtr $textCStr]
            
            if {[string match "*${oldText}*" $currentText]} {
                set newTextValue [string map [list $oldText $newText] $currentText]
                set newTextCStr [DboTclHelper_sMakeCString $newTextValue]
                $textDef SetText $newTextCStr
                updateObjectBoundingBox $textInst $objType $objectTypes $activePage
                puts "Text replaced: '$currentText' -> '$newTextValue'"
                return true
            }
        }
    } elseif {[dict exists $objectTypes PORT] && $objType == [dict get $objectTypes PORT]} {
        set portInst $obj
        set nameCStr [DboTclHelper_sMakeCString]
        $portInst GetName $nameCStr
        set currentText [DboTclHelper_sGetConstCharPtr $nameCStr]
        
        if {[string match "*${oldText}*" $currentText]} {
            set newTextValue [string map [list $oldText $newText] $currentText]
            set newNameCStr [DboTclHelper_sMakeCString $newTextValue]
            $portInst SetName $newNameCStr
			# Adjust text position after replacement
#			adjustPortTextPosition $portInst $currentText $newTextValue			
			# update Object Bounding Box
            updateObjectBoundingBox $portInst $objType $objectTypes $activePage
            puts "Port name replaced: '$currentText' -> '$newTextValue'"
            return true
        }
    } elseif {[dict exists $objectTypes PART] && $objType == [dict get $objectTypes PART]} {
        set partInst $obj
        set replaced false
        
        # Check RefDes
        set refDesCStr [DboTclHelper_sMakeCString]
        $partInst GetReferenceDesignator $refDesCStr
        set currentRefDes [DboTclHelper_sGetConstCharPtr $refDesCStr]
        
        if {[string match "*${oldText}*" $currentRefDes]} {
            set newRefDes [string map [list $oldText $newText] $currentRefDes]
            set newRefDesCStr [DboTclHelper_sMakeCString $newRefDes]
            $partInst SetReferenceDesignator $newRefDesCStr
            updateObjectBoundingBox $partInst $objType $objectTypes $activePage
            puts "RefDes replaced: '$currentRefDes' -> '$newRefDes'"
            set replaced true
        }
        
        # Check Value
        set valueCStr [DboTclHelper_sMakeCString]
        $partInst GetPartValue $valueCStr
        set currentValue [DboTclHelper_sGetConstCharPtr $valueCStr]
        
        if {[string match "*${oldText}*" $currentValue]} {
            set newValue [string map [list $oldText $newText] $currentValue]
            set newValueCStr [DboTclHelper_sMakeCString $newValue]
            $partInst SetPartValue $newValueCStr
            updateObjectBoundingBox $partInst $objType $objectTypes $activePage
            puts "Part value replaced: '$currentValue' -> '$newValue'"
            set replaced true
        }
        return $replaced
        
    } elseif {[dict exists $objectTypes OFFPAGE] && $objType == [dict get $objectTypes OFFPAGE]} {
        set offPageInst $obj
        set nameCStr [DboTclHelper_sMakeCString]
        $offPageInst GetName $nameCStr
        set currentText [DboTclHelper_sGetConstCharPtr $nameCStr]
        
        if {[string match "*${oldText}*" $currentText]} {
            set newTextValue [string map [list $oldText $newText] $currentText]
            set newNameCStr [DboTclHelper_sMakeCString $newTextValue]
            $offPageInst SetName $newNameCStr
            updateObjectBoundingBox $offPageInst $objType $objectTypes $activePage
            puts "OffPage connector name replaced: '$currentText' -> '$newTextValue'"
            return true
        }
    } elseif {[dict exists $objectTypes DISPLAY] && $objType == [dict get $objectTypes DISPLAY]} {
        set displayInst $obj
        set nameCStr [DboTclHelper_sMakeCString]
        set owner [$displayInst GetParentObj]
        $displayInst GetActualValueString $owner $nameCStr
        set currentText [DboTclHelper_sGetConstCharPtr $nameCStr]
        
        if {[string match "*${oldText}*" $currentText]} {
            set newTextValue [string map [list $oldText $newText] $currentText]
            set newNameCStr [DboTclHelper_sMakeCString $newTextValue]
            $displayInst SetValueString $newNameCStr
            updateObjectBoundingBox $displayInst $objType $objectTypes $activePage
            puts "Display Property name replaced: '$currentText' -> '$newTextValue'"
            return true
        }
    } elseif {[dict exists $objectTypes WIRE_ALIAS] && $objType == [dict get $objectTypes WIRE_ALIAS]} {
        set aliasInst $obj
        set nameCStr [DboTclHelper_sMakeCString]
        
        if {[catch {$aliasInst GetName $nameCStr} err]} {
            puts "Error: Failed to get Name for Wire Alias: $err"
            return false
        }
        
        set currentText [DboTclHelper_sGetConstCharPtr $nameCStr]
        if {[string match "*${oldText}*" $currentText]} {
            set newTextValue [string map [list $oldText $newText] $currentText]
            set newNameCStr [DboTclHelper_sMakeCString $newTextValue]
            
            if {[catch {$aliasInst SetName $newNameCStr} err]} {
                puts "Error: Failed to set Name for Alias: $err"
                return false
            }
            
            updateObjectBoundingBox $aliasInst $objType $objectTypes $activePage
            puts "Alias Property name replaced: '$currentText' -> '$newTextValue'"
            return true
        }
    } elseif {$objType == $::DboBaseObject_WIRE_SCALAR} {
        # Handle Wire objects - find and process their Net Aliases
        set lStatus [DboState]
        set replaced false
        
        # Get all aliases for this wire
        set lAliasIter [$obj NewAliasesIter $lStatus]
        set lAlias [$lAliasIter NextAlias $lStatus]
        
        while {$lAlias != "NULL"} {
            set nameCStr [DboTclHelper_sMakeCString]
            
            if {[catch {$lAlias GetName $nameCStr} err]} {
                puts "Error: Failed to get Name for Wire Alias: $err"
            } else {
                set currentText [DboTclHelper_sGetConstCharPtr $nameCStr]
                if {[string match "*${oldText}*" $currentText]} {
                    set newTextValue [string map [list $oldText $newText] $currentText]
                    set newNameCStr [DboTclHelper_sMakeCString $newTextValue]
                    
                    if {[catch {$lAlias SetName $newNameCStr} err]} {
                        puts "Error: Failed to set Name for Alias: $err"
                    } else {
                        updateObjectBoundingBox $lAlias [dict get $objectTypes WIRE_ALIAS] $objectTypes $activePage
                        puts "Wire Alias replaced: '$currentText' -> '$newTextValue'"
                        set replaced true
                    }
                }
            }
            
            set lAlias [$lAliasIter NextAlias $lStatus]
        }
        
        delete_DboWireAliasesIter $lAliasIter
        return $replaced
    }
    
    return false
}

proc processObject {obj objectTypes oldText newText activePage} {
    set objType [$obj GetObjectType]
    
    # Check if object type is supported
    foreach {key typeValue} $objectTypes {
        if {$objType == $typeValue} {
            return [replaceTextInObject $obj $objectTypes $oldText $newText $activePage]
        }
    }
    
	# Silent skip for unsupported object types (no text content)
    # puts "Unsupported object type: $objType"
    return false
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

proc replaceSelectedTexts {oldText newText} {
	SafeLog "Script started"
    # Validate input
    if {$oldText eq ""} {
        puts "Error: Text to find cannot be empty."
        return
    }

    # Get active page
    set activePage [GetActivePage]
    if {$activePage == "NULL"} {
        puts "Failed to get active page."
        return
    }

    # Get selected objects list
    set selectedObjects [GetSelectedObjects]
    if {[llength $selectedObjects] == 0} {
        puts "No objects selected for text replacement."
        return
    }

    # Initialize object types
    set objectTypes [initObjectTypes $activePage]
    
    # Check if any types were found
    if {[dict size $objectTypes] == 0} {
        puts "Error: No object types could be determined"
        return
    }
    
    # Replacement counter
    set replaceCount 0

    # Process selected objects
    foreach obj $selectedObjects {
        if {[processObject $obj $objectTypes $oldText $newText $activePage]} {
            incr replaceCount
        }
    }
    
    # Print summary
    if {$replaceCount > 0} {
        puts "Total replacements made: $replaceCount"
        UnSelectAll
    } else {
        puts "Text '$oldText' not found in selected objects."
    }
	SafeLog "Script done!"
}

if {[info exists ::find_text] && [info exists ::replace_text]} {
	replaceSelectedTexts $::find_text $::replace_text
} else {
	puts "ERROR: Global variables find_text or/and replace_text not set!"
}
