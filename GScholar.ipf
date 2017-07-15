#pragma TextEncoding = "MacRoman"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Menu "Macros"
	"Google Scholar",  GScholar()
End

Function GScholar()
	CoastClear()
	GScholarLoad()
	MakePaperWaves()
	GainDays()
End

// Loads the concatenated output from scholar.py
// files are |-delimited. Columns are
// title, url, year, num_citations, num_versions, cluster_id
// url_pdf, url_citations, url_versions, url_citation, excerpt
// We need num_citations (3) and cluster_id (5)
Function GScholarLoad()

	String expDiskFolderName
	String FileList, ThisFile
	Variable FileLoop, nWaves, i
	
	NewPath/O/Q/M="Please find disk folder" ExpDiskFolder
	if (V_flag!=0)
		DoAlert 0, "Disk folder error"
		Return -1
	endif
	PathInfo /S ExpDiskFolder
	ExpDiskFolderName = S_path
	FileList=IndexedFile(expDiskFolder,-1,".csv")
	FileList = RemoveFromList("a.csv;b.csv;c.csv",FileList) // remove three csv files from list
	FileList = SortList(FileList, ";", 16) // alphanumeric sort
	Variable nFiles=ItemsInList(FileList)
	
	Make/O/T/N=(nFiles) DateNameWave
	Make/O/D/N=(nFiles) DateWave
	String DateName
	String w0Name,new0Name,w1Name,new1Name
	String gExp = "([0-9]{4})([0-9]{2})([0-9]{2})"
	String yy, mm, dd
	
	for (FileLoop = 0; FileLoop < nFiles; FileLoop += 1)
		ThisFile = StringFromList(FileLoop, FileList)
		if(stringmatch(ThisFile,"all*") == 1)
			// load file
			LoadWave/Q/O/J/V={"|","",0,0}/K=2/A=colW/L={0,0,0,3,3}/P=expDiskFolder ThisFile
			DateName = ReplaceString("all_",RemoveEnding(ThisFile,".csv"),"")
			// store date name string
			DateNameWave[fileLoop] = DateName
			// recover year month and day
			SplitString/E=(gExp) DateName, yy, mm, dd
			// store date as secs
			DateWave[FileLoop] = date2secs(str2num(yy),str2num(mm),str2num(dd))
			
			w0Name = "colW0"
			new0Name = "cites_" + num2str(FileLoop)
			Duplicate/O $w0Name, $new0Name
			w1Name = "colW2"
			new1Name = "cID_" + num2str(FileLoop)
			Duplicate/O $w1Name, $new1Name
			KillWaves/Z colW0,colW1,colW2
		endif
	endfor
	// turn date wave into date/time
	SetScale d 0, 0, "dat", DateWave
	ConvertCiteWavesToNum()
End

Function ConvertCiteWavesToNum()
	String wList = Wavelist("cites_*",";","")
	Variable nWaves = ItemsInList(wList)
	String wName, newName
	
	Variable i
	
	for(i = 0; i < nWaves; i += 1)
		wName = StringFromList(i,wList)
		Wave/T w0 = $wName
		newName = ReplaceString("cites", wName, "nCite")
		Make/O/N=(numpnts(w0)) $newName = str2num(w0)
		KillWaves/Z w0
	endfor
End

