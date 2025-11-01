# RIGa&DeepSeek 25.10.2025
# Script to cable automation from csv table

# Global constant
set STEP_XY 2.54
set A3_WIDTH 414
set A3_HEIGHT 350
set StepWireY [expr $STEP_XY * 2]
set StartWireY [expr $STEP_XY * 8]
set StartWireX [expr $STEP_XY * 20]
set EndWireX [expr $STEP_XY * 143]
set LeftOffPageX [expr $StartWireX - $STEP_XY]
set RightOffPageX $EndWireX
set StartTextPinX [expr $StartWireX - $STEP_XY * 8]
set offsetNameLeftOffPageX -20
set StartMiddleTextColorX [expr $STEP_XY * 75]
set SpliceLeftX [expr $StartWireX + $STEP_XY * 3]
set ShieldLeftX [expr $StartWireX + $STEP_XY * 14]
set LeftPartX [expr $StartWireX + $STEP_XY * 15]
set StartLeftTextColorX [expr $StartWireX + $STEP_XY * 19]
set SpliceRightX [expr $EndWireX - $STEP_XY * 4]
set ShieldRightX [expr $EndWireX - $STEP_XY * 17] 
set RightPartX [expr $EndWireX - $STEP_XY * 16]
set StartRightTextColorX [expr $EndWireX - $STEP_XY * 23]
set tclLibName ""
set pathLib ""
set ProjectNumber ""
set NameRightSide ""
set NameLeftSide ""
set PageCount 0
set PageNumber 0

# The procedure for checking that the active page is A3 size and the dimension is millimeters
proc CheckPageA3Millimeters {} {
    set lPage [GetActivePage]
    set lNullObj NULL
    
    if {$lPage == $lNullObj} {
        SafeLog "ERROR: No active page found"
        return false
    }
    
    # We get the page dimensions (in thousandths of a millimeter)
    set pageWidth [$lPage GetPageWidth]
    set pageHeight [$lPage GetPageHeight]
    set isMetric [$lPage GetIsMetric]
    
    SafeLog "Page dimensions: [expr {$pageWidth / 1000.0}]x[expr {$pageHeight / 1000.0}]mm, Is metric: $isMetric"
    
    # Checking units of measurement
    if {!$isMetric} {
        SafeLog "ERROR: Page units are not metric"
        return false
    }
    
    # Checking the A3 size (420x297 mm in thousandths)
    set expectedWidth 420000
    set expectedHeight 297000
    set tolerance 1000  ; # Tolerance 1mm
    
    set widthOk [expr {abs($pageWidth - $expectedWidth) <= $tolerance}]
    set heightOk [expr {abs($pageHeight - $expectedHeight) <= $tolerance}]
    
    if {!$widthOk || !$heightOk} {
        SafeLog "ERROR: Page size is not A3. Expected: 420x297mm, Actual: [expr {$pageWidth / 1000.0}]x[expr {$pageHeight / 1000.0}]mm"
        return false
    }
    
    SafeLog "SUCCESS: Page is A3 size (420x297mm) with millimeter units"
    return true
}

# Places text on the schematic at specified coordinates
#  X, Y - Starting coordinates
#  L, W - Length and width of text area
#  T - Text content
#  S - Font size
#  B - Bold flag (TRUE/FALSE)
proc PlaceTextCheck {X Y L W T S B} {
	SafeLog "Place text X=[format "%.2f" $X], Y=[format "%.2f" $Y], $T"
	global A3_WIDTH A3_HEIGHT
	set lNullObj NULL
	# Check boundaries
	if {$X < 0 || $X > $A3_WIDTH || $Y < 0 || $Y > $A3_HEIGHT} {
		SafeLog "Text boundary error: X=[format "%.2f" $X], Y=[format "%.2f" $Y], L=[format "%.2f" $L], W=[format "%.2f" $W]"
		return
	}		
	PlaceText $X $Y [expr $X + $L] [expr $Y + $W] $T
	SelectObject $X $Y FALSE
	SetFont "Courier New" $S $B FALSE
    # Get the selected text object and update its bounding box
    set selObj [GetSelectedObjects]
    if {$selObj != $lNullObj} {
        set textInst [DboGraphicInstanceToDboGraphicCommentTextInst $selObj]
        if {$textInst != $lNullObj} {
            set textDef [$textInst GetDboCommentText]
            if {$textDef != $lNullObj} {
                if {[catch {$textDef SetRecalBoundingBox} err]} {
                    SafeLog "Warning: SetRecalBoundingBox failed for CommentText: $err"
                }
				$textInst MarkModified
            }
        }
    }
    UnSelectAll
    return
}

#  Place rectangle with check coordinates
proc PlaceRectangleCheck {X Y L W} {
	SafeLog "Place rectangle: X=[format "%.2f" $X], Y=[format "%.2f" $Y], L=[format "%.2f" $L], W=[format "%.2f" $W]"
    global A3_WIDTH A3_HEIGHT
    # Checking input parameter types
    if {![string is double -strict $X] || ![string is double -strict $Y] || 
        ![string is double -strict $L] || ![string is double -strict $W]} {
        SafeLog "Error: Non-numeric input in PlaceRectangle"
        return
    }
    # Checking positive dimensions
    if {$L <= 0 || $W <= 0} {
        SafeLog "Error: Invalid dimensions L, W in PlaceRectangle"
        return
    }
    set X2 [expr $X + $W]
    set Y2 [expr $Y + $L]
    # Checking the borders of A3 sheet
    if {$X < 0 || $X2 > $A3_WIDTH || $Y < 0 || $Y2 > $A3_HEIGHT} {
        SafeLog "Error: Rectangle out of size in PlaceRectangle: X=[format "%.2f" $X], Y=[format "%.2f" $Y], X2=[format "%.2f" $X2], Y2=[format "%.2f" $Y2]"
        return
    }
    PlaceRectangle $X $Y $X2 $Y2
    SetLineStyle 0
    SetLineWidth 1
    UnSelectAll
    return
}

