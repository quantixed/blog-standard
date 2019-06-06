#pragma TextEncoding = "MacRoman"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Menu "Macros"
	"Google Scholar",  GScholar()
End

Function GScholar()
	CoastClear()
	if(GScholarLoad() == -1)
		return -1
	endif
	MakePaperWaves()
	GainDays()
	PlotTogether()
	MakeTheLayout()
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
	Make/O/D/N=(nFiles) DateWave = NaN
	String DateName
	String w0Name,new0Name,w1Name,new1Name,w2Name,new2Name
	String gExp = "([0-9]{4})([0-9]{2})([0-9]{2})"
	String yy, mm, dd
	
	for (FileLoop = 0; FileLoop < nFiles; FileLoop += 1)
		ThisFile = StringFromList(FileLoop, FileList)
		if(stringmatch(ThisFile,"all*") == 1)
			GetFileFolderInfo/P=expDiskFolder/Q/Z ThisFile
			if(V_logEOF > 0)
				// load file
				LoadWave/Q/O/J/V={"|","",0,0}/K=2/A=colW/L={0,0,0,0,6}/P=expDiskFolder ThisFile
				DateName = ReplaceString("all_",RemoveEnding(ThisFile,".csv"),"")
				// store date name string
				DateNameWave[fileLoop] = DateName
				// recover year month and day
				SplitString/E=(gExp) DateName, yy, mm, dd
				// store date as secs
				DateWave[FileLoop] = date2secs(str2num(yy),str2num(mm),str2num(dd))
				w0Name = "colW3"
				new0Name = "cites_" + num2str(FileLoop)
				Duplicate/O $w0Name, $new0Name
				w1Name = "colW5"
				new1Name = "cID_" + num2str(FileLoop)
				Duplicate/O $w1Name, $new1Name
				w2Name = "colW0"
				new2Name = "title_" + num2str(FileLoop)
				Duplicate/O $w2Name, $new2Name
				KillWaves/Z colW0,colW1,colW2,colW3,colW4,colW5
			endif
		endif
	endfor
	// in case a file was skipped (because it contained no data), remove the point(s)
	WaveTransform zapnans DateWave
	// turn date wave into date/time
	SetScale d 0, 0, "dat", DateWave
	// get a list of valid clusterIDs
	GetValidClusterIDs()
	ConvertCiteWavesToNum()
End