Function MakePaperWaves()
	// list of clusterIDs of interest
	String cIDs = "15016173950428410821;9683765884842198319;18296739081634239386;9626759100164550994;"
	cIDs += "16351400673776359794;1428264735233095967;16834745983320948300;14753446495254825137;"
	cIDs += "4300564388808868235;9366596329566996471;16143921973158212529;17814647050957940888;"
	cIDs += "7511796437554982836;1165698395370563763;6427778225997804242;14239200322071222711;"
	cIDs += "6195075383529016357;5343832766970681357;6316885609950876132;13352287978519560001;"
	cIDs += "12105781357910787575;13028245803754308570;4906842635897699268;6395799916693880124;"
	cIDs += "13742050712244743062;2831756297338412540;15828437071410686488;16351337942836930429;"
	cIDs += "5185159510213035770;5518681586324239709;"
	Variable nPapers = ItemsInList(cIDs)
	Make/O/N=(nPapers)/T MasterCIDWave
	Make/O/N=(nPapers) orderWave, outkeyW = p
	String cIDstr
	
	String nCiteList = WaveList("nCite_*",";","")
	Variable nDays = ItemsInList(nCiteList)
	String NCName, wName, cIDName, newName, axisName
	
	Variable i, j
	
	for(i = 0; i < nPapers; i += 1)
		// this is the paper we'll get cites for
		cIDstr = StringFromList(i,cIDs)
		// store cluster ID so we know from indexing which wave corresponds to which paper
		MasterCIDWave[i] = cIDstr
		// make a wave to store cites per day for each paper
		wName = "pCite_" + num2str(i)
		Make/O/N=(nDays) $wName
		Wave w0 = $wName
		for(j = 0; j < nDays; j += 1)
			// work through the days we have data for
			nCName = StringFromList(j,nCiteList)
			Wave nCw = $nCName
			cIDName = ReplaceString("nCite",nCName,"cID")
			Wave/T cIDw = $cIDName
			// find which row corresponds to the paper
			FindValue/TEXT=cIDstr cIDw
			// put citation in at correct day
			if(V_Value < 0)
//				w0[j] = NaN
				if(j > 0)
					w0[j] = w0[j-1]
				else
					w0[j] = 0
				endif
			else
				w0[j] = nCw[V_Value]
			endif
		endfor
	endfor
	
	for(i = 0; i < nDays; i += 1)
		// the waves we've taken the data from
		nCName = StringFromList(i,nCiteList)
		cIDName = ReplaceString("nCite",nCName,"cID")
		KillWaves/Z $nCName,$cIDName
	endfor
	
	String wList = WaveList("pCite_*",";","")
	nPapers = ItemsInList(wList)
	WAVE DateWave
	KillWindow/Z paperPlot
	Display/N=paperPlot/W=(50,50,500,900)
	// load colortablewave
	LoadNiceCTableW()
	Variable bVar,tVar,lowVar=0,highVar=0,limVar
	
	for(i = 0; i < nPapers; i += 1)
		wName = StringFromList(i, wList)
		Wave w0 = $wName
		newName = ReplaceString("pCite",wName,"normCite")
		Duplicate/O $wName, $newName
		Wave w1 = $newName
		w1 -= w0[0]
		bVar = wavemin(w1)
		tVar = wavemax(w1)
		if(bVar < lowVar)
			lowVar = bVar
		endif
		if(tVar > highVar)
			highVar = tVar
		endif
		orderWave[i] = sum(w1)
	endfor
	
	WAVE normCite_0
	Duplicate/O normCite_0,zeroW
	zeroW = 0
	
	limVar = max(highVar,sqrt(lowVar^2))
	
	// sort list into the net change at end of wave
	Sort orderWave, orderWave,outkeyW
	wList = ""
	
	for(i = 0; i < nPapers; i += 1)
		//construct list of waves in the right order
		wName = "pCite_" + num2str(outkeyW[i])
		wList += wName + ";"
	endfor
	
	// now plot them out
	for(i = 0; i < nPapers; i += 1)
		wName = StringFromList(i, wList)
		newName = ReplaceString("pCite",wName,"normCite")
		Wave w1 = $newName
		axisName = "axis" + num2str(i)
		// add zero line
		AppendToGraph/W=paperPlot/L=$axisName zeroW vs DateWave
		AppendToGraph/W=paperPlot/L=$axisName $newName vs DateWave
		ModifyGraph/W=paperPlot zColor($newName)={$newName,-limVar,limVar,ctableRGB,0,:Packages:ColorTables:Moreland:SmoothCoolWarm256}
		ModifyGraph/W=paperPlot lsize($newName)=2
		ModifyGraph/W=paperPlot margin(left)=45
	endfor
	
	// scale axes
	for(i = 0; i < nPapers; i += 1)
		axisName = "axis" + num2str(i)
		ModifyGraph/W=paperPlot axisEnab($axisName)={i * (1/nPapers),(i + 1) * (1/nPapers)}
		ModifyGraph/W=paperPlot noLabel($axisName)=2,axThick($axisName)=0,standoff(axis0)=0
		SetAxis/W=paperPlot $axisName -limVar,limVar
	endfor
	
	// make zero line look good
	String zList = TraceNameList("paperPlot",";",1)
	Variable nZ = ItemsInList(zList)
	String zName
	
	for(i = 0; i < nZ; i += 1)
		zName = StringFromList(i,zList)
		if(stringmatch(zName,"zero*") == 1)
			ModifyGraph/W=paperPlot lstyle($zName)=1,rgb($zName)=(56797,56797,56797)
		endif
	endfor
	
	ModifyGraph/W=paperPlot standoff=0