# Place wire with check coordinates
proc PlaceWireCheck {X1 Y1 X2 Y2} {
	SafeLog "Place wire: X1=[format "%.2f" $X1], Y1=[format "%.2f" $Y1], X2=[format "%.2f" $X2], Y2=[format "%.2f" $Y2]"
	global A3_WIDTH A3_HEIGHT
	# Check if coordinates are numeric
	if {![string is double -strict $X1] || ![string is double -strict $Y1] || 
		![string is double -strict $X2] || ![string is double -strict $Y2]} {
		SafeLog "Error: Non-numeric coordinates in PlaceWire"
	    return
	}
	# Check if coordinates are within A3 bounds
	if {($X1 < 0) || ($X1 > $A3_WIDTH) || ($X2 < 0) || ($X2 > $A3_WIDTH) || 
		($Y1 < 0) || ($Y1 > $A3_HEIGHT) || ($Y2 < 0) || ($Y2 > $A3_HEIGHT)} {
		SafeLog "Error: Wire out of size in PlaceWire"
	    return
	}
	PlaceWire $X1 $Y1 $X2 $Y2
}

# Place line with check coordinates
proc PlaceLineSieldCheck {X1 Y1 X2 Y2} {
	SafeLog "Place line: X1=[format "%.2f" $X1], Y1=[format "%.2f" $Y1], X2=[format "%.2f" $X2], Y2=[format "%.2f" $Y2]"
	global A3_WIDTH A3_HEIGHT
	# Check if coordinates are numeric
	if {![string is double -strict $X1] || ![string is double -strict $Y1] || 
		![string is double -strict $X2] || ![string is double -strict $Y2]} {
		SafeLog "Error: Non-numeric coordinates in PlaceLine"
	    return
	}
	# Check if coordinates are within A3 bounds
	if {($X1 < 0) || ($X1 > $A3_WIDTH) || ($X2 < 0) || ($X2 > $A3_WIDTH) || 
		($Y1 < 0) || ($Y1 > $A3_HEIGHT) || ($Y2 < 0) || ($Y2 > $A3_HEIGHT)} {
		SafeLog "Error: Wire out of size in PlaceLine"
	    return
	}
	PlaceLine $X1 $Y1 $X2 $Y2
	SetLineStyle 2
}

# Place arc shield top with check coordinates
proc PlaceArcShieldTopCheck {X Y} {
	SafeLog "Place top shield arc: X=[format "%.2f" $X], Y=[format "%.2f" $Y]"
	global A3_WIDTH A3_HEIGHT
	global STEP_XY
	# Check if coordinates are numeric
	if {![string is double -strict $X] || ![string is double -strict $Y]} {
		SafeLog "Error: Non-numeric coordinates in PlaceArc"
	    return
	}
	# Check if coordinates are within A3 bounds
	if {($X < 0) || ($X > $A3_WIDTH) || ($Y < 0) || ($Y > $A3_HEIGHT)} {
		SafeLog "Error: Arc out of size in PlaceArc"
	    return
	}
	set X1 $X
	set Y1 [expr $Y + $STEP_XY]
	set X2 [expr $X1 + 4 * $STEP_XY]
	set Y2 [expr $Y1 + 4 * $STEP_XY]
	set X3 [expr $X1 + 4 * $STEP_XY]
	set Y3 [expr $Y1 + 2 * $STEP_XY]
	set X4 [expr $X1 + 0 * $STEP_XY]
	set Y4 [expr $Y1 + 2 * $STEP_XY]
	# Check if coordinates are within A3 bounds
	if {($X2 > $A3_WIDTH) || ($Y1 > $A3_HEIGHT) || ($Y2 > $A3_HEIGHT)} {
		SafeLog "Error: Arc out of size in PlaceArc"
	    return
	}
	PlaceArc $X1 $Y1 $X2 $Y2 $X3 $Y3 $X4 $Y4
	SetLineStyle 2
}

# Place arc shield bottom with check coordinates
proc PlaceArcShieldBottomCheck {X Y} {
	SafeLog "Place bottom shield arc: X=[format "%.2f" $X], Y=[format "%.2f" $Y]"
	global A3_WIDTH A3_HEIGHT
	global STEP_XY
	# Check if coordinates are numeric
	if {![string is double -strict $X] || ![string is double -strict $Y]} {
		SafeLog "Error: Non-numeric coordinates in PlaceArc"
	    return
	}
	# Check if coordinates are within A3 bounds
	if {($X < 0) || ($X > $A3_WIDTH) || ($Y < 0) || ($Y > $A3_HEIGHT)} {
		SafeLog "Error: Arc out of size in PlaceArc"
	    return
	}
	set X1 $X
	set Y1 [expr $Y - $STEP_XY]
	set X2 [expr $X1 + 4 * $STEP_XY]
	set Y2 [expr $Y1 + 4 * $STEP_XY]
	set X3 [expr $X1 + 4 * $STEP_XY]
	set Y3 [expr $Y1 + 2 * $STEP_XY]
	set X4 [expr $X1 + 0 * $STEP_XY]
	set Y4 [expr $Y1 + 2 * $STEP_XY]
	# Check if coordinates are within A3 bounds
	if {($X2 > $A3_WIDTH) || ($Y1 > $A3_HEIGHT) || ($Y2 > $A3_HEIGHT)} {
		SafeLog "Error: Arc out of size in PlaceArc"
	    return
	}
	PlaceArc $X1 $Y1 $X2 $Y2 $X4 $Y4 $X3 $Y3
	SetLineStyle 2
}

# Place shield with check coordinates
# L - length, C - wire connection LEFT RIGHT DOWN
proc PlaceShieldCheck {X Y L C} {
    SafeLog "Place shield: X=[format "%.2f" $X], Y=[format "%.2f" $Y], L=[format "%.2f" $L], C=$C"
	# Checking input parameter types
    if {![string is double -strict $X] || ![string is double -strict $Y] || ![string is double -strict $L]} {
	    SafeLog "Error: Non-numeric input in PlaceShield: X=$X, Y=$Y, L=$L"
	    return
	}
    # Checking positive dimensions
    if {$L <= 0} {
        SafeLog "Error: Invalid dimension L in PlaceShield: L=$L"
        return
    }
	global STEP_XY

	PlaceArcShieldTopCheck $X $Y
	PlaceArcShieldBottomCheck $X [expr $Y + $L]

	set X1 $X
	set Y1 [expr $Y + 3 * $STEP_XY]
	set X2 [expr $X + 4 * $STEP_XY]
	set Y2 [expr $Y1 + $L - 2 * $STEP_XY]
	PlaceLineSieldCheck $X1 $Y1 $X1 $Y2
	PlaceLineSieldCheck $X2 $Y1 $X2 $Y2
	UnSelectAll
	switch -exact $C {
		"LEFT" {
			set X1 [expr $X + 2 * $STEP_XY]
			set Y1 [expr $Y + $L + 3 * $STEP_XY]
			set X2 [expr $X - 16 * $STEP_XY]
			set Y2 [expr $Y1 + $STEP_XY]
			PlaceWireCheck $X1 $Y1 $X1 $Y2
			PlaceWireCheck $X1 $Y2 $X2 $Y2
			PlaceWireCheck $X2 $Y2 $X2 $Y1
		}
		"RIGHT" {
			set X1 [expr $X + 2 * $STEP_XY]
			set Y1 [expr $Y + $L + 3 * $STEP_XY]
			set X2 [expr $X + 19 * $STEP_XY]
			set Y2 [expr $Y1 + $STEP_XY]
			PlaceWireCheck $X1 $Y1 $X1 $Y2
			PlaceWireCheck $X1 $Y2 $X2 $Y2
			PlaceWireCheck $X2 $Y2 $X2 $Y1
		}
		"DOWN" {
			set X1 [expr $X + 2 * $STEP_XY]
			set Y1 [expr $Y + $L + 3 * $STEP_XY]
			set Y2 [expr $Y1 + 2 * $STEP_XY]
			PlaceWireCheck $X1 $Y1 $X1 $Y2
		}
		default {}
	}
	return
}

