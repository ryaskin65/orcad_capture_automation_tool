################################################################################
# 2025.06.19
# Enertec Systems
# Igor R.
#
# How to use:
# 1. Create a CSV file with cable
# 2. In command window execute:
# source "path_to_script.tcl"
# 
#SetOptionBool Journaling TRUE
#SetOptionBool DisplayCommands TRUE
################################################################################

# Global constant
set VERSION_SCRIPT "19/06/2025"
set STEP_XY 2.54
set A3_WIDTH 410
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
 
	################################################################################
	# DrawText - Places text on the schematic at specified coordinates
	#  X, Y - Starting coordinates
	#  L, W - Length and width of text area
	#  T - Text content
	#  S - Font size
	#  B - Bold flag (TRUE/FALSE)
	proc DrawText {X Y L W T S B} {
		#set logfont [DboTclHelper_sMakeLOGFONT "Courier New" 10 0 0 0 400 0 0 0 0 7 0 1 16]
		#Create display property
		#set pNewDispProp [$lInst NewDisplayProp $lStatus $lPropNameCStr $displocation $rotation $logfont $color] 
		#set property as value visible
		#$pNewDispProp SetDisplayType $::DboValue_VALUE_ONLY  
		
		PlaceText $X $Y [expr $X + $L] [expr $Y + $W] $T
		SelectObject $X $Y FALSE
		SetFont "Courier New" $S $B FALSE
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
		global STEP_XY
		global offsetNameLeftOffPageX StartTextPinX pathLib
		global LeftOffPageX RightOffPageX
		set OffPageY [expr $Y - $STEP_XY]
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
		global STEP_XY
		global offsetNameLeftOffPageX StartTextPinX pathLib
		global LeftOffPageX RightOffPageX
		set OffPageY [expr $Y - $STEP_XY]
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
	# Get name of groupe from pin name
	proc GetGroupNameOld {arrPinName idx} {
		set PinName $arrPinName($idx)
		
		if {[string first "/" $pinName] != -1} {
			set parts [split $pinName "/"]
			set beforeSlash [lindex $parts 0]
			set afterSlash [lindex $parts 1]
			if {[regexp {^[A-D][0-9]+$} $afterSlash]} {
				return "$beforeSlash[string range $afterSlash 0 0]"
			} else {
				return $beforeSlash
			}
		}
		return ""
	}

	################################################################################
	# Get name of group from pin name, considering neighboring pins with same letter after slash
	proc GetGroupName {arrPinName idx} {
		set maxIdx [expr {[array size arrPinName] - 1}]
		upvar 1 $arrPinName arr
		# Check if index is valid
		if {![info exists arr($idx)]} {
			puts "Error: Invalid index $idx"
			return ""
		}
		set PinName $arr($idx)
		# Check for empty pin name
		if {$PinName eq ""} {
			return ""
		}
		if {[string first "/" $PinName] != -1} {
			set parts [split $PinName "/"]
			set beforeSlash [lindex $parts 0]
			set afterSlash [lindex $parts 1]
			# Check if afterSlash matches pattern ^[A-D][0-9]+$
			set isValidGroup [regexp {^[A-D][0-9]+$} $afterSlash]
			if {$isValidGroup} {
				set currentLetter [string range $afterSlash 0 0]
				# Check neighboring pins for matching letter after slash
				set sameGroup 0
				# Check previous pin (if not first)
				if {$idx > 0} {
					set prevIdx [expr {$idx - 1}]
					if {[info exists arr($prevIdx)]} {
						set prevPin $arr($prevIdx)
						if {[string first "/" $prevPin] != -1} {
							set prevAfterSlash [lindex [split $prevPin "/"] 1]
							if {[regexp {^[A-D][0-9]+$} $prevAfterSlash]} {
								set prevLetter [string range $prevAfterSlash 0 0]
								if {$prevLetter eq $currentLetter} {
									set sameGroup 1
								}
							}
						}
					}
				}
				# Check next pin (if not last)
				if {$idx < $maxIdx} {
					set nextIdx [expr {$idx + 1}]
					if {[info exists arr($nextIdx)]} {
						set nextPin $arr($nextIdx)
						if {[string first "/" $nextPin] != -1} {
							set nextAfterSlash [lindex [split $nextPin "/"] 1]
							if {[regexp {^[A-D][0-9]+$} $nextAfterSlash]} {
								set nextLetter [string range $nextAfterSlash 0 0]
								if {$nextLetter eq $currentLetter} {
									set sameGroup 1
								}
							}
						}
					}
				}
				# Return group name with letter if same group
				if {$sameGroup} {
					return "$beforeSlash$currentLetter"
				}
			}
			return $beforeSlash
		}
		return ""
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
		global STEP_XY StepWireY StartWireY
		upvar $arrayShield arShield
		upvar $arrayCon arCon
		set arSize [array size arShield]
		for {set i 0} {$i < $arSize} {incr i} {
			if {[expr $i & 1] == 0} {
				set I1 $arShield($i)
				set Y [expr $StartWireY - 3 * $STEP_XY + $I1 * $StepWireY]
			} else {
				set I2 $arShield($i)
				set L [expr ($I2 - $I1) * $StepWireY]
				# Place shield
				if {[findLineInArray arCon $I2]} {
					DrawShield $X $Y $L $sideLeftRight
				} else {
					DrawShield $X $Y $L "DOWN"
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
		# if {[string is integer -strict $XSL] && [string is integer -strict $XSR] &&
		# 	[string is integer -strict $XDL] && [string is integer -strict $XDR] &&
		# 	[string is integer -strict $Y]} {
			global StartWireX EndWireX STEP_XY
			# Horizontal wire with SPLC
			if {($WOL == "") && ($WOR == "")} {
			# Without SPLC
				PlaceWire $StartWireX $Y $EndWireX $Y
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
		# }
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
		global pathLib tclLibName NameRightSide NameLeftSide EditTitleBlock
		global Title DocumentNumber ProjectNumber Revision PageNumber PageCount
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
		} else {
			set leftConnector ""
		}
		set arrayNameLeftConnector($iLT) $leftConnector
		set iRT 0
		if {($WireRightOffset(1) == "") || ($WireRightOffset(1) == 0)} {
			set rightConnector [GetConnectorName $RightConnector(1)]
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
		#NEW ENERTEC TITLE BLOCK
		if {$EditTitleBlock} {
			SelectObject 342.14 276.35 FALSE
			SetProperty {Title} $Title
			SelectObject 349.76 284.48 FALSE
			SetProperty {Doc} $DocumentNumber
			SelectObject 391.41 283.72 FALSE
			SetProperty {Project Number} $ProjectNumber
			SelectObject 410.46 283.72 FALSE
			SetProperty {RevCode} $Revision
			SelectObject 384.30 288.29 FALSE
			SetProperty {Page Number} $PageNumber
			SelectObject 402.34 288.29 FALSE
			SetProperty {Page Count} $PageCount
		}
		UnSelectAll
	}

	################################################################################
	proc drawCable {filePath} {
		global VERSION_SCRIPT tclLibName pathLib
		global EditTitleBlock NameLeftSide NameRightSide
		global Title DocumentNumber ProjectNumber Revision PageNumber PageCount
		set ProductVersion [GetProductVersion]
		set dot_pos [string first "." $ProductVersion]
		if {$dot_pos != -1} {
			set ver [string range $ProductVersion 0 [expr {$dot_pos - 1}]]
		} else {
		    # set ver 17
			set ver ""
		}
		puts "\nStart script Enertec Systems ver. $VERSION_SCRIPT\n"
		set executableName [info nameofexecutable]
		if {[regexp -nocase {.*(/spb_[^/]+).*} $executableName match fullMatch]} {
			set versionInfo [string trimleft $fullMatch "/"]
			set versionInfo [string toupper $versionInfo]
			set pathLib "C:/CADENCE/$versionInfo/TOOLS/CAPTURE/LIBRARY/CAPSYM.OLB"
		} else {
		    # set pathLib "C:/CADENCE/SPB_17.4/TOOLS/CAPTURE/LIBRARY/CAPSYM.OLB"
			set pathLib ""
		}
		set NameRightSide ""
		set NameLeftSide ""
		set Title ""
		set DocumentNumber ""
		set ProjectNumber ""
		set Revision ""
		set PageCount 0
		set PageNumber 0
		set EditTitleBlock FALSE

		# get from file csv pins of connectors
		if {[file exists $filePath]} {
			set fileId [open $filePath "r"]
			set PageCount [CountPagesInCSV $filePath]
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
						"NumberCable"     {set NumberCable $parValue}
						"NameRightSide"   {set NameRightSide $parValue}
						"NameLeftSide"    {set NameLeftSide $parValue}
						"Title"           {set Title $parValue}
						"PartNumber"      {set PartNumber $parValue}
						"DocumentNumber"  {set DocumentNumber $parValue}
						"ProjectNumber"   {set ProjectNumber $parValue}
						"Revision"        {set Revision $parValue}
						"EditTitleBlock"  {set EditTitleBlock $parValue}
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
		foreach var [info vars] {
			if {[info exists $var]} {
				unset $var
			}
		}
		UnSelectAll
		puts "\nScript done!\n"
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

set NameRightSide ""
set NameLeftSide ""
set Title ""
set DocumentNumber ""
set ProjectNumber ""
set Revision ""
set PageCount 0
set PageNumber 0
set EditTitleBlock FALSE

# Example execution
# drawCable "path_to_csv_file"
drawCable "D:/Cables/W402/W402.csv"