End


///////////////////////////////////////////////
Function CoastClear()
	String fullList = WinList("*", ";","WIN:3")
	Variable allItems = ItemsInList(fullList)
	String name
	Variable i
 
	for(i = 0; i < allItems; i += 1)
		name = StringFromList(i, fullList)
		DoWindow/K $name		
	endfor
	
	// Look for data folders
	DFREF dfr = GetDataFolderDFR()
	allItems = CountObjectsDFR(dfr, 4)
	for(i = 0; i < allItems; i += 1)
		name = GetIndexedObjNameDFR(dfr, 4, i)
		KillDataFolder $name		
	endfor
	
	KillWaves/A/Z
End

Function LoadNiceCTableW()
	NewDataFolder/O root:Packages
	NewDataFolder/O root:Packages:ColorTables
	String/G root:Packages:ColorTables:oldDF = GetDataFolder(1)
	NewDataFolder/O/S root:Packages:ColorTables:Moreland
	LoadWave/H/O/P=Igor ":Color Tables:Moreland:SmoothCoolWarm256.ibw"
	KillStrings/Z/A
	SetDataFolder root:
	KillStrings/Z root:Packages:ColorTables:oldDF
	KillVariables/Z root:Packages:ColorTables:Moreland:V_flag
End

Function GainDays()
	String wList = WaveList("pCite_*",";","")
	Variable nPapers = ItemsInList(wList)
	String wName, newName
	
	Variable i
	
	for (i = 0; i < nPapers; i += 1)
		wName = StringFromList(i, wList)
		Wave w0 = $wName
		newName = ReplaceString("pCite_",wName,"diffW_")
		Differentiate/METH=1/EP=1 w0 /D=$newName
	endfor
	wList = ReplaceString("pCite_",wList,"diffW_")
	Concatenate/O/KILL wList, matA
	Duplicate/O matA,matB
	matB[][] = (matA[p][q] < 0) ? -matA[p][q]:matA[p][q]
	MatrixOp/O diffZW = sumrows(matB)
	Duplicate/O diffZW, diffYW
	diffYW[] = 0
	KillWaves/Z matA,MatB
	
	WAVE/Z DateWave
	WaveStats/Q diffYW
	Variable limVar = max(V_max,-V_min)
	KillWindow/Z diffPlot
	Display/N=diffPlot/W=(550,50,1050,200) diffYW vs DateWave
	ModifyGraph/W=diffPlot mode=3,marker=19
	ModifyGraph/W=diffPlot zColor(diffYW)={diffZW,-limVar,limVar,ctableRGB,0,:Packages:ColorTables:Moreland:SmoothCoolWarm256}
	ModifyGraph/W=diffPlot noLabel(left)=2,axThick(left)=0,standoff(left)=0
	ModifyGraph/W=diffPlot margin(left)=45

End