# Place left and right OutOffPage
proc PlaceOutOffPageCheck {SrcCon DstCon Y} {
	global STEP_XY A3_WIDTH A3_HEIGHT
	global offsetNameLeftOffPageX StartTextPinX pathLib
	global LeftOffPageX RightOffPageX
	set OffPageY [expr $Y - $STEP_XY]
	# Check boundaries
	if {$OffPageY < 0 || $OffPageY > $A3_HEIGHT || 
		$LeftOffPageX < 0 || $LeftOffPageX > $A3_WIDTH ||
		$RightOffPageX < 0 || $RightOffPageX > $A3_WIDTH} {
		SafeLog "OffPage coordinates out of bounds: Y=[format "%.2f" $Y], LeftX=[format "%.2f" $LeftOffPageX], RightX=[format "%.2f" $RightOffPageX]"
		return
	}
	if {$DstCon ne ""} {
		SafeLog "Place OffPageLeft-R: X=[format "%.2f" $LeftOffPageX], Y=[format "%.2f" $OffPageY], $DstCon"
		PlaceOffPage $LeftOffPageX $OffPageY $pathLib "OFFPAGELEFT-R" $DstCon
		SelectObject $StartTextPinX $Y FALSE
		set selObj [GetSelectedObjects]
		set lNullObj NULL
		if {$selObj != $lNullObj} {
			set lPoint [DboTclHelper_sMakeCPoint $offsetNameLeftOffPageX 5]
			$selObj SetLocation $lPoint
			DboTclHelper_sDeleteCPoint $lPoint
		}
	}
	if {$SrcCon ne ""} {
		SafeLog "Place OffPageLeft-L X=[format "%.2f" $RightOffPageX], Y=[format "%.2f" $OffPageY], $SrcCon"
		PlaceOffPage $RightOffPageX $OffPageY $pathLib "OFFPAGELEFT-L" $SrcCon
	}
}

# Place left and right InOffPage
proc PlaceInOffPageCheck {SrcCon DstCon Y} {
	global STEP_XY A3_WIDTH A3_HEIGHT
	global offsetNameLeftOffPageX StartTextPinX pathLib
	global LeftOffPageX RightOffPageX
	set OffPageY [expr $Y - $STEP_XY]
	# Check boundaries
	if {$OffPageY < 0 || $OffPageY > $A3_HEIGHT || 
		$LeftOffPageX < 0 || $LeftOffPageX > $A3_WIDTH ||
		$RightOffPageX < 0 || $RightOffPageX > $A3_WIDTH} {
		SafeLog "OffPage coordinates out of bounds: Y=[format "%.2f" $Y], LeftX=[format "%.2f" $LeftOffPageX], RightX=[format "%.2f" $RightOffPageX]"
		return
	}
	if {$DstCon ne ""} {
		SafeLog "Place OffPageLeft-L Mirror X=[format "%.2f" $LeftOffPageX], Y=[format "%.2f" $OffPageY], $DstCon"
		PlaceOffPage $LeftOffPageX $OffPageY $pathLib "OFFPAGELEFT-L" "OFFPAGELEFT-L"
		MirrorHorizontal
		SetProperty {Name} $DstCon
		SelectObject $StartTextPinX $Y FALSE
		set selObj [GetSelectedObjects]
		set lNullObj NULL
		if {$selObj != $lNullObj} {
			set lPoint [DboTclHelper_sMakeCPoint $offsetNameLeftOffPageX 5]
			$selObj SetLocation $lPoint
			DboTclHelper_sDeleteCPoint $lPoint
		}
	}
	if {$SrcCon ne ""} {
		SafeLog "Place OffPageLeft-R Mirror X=[format "%.2f" $RightOffPageX], Y=[format "%.2f" $OffPageY], $SrcCon"
		PlaceOffPage $RightOffPageX $OffPageY $pathLib "OFFPAGELEFT-R" "OFFPAGELEFT-R"
		MirrorHorizontal
		SetProperty {Name} $SrcCon
	}
}

# Place SPLC
proc PlaceSPLC {X Y} {
	global ver tclLibName STEP_XY A3_WIDTH A3_HEIGHT
	if {[string is double -strict $X] && [string is double -strict $Y]} {
		# Check if coordinates are within A3 bounds
		if {($X < 0) || ($X > $A3_WIDTH) || ($Y < 0) || ($Y > $A3_HEIGHT)} {
			SafeLog [format "Position error in PlaceSPLC X:%s Y:%s" $X $Y]
		} else {

			if {$ver > 16} {
				PlacePart $X [expr $Y - $STEP_XY] $tclLibName "SPLC" "" FALSE
			} else {
				PlacePart $X [expr $Y - $STEP_XY/2] $tclLibName "SPLC" "" FALSE
			}
			SafeLog [format "Non-numeric coordinates in PlaceSPLC X:%s Y:%s" $X $Y]
		}
	} else {
		SafeLog [format "Non-numeric coordinates in PlaceSPLC X:%s Y:%s" $X $Y]
	}
}