STATIC Function GetValidClusterIDs()
	Concatenate/O/NP=0/T WaveList("cID_*",";",""), everyClusterID
	FindDuplicates/RT=uniquecIDs everyClusterID
	WAVE/Z/T uniquecIDs
	// this is a list of all the erroneous hits to other people's papers that appear from time to time
	// make a table of MastCIDWave and MasterTitleWave to check the quality of the output
	String wrongCIDs = "12832797694134823393;8424969549686024317;17482797509563845925;18306591328074272968;10013295782066828040;2125655142589813572;3558958992820286199;"
	wrongCIDs += "14246648383530238504;49600189508354987;12170316177373808744;15022890458582764547;6990621657316245383;17737068528487516800;2643276423443689932;8400244114504009885;16796530880377775351;"
	wrongCIDs += "8172080200369448988;13257412446242505832;6414260879096097898;16561045760721102731;12147859807550400097;3767129554966147446;16064510235057245135;12961542289533037841;1012099057611865473;"
	wrongCIDs += "4637912772477528862;14386248762047904914;16519942760416969381;1401951684347416182;4724021833128122377;6745547896119480000;"
	wrongCIDs += "11500742584022636474;3264686427582431735;6890966404701379000;11100910687997000000;9556249571163400000;None;"
	wrongCIDs += "9556249571163401280;6745547896119489049;11100910687997005551;"
	Variable nCID = numpnts(uniquecIDs)
	Variable wCID = ItemsInList(wrongCIDs)
	String uCID,zCID
	Make/O/N=(nCID)/FREE countWave
	
	Variable i,j
	
	for(i = 0; i < nCID; i += 1)
		uCID = uniquecIDs[i]
		countWave[i] = 1
		for(j = 0; j < wCID; j += 1)
			zCID = StringFromList(j,wrongCIDs)
			if(cmpstr(uCID,zCID) == 0)
				uniquecIDs[i] = ""
				countWave[i] = 0
				break
			endif
		endfor
	endfor
	Sort/R uniquecIDs,uniquecIDs
	Variable vCID = sum(countWave)
	Make/O/N=(vCID)/T MasterCIDWave, MasterTitleWave
	MasterCIDWave[] = uniqueCIDs[p]
	// now go through MasterCIDWave and put titles into MasterTitleWave
	Concatenate/O/NP=0/T WaveList("title_*",";",""), everyTitle
	String mCID, mTitle
	for(i = 0; i < vCID; i += 1)
		mCID = MasterCIDWave[i]
		if(strlen(mCID) == 0)
			continue
		endif
		FindValue/TEXT=mCID/Z everyClusterID
		if(V_Value >= 0)
			mTitle = everyTitle[V_Value]
			MasterTitleWave[i] = mTitle
		else
			MasterTitleWave[i] = ""
		endif
	endfor
	KillWaves/Z everyClusterID, everyTitle
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
	WAVE/Z/T MasterCIDWave
	Variable nPapers = numpnts(MasterCIDWave)
	Make/O/N=(nPapers) orderWave, outkeyW = p
	String cIDstr
	
	String nCiteList = WaveList("nCite_*",";","")
	Variable nDays = ItemsInList(nCiteList)
	String NCName, wName, cIDName, newName, axisName, titleName
	
	Variable i, j
	
	for(i = 0; i < nPapers; i += 1)
		// this is the paper we'll get cites for
		cIDstr = MasterCIDWave[i]
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
				if(j > 0)
					// if cID was missing that day, use the day before
					// as long as it's not the first day
					w0[j] = w0[j-1]
				else
					w0[j] = NaN
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
		titleName = ReplaceString("nCite",nCName,"title")
		KillWaves/Z $nCName,$cIDName,$titleName
	endfor
	
	String wList = WaveList("pCite_*",";","")
	nPapers = ItemsInList(wList)
	WAVE/Z DateWave
	// load colortablewave
	LoadNiceCTableW()
	Variable bVar,tVar,lowVar=0,highVar=0,limVar
	
	for(i = 0; i < nPapers; i += 1)
		wName = StringFromList(i, wList)
		Wave w0 = $wName
		newName = ReplaceString("pCite",wName,"normCite")
		Duplicate/O $wName, $newName
		Wave w1 = $newName
		// offset the wave
		if(numtype(w0[0]) == 0)
			w1 -= w0[0]
		else
			w1 -= w0[firstVal(w0)]
		endif
		bVar = wavemin(w1)
		tVar = wavemax(w1)
		if(bVar < lowVar)
			lowVar = bVar
		endif
		if(tVar > highVar)
			highVar = tVar
		endif
		orderWave[i] = netChange(w1)
	endfor
	
	WAVE/Z normCite_0
	Duplicate/O normCite_0, zeroW
	zeroW = 0
	// previously used this to set limits as -limVar,limVar for zColor
	limVar = max(highVar,abs(lowVar))
	// sort list into the net change at end of wave
	Sort orderWave, orderWave, outkeyW
	wList = ""
	
	for(i = 0; i < nPapers; i += 1)
		//construct list of waves in the right order
		wName = "pCite_" + num2str(outkeyW[i])
		wList += wName + ";"
	endfor
	
	WAVE/Z/T MasterTitleWave
	Make/O/N=(nPapers)/T titleSortedWave = MasterTitleWave[outkeyW[p]]
	
	// Make graph windows
	String thePlotList = "paperPlot;paperRawPlot;paperLabelPlot;"
	Variable nPlots = ItemsInList(thePlotList)
	String plotName
	KillWindow/Z paperPlot
	Display/N=paperPlot/W=(0,50,450,900)
	KillWindow/Z paperRawPlot
	Display/N=paperRawPlot/W=(450,50,900,900)
	KillWindow/Z paperLabelPlot
	Display/N=paperLabelPlot/W=(0,50,900,900)
	
	// now plot them out
	for(i = 0; i < nPapers; i += 1)
		wName = StringFromList(i, wList)
		newName = ReplaceString("pCite",wName,"normCite")
		Wave w1 = $newName
		axisName = "axis" + num2str(i)
		// add to graphs
		for(j = 0; j < nPlots; j += 1)
			plotName = StringFromList(j,thePlotList)
			AppendToGraph/W=$plotName/L=$axisName zeroW vs DateWave
			AppendToGraph/W=$plotName/L=$axisName $newName vs DateWave
			ModifyGraph/W=$plotName zColor($newName)={$newName,lowVar,highVar,ctableRGB,0,:Packages:ColorTables:Moreland:SmoothCoolWarm256}
			ModifyGraph/W=$plotName lsize($newName)=2
			ModifyGraph/W=$plotName axisEnab($axisName)={i * (1/nPapers),(i + 1) * (1/nPapers)}
			ModifyGraph/W=$plotName noLabel($axisName)=2,axThick($axisName)=0,standoff(axis0)=0
		endfor
		SetAxis/W=paperPlot $axisName -limVar,limVar
	endfor
	
	// make zero line look good
	String zList = TraceNameList("paperPlot",";",1)
	Variable nZ = ItemsInList(zList)
	String zName
	
	for(i = 0; i < nZ; i += 1)
		zName = StringFromList(i,zList)
		if(stringmatch(zName,"zero*") == 1)
			for(j = 0; j < nPlots; j += 1)
				plotName = StringFromList(j,thePlotList)
				ModifyGraph/W=$plotName lstyle($zName)=1,rgb($zName)=(56797,56797,56797)
			endfor
		endif
	endfor
	
	for(i = 0; i < nPlots; i += 1)
		plotName = StringFromList(i,thePlotList)
		ModifyGraph/W=$plotName standoff=0
		Label/W=$plotName bottom "Date"
		ModifyGraph/W=$plotName margin(left)=45
		ModifyGraph/W=$plotName gfSize=9
	endfor
	
	// add a right axis to the graph and attach paper names
	Make/O/N=(numpnts(dateWave)) dummyWave = 0
	dummyWave[0] = nPapers -1
	AppendToGraph/R/W=paperLabelPlot dummyWave vs DateWave
	ModifyGraph/W=paperLabelPlot lsize(dummyWave)=0
	SetAxis/W=paperLabelPlot right -0.5, nPapers - 0.5
	Make/O/N=(nPapers)/T labelWave = (titleSortedWave[p])[0,39] // first forty characters of title
	Make/O/N=(nPapers) labelPosW = p
	ModifyGraph/W=paperLabelPlot userticks(right)={labelPosW,labelWave}
	ModifyGraph/W=paperLabelPlot gfSize=9
