# 2025.10.14
# How to use:
# 1. Create a CSV file with cable
# 2. In command window execute:
# source "path_to_script.tcl"

# Global constant
set VERSION_SCRIPT "14/10/2025"
set STEP_XY 2.54
set A3_WIDTH 417
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
 
#set A3_MARGIN 10
#set MIN_TEXT_AREA 5
#set COORD_CHECK_ENABLED 0
#set ERROR_LOG_ENABLED 1
#set ERROR_LOG_FILE "cable_script_errors.log"

#set tclLibName ""
#set pathLib ""
#set ProjectNumber ""
#set NameRightSide ""
#set NameLeftSide ""
#set PageCount 0
#set PageNumber 0

	################################################################################
	# DrawText - Places text on the schematic at specified coordinates
	#  X, Y - Starting coordinates
	#  L, W - Length and width of text area
	#  T - Text content
	#  S - Font size
	#  B - Bold flag (TRUE/FALSE)
	proc DrawText {X Y L W T S B} {
		global A3_WIDTH A3_HEIGHT
		# Check boundaries
		if {$X < 0 || $X > $A3_WIDTH || $Y < 0 || $Y > $A3_HEIGHT ||
			[expr $X + $L] > $A3_WIDTH || [expr $Y + $W] > $A3_HEIGHT} {
			#puts "Text boundary error: X=$X, Y=$Y, L=$L, W=$W"
			puts "Text boundary error: X=[format "%.2f" $X], Y=[format "%.2f" $Y], L=[format "%.2f" $L], W=[format "%.2f" $W]"
			return
		}		
		PlaceText $X $Y [expr $X + $L] [expr $Y + $W] $T
		SelectObject $X $Y FALSE
		SetFont "Courier New" $S $B FALSE
		# Get the selected text object and update its bounding box
		set selObj [GetSelectedObjects]
        set textInst [DboGraphicInstanceToDboGraphicCommentTextInst $selObj]
        set textDef [$textInst GetDboCommentText]
        if {$textDef != "NULL"} {
            if {[catch {$textDef SetRecalBoundingBox} err]} {
                puts "Warning: SetRecalBoundingBox failed for CommentText: $err"
                $textInst MarkModified
            } else {
                $textInst MarkModified
            }
        }
		UnSelectAll
		return
	}

	################################################################################
	# Draw rectangle
	proc DrawRectangle {X Y L W} {
		global A3_WIDTH A3_HEIGHT
		set X2 [expr $X + $W]
		set Y2 [expr $Y + $L]
		if {($X < 0 && $X > $A3_WIDTH) || ($X2 < 0 && $X2 > $A3_WIDTH) || ($Y < 0 && $Y > $A3_HEIGHT) || ($Y2 < 0 && $Y2 > $A3_HEIGHT)} {
			puts "Position or size error in DrawRectangle"
			return
		}
		PlaceRectangle $X $Y $X2 $Y2
		SetLineStyle 0
		SetLineWidth 1
		UnSelectAll
		return
	}

	################################################################################
	# Draw wire with control
	proc PlaceWireA3 {X1 Y1 X2 Y2} {
		global A3_WIDTH A3_HEIGHT
		# Check if coordinates are numeric
		if {[string is double -strict $X1] && [string is double -strict $Y1] && 
			[string is double -strict $X2] && [string is double -strict $Y2]} {
			# Check if coordinates are within A3 bounds
			if {($X1 < 0) || ($X1 > $A3_WIDTH) || ($X2 < 0) || ($X2 > $A3_WIDTH) || 
				($Y1 < 0) || ($Y1 > $A3_HEIGHT) || ($Y2 < 0) || ($Y2 > $A3_HEIGHT)} {
				puts [format "Position error in PlaceWireA3 X1:%s Y1:%s X2:%s Y2:%s" $X1 $Y1 $X2 $Y2]
			} else {
				PlaceWire $X1 $Y1 $X2 $Y2
			}
		} else {
			puts [format "Non-numeric coordinates in PlaceWireA3 X1:%s Y1:%s X2:%s Y2:%s" $X1 $Y1 $X2 $Y2]
		}
	}

	################################################################################
	# Draw shield
	# L - length, C - wire connection LEFT RIGHT DOWN
	proc DrawShield {X Y L C} {
		global STEP_XY
		set X1 $X
		set Y1 [expr $Y + $STEP_XY]
		set X2 [expr $X1 + 4 * $STEP_XY]
		set Y2 [expr $Y1 + 4 * $STEP_XY]
		set X3 [expr $X1 + 4 * $STEP_XY]
		set Y3 [expr $Y1 + 2 * $STEP_XY]
		set X4 [expr $X1 + 0 * $STEP_XY]
		set Y4 [expr $Y1 + 2 * $STEP_XY]
		PlaceArc $X1 $Y1 $X2 $Y2 $X3 $Y3 $X4 $Y4
		SetLineStyle 2
		set Y1 [expr $Y1 + $L]
		set Y2 [expr $Y2 + $L]
		set Y3 [expr $Y3 + $L]
		set Y4 [expr $Y4 + $L]
		PlaceArc $X1 $Y1 $X2 $Y2 $X3 $Y3 $X4 $Y4
		SetLineStyle 2
		MirrorVertical
		set Y1 [expr $Y + 3 * $STEP_XY]
		set X2 [expr $X + 4 * $STEP_XY]
		set Y2 [expr $Y1 + $L - 2 * $STEP_XY]
		PlaceLine $X1 $Y1 $X1 $Y2
		SetLineStyle 2
		PlaceLine $X2 $Y1 $X2 $Y2
		SetLineStyle 2
		UnSelectAll
		switch -exact $C {
			"LEFT" {
				set X1 [expr $X + 2 * $STEP_XY]
				set Y1 [expr $Y + $L + 3 * $STEP_XY]
				set X2 [expr $X - 16 * $STEP_XY]
				set Y2 [expr $Y1 + $STEP_XY]
				PlaceWire $X1 $Y1 $X1 $Y2
				PlaceWire $X1 $Y2 $X2 $Y2
				PlaceWire $X2 $Y2 $X2 $Y1
			}
			"RIGHT" {
				set X1 [expr $X + 2 * $STEP_XY]
				set Y1 [expr $Y + $L + 3 * $STEP_XY]
				set X2 [expr $X + 19 * $STEP_XY]
				set Y2 [expr $Y1 + $STEP_XY]
				PlaceWire $X1 $Y1 $X1 $Y2
				PlaceWire $X1 $Y2 $X2 $Y2
				PlaceWire $X2 $Y2 $X2 $Y1
			}
			"DOWN" {
				set X1 [expr $X + 2 * $STEP_XY]
				set Y1 [expr $Y + $L + 3 * $STEP_XY]
				set Y2 [expr $Y1 + 2 * $STEP_XY]
				PlaceWire $X1 $Y1 $X1 $Y2
			}
			default {}
		}
		if {$X < 100.0} {
		}
		if {$X > 300.0} {
		}
		return
	}

	################################################################################
	# Draw left and right Out OffPage
	proc DrawOutOffPage {SrcCon DstCon Y} {
		global STEP_XY A3_WIDTH A3_HEIGHT
		global offsetNameLeftOffPageX StartTextPinX pathLib
		global LeftOffPageX RightOffPageX
		set OffPageY [expr $Y - $STEP_XY]
		# Check boundaries
		if {$OffPageY < 0 || $OffPageY > $A3_HEIGHT || 
			$LeftOffPageX < 0 || $LeftOffPageX > $A3_WIDTH ||
			$RightOffPageX < 0 || $RightOffPageX > $A3_WIDTH} {
			puts "OffPage coordinates out of bounds: Y=$Y, LeftX=$LeftOffPageX, RightX=$RightOffPageX"
			return
		}
		if {$DstCon > ""} {
			PlaceOffPage $LeftOffPageX $OffPageY $pathLib "OFFPAGELEFT-R" "OFFPAGELEFT-R"
			SetProperty {Name} $DstCon
			SelectObject $StartTextPinX $Y FALSE
			set selObj [GetSelectedObjects]
			$selObj SetLocation [DboTclHelper_sMakeCPoint $offsetNameLeftOffPageX 5]
		}
		if {$SrcCon > ""} {
			PlaceOffPage $RightOffPageX $OffPageY $pathLib "OFFPAGELEFT-L" $SrcCon
		}
	}

	################################################################################
	# Draw left and right In OffPage
	proc DrawInOffPage {SrcCon DstCon Y} {
		global STEP_XY A3_WIDTH A3_HEIGHT
		global offsetNameLeftOffPageX StartTextPinX pathLib
		global LeftOffPageX RightOffPageX
		set OffPageY [expr $Y - $STEP_XY]
		# Check boundaries
		if {$OffPageY < 0 || $OffPageY > $A3_HEIGHT || 
			$LeftOffPageX < 0 || $LeftOffPageX > $A3_WIDTH ||
			$RightOffPageX < 0 || $RightOffPageX > $A3_WIDTH} {
			puts "OffPage coordinates out of bounds: Y=$Y, LeftX=$LeftOffPageX, RightX=$RightOffPageX"
			return
		}
		if {$DstCon > ""} {
			PlaceOffPage $LeftOffPageX $OffPageY $pathLib "OFFPAGELEFT-L" "OFFPAGELEFT-L"
			MirrorHorizontal
			SetProperty {Name} $DstCon
			SelectObject $StartTextPinX $Y FALSE
			set selObj [GetSelectedObjects]
			$selObj SetLocation [DboTclHelper_sMakeCPoint $offsetNameLeftOffPageX 5]
		}
		if {$SrcCon > ""} {
			PlaceOffPage $RightOffPageX $OffPageY $pathLib "OFFPAGELEFT-R" "OFFPAGELEFT-R"
			MirrorHorizontal
			SetProperty {Name} $SrcCon
		}
	}

	################################################################################
	# Draw SPLC
	proc DrawSPLC {X Y} {
		global ver tclLibName STEP_XY A3_WIDTH A3_HEIGHT
		if {[string is double -strict $X] && [string is double -strict $Y]} {
			# Check if coordinates are within A3 bounds
			if {($X < 0) || ($X > $A3_WIDTH) || ($Y < 0) || ($Y > $A3_HEIGHT)} {
				puts [format "Position error in DrawSPLC X:%s Y:%s" $X $Y]
			} else {

				if {$ver > 16} {
					PlacePart $X [expr $Y - $STEP_XY] $tclLibName "SPLC" "" FALSE
				} else {
					PlacePart $X [expr $Y - $STEP_XY/2] $tclLibName "SPLC" "" FALSE
				}
			}
		} else {
			puts [format "Non-numeric coordinates in DrawSPLC X:%s Y:%s" $X $Y]
		}
	}
	
	################################################################################
	# Get group identifier from pin name for cable drawing
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

	################################################################################
	# Get name of connector from pin name
	proc GetConnectorName {pinName} {
		if {[string first "/" $pinName] != -1} {
			set parts [split $pinName "/"]
			return [lindex $parts 0]
		}
		return ""
	}

	################################################################################
	proc DrawRectangleConnectors {arrayCon arrayNameCon X} {
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
				# Checking if a rectangle needs to be drawn
				if {$arNameCon($it) != ""} {
					DrawRectangle $X $Y $L $W
					# Place the text - connector name
					set XT [expr $X + $STEP_XY * 2]
					set YT [expr $Y - $STEP_XY * 2]
					DrawText $XT $YT $LT $WT $arNameCon($it) 19 TRUE
				}
				incr it
			}
		}
	}

	################################################################################
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

	################################################################################
	proc DrawShields {arrayShield X sideLeftRight arrayCon} {
		global STEP_XY StepWireY StartWireY A3_WIDTH A3_HEIGHT
		upvar $arrayShield arShield
		upvar $arrayCon arCon
		
		# Check if X coordinate is within bounds
		if {$X < 0 || $X > $A3_WIDTH} {
			puts "Shield X coordinate out of bounds: $X"
			return
		}
		
		set arSize [array size arShield]
		for {set i 0} {$i < $arSize} {incr i} {
			if {[expr $i & 1] == 0} {
				set I1 $arShield($i)
				set Y [expr $StartWireY - 3 * $STEP_XY + $I1 * $StepWireY]
				
				# Check Y coordinate
				if {$Y < 0 || $Y > $A3_HEIGHT} {
					puts "Shield Y coordinate out of bounds: $Y"
					continue
				}
			} else {
				set I2 $arShield($i)
				set L [expr ($I2 - $I1) * $StepWireY]
				
				# Check if shield length is reasonable
				if {$L < 0 || $L > $A3_HEIGHT} {
					puts "Shield length out of bounds: $L"
					continue
				}
				
				# Place shield with error handling
				if {[catch {
					if {[findLineInArray arCon $I2]} {
						DrawShield $X $Y $L $sideLeftRight
					} else {
						DrawShield $X $Y $L "DOWN"
					}
				} err]} {
					puts "Error drawing shield at X=$X, Y=$Y: $err"
				}
			}
		}
	}

	################################################################################
	proc DrawRightWireWithOffset {XDR YD Y Offset} {
		if {[string is integer -strict $Offset]} {
			global STEP_XY
			# Right wire with offset (up or down)
			if {$Offset > 0} {
				# !!!Top and right side!!!
				# Vertical wire
				PlaceWireA3 $XDR [expr $Y + $STEP_XY] $XDR [expr $YD - $STEP_XY]
				# First slant - close Y
				PlaceWireA3 [expr $XDR - $STEP_XY] $Y $XDR [expr $Y + $STEP_XY]
				# Second slant - close YD
				PlaceWireA3 $XDR [expr $YD - $STEP_XY] [expr $XDR + $STEP_XY] $YD
			} elseif {$Offset < 0} {
				# !!!Bottom and right side!!!
				# Vertical wire
				PlaceWireA3 $XDR [expr $Y - $STEP_XY] $XDR [expr $YD + $STEP_XY]
				# First slant - close Y
				PlaceWireA3 [expr $XDR - $STEP_XY] $Y $XDR [expr $Y - $STEP_XY]
				# Second slant - close YD
				PlaceWireA3 $XDR [expr $YD + $STEP_XY] [expr $XDR + $STEP_XY] $YD
			}
		}
	}

	################################################################################
	proc DrawLeftWireWithOffset {XDL YD Y Offset} {
		if {[string is integer -strict $Offset]} {
			global STEP_XY
			# Left wire with offset (up or down)
			if {$Offset > 0} {
				# !!!Top and left side!!!
				# Vertical wire
				PlaceWireA3 $XDL [expr $Y + $STEP_XY] $XDL [expr $YD - $STEP_XY]
				# First slant - close Y
				PlaceWireA3 [expr $XDL + $STEP_XY] $Y $XDL [expr $Y + $STEP_XY]
				# Second slant - close YD
				PlaceWireA3 $XDL [expr $YD - $STEP_XY] [expr $XDL - $STEP_XY] $YD
			} elseif {$Offset < 0} {
				# !!!Bottom and left side!!!
				# Vertical wire
				PlaceWireA3 $XDL [expr $Y - $STEP_XY] $XDL [expr $YD + $STEP_XY]
				# First slant - close Y
				PlaceWireA3 [expr $XDL + $STEP_XY] $Y $XDL [expr $Y - $STEP_XY]
				# Second slant - close YD
				PlaceWireA3 $XDL [expr $YD + $STEP_XY] [expr $XDL - $STEP_XY] $YD
			}
		}
	}

	################################################################################
	proc DrawHorizontalWireWithSPLC {WOL WOR WGL WGR XSL XSR XDL XDR Y} {
		global StartWireX EndWireX STEP_XY A3_WIDTH A3_HEIGHT
		# Validate all coordinates
		foreach coord [list $XSL $XSR $XDL $XDR $Y $StartWireX $EndWireX] {
			if {![string is double $coord]} {
				puts "Error: Non-numeric coordinate in DrawHorizontalWireWithSPLC: $coord"
				return
			}
		}
		# Check boundaries
		if {$Y < 0 || $Y > $A3_HEIGHT || $StartWireX < 0 || $EndWireX > $A3_WIDTH} {
			puts "Error: Coordinates out of bounds in DrawHorizontalWireWithSPLC: Y=$Y, StartX=$StartWireX, EndX=$EndWireX"
			return
		}
		# Horizontal wire with SPLC
		if {($WOL == "") && ($WOR == "")} {
		# Without SPLC
			if {[catch {PlaceWire $StartWireX $Y $EndWireX $Y} err]} {
				puts "Error placing wire: $err"
			}
		} elseif {($WOR == 0) && ($WOL != 0)} {
		# Right SPLC
			DrawSPLC $XSR $Y
			PlaceWireA3 [expr $XSR + 2 * $STEP_XY] $Y $EndWireX $Y
			if {$WOL == ""} {
				PlaceWireA3 $StartWireX $Y $XSR $Y
			} else {
				PlaceWireA3 [expr $XDL + $STEP_XY] $Y $XSR $Y
			}
		} elseif {($WOR != 0) && ($WOL == 0)} {
		# Left SPLC
			DrawSPLC $XSL $Y
			PlaceWireA3 $StartWireX $Y $XSL $Y
			if {$WOR == ""} {
				PlaceWireA3 [expr $XSL + 2 * $STEP_XY] $Y $EndWireX $Y
			} else {
				PlaceWireA3 [expr $XSL + 2 * $STEP_XY] $Y [expr $XDR - $STEP_XY] $Y
			}
		} elseif {($WOR == 0) && ($WOL == 0)} {
		# Right and left SPLC
			DrawSPLC $XSL $Y
			DrawSPLC $XSR $Y 
			PlaceWireA3 $StartWireX $Y $XSL $Y
			PlaceWireA3 [expr $XSL + 2 * $STEP_XY] $Y $XSR $Y
			PlaceWireA3 [expr $XSR + 2 * $STEP_XY] $Y $EndWireX $Y
		} elseif {($WOR != "") && ($WOL == "")} {
		# Right wire up or down: horizontal -> slant -> vertical -> slant
			PlaceWireA3 $StartWireX $Y [expr $XDR - $STEP_XY] $Y
		} elseif {($WOR == "") && ($WOL != "")} {
		# Left wire up or down: horizontal -> slant -> vertical -> slant
			PlaceWireA3 [expr $XDL + $STEP_XY] $Y $EndWireX $Y
		} elseif {($WOR != "") && ($WOL != "")} {
		# Right and left wire up or down: horizontal -> slant -> vertical -> slant
			PlaceWireA3 [expr $XDL + $STEP_XY] $Y [expr $XDR - $STEP_XY] $Y
		}
	}

	################################################################################
	# Count the number of PAGE entries in the CSV file
	proc CountPagesInCSV {filePath} {
		if {![file exists $filePath]} {
			puts "Error: File does not exist: $filePath"
			return 0
		}
		set fileId [open $filePath "r"]
		set pageCount 0
		while {[gets $fileId line] >= 0} {
			set elements [split $line ","]
			set parName [lindex $elements 0]
			if {$parName == "PAGE"} {
				incr pageCount
			}
		}
		close $fileId
		return $pageCount
	}

	################################################################################
	proc DrawPage {fileId} {
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
			# Draw left and right OffPage
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
				DrawOutOffPage $rightCon $leftCon $Y
			} else {
				# In OffPage
				DrawInOffPage $rightCon $leftCon $Y
			}
			# Draw wire from pin of left connector to pin of right connector
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
				DrawHorizontalWireWithSPLC $WireLeftOffset($i) $WireRightOffset($i) $WGL $WGR $XSL $XSR $XDL $XDR $Y
				# Draw right offset wire
				DrawRightWireWithOffset $XDR $YDR $Y $WireRightOffset($i)
				# Draw left offset wire
				DrawLeftWireWithOffset $XDL $YDL $Y $WireLeftOffset($i)
				# Left text - color
				set XT $StartLeftTextColorX
				set YT [expr $Y - $STEP_XY]
				set LT [expr $STEP_XY * 10]
				set WT $STEP_XY
				if {$WidthLeftGauge($i) > ""} {
					set T "$Color($i) $WidthLeftGauge($i)#"
				} else {
					set T "$Color($i)"
				}
				DrawText $XT $YT $LT $WT $T 9 TRUE
				# Right text - color
				set XT $StartRightTextColorX
				if {$WidthRightGauge($i) > ""} {
					set T "$Color($i) $WidthRightGauge($i)#"
				} elseif {$WidthLeftGauge($i) > ""} {
					set T "$Color($i) $WidthLeftGauge($i)#"
				} else {
					set T "$Color($i)"
				}
				DrawText $XT $YT $LT $WT $T 9 TRUE
				# Middle text - signal name
				set XT $StartMiddleTextColorX
				set LT [expr $STEP_XY * 20]
				DrawText $XT $YT $LT $WT $SignalName($i) 9 TRUE
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
		DrawRectangle $X $Y $L $W
		# Place right rectangle box
		set X [expr $EndWireX + 6 * $STEP_XY]
		DrawRectangle $X $Y $L $W
		# Draw left rectangle connectors
		set X [expr $StartWireX - 6 * $STEP_XY]
		DrawRectangleConnectors arrayLineLeftConnector arrayNameLeftConnector $X
		# Draw right rectangle connectors
		set X [expr $EndWireX - $STEP_XY]
		DrawRectangleConnectors arrayLineRightConnector arrayNameRightConnector $X
		# Place text - name of destination (left)
		set X1 [expr 2 * $STEP_XY]
		set Y1 [expr $MiddleRectangleY - $STEP_XY * 2]
		DrawText $X1 $Y1 $L $W $NameLeftSide 19 TRUE
		# Place text - name of source (right)
		set X1 [expr $EndWireX + $STEP_XY * 8]
		set Y1 [expr $MiddleRectangleY - $STEP_XY * 2]
		DrawText $X1 $Y1 $L $W $NameRightSide 19 TRUE
		# Draw left shields
		DrawShields arrayLineLeftShield $ShieldLeftX "LEFT" arrayLineLeftConnector
		# Draw right shields
		DrawShields arrayLineRightShield $ShieldRightX "RIGHT" arrayLineRightConnector
		#
		UnSelectAll
	}

	################################################################################
	proc SafeLog {message} {
		set timestamp [clock format [clock seconds] -format "%Y.%m.%d %H:%M:%S"]
		set logEntry "$timestamp - $message"
		puts "LOG: $logEntry"
		catch {
			set fileId [open "script_safe.log" "a"]
			puts $fileId $logEntry
			close $fileId
		}
	}

	################################################################################
	# Main procedure with global error handling
	proc drawCable {filePath} {
		SafeLog "Script started"
		global VERSION_SCRIPT tclLibName pathLib
		global ProjectNumber NameRightSide NameLeftSide PageCount PageNumber
		
		set ProductVersion [GetProductVersion]
		set dot_pos [string first "." $ProductVersion]
		if {$dot_pos != -1} {
			set ver [string range $ProductVersion 0 [expr {$dot_pos - 1}]]
		} else {
			set ver ""
		}
		puts "\nStart script cable draw ver. $VERSION_SCRIPT\n"
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

		# get from file csv pins of connectors
		if {[file exists $filePath]} {
			set fileId [open $filePath "r"]
			set PageCount [CountPagesInCSV $filePath]
			close $fileId 
			if {$PageCount > 0} {
				puts "Found $PageCount pages in CSV"
				set PageCount [expr $PageCount + 1]
				set PageNumber 2
			} else {
				puts "Pages not found in: $filePath"
				return
			}
			set fileId [open $filePath "r"]
		} else {
			puts "File does not exist: $filePath"
			return
		}
		
		#SelectPMItem "SCHEMATIC1"
		while {TRUE} {
			set PageName ""
			while {[gets $fileId line] >= 0} {
				set elements [split $line ","]
				set parName [lindex $elements 0]
				set parValue [lindex $elements 1]
				if {$parValue > ""} {
					switch -exact $parName {
						"ProjectNumber"   {set ProjectNumber $parValue}
						"NameRightSide"   {set NameRightSide $parValue}
						"NameLeftSide"    {set NameLeftSide $parValue}
						"PAGE"            {set PageName $parValue; break}
						default {puts "Unknown parameter: $parName"}
					}
				}
			}
			if {$PageName > ""} {
				puts "Processing page: $PageName"
				if {[catch {
					SelectPMItem "SCHEMATIC1/$PageName"
					OPage "SCHEMATIC1" $PageName
					ui::SchematicActivate "/ - (SCHEMATIC1 : $PageName)"
					DrawPage $fileId
				} err]} {
					puts "Error processing page $PageName: $err"
				}
				incr PageNumber
			} else {
				break
			}
		}
		close $fileId
		
		# Delete all vars
		set safeVars {VERSION_SCRIPT STEP_XY A3_WIDTH A3_HEIGHT StepWireY 
					  StartWireY StartWireX EndWireX LeftOffPageX RightOffPageX 
					  StartTextPinX offsetNameLeftOffPageX StartMiddleTextColorX 
					  SpliceLeftX ShieldLeftX LeftPartX StartLeftTextColorX 
					  SpliceRightX ShieldRightX RightPartX StartRightTextColorX 
					  tclLibName pathLib ProjectNumber NameRightSide NameLeftSide 
					  PageCount PageNumber}

		foreach var $safeVars {
			if {[info exists $var]} {
				unset $var
			}
		}
		UnSelectAll
		SafeLog "Script done!"
		set currentDir [pwd]
		puts "\nLog file location: $currentDir/script_safe.log\n"
	}

# Path to libraty
# Get the directory where the script is located
set scriptDir [file dirname [info script]]
# Define the library filename
set libFileName "TCL_CABLE.OLB"
# Construct the full path to the library
set tclLibName [file join $scriptDir $libFileName]
# Check if the library file exists
if {[file exists $tclLibName]} {
    # Library found, proceed with the script
    puts "INFO: Library found at: $tclLibName"
} else {
    # Library not found, display an error message
    puts "ERROR: Library file not found at: $tclLibName"
    puts "INFO: Please ensure the file '$libFileName' exists in the script directory."
	return
}

set ProjectNumber ""
set NameRightSide ""
set NameLeftSide ""
set PageCount 0
set PageNumber 0

# Example execution
# drawCable "path_to_csv_file"
drawCable "D:/py/Git_OrCAD/data/W203.csv"