# Get group identifier from pin name for cable placing
# - If all pins in connector belong to groups A1-A9, B1-B9, C1-C9, D1-D9: returns "CONNECTOR/GROUP"
# - Otherwise: returns "CONNECTOR"  
# - If no connector name (no slash): returns "GROUP" if pin matches group pattern, else ""
proc GetGroupName {arrPinName idx} {
	set maxIdx [expr {[array size arrPinName] - 1}]
	upvar 1 $arrPinName arr
	
	if {![info exists arr($idx)]} {
		return ""
	}
	set PinName $arr($idx)
	if {$PinName eq ""} {
		return ""
	}
	# Parse connector and pin name
	if {[string first "/" $PinName] != -1} {
		set parts [split $PinName "/"]
		set connectorName [lindex $parts 0]
		set pinName [lindex $parts 1]
		set hasConnector 1
	} else {
		set connectorName ""
		set pinName $PinName
		set hasConnector 0
	}
	# Check if pin matches group pattern A1-A9, B1-B9, C1-C9, D1-D9
	if {![regexp {^([A-D])[1-9]$} $pinName match groupLetter]} {
		# Not a group pin - return connector name only or empty
		return [expr {$hasConnector ? $connectorName : ""}]
	}
	# For pins without connector name - return group letter
	if {!$hasConnector} {
		return $groupLetter
	}
	# Analyze all pins of this connector to check group distribution
	set allPinsValidGroups 1
	set foundGroups [list]
	for {set i 0} {$i <= $maxIdx} {incr i} {
		if {[info exists arr($i)] && $arr($i) ne ""} {
			if {[string first "/" $arr($i)] != -1} {
				set currentParts [split $arr($i) "/"]
				set currentConnector [lindex $currentParts 0]
				set currentPin [lindex $currentParts 1]
				
				# Check if this pin belongs to the same connector
				if {$currentConnector eq $connectorName} {
					if {[regexp {^([A-D])[1-9]$} $currentPin match currentGroup]} {
						lappend foundGroups $currentGroup
					} else {
						set allPinsValidGroups 0
						break
					}
				}
			}
		}
	}
	# Return appropriate identifier
	if {$allPinsValidGroups} {
		# All pins are valid groups - return connector/group
		return "$connectorName/$groupLetter"
	} else {
		# Not all pins are valid groups - return connector only
		return $connectorName
	}
}

# Get name of connector from pin name
proc GetConnectorName {pinName} {
	if {[string first "/" $pinName] != -1} {
		set parts [split $pinName "/"]
		return [lindex $parts 0]
	}
	return ""
}

proc PlaceRectangleCheckConnectors {arrayCon arrayNameCon X} {
	global STEP_XY StepWireY StartWireY
	upvar $arrayCon arCon
	upvar $arrayNameCon arNameCon
	set W [expr 7 * $STEP_XY]
	set LT [expr 10 * $StepWireY]
	set WT [expr 2 * $STEP_XY]
	set arSize [array size arCon]
	set it 0
	for {set i 0} {$i < $arSize} {incr i} {
		if {[expr $i & 1] == 0} {
			set I1 $arCon($i)
			set Y [expr $StartWireY - 2 * $STEP_XY + $I1 * $StepWireY]
		} else {
			set I2 $arCon($i)
			set L [expr ($I2 - $I1 + 1) * $StepWireY]
			# Checking if a rectangle needs to be place
			if {$arNameCon($it) != ""} {
				PlaceRectangleCheck $X $Y $L $W
				# Place the text - connector name
				set XT [expr $X + $STEP_XY * 2]
				set YT [expr $Y - $STEP_XY * 2]
				PlaceTextCheck $XT $YT $LT $WT $arNameCon($it) 19 TRUE
			}
			incr it
		}
	}
}

proc findLineInArray {arrayLine N} {
	upvar $arrayLine arLine
	set arSize [array size arLine]
	for {set i 0} {$i < $arSize} {incr i} {
		if {$N == $arLine($i)} {
			return TRUE
		}
	}
	return FALSE
}

proc PlaceShieldChecks {arrayShield X sideLeftRight arrayCon} {
	global STEP_XY StepWireY StartWireY A3_WIDTH A3_HEIGHT
	upvar $arrayShield arShield
	upvar $arrayCon arCon
	
	# Check if X coordinate is within bounds
	if {$X < 0 || $X > $A3_WIDTH} {
		SafeLog "Shield X coordinate out of bounds: $X"
		return
	}
	
	set arSize [array size arShield]
	for {set i 0} {$i < $arSize} {incr i} {
		if {[expr $i & 1] == 0} {
			set I1 $arShield($i)
			set Y [expr $StartWireY - 3 * $STEP_XY + $I1 * $StepWireY]
			
			# Check Y coordinate
			if {$Y < 0 || $Y > $A3_HEIGHT} {
				SafeLog "Shield Y coordinate out of bounds: $Y"
				continue
			}
		} else {
			set I2 $arShield($i)
			set L [expr ($I2 - $I1) * $StepWireY]
			
			# Check if shield length is reasonable
			if {$L < 0 || $L > $A3_HEIGHT} {
				SafeLog "Shield length out of bounds: $L"
				continue
			}
			
			# Place shield with error handling
			if {[catch {
				if {[findLineInArray arCon $I2]} {
					PlaceShieldCheck $X $Y $L $sideLeftRight
				} else {
					PlaceShieldCheck $X $Y $L "DOWN"
				}
			} err]} {
				SafeLog "Error placing shield at X=$X, Y=$Y: $err"
			}
		}
	}
}

proc PlaceRightWireWithOffset {XDR YD Y Offset} {
	if {[string is integer -strict $Offset]} {
		global STEP_XY
		# Right wire with offset (up or down)
		if {$Offset > 0} {
			# !!!Top and right side!!!
			# Vertical wire
			PlaceWireCheck $XDR [expr $Y + $STEP_XY] $XDR [expr $YD - $STEP_XY]
			# First slant - close Y
			PlaceWireCheck [expr $XDR - $STEP_XY] $Y $XDR [expr $Y + $STEP_XY]
			# Second slant - close YD
			PlaceWireCheck $XDR [expr $YD - $STEP_XY] [expr $XDR + $STEP_XY] $YD
		} elseif {$Offset < 0} {
			# !!!Bottom and right side!!!
			# Vertical wire
			PlaceWireCheck $XDR [expr $Y - $STEP_XY] $XDR [expr $YD + $STEP_XY]
			# First slant - close Y
			PlaceWireCheck [expr $XDR - $STEP_XY] $Y $XDR [expr $Y - $STEP_XY]
			# Second slant - close YD
			PlaceWireCheck $XDR [expr $YD + $STEP_XY] [expr $XDR + $STEP_XY] $YD
		}
	}
}

