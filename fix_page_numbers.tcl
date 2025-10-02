# 2025.06.23
# Page number and page count correction script for OrCAD Capture
# Updates Page Number and Page Count attributes for all pages in the active project
# Menu > Tools > Annotate > Reset Page Numbers (Set Check Box)

proc GetPageNumber { pInstOcc pPage } {
	set PageName [DboTclHelper_sMakeCString]
	$pPage GetName $PageName
	#puts "Reading TitleBlock On Page: [DboTclHelper_sGetConstCharPtr $PageName]"
	set pStatus [DboState]
	set pTBIter [$pPage NewTitleBlocksIter $pStatus]
	set pTB [$pTBIter NextTitleBlock $pStatus]
	set varNullObj NULL
	set strTBPageNumberPropertyValue [DboTclHelper_sMakeCString]
	set strTBPageNumberPropertyName [DboTclHelper_sMakeCString {Page Number}]

	set strTBPageCountPropertyValue [DboTclHelper_sMakeCString]
	set strTBPageCountPropertyName [DboTclHelper_sMakeCString {Page Count}]

	while {$pTB!=$varNullObj} {
		set TitleBlockID [$pTB GetId $pStatus]
		set pTitleBlockOcc [$pInstOcc GetTitleBlockOccurrence $TitleBlockID $pStatus]
		if {$pTitleBlockOcc!=$varNullObj} {
			$pTitleBlockOcc GetEffectivePropStringValue $strTBPageNumberPropertyName $strTBPageNumberPropertyValue
			puts "TitleBlock Occurrence Page Number: [DboTclHelper_sGetConstCharPtr $strTBPageNumberPropertyValue]"

			$pTitleBlockOcc GetEffectivePropStringValue $strTBPageCountPropertyName $strTBPageCountPropertyValue
			puts "TitleBlock Occurrence Page Count: [DboTclHelper_sGetConstCharPtr $strTBPageCountPropertyValue]"

		} else {
			$pTB GetEffectivePropStringValue $strTBPageNumberPropertyName $strTBPageNumberPropertyValue
			puts "TitleBlock Instance Page Number: [DboTclHelper_sGetConstCharPtr $strTBPageNumberPropertyValue]"
		}
		set pTB [$pTBIter NextTitleBlock $pStatus]
	}
	delete_DboPageTitleBlocksIter $pTBIter
	$pStatus -delete
	set PageNumber [DboTclHelper_sGetConstCharPtr $strTBPageNumberPropertyValue]
	return $PageNumber
}

proc GetTitleBlockPageNumber { pDboInstOcc pSchematicObj } {
	set pStatus [DboState]
	set pPagesIter [$pSchematicObj NewPagesIter $pStatus]
	set pPage [$pPagesIter NextPage $pStatus]
	set varNullObj NULL
	while {$pPage!=$varNullObj} {
		set PageNumber [GetPageNumber $pDboInstOcc $pPage]
		set pPage [$pPagesIter NextPage $pStatus]
	}
	delete_DboSchematicPagesIter $pPagesIter
	$pStatus -delete
	return $PageNumber
}

proc FixPageNumbers {} {
    puts "Start script."
    # Initialize status object
    set lSession $::DboSession_s_pDboSession
    DboSession -this $lSession
    set lStatus [DboState]
    set lNullObj NULL

    set lDesignsIter [$lSession NewDesignsIter $lStatus]
    #get the first design
    set lDesign [$lDesignsIter NextDesign $lStatus]
    if {$lDesign == $lNullObj} {
        puts "Error: No design found in the project."
        return
    }    

    set lSchematicIter [$lDesign NewViewsIter $lStatus $::IterDefs_SCHEMATICS]
    #get the first schematic view
    set lView [$lSchematicIter NextView $lStatus]
    if {$lView == $lNullObj} {
        puts "Error: No schematic view found in the design."
        return
    }
    set lSchematic [DboViewToDboSchematic $lView]

    set lPagesIter [$lSchematic NewPagesIter $lStatus]
    #get the first page
    set lPage [$lPagesIter NextPage $lStatus]
    set lCount 0
    while {$lPage!=$lNullObj} {
        # Calculate Count Page
        incr lCount
        #get the next page
        set lPage [$lPagesIter NextPage $lStatus]
    }
    delete_DboSchematicPagesIter $lPagesIter

    # Total number of pages
    if {$lCount == 0} {
        puts "Error: No pages found in the project."
        return
    }
    puts "Total pages found: $lCount"

    set nameCStr [DboTclHelper_sMakeCString]
    set lPagesIter [$lSchematic NewPagesIter $lStatus]
    #get the first page
    set lPage [$lPagesIter NextPage $lStatus]
    set lNumPage 1
    while {$lPage!=$lNullObj} {
        puts "Processing Page $lNumPage"
        $lPage GetName $nameCStr
        puts $lPage


                # # 3.2.22
                # # set lPropsIter [$lObject NewDisplayPropsIter $lStatus]
                # set lPropsIter [$lPage NewDisplayPropsIter $lStatus]
                # #get the first display property on the object 
                # set lDProp [$lPropsIter NextProp $lStatus] 
                # puts "DisplayProp $lDProp"
                # while {$lDProp !=$lNullObj } {
                #     #get the name
                #     set lName [DboTclHelper_sMakeCString]
                #     $lDProp GetName $lName
                #     puts "DisplayPropName $lDProp"
                #     # #get the location
                #     # set lLocation [$lDProp GetLocation $lStatus]
                #     # #get the rotation
                #     # set lRot  [$lDProp GetRotation $lStatus]
                #     # #get the font
                #     # set lFont [DboTclHelper_sMakeLOGFONT]
                #     # set lStatus [$lDProp GetFont $::DboLib_DEFAULT_FONT_PROPERTY $lFont]
                #     # #get the color
                #     # set lColor [$lDProp GetColor $lStatus]
                #     #get the next display property on the object
                #     set lDProp [$lPropsIter NextProp $lStatus]
                # }
                # delete_DboDisplayPropsIter $lPropsIter 

        break

        incr lNumPage
        #get the next page
        set lPage [$lPagesIter NextPage $lStatus]
    }
    delete_DboSchematicPagesIter $lPagesIter



    # Iterate over occurrences
    DboDesignOccurrencesIter iterOccs $lDesign
    set lDboInstOcc [iterOccs NextOccurrence $lStatus]
    set lView [$lDboInstOcc GetContents $lStatus]
    # if {$lView!=$lNullObj && [$lView GetObjectType]==9} { 
        set lSchematicObj [DboViewToDboSchematic $lView]
        set PageNumber [GetTitleBlockPageNumber $lDboInstOcc $lSchematicObj]
        puts "Page Number: $PageNumber"
    # }

    puts "Script done."
}

# Execute the procedure
# source d:/py_proj/orcad/fix_page_numbers.tcl
FixPageNumbers