End

Function PlotTogether()
	String thePlotList = "allpCite;allNorm;"
	Variable nPlots = ItemsInList(thePlotList)
	String plotName
	WAVE/Z colorWave = root:Packages:ColorTables:MatplotLib:set1

	Variable i
	
	for(i = 0; i < nPlots; i += 1)
		plotName = StringFromList(i,thePlotList)
		KillWindow/Z $plotName
		Display/N=$plotName
	endfor
	
	String wList = WaveList("pCite_*",";","")
	Variable nWaves = ItemsInList(wList)
	WAVE/Z DateWave
	String wName
	
	for(i = 0; i < nWaves; i += 1)
		wName = StringFromList(i,wList)
		AppendToGraph/W=allpCite $wName vs DateWave
		wName = ReplaceString("pCite_",wName,"normCite_")
		AppendToGraph/W=allNorm $wName vs DateWave
	endfor
	
	for(i = 0; i < nPlots; i += 1)
		plotName = StringFromList(i,thePlotList)
		ColorTraces(plotName, 1, colorWave)
		ModifyGraph/W=$plotName standoff=0
		Label/W=$plotName bottom "Date"
		ModifyGraph/W=$plotName margin(left)=45
		ModifyGraph/W=$plotName gfSize=9
		SetAxis/W=$plotName/A/N=1 left
		ModifyGraph/W=$plotName lsize=1.5
	endfor
	Label/W=allNorm left "Citations (n - n\\B0\\M)"
	Label/W=allpCite left "Total citations"
End

STATIC Function ColorTraces(plotName, rev, colorTable)
	String plotName
	Variable rev // 0 or 1 for reverse or not
	Wave colorTable // Point to Wave in Packages:ColorTables
 
	String list = TraceNameList(plotName,";",1)
	Variable nItems = ItemsInList(list)
	if(nItems == 0)
		return 0
	endif	
 
	Variable i, traceindex
	
	for(i = 0; i < nItems; i += 1)			
		Variable row = (i / nItems) * DimSize(colorTable,0)
		traceindex = (rev == 0 ? i : nItems-1 - i)
		Variable red = colorTable[row][0], green = colorTable[row][1], blue = colorTable[row][2]
		ModifyGraph/Z/W=$plotName rgb[traceindex] = (red,green,blue)
	endfor