proc PlaceLeftWireWithOffset {XDL YD Y Offset} {
	if {[string is integer -strict $Offset]} {
		global STEP_XY
		# Left wire with offset (up or down)
		if {$Offset > 0} {
			# !!!Top and left side!!!
			# Vertical wire
			PlaceWireCheck $XDL [expr $Y + $STEP_XY] $XDL [expr $YD - $STEP_XY]
			# First slant - close Y
			PlaceWireCheck [expr $XDL + $STEP_XY] $Y $XDL [expr $Y + $STEP_XY]
			# Second slant - close YD
			PlaceWireCheck $XDL [expr $YD - $STEP_XY] [expr $XDL - $STEP_XY] $YD
		} elseif {$Offset < 0} {
			# !!!Bottom and left side!!!
			# Vertical wire
			PlaceWireCheck $XDL [expr $Y - $STEP_XY] $XDL [expr $YD + $STEP_XY]
			# First slant - close Y
			PlaceWireCheck [expr $XDL + $STEP_XY] $Y $XDL [expr $Y - $STEP_XY]
			# Second slant - close YD
			PlaceWireCheck $XDL [expr $YD + $STEP_XY] [expr $XDL - $STEP_XY] $YD
		}
	}
}

proc PlaceHorizontalWireWithSPLC {WOL WOR WGL WGR XSL XSR XDL XDR Y} {
	global StartWireX EndWireX STEP_XY A3_WIDTH A3_HEIGHT
	# Validate all coordinates
	foreach coord [list $XSL $XSR $XDL $XDR $Y $StartWireX $EndWireX] {
		if {![string is double -strict $coord]} {
			SafeLog "Error: Non-numeric coordinate in PlaceHorizontalWireWithSPLC: $coord"
			return
		}
	}
	# Check boundaries
	if {$Y < 0 || $Y > $A3_HEIGHT || $StartWireX < 0 || $EndWireX > $A3_WIDTH} {
		SafeLog "Error: Coordinates out of bounds in PlaceHorizontalWireWithSPLC: Y=$Y, StartX=$StartWireX, EndX=$EndWireX"
		return
	}
	# Horizontal wire with SPLC
	if {($WOL == "") && ($WOR == "")} {
	# Without SPLC
		if {[catch {PlaceWire $StartWireX $Y $EndWireX $Y} err]} {
			SafeLog "Error placing wire: $err"
		}
	} elseif {($WOR == 0) && ($WOL != 0)} {
	# Right SPLC
		PlaceSPLC $XSR $Y
		PlaceWireCheck [expr $XSR + 2 * $STEP_XY] $Y $EndWireX $Y
		if {$WOL == ""} {
			PlaceWireCheck $StartWireX $Y $XSR $Y
		} else {
			PlaceWireCheck [expr $XDL + $STEP_XY] $Y $XSR $Y
		}
	} elseif {($WOR != 0) && ($WOL == 0)} {
	# Left SPLC
		PlaceSPLC $XSL $Y
		PlaceWireCheck $StartWireX $Y $XSL $Y
		if {$WOR == ""} {
			PlaceWireCheck [expr $XSL + 2 * $STEP_XY] $Y $EndWireX $Y
		} else {
			PlaceWireCheck [expr $XSL + 2 * $STEP_XY] $Y [expr $XDR - $STEP_XY] $Y
		}
	} elseif {($WOR == 0) && ($WOL == 0)} {
	# Right and left SPLC
		PlaceSPLC $XSL $Y
		PlaceSPLC $XSR $Y 
		PlaceWireCheck $StartWireX $Y $XSL $Y
		PlaceWireCheck [expr $XSL + 2 * $STEP_XY] $Y $XSR $Y
		PlaceWireCheck [expr $XSR + 2 * $STEP_XY] $Y $EndWireX $Y
	} elseif {($WOR != "") && ($WOL == "")} {
	# Right wire up or down: horizontal -> slant -> vertical -> slant
		PlaceWireCheck $StartWireX $Y [expr $XDR - $STEP_XY] $Y
	} elseif {($WOR == "") && ($WOL != "")} {
	# Left wire up or down: horizontal -> slant -> vertical -> slant
		PlaceWireCheck [expr $XDL + $STEP_XY] $Y $EndWireX $Y
	} elseif {($WOR != "") && ($WOL != "")} {
	# Right and left wire up or down: horizontal -> slant -> vertical -> slant
		PlaceWireCheck [expr $XDL + $STEP_XY] $Y [expr $XDR - $STEP_XY] $Y
	}
}

