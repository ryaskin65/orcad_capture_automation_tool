# RIGa&DeepSeek 25.10.2025
# Script to find and replace text for OrCAD Capture
# Replaces specified text in selected objects

proc initObjectTypes {activePage} {
    array set types {}
    set lNullObj NULL
    set lStatus [DboState]
    
    # Declare all iterators in advance for guaranteed cleanup
    set offPageIter ""
    set portIter ""
    set lPartInstsIter ""
    set lPropsIter ""
    set lWiresIter ""
    set lAliasIter ""
    
    # OffPageConnector type (38) - from original code
    if {[catch {
        set offPageIter [$activePage NewOffPageConnectorsIter $lStatus]
        set offPageInst [$offPageIter NextOffPageConnector $lStatus]
        if {$offPageInst != "NULL"} {
            set types(OFFPAGE) [$offPageInst GetObjectType]
        }
    } err]} {
        SafeLog "Warning: Failed to create OffPageConnectors iterator: $err"
    }
    catch {delete_DboPageOffPageConnectorsIter $offPageIter}

    # Port type (36) - from original code
    if {[catch {
        set portIter [$activePage NewPortsIter $lStatus]
        set portInst [$portIter NextPort $lStatus]
        if {$portInst != "NULL"} {
            set types(PORT) [$portInst GetObjectType]
        }
    } err]} {
        SafeLog "Warning: Failed to create Ports iterator: $err"
    }
    catch {delete_DboPagePortsIter $portIter}

    # Part type (13) - from original code
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
    catch {delete_DboPagePartInstsIter $lPartInstsIter}

    # DisplayProperty type (39) - from original code
    if {![info exists types(DISPLAY)]} {
        if {[info exists offPageInst] && $offPageInst != "NULL"} {
            if {[catch {
                set lPropsIter [$offPageInst NewDisplayPropsIter $lStatus]
                set lDProp [$lPropsIter NextProp $lStatus]
                if {$lDProp != $lNullObj} { 
                    set types(DISPLAY) [$lDProp GetObjectType]
                }
            } err]} {
                SafeLog "Warning: Failed to process DisplayProps: $err"
            }
            catch {delete_DboDisplayPropsIter $lPropsIter}
        }
    }

    # Wire Scalar type (20) and Wire Alias type (49) - from original code
    set wireScalarFound false
    set wireAliasFound false
    
    if {[catch {
        set lWiresIter [$activePage NewWiresIter $lStatus]
        set lWire [$lWiresIter NextWire $lStatus]
        
        while {$lWire != $lNullObj && (!$wireScalarFound || !$wireAliasFound)} {
            if {[$lWire GetObjectType] == $::DboBaseObject_WIRE_SCALAR} {
                # Store Wire Scalar type (20) only once
                if {!$wireScalarFound} {
                    set types(WIRE_SCALAR) [$lWire GetObjectType]
                    set wireScalarFound true
                }
                
                # Get Wire Alias type (49) from first alias
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
                    if {$lAliasIter != ""} {
                        catch {delete_DboWireAliasesIter $lAliasIter}
                    }
                }
            }
            set lWire [$lWiresIter NextWire $lStatus]
        }
    } err]} {
        SafeLog "Warning: Failed to process Wires: $err"
    }
    catch {delete_DboPageWiresIter $lWiresIter}

    # Graphic Comment Text type (61) - standard constant
    if {[info exists ::DboBaseObject_GRAPHIC_COMMENTTEXT_INST]} {
        set types(COMMENT_TEXT) $::DboBaseObject_GRAPHIC_COMMENTTEXT_INST
    }

    return [array get types]
}

