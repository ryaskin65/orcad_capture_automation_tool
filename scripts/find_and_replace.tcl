# RIGa&DeepSeek 04.11.2025
# Script to find and replace text for OrCAD Capture
# Replaces specified text in selected objects

# Safely Removing Iterators
proc SafeDeleteIter {iterVar iterType} {
    upvar $iterVar iter
    if {[info exists iter] && $iter != ""} {
        catch [list delete_$iterType $iter]
        set iter ""
    }
}

# Safe removal of CString
proc SafeDeleteCString {cstrVar} {
    upvar $cstrVar cstr
    if {[info exists cstr] && $cstr != ""} {
        catch {DboTclHelper_sDeleteCString $cstr}
        set cstr ""
    }
}

# Safely deleting C++ objects
proc SafeDeleteObject {objVar objType} {
    upvar $objVar obj
    if {[info exists obj] && $obj != ""} {
        catch [list DboTclHelper_sDelete$objType $obj]
        set obj ""
    }
}

proc initObjectTypes {activePage} {
    set lNullObj NULL
    set lStatus [DboState]
    
    # Declaring all iterators in advance to guarantee cleanup
    set offPageIter ""
    set portIter ""
    set lPartInstsIter ""
    set lPropsIter ""
    set lWiresIter ""
    set lAliasIter ""
    
    array set types {}
    
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

proc updateObjectBoundingBox {obj objType objectTypes activePage} {
    set lNullObj NULL
    
    # Convert objectTypes list back to array for easier access
    array set typesArr $objectTypes
    
    if {[info exists typesArr(COMMENT_TEXT)] && $objType == $typesArr(COMMENT_TEXT)} {
        set textInst ""
        set textDef ""
        if {[catch {
            set textInst [DboGraphicInstanceToDboGraphicCommentTextInst $obj]
            set textDef [$textInst GetDboCommentText]
            if {$textDef != $lNullObj} {
                if {[catch {$textDef SetRecalBoundingBox} err]} {
                    SafeLog "Warning: SetRecalBoundingBox failed for CommentText"
                }
                $textInst MarkModified
            }
        } err]} {
            SafeLog "Warning: Failed to process CommentText bounding box"
            catch {$obj MarkModified}
        }
    } elseif {[info exists typesArr(PORT)] && $objType == $typesArr(PORT)} {
        set portInst $obj
        if {[catch {$portInst SetBoundingBoxDirty 1} err]} {
            SafeLog "Warning: SetBoundingBoxDirty failed for Port"
        }
        $portInst MarkModified
    } elseif {[info exists typesArr(PART)] && $objType == $typesArr(PART)} {
        if {[catch {$obj SetRecalBoundingBox} err]} {
            SafeLog "Warning: SetRecalBoundingBox failed for Part"
        }
        $obj MarkModified
    } elseif {[info exists typesArr(OFFPAGE)] && $objType == $typesArr(OFFPAGE)} {
        if {[catch {$obj SetBoundingBoxDirty 1} err]} {
            SafeLog "Warning: SetBoundingBoxDirty failed for OffPage"
        }
        $obj MarkModified
    } elseif {[info exists typesArr(DISPLAY)] && $objType == $typesArr(DISPLAY)} {
        $obj MarkModified
    } elseif {[info exists typesArr(WIRE_ALIAS)] && $objType == $typesArr(WIRE_ALIAS)} {
        $obj MarkModified
    } else {
        SafeLog "Warning: Unknown object type for bounding box update: $objType"
        catch {$obj MarkModified}
    }
    
    $activePage MarkModified
    catch {array unset typesArr}
    return true
}

proc getObjectTypeName {objType objectTypes} {
    array set typesArr $objectTypes
    foreach {name type} [array get typesArr] {
        if {$objType == $type} {
            return $name
        }
    }
    return "UNKNOWN($objType)"
}

proc replaceTextInObject {obj objectTypes oldText newText activePage} {
    set result false
    set lNullObj NULL
    array set typesArr $objectTypes
    set objType [$obj GetObjectType]
    set objTypeName [getObjectTypeName $objType $objectTypes]
    
    # Handle different object types with text replacement
    if {[info exists typesArr(COMMENT_TEXT)] && $objType == $typesArr(COMMENT_TEXT)} {
        set textCStr ""
        set newTextCStr ""
        if {[catch {
            set textInst [DboGraphicInstanceToDboGraphicCommentTextInst $obj]
            set textDef [$textInst GetDboCommentText]
            
            if {$textDef != $lNullObj} {
                set textCStr [DboTclHelper_sMakeCString]
                $textDef GetText $textCStr
                set currentText [DboTclHelper_sGetConstCharPtr $textCStr]
                
                if {[string match "*${oldText}*" $currentText]} {
                    set newTextValue [string map [list $oldText $newText] $currentText]
                    set newTextCStr [DboTclHelper_sMakeCString $newTextValue]
                    $textDef SetText $newTextCStr
                    updateObjectBoundingBox $textInst $objType $objectTypes $activePage
                    SafeLog "$objTypeName replaced: '$currentText' -> '$newTextValue'"
                    set result true
                }
            }
        } err]} {
            SafeLog "Error in $objTypeName processing: $err"
        }
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
                SafeLog "$objTypeName replaced: '$currentText' -> '$newTextValue'"
                set result true
            }
        } err]} {
            SafeLog "Error in $objTypeName processing: $err"
        }
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
                SafeLog "$objTypeName RefDes replaced: '$currentRefDes' -> '$newRefDes'"
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
                SafeLog "$objTypeName Value replaced: '$currentValue' -> '$newValue'"
                set replaced true
            }
            set result $replaced
        } err]} {
            SafeLog "Error in $objTypeName processing: $err"
        }
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
                SafeLog "$objTypeName replaced: '$currentText' -> '$newTextValue'"
                set result true
            }
        } err]} {
            SafeLog "Error in $objTypeName processing: $err"
        }
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
                SafeLog "$objTypeName replaced: '$currentText' -> '$newTextValue'"
                set result true
            }
        } err]} {
            SafeLog "Error in $objTypeName processing: $err"
        }
        SafeDeleteCString nameCStr
        SafeDeleteCString newTextCStr
        
    } elseif {[info exists typesArr(WIRE_ALIAS)] && $objType == $typesArr(WIRE_ALIAS)} {
        set nameCStr ""
        set newTextCStr ""
        if {[catch {
            set aliasInst $obj
            set nameCStr [DboTclHelper_sMakeCString]
            
            if {[catch {$aliasInst GetName $nameCStr} err]} {
                SafeLog "Error: Failed to get Name for $objTypeName: $err"
            } else {
                set currentText [DboTclHelper_sGetConstCharPtr $nameCStr]
                if {[string match "*${oldText}*" $currentText]} {
                    set newTextValue [string map [list $oldText $newText] $currentText]
                    set newTextCStr [DboTclHelper_sMakeCString $newTextValue]
                    
                    if {[catch {$aliasInst SetName $newTextCStr} err]} {
                        SafeLog "Error: Failed to set Name for $objTypeName: $err"
                    } else {
                        updateObjectBoundingBox $aliasInst $objType $objectTypes $activePage
                        SafeLog "$objTypeName replaced: '$currentText' -> '$newTextValue'"
                        set result true
                    }
                }
            }
        } err]} {
            SafeLog "Error in $objTypeName processing: $err"
        }
        SafeDeleteCString nameCStr
        SafeDeleteCString newTextCStr
        
    } elseif {$objType == $::DboBaseObject_WIRE_SCALAR} {
        set lStatus [DboState]
        set lAliasIter ""
        set replaced false
        
        if {[catch {
            set lAliasIter [$obj NewAliasesIter $lStatus]
            set lAlias [$lAliasIter NextAlias $lStatus]
            
            while {$lAlias != $lNullObj} {
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
                                SafeLog "WIRE_ALIAS replaced: '$currentText' -> '$newTextValue'"
                                set replaced true
                            }
                        }
                    }
                } err]} {
                    SafeLog "Error in wire alias iteration: $err"
                }
                SafeDeleteCString nameCStr
                SafeDeleteCString newTextCStr
                set lAlias [$lAliasIter NextAlias $lStatus]
            }
            set result $replaced
        } err]} {
            SafeLog "Error in WIRE_SCALAR processing: $err"
        }
        SafeDeleteIter lAliasIter DboWireAliasesIter
    }
    
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