proc PlacePage {fileId} {
	global STEP_XY
	global offsetNameLeftOffPageX SpliceRightX SpliceLeftX ShieldRightX ShieldLeftX
	global StepWireY StartWireY StartWireX EndWireX LeftOffPageX RightOffPageX LeftPartX RightPartX
	global StartTextPinX StartLeftTextColorX StartRightTextColorX StartMiddleTextColorX
	global pathLib tclLibName NameRightSide NameLeftSide
	global PageNumber PageCount
	#Page it is all rows after PAGE to empty row
	set i 0
	set maxLenLeftConName 0
	while {[gets $fileId line] >= 0} {
		set elements [split $line ","]
		set vSignalName [lindex $elements 0]
		if {$vSignalName == ""} {break}
		set RightConnector($i) [lindex $elements 1]
		set SignalName($i) $vSignalName
		set LeftConnector($i) [lindex $elements 2]
		set lenLeftConName [string length $LeftConnector($i)]
		if {($i > 0) && ($maxLenLeftConName < $lenLeftConName)} {
			set maxLenLeftConName $lenLeftConName
		}
		set InOut($i) [lindex $elements 3]
		set vWireType [lindex $elements 4]
		if {($vWireType == "SINGLE") || ($vWireType == "SN") || ($vWireType == "")} {
			set WireType($i) 0
		} elseif {($vWireType == "TWISTED") || ($vWireType == "TW")} {
			set WireType($i) 1
		} elseif {($vWireType == "SHIELDED TWISTED") || ($vWireType == "ST")} {
			set WireType($i) 2
		} else {
			set WireType($i) 0
		}
		set WidthLeftGauge($i) [lindex $elements 5]
		set vColor [lindex $elements 6]
		if {$vColor == ""} {
			set patterns {"_RXL" "_TXL" "_RXN" "_TXN" "GND" "RTN" "GND_" "_TDN" "_RDN" "_N_" "_L_"}
			set Color($i) "WHITE"
			foreach pattern $patterns {
				if {[string match *$pattern* $SignalName($i)] || [string match *_N $SignalName($i)] || [string match *_L $SignalName($i)]} {
					set Color($i) "BLACK"
					break
				}
			}
		} else {
			set Color($i) $vColor
		}
		set WidthRightGauge($i) [lindex $elements 7]
		set WireRightOffset($i) [lindex $elements 8]
		set WireInRightGroupe($i) [lindex $elements 9]
		set WireLeftOffset($i) [lindex $elements 10]
		set WireInLeftGroupe($i) [lindex $elements 11]
		incr i
	}
	# Set offset X of PageOff name
	if {$maxLenLeftConName < 5} {
		set offsetNameLeftOffPageX -20
	} elseif {$maxLenLeftConName < 7} {
		set offsetNameLeftOffPageX -30
	} else {
		set offsetNameLeftOffPageX -35
	}
	#set  numWires $i
	set numWires [array size RightConnector]
	# Names connectors
	if {[string first "/" $RightConnector(1)] != -1} {
		set NameRightConnector [string range $RightConnector(1) 0 [expr {[string first "/" $RightConnector(1)] - 1}]]
	} else {
		set NameRightConnector "P__"
	}
	if {[string first "/" $LeftConnector(1)] != -1} {
		set NameLeftConnector [string range $LeftConnector(1) 0 [expr {[string first "/" $LeftConnector(1)] - 1}]]
	} else {
		set NameLeftConnector "P__"
	}
	#
	set lStatus [DboState]
	set lPage [GetActivePage]
	# 
	set numLines 0
	set numSpaceLines 0
	set numWireTwist 0
	set prevTypePair 0
	set iLS 0
	set arrayLineLeftShield($iLS) 0
	set prevLeftGroupePin ""
	set iRS 0
	set arrayLineRightShield($iRS) 0
	set prevRightGroupePin ""
	set iLC 0
	set arrayLineLeftConnector($iLC) 0
	set prevLeftConnector ""
	set iRC 0
	set arrayLineRightConnector($iRC) 0
	set prevRightConnector ""
	set iLT 0
	if {($WireLeftOffset(1) == "") || ($WireLeftOffset(1) == 0)} {
		set leftConnector [GetConnectorName $LeftConnector(1)]
		set prevLeftConnector $leftConnector
	} else {
		set leftConnector ""
	}
	set arrayNameLeftConnector($iLT) $leftConnector
	set iRT 0
	if {($WireRightOffset(1) == "") || ($WireRightOffset(1) == 0)} {
		set rightConnector [GetConnectorName $RightConnector(1)]
		set prevRightConnector $rightConnector
	} else {
		set rightConnector ""
	}
	set arrayNameRightConnector($iRT) $rightConnector
	for {set i 1} {$i < $numWires} {incr i} {
		SafeLog "Wire: $i"
		# Array humbers of Y for left and right connector box
		set leftConnector [GetConnectorName $LeftConnector($i)]
		set rightConnector [GetConnectorName $RightConnector($i)]
		set fLC [expr {$leftConnector != $prevLeftConnector}]
		set fRC [expr {$rightConnector != $prevRightConnector}]
		# Array numbers of wires for left and right shield
		set leftGroupePin [GetGroupName LeftConnector $i]
		set rightGroupePin [GetGroupName RightConnector $i]
		set fLS [expr {$leftGroupePin != $prevLeftGroupePin}]
		set fRS [expr {$rightGroupePin != $prevRightGroupePin}]
		#
		if {$fRC || $fLC} {set prevTypePair 0}
		if {($WireType($i) == 1) || ($WireType($i) == 2)} {set typePair 1} else {set typePair 0}
		if {($WireType($i) == 0) && ($prevTypePair == 1)} {incr numSpaceLines}
		if {(!($fRC || $fLC || $fRS || $fLS)) && ($numWireTwist == 0) && ($typePair == 1)} {incr numSpaceLines}
		if {($numWireTwist < 1) && ($typePair == 1)} {incr numWireTwist} else {set numWireTwist 0}
		#
		if {($i > 1) &&  ($fLS || $fRS || $fLC || $fRC)} {
			if {$fLS && ($prevLeftGroupePin != "")} {
				incr iLS
				set arrayLineLeftShield($iLS) [expr $numLines + $numSpaceLines]
			}
			if {$fRS && ($prevRightGroupePin != "")} {
				incr iRS
				set arrayLineRightShield($iRS) [expr $numLines + $numSpaceLines]
			}
			if {$fLC && ($prevLeftConnector != "")} {
				incr iLC
				set arrayLineLeftConnector($iLC) [expr $numLines + $numSpaceLines]
				incr iLT
				set arrayNameLeftConnector($iLT) $leftConnector
			}
			if {$fRC && ($prevRightConnector != "")} {
				incr iRC
				set arrayLineRightConnector($iRC) [expr $numLines + $numSpaceLines]
				incr iRT
				set arrayNameRightConnector($iRT) $rightConnector
			}
			# Add offset only once when changing any connector
			if {$fLC || $fRC} {
				set numSpaceLines [expr $numSpaceLines + 3]
			} else {
				set numSpaceLines [expr $numSpaceLines + 2]
			}
			if {$fLS} {
				if {$prevLeftGroupePin != ""} {
					incr iLS
				}
				set arrayLineLeftShield($iLS) [expr $numLines + $numSpaceLines]
			}
			if {$fRS} {
				if {$prevRightGroupePin != ""} {
					incr iRS
				}
				set arrayLineRightShield($iRS) [expr $numLines + $numSpaceLines]
			}
			if {$fLC} {
				if {$prevLeftConnector != ""} {
					incr iLC
				}
				set arrayLineLeftConnector($iLC) [expr $numLines + $numSpaceLines]
			}
			if {$fRC} {
				if {$prevRightConnector != ""} {
					incr iRC
				}
				set arrayLineRightConnector($iRC) [expr $numLines + $numSpaceLines]
			}
		}
		# Y of wire
		set Y [expr $StartWireY + $numLines * $StepWireY + $numSpaceLines * $StepWireY]
		# Place left and right OffPage
		if {($WireRightOffset($i) == "") || ($WireRightOffset($i) == 0)} {
			set rightCon $RightConnector($i)
		} else {
			set rightCon ""
		}
		if {($WireLeftOffset($i) == "") || ($WireLeftOffset($i) == 0)} {
			set leftCon $LeftConnector($i)
		} else {
			set leftCon ""
		}
		if {$InOut($i) == "OUT"} {
			# Out OffPage
			PlaceOutOffPageCheck $rightCon $leftCon $Y
		} else {
			# In OffPage
			PlaceInOffPageCheck $rightCon $leftCon $Y
		}
		# Place wire from pin of left connector to pin of right connector
		if {$SignalName($i) != "SPACE"} {
			set WGR [expr {$WireInRightGroupe($i) == "" ? 0 : $WireInRightGroupe($i)}]
			set WGL [expr {$WireInLeftGroupe($i) == "" ? 0 : $WireInLeftGroupe($i)}]
			set WOR [expr {$WireRightOffset($i) == "" ? 0 : $WireRightOffset($i)}]
			set WOL [expr {$WireLeftOffset($i) == "" ? 0 : $WireLeftOffset($i)}]
			set XDR [expr $SpliceRightX - $STEP_XY * 1 - $StepWireY * 3 * $WGR]
			set XDL [expr $SpliceLeftX  + $STEP_XY * 3 + $StepWireY * 3 * $WGL]
			set YDR [expr $Y + $WOR * $StepWireY]
			set YDL [expr $Y + $WOL * $StepWireY]
			set XSR [expr $SpliceRightX - $StepWireY * 3 * $WGR]
			set XSL [expr $SpliceLeftX  + $StepWireY * 3 * $WGL]
			# Horizontal wire with SPLC
			PlaceHorizontalWireWithSPLC $WireLeftOffset($i) $WireRightOffset($i) $WGL $WGR $XSL $XSR $XDL $XDR $Y
			# Place right offset wire
			PlaceRightWireWithOffset $XDR $YDR $Y $WireRightOffset($i)
			# Place left offset wire
			PlaceLeftWireWithOffset $XDL $YDL $Y $WireLeftOffset($i)
			# Left text - color
			set XT $StartLeftTextColorX
			set YT [expr $Y - $STEP_XY]
			set LT [expr $STEP_XY * 10]
			set WT $STEP_XY
			if {$WidthLeftGauge($i) ne ""} {
				set T "$Color($i) $WidthLeftGauge($i)#"
			} else {
				set T "$Color($i)"
			}
			PlaceTextCheck $XT $YT $LT $WT $T 9 TRUE
			# Right text - color
			set XT $StartRightTextColorX
			if {$WidthRightGauge($i) ne ""} {
				set T "$Color($i) $WidthRightGauge($i)#"
			} elseif {$WidthLeftGauge($i) ne ""} {
				set T "$Color($i) $WidthLeftGauge($i)#"
			} else {
				set T "$Color($i)"
			}
			PlaceTextCheck $XT $YT $LT $WT $T 9 TRUE
			# Middle text - signal name
			set XT $StartMiddleTextColorX
			set LT [expr $STEP_XY * 20]
			PlaceTextCheck $XT $YT $LT $WT $SignalName($i) 9 TRUE
		}
		# Twisted wire
		if {($typePair == 1) && ($numWireTwist == 0)} {
			if {$WireType($i) == 1} {
				set devName "TWS"
			} elseif {$WireType($i) == 2} {
				set devName "TWS_S"
				set X1 [expr $LeftPartX + $STEP_XY]
				set Y1 [expr $Y + $STEP_XY]
				set X2 [expr $LeftPartX - $STEP_XY]
				set Y2 [expr $Y1 + $STEP_XY]
				PlaceWire $X1 $Y1 $X1 $Y2
				if {$numLines < [expr $numWires - 2]} {
					PlaceWire $X1 $Y2 $X2 $Y2
				}
				if {$rightGroupePin != ""} {
					set X1 [expr $RightPartX + $STEP_XY]
					set X2 [expr $RightPartX + 3 * $STEP_XY]
					PlaceWire $X1 $Y1 $X1 $Y2
					if {$numLines < [expr $numWires - 2]} {
						PlaceWire $X1 $Y2 $X2 $Y2
					}
				}
			} else {
				set devName "TWS"
			}
			set Y1 [expr $Y - 3 * $STEP_XY]
			PlacePart $LeftPartX $Y1 $tclLibName $devName "" FALSE
			if {$rightGroupePin != ""} {
				PlacePart $RightPartX $Y1 $tclLibName $devName "" FALSE
			}
		}
		# next wire
		incr numLines
		set prevTypePair $typePair
		set prevLeftGroupePin $leftGroupePin
		set prevRightGroupePin $rightGroupePin
		set prevLeftConnector $leftConnector
		set prevRightConnector $rightConnector
	}
	if {$prevLeftGroupePin != ""} {
		incr iLS
		set arrayLineLeftShield($iLS) [expr $numLines + $numSpaceLines]
	}
	if {$prevRightGroupePin != ""} {
		incr iRS
		set arrayLineRightShield($iRS) [expr $numLines + $numSpaceLines]
	}
	if {$prevLeftConnector != ""} {
		incr iLC
		set arrayLineLeftConnector($iLC) [expr $numLines + $numSpaceLines]
	}
	if {$prevRightConnector != ""} {
		incr iRC
		set arrayLineRightConnector($iRC) [expr $numLines + $numSpaceLines]
	}
	#
	set StartRectangleY [expr $StartWireY - $StepWireY]
	set EndRectangleY [expr $StartRectangleY + $StepWireY * ($numLines + 1)  + $StepWireY * $numSpaceLines]
	set MiddleRectangleY [expr ($StartRectangleY + $EndRectangleY) / 2]
	# Place left rectangle box
	set X [expr 1 * $STEP_XY]
	set Y [expr $StartWireY - 4 * $STEP_XY]
	set L [expr ($numLines + $numSpaceLines + 3) * $StepWireY]
	set W [expr 13 * $STEP_XY]
	PlaceRectangleCheck $X $Y $L $W
	# Place right rectangle box
	set X [expr $EndWireX + 6 * $STEP_XY]
	PlaceRectangleCheck $X $Y $L $W
	# Place left rectangle connectors
	set X [expr $StartWireX - 6 * $STEP_XY]
	PlaceRectangleCheckConnectors arrayLineLeftConnector arrayNameLeftConnector $X
	# Place right rectangle connectors
	set X [expr $EndWireX - $STEP_XY]
	PlaceRectangleCheckConnectors arrayLineRightConnector arrayNameRightConnector $X
	# Place text - name of destination (left)
	set X1 [expr 2 * $STEP_XY]
	set Y1 [expr $MiddleRectangleY - $STEP_XY * 2]
	PlaceTextCheck $X1 $Y1 $L $W $NameLeftSide 19 TRUE
	# Place text - name of source (right)
	set X1 [expr $EndWireX + $STEP_XY * 8]
	set Y1 [expr $MiddleRectangleY - $STEP_XY * 2]
	PlaceTextCheck $X1 $Y1 $L $W $NameRightSide 19 TRUE
	# Place left shields
	PlaceShieldChecks arrayLineLeftShield $ShieldLeftX "LEFT" arrayLineLeftConnector
	# Place right shields
	PlaceShieldChecks arrayLineRightShield $ShieldRightX "RIGHT" arrayLineRightConnector
	
    # Cleanup arrays to prevent memory leaks
    if {[info exists RightConnector]} { array unset RightConnector }
    if {[info exists SignalName]} { array unset SignalName }
    if {[info exists LeftConnector]} { array unset LeftConnector }
    if {[info exists InOut]} { array unset InOut }
    if {[info exists WireType]} { array unset WireType }
    if {[info exists WidthLeftGauge]} { array unset WidthLeftGauge }
    if {[info exists Color]} { array unset Color }
    if {[info exists WidthRightGauge]} { array unset WidthRightGauge }
    if {[info exists WireRightOffset]} { array unset WireRightOffset }
    if {[info exists WireInRightGroupe]} { array unset WireInRightGroupe }
    if {[info exists WireLeftOffset]} { array unset WireLeftOffset }
    if {[info exists WireInLeftGroupe]} { array unset WireInLeftGroupe }
    
    # Cleanup temporary arrays
    catch {array unset arrayLineLeftShield}
    catch {array unset arrayLineRightShield}
    catch {array unset arrayLineLeftConnector}
    catch {array unset arrayLineRightConnector}
    catch {array unset arrayNameLeftConnector}
    catch {array unset arrayNameRightConnector}

	UnSelectAll
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

# Main procedure with global error handling
proc PlaceCable {filePath} {
	SafeLog "Script started"
	global tclLibName pathLib
	global ProjectNumber NameRightSide NameLeftSide PageCount PageNumber
	
	set ProductVersion [GetProductVersion]
	set dot_pos [string first "." $ProductVersion]
	if {$dot_pos != -1} {
		set ver [string range $ProductVersion 0 [expr {$dot_pos - 1}]]
	} else {
		set ver ""
	}
	if {$ver == ""} {
		set ver 24
	} else {
		set ver [expr int($ver)]
	}

	set executableName [info nameofexecutable]
	if {[regexp -nocase {.*(/spb_[^/]+).*} $executableName match fullMatch]} {
		set versionInfo [string trimleft $fullMatch "/"]
		set versionInfo [string toupper $versionInfo]
		set pathLib "C:/CADENCE/$versionInfo/TOOLS/CAPTURE/LIBRARY/CAPSYM.OLB"
	} else {
		set pathLib ""
	}
	set ProjectNumber ""
	set NameRightSide ""
	set NameLeftSide ""
	set PageCount 0
	set PageNumber 0
	set Result true

	# get from file csv pins of connectors
	if {![file exists $filePath]} {
		SafeLog "Error: File does not exist: $filePath"
		set Result false
	}
	if {$Result} {
		if {[catch {open $filePath "r"} fileId]} {
			SafeLog "Error: Cannot open file: $filePath"
			set Result false
		}
	}
	if {$Result} {
		# Count the number of PAGE entries in the CSV file
		while {[gets $fileId line] >= 0} {
			set elements [split $line ","]
			set parName [lindex $elements 0]
			if {$parName == "PAGE"} {
				incr PageCount
			}
		}
		# Reset to file beginning
		seek $fileId 0

		if {$PageCount > 0} {
			SafeLog "Found $PageCount pages in CSV"
			set PageCount [expr $PageCount + 1]
			set PageNumber 2
		} else {
			SafeLog "Pages not found in: $filePath"
			close $fileId
			set Result false
		}
	}
	if {$Result} {
		#SelectPMItem "SCHEMATIC1"
		while {TRUE} {
			set PageName ""
			while {[gets $fileId line] >= 0} {
				set elements [split $line ","]
				set parName [lindex $elements 0]
				set parValue [lindex $elements 1]
				if {[string length $parValue ] > 0} {
					switch -exact $parName {
						"ProjectNumber"   {set ProjectNumber $parValue}
						"NameRightSide"   {set NameRightSide $parValue}
						"NameLeftSide"    {set NameLeftSide $parValue}
						"PAGE"            {set PageName $parValue; break}
						default {SafeLog "Unknown parameter: $parName"}
					}
				}
			}
			if {$PageName ne ""} {
				SafeLog "Processing page: $PageName"
				if {[catch {
					SelectPMItem "SCHEMATIC1/$PageName"
					OPage "SCHEMATIC1" $PageName
					ui::SchematicActivate "/ - (SCHEMATIC1 : $PageName)"

					if {[CheckPageA3Millimeters]} {
						# SafeLog "ERROR: Page must be A3 with millimeter units"
						PlacePage $fileId
					}
				} err]} {
					SafeLog "Error processing page $PageName: $err"
				}
				incr PageNumber
			} else {
				break
			}
		}
		if {$fileId ne ""} {
			if {[catch {close $fileId} err]} {
				SafeLog "Warning: Error closing file: $err"
			}
		}
		UnSelectAll
	}

	SafeLog "Script done!"
}

if {[info exists ::path_to_csv_file]} {
	# Get the directory where the script is located
	set scriptDir [file dirname [info script]]
	# Define the library filename
	set libFileName "TCL_CABLE.OLB"
	# Construct the full path to the library
	set tclLibName [file join $scriptDir $libFileName]
	# Check if the library file exists
	if {[file exists $tclLibName]} {
		PlaceCable $::path_to_csv_file
	} else {
		SafeLog "Error: Library file not found at: $tclLibName"
	}
} else {
	SafeLog "Error: Global variables path_to_csv_file not set!"
}
# Delete global vars
set safeVars {STEP_XY A3_WIDTH A3_HEIGHT StepWireY 
              StartWireY StartWireX EndWireX LeftOffPageX RightOffPageX 
              StartTextPinX offsetNameLeftOffPageX StartMiddleTextColorX 
              SpliceLeftX ShieldLeftX LeftPartX StartLeftTextColorX 
              SpliceRightX ShieldRightX RightPartX StartRightTextColorX 
              tclLibName pathLib ProjectNumber NameRightSide NameLeftSide 
              PageCount PageNumber scriptDir libFileName}

foreach var $safeVars {
	if {[info exists $var]} {
		# puts "unset $var"
		unset $var
	}
}