proc updateObjectBoundingBox {obj objType objectTypes activePage} {
    # Convert objectTypes list back to array for easier access
    array set typesArr $objectTypes
    
    if {[info exists typesArr(COMMENT_TEXT)] && $objType == $typesArr(COMMENT_TEXT)} {
        # For text objects, use SetRecalBoundingBox on the text definition
        if {[catch {
            set textInst [DboGraphicInstanceToDboGraphicCommentTextInst $obj]
            set textDef [$textInst GetDboCommentText]
            if {$textDef != "NULL"} {
                if {[catch {$textDef SetRecalBoundingBox} err]} {
                    SafeLog "Warning: SetRecalBoundingBox failed for CommentText: $err"
                    $textInst MarkModified
                } else {
                    $textInst MarkModified
                }
            }
        } err]} {
            SafeLog "Warning: Failed to process CommentText bounding box: $err"
            catch {$obj MarkModified}
        }
    } elseif {[info exists typesArr(PORT)] && $objType == $typesArr(PORT)} {
        set portInst $obj
        if {[catch {$portInst SetBoundingBoxDirty 1} err]} {
            SafeLog "Warning: SetBoundingBoxDirty failed for Port: $err"
            $portInst MarkModified
        } else {
            $portInst MarkModified
        }
    } elseif {[info exists typesArr(PART)] && $objType == $typesArr(PART)} {
        if {[catch {$obj SetRecalBoundingBox} err]} {
            SafeLog "Warning: SetRecalBoundingBox failed for Part: $err"
            $obj MarkModified
        }
    } elseif {[info exists typesArr(OFFPAGE)] && $objType == $typesArr(OFFPAGE)} {
        # For OffPage Connector, use SetBoundingBoxDirty with argument 1
        if {[catch {$obj SetBoundingBoxDirty 1} err]} {
            SafeLog "Warning: SetBoundingBoxDirty failed for OffPage: $err"
            $obj MarkModified
        } else {
            $obj MarkModified
        }
    } elseif {[info exists typesArr(DISPLAY)] && $objType == $typesArr(DISPLAY)} {
        if {[catch {$obj SetRecalBoundingBox} err]} {
            SafeLog "Warning: SetRecalBoundingBox failed for Display: $err"
            $obj MarkModified
        }
    } elseif {[info exists typesArr(WIRE_ALIAS)] && $objType == $typesArr(WIRE_ALIAS)} {
        # For Wire Alias, only use MarkModified as SetRecalBoundingBox is not supported
        $obj MarkModified
    } else {
        SafeLog "Warning: Unknown object type for bounding box update: $objType"
        catch {$obj MarkModified}
    }
    
    $activePage MarkModified
    return true
}

proc SafeDeleteCString {cstrVar} {
    upvar $cstrVar cstr
    if {[info exists cstr] && $cstr != ""} {
        catch {DboTclHelper_sDeleteCString $cstr}
        set cstr ""
    }
}