End

STATIC Function FirstVal(w0)
	Wave w0
	Variable firstRow
	Variable nRow = numpnts(w0)
	Variable i
	for(i = 0; i < nRow; i += 1)
		if(numtype(w0[i]) == 0)
			firstRow = i
			break
		endif
	endfor
	return firstRow
End

STATIC Function NetChange(w1)
	Wave w1
	Duplicate/O/FREE w1, tempW
	WaveTransform zapnans tempW
	return sum(tempW)
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
	matB[][] = (numtype(matB[p][q]) == 2) ? 0 : abs(matA[p][q])
	MatrixOp/O diffZW = sumrows(matB)
	Duplicate/O diffZW, diffYW
	diffYW[] = 0
	KillWaves/Z matA,MatB
	
	WAVE/Z DateWave
	WaveStats/Q diffYW
	Variable limVar = max(V_max,-V_min)
	KillWindow/Z diffPlot
	Display/N=diffPlot/W=(900,50,1350,200) diffYW vs DateWave
	ModifyGraph/W=diffPlot mode=3,marker=19
	ModifyGraph/W=diffPlot zColor(diffYW)={diffZW,-limVar,limVar,ctableRGB,0,:Packages:ColorTables:Moreland:SmoothCoolWarm256}
	ModifyGraph/W=diffPlot noLabel(left)=2,axThick(left)=0,standoff(left)=0
	ModifyGraph/W=diffPlot margin(left)=45
	Label/W=diffPlot bottom "Date"
End

Function MakeTheLayout()
	KillWindow/Z summaryLayout
	NewLayout/N=summaryLayout
	AppendLayoutObject/W=summaryLayout graph paperPlot
	AppendLayoutObject/W=summaryLayout graph paperRawPlot
	ModifyLayout/W=summaryLayout left(paperPlot)=21,top(paperPlot)=21,width(paperPlot)=260,height(paperPlot)=800
	ModifyLayout/W=summaryLayout left(paperRawPlot)=271,top(paperRawPlot)=21,width(paperRawPlot)=260,height(paperRawPlot)=800
	ColorScale/W=summaryLayout/C/N=text0/F=0/A=RB/X=0.00/Y=0.00 trace={paperPlot,normCite_0}
	ColorScale/W=summaryLayout/C/N=text0 heightPct=50,frame=0.00
	LayoutPageAction/W=summaryLayout appendPage
	AppendLayoutObject/W=summaryLayout/PAGE=2 graph paperLabelPlot
	LayoutPageAction/W=summaryLayout page=2
	ModifyLayout/W=summaryLayout left(paperLabelPlot)=21,top(paperLabelPlot)=21,width(paperLabelPlot)=553,height(paperLabelPlot)=808
	LayoutPageAction/W=summaryLayout appendPage
	AppendLayoutObject/W=summaryLayout/PAGE=3 graph allpCite
	AppendLayoutObject/W=summaryLayout/PAGE=3 graph allNorm
	LayoutPageAction/W=summaryLayout page=3
	ModifyLayout/W=summaryLayout left(allpCite)=21,top(allpCite)=21,width(allpCite)=553,height(allpCite)=261
	ModifyLayout/W=summaryLayout left(allNorm)=21,top(allNorm)=290,width(allNorm)=553,height(allNorm)=261
	
	// cycle through pages and tidy them
	Variable nPages = 3 // not sure how to ascertain this programmatically
	Variable i
	
	for(i = 0; i < nPages; i += 1)
		LayoutPageAction/W=summaryLayout page=(i + 1) // page numbers start from 1
		LayoutPageAction/W=summaryLayout size(-1)=(595, 842), margins(-1)=(18, 18, 18, 18)
		ModifyLayout/W=summaryLayout units=0
		ModifyLayout/W=summaryLayout frame=0,trans=1
	endfor
End


///////////////////////////////////////////////
Function CoastClear()
	String fullList = WinList("*", ";","WIN:7")
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
	NewDataFolder/O/S root:Packages:ColorTables:Moreland
	LoadWave/Q/H/O/P=Igor ":Color Tables:Moreland:SmoothCoolWarm256.ibw"
	NewDataFolder/O/S root:Packages:ColorTables:Matplotlib
	LoadWave/Q/H/O/P=Igor ":Color Tables:Matplotlib:Set1.ibw"
	SetDataFolder root:		
End