#pragma TextEncoding = "MacRoman"		// For details execute DisplayHelpTopic "The TextEncoding Pragma"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function Cruncher()
//Cruncher() will generate citation distributions for multiple journals
//Minimally needs 3 text waves and 2 numeric waves
//this function will remove PubMed Exclude=1
//generate x2014 wave per journal (use jOpt to step thru)
//calculate mean, median, H and make a histogram
//graph of histogram in a style
//make 1-cumulative histogram like Stuart Cantrill's
//means and medians stored in 2 separate waves

	Wave /T JOpts,Source_Title,JOpts1
	Wave x2014,PMExclude
	Variable nJs=numpnts(JOpts)
	Variable nPs=numpnts(x2014)
	String jName,wName,histName
	Make/O/N=(nJs) aMean,aMedian,aPs,aCs,aH
	
	Variable i,h
	
	For (i=0; i<nJs; i+=1)
		jName=JOpts[i]
		Make/O/N=(nPs) filterWave
		filterWave[] = cmpStr(Source_Title[p],jName)
		//make 2014 citation wave based on journal
		wName="a2014_" + num2str(i)
		Duplicate/O x2014, $wName
		Wave w0=$wName
		w0 = (filterWave==0) && (PMExclude==0) ? w0 : NaN
		WaveTransform zapnans w0
		aMean[i]=mean(w0)
		aMedian[i]=statsmedian(w0)
		aPs[i]=numpnts(w0)
		aCs[i]=sum(w0)
		histName=wName + "_hist"
		Make/N=(wavemax(x2014)+1)/O $histName
		Histogram/C/B={0,1,wavemax(x2014)+1} w0,$histName
		histName=wName + "_chist"
		Make/N=(wavemax(x2014)+1)/O $histName
		Histogram/B={0,1,wavemax(x2014)+1}/P/CUM w0,$histName
		Wave h0=$histName
		h0 *=-1
		h0 +=1
		//calculate h-index
		Duplicate /O w0 w1
		Sort /R w1, w1
		Make /O /N=(numpnts(w1)) resWave
		resWave = w1[p]>=(p+1) ? 1 : 0	//p+1 is used so that the first paper is paper 1
		FindValue /V=0 resWave
		if (V_value==-1)
			h=numpnts(w1)
		else
			h=V_value
		endif
		aH[i]=h
	EndFor
 	Killwaves filterWave,w1,resWave
 	DoWindow /K Summary
 	Edit /N=Summary JOpts,aMean,aMedian,aPs,aCs,aH
 	
 	DoWindow /K saPlot
	Display /N=saPlot
	For (i=0; i<nJs; i+=1)
		jName=JOpts1[i]
		If(numtype(aMean[i])==0)
			histName="a2014_" + num2str(i) + "_hist"
			Display $histName
			SetAxis bottom 0,50
			ModifyGraph mode=5,hbFill=4
			Label bottom "Citations"
			Label left "Frequency"
			TextBox/C/N=text0/F=0/X=5.00/Y=0.00/E=2 jName
			Display /W=(0.4,0.1,0.9,0.6)/HOST=# $histName
			SetAxis bottom 50,1000
			SetAxis left 0,2
			ModifyGraph nticks(left)=2
			ModifyGraph margin(left)=22,margin(bottom)=22,margin(top)=6,margin(right)=6
			ModifyGraph mode=6
			ModifyGraph gfSize=8
			//cumulative histogram
			histName=ReplaceString("_hist",histName,"_chist")
			AppendToGraph /W=saPlot $histName
			DoWindow/F saPlot
			SetAxis left 0,1
			SetAxis bottom 0,40
			Label bottom "Citations"
			Label left "Frequency"
		EndIf
	EndFor
	OrderGraphs()
	Execute "TileWindows/O=1/C"
End

Function OrderGraphs()
	String list = WinList("*", ";", "WIN:1")		// List of all graph windows
	list = SortList(list, ";", 17)				// Case-insensitive alphanumeric descending sort
	// Print list
	Variable numWindows = ItemsInList(list)
	Variable i
	for(i=0; i<numWindows; i+=1)
		String name = StringFromList(i, list)
		DoWindow /F $name
	endfor
End