proc replaceTextInObject {obj objectTypes oldText newText activePage} {
    set result false
    array set typesArr $objectTypes
    set objType [$obj GetObjectType]
    
    # Handle different object types with text replacement
    if {[info exists typesArr(COMMENT_TEXT)] && $objType == $typesArr(COMMENT_TEXT)} {
        set textCStr ""
        set newTextCStr ""
        if {[catch {
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
                    SafeLog "Text replaced: '$currentText' -> '$newTextValue'"
                    set result true
                }
            }
        } err]} {
            SafeLog "Error in COMMENT_TEXT processing: $err"
        }
        # Guaranteed cleanup
        SafeDeleteCString textCStr
        SafeDeleteCString newTextCStr
        
    } elseif {[info exists typesArr(PORT)] && $objType == $typesArr(PORT)} {
        set nameCStr ""
        set newTextCStr ""
        if {[catch {
            set portInst $obj
            set nameCStr [DboTclHelper_sMakeCString]
            $portInst GetName $nameCStr
            set currentText [DboTclHelper_sGetConstCharPtr $nameCStr]
            
            if {[string match "*${oldText}*" $currentText]} {
                set newTextValue [string map [list $oldText $newText] $currentText]
                set newTextCStr [DboTclHelper_sMakeCString $newTextValue]
                $portInst SetName $newTextCStr
                updateObjectBoundingBox $portInst $objType $objectTypes $activePage
                SafeLog "Port name replaced: '$currentText' -> '$newTextValue'"
                set result true
            }
        } err]} {
            SafeLog "Error in PORT processing: $err"
        }
        # Guaranteed cleanup
        SafeDeleteCString nameCStr
        SafeDeleteCString newTextCStr
        
    } elseif {[info exists typesArr(PART)] && $objType == $typesArr(PART)} {
        set refDesCStr ""
        set valueCStr ""
        set newRefDesCStr ""
        set newValueCStr ""
        set replaced false
        
        if {[catch {
            set partInst $obj
            # Check RefDes
            set refDesCStr [DboTclHelper_sMakeCString]
            $partInst GetReferenceDesignator $refDesCStr
            set currentRefDes [DboTclHelper_sGetConstCharPtr $refDesCStr]
            
            if {[string match "*${oldText}*" $currentRefDes]} {
                set newRefDes [string map [list $oldText $newText] $currentRefDes]
                set newRefDesCStr [DboTclHelper_sMakeCString $newRefDes]
                $partInst SetReferenceDesignator $newRefDesCStr
                updateObjectBoundingBox $partInst $objType $objectTypes $activePage
                SafeLog "RefDes replaced: '$currentRefDes' -> '$newRefDes'"
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
                SafeLog "Part value replaced: '$currentValue' -> '$newValue'"
                set replaced true
            }
            set result $replaced
        } err]} {
            SafeLog "Error in PART processing: $err"
        }
        # Guaranteed cleanup
        SafeDeleteCString refDesCStr
        SafeDeleteCString valueCStr
        SafeDeleteCString newRefDesCStr
        SafeDeleteCString newValueCStr
        
    } elseif {[info exists typesArr(OFFPAGE)] && $objType == $typesArr(OFFPAGE)} {
        set nameCStr ""
        set newTextCStr ""
        if {[catch {
            set offPageInst $obj
            set nameCStr [DboTclHelper_sMakeCString]
            $offPageInst GetName $nameCStr
            set currentText [DboTclHelper_sGetConstCharPtr $nameCStr]
            
            if {[string match "*${oldText}*" $currentText]} {
                set newTextValue [string map [list $oldText $newText] $currentText]
                set newTextCStr [DboTclHelper_sMakeCString $newTextValue]
                $offPageInst SetName $newTextCStr
                updateObjectBoundingBox $offPageInst $objType $objectTypes $activePage
                SafeLog "OffPage connector name replaced: '$currentText' -> '$newTextValue'"
                set result true
            }
        } err]} {
            SafeLog "Error in OFFPAGE processing: $err"
        }
        # Guaranteed cleanup
        SafeDeleteCString nameCStr
        SafeDeleteCString newTextCStr
        
    } elseif {[info exists typesArr(DISPLAY)] && $objType == $typesArr(DISPLAY)} {
        set nameCStr ""
        set newTextCStr ""
        if {[catch {
            set displayInst $obj
            set nameCStr [DboTclHelper_sMakeCString]
            set owner [$displayInst GetParentObj]
            $displayInst GetActualValueString $owner $nameCStr
            set currentText [DboTclHelper_sGetConstCharPtr $nameCStr]
            
            if {[string match "*${oldText}*" $currentText]} {
                set newTextValue [string map [list $oldText $newText] $currentText]
                set newTextCStr [DboTclHelper_sMakeCString $newTextValue]
                $displayInst SetValueString $newTextCStr
                updateObjectBoundingBox $displayInst $objType $objectTypes $activePage
                SafeLog "Display Property name replaced: '$currentText' -> '$newTextValue'"
                set result true
            }
        } err]} {
            SafeLog "Error in DISPLAY processing: $err"
        }
        # Guaranteed cleanup
        SafeDeleteCString nameCStr
        SafeDeleteCString newTextCStr
        
    } elseif {[info exists typesArr(WIRE_ALIAS)] && $objType == $typesArr(WIRE_ALIAS)} {
        set nameCStr ""
        set newTextCStr ""
        if {[catch {
            set aliasInst $obj
            set nameCStr [DboTclHelper_sMakeCString]
            
            if {[catch {$aliasInst GetName $nameCStr} err]} {
                SafeLog "Error: Failed to get Name for Wire Alias: $err"
            } else {
                set currentText [DboTclHelper_sGetConstCharPtr $nameCStr]
                if {[string match "*${oldText}*" $currentText]} {
                    set newTextValue [string map [list $oldText $newText] $currentText]
                    set newTextCStr [DboTclHelper_sMakeCString $newTextValue]
                    
                    if {[catch {$aliasInst SetName $newTextCStr} err]} {
                        SafeLog "Error: Failed to set Name for Alias: $err"
                    } else {
                        updateObjectBoundingBox $aliasInst $objType $objectTypes $activePage
                        SafeLog "Alias Property name replaced: '$currentText' -> '$newTextValue'"
                        set result true
                    }
                }
            }
        } err]} {
            SafeLog "Error in WIRE_ALIAS processing: $err"
        }
        # Guaranteed cleanup
        SafeDeleteCString nameCStr
        SafeDeleteCString newTextCStr
        
    } elseif {$objType == $::DboBaseObject_WIRE_SCALAR} {
        set lStatus [DboState]
        set lAliasIter ""
        set replaced false
        
        if {[catch {
            set lAliasIter [$obj NewAliasesIter $lStatus]
            set lAlias [$lAliasIter NextAlias $lStatus]
            
            while {$lAlias != "NULL"} {
                set nameCStr ""
                set newTextCStr ""
                if {[catch {
                    set nameCStr [DboTclHelper_sMakeCString]
                    
                    if {[catch {$lAlias GetName $nameCStr} err]} {
                        SafeLog "Error: Failed to get Name for Wire Alias: $err"
                    } else {
                        set currentText [DboTclHelper_sGetConstCharPtr $nameCStr]
                        if {[string match "*${oldText}*" $currentText]} {
                            set newTextValue [string map [list $oldText $newText] $currentText]
                            set newTextCStr [DboTclHelper_sMakeCString $newTextValue]
                            
                            if {[catch {$lAlias SetName $newTextCStr} err]} {
                                SafeLog "Error: Failed to set Name for Alias: $err"
                            } else {
                                array set typesArr $objectTypes
                                updateObjectBoundingBox $lAlias $typesArr(WIRE_ALIAS) $objectTypes $activePage
                                SafeLog "Wire Alias replaced: '$currentText' -> '$newTextValue'"
                                set replaced true
                            }
                        }
                    }
                } err]} {
                    SafeLog "Error in wire alias iteration: $err"
                }
                # Cleanup in every iteration
                SafeDeleteCString nameCStr
                SafeDeleteCString newTextCStr
                set lAlias [$lAliasIter NextAlias $lStatus]
            }
            set result $replaced
        } err]} {
            SafeLog "Error in WIRE_SCALAR processing: $err"
        }
        # Guaranteed iterator cleanup
        if {$lAliasIter != ""} {
            catch {delete_DboWireAliasesIter $lAliasIter}
        }
    }
    
    # Clean up array
    catch {array unset typesArr}
    
    return $result
}

proc processObject {obj objectTypes oldText newText activePage} {
    set result false
    set objType [$obj GetObjectType]
    # Convert objectTypes list back to array for easier access
    array set typesArr $objectTypes
    # Check if object type is supported
    foreach {key typeValue} [array get typesArr] {
        if {$objType == $typeValue} {
            set result [replaceTextInObject $obj $objectTypes $oldText $newText $activePage]
        }
    }
    # Silent skip for unsupported object types (no text content)
    return $result
}

proc SafeLog {message} {
    global scriptDir
    set timestamp [clock format [clock seconds] -format "%Y.%m.%d %H:%M:%S"]
    set logEntry "$timestamp - $message"
    # Log to OrCAD console
	puts $message
    # Log to file safely
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
        SafeLog "Error: Text to find cannot be empty."
        return
    }

    # Get active page
    set activePage [GetActivePage]
    if {$activePage == "NULL"} {
        SafeLog "Failed to get active page."
        return
    }

    # Get selected objects list
    set selectedObjects [GetSelectedObjects]
    if {[llength $selectedObjects] == 0} {
        SafeLog "No objects selected for text replacement."
        return
    }

    # Initialize object types
    set objectTypes [initObjectTypes $activePage]
    
    # Check if any types were found
    if {[llength $objectTypes] == 0} {
        SafeLog "Error: No object types could be determined"
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
        SafeLog "Total replacements made: $replaceCount"
        UnSelectAll
    } else {
        SafeLog "Text '$oldText' not found in selected objects."
    }
    SafeLog "Script done!"
}

if {[info exists ::find_text] && [info exists ::replace_text]} {
	# Get the directory where the script is located
	set scriptDir [file dirname [info script]]
    replaceSelectedTexts $::find_text $::replace_text
    set scriptDir ""
} else {
    SafeLog "ERROR: Global variables find_text or/and replace_text not set!"
}