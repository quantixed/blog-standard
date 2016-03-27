#pragma TextEncoding = "MacRoman"		// For details execute DisplayHelpTopic "The TextEncoding Pragma"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function MakeLotto()
	Make/O/N=49 data
	data =x+1
	StatsSample /N=6 /ACMB data	// generates all combinations IP7 only - currently has a bug
End

Function RunSim()
	//results are 1D waves in the form of B1-7
	Concatenate/O "B1;B2;B3;B4;B5;B6;B7;", m0 // make matrix
	MakeLotto() // make combinations
	Wave m1=M_Combinations
	Variable nResults=Dimsize(m0,0)
	Variable nCr=Dimsize(m1,0)
	Variable r1,r2,r3,r4,r5,r6	// these are the six numbers from the combination
	Variable b1,b2,b3,b4,b5,b6,b7	// these are the six drawn numbers + bonus
	Variable s0	// the "score"
	Make/O/N=(nCr,5) OutWave	// put outcomes here
	
	Variable i,j
	
	For(i=0; i<nCr; i+=1)
		r1=m1[i][0]
		r2=m1[i][1]
		r3=m1[i][2]
		r4=m1[i][3]
		r5=m1[i][4]
		r6=m1[i][5]
		For(j=0; j<nResults; j+=1)
			b1=m0[j][0]
			b2=m0[j][1]
			b3=m0[j][2]
			b4=m0[j][3]
			b5=m0[j][4]
			b6=m0[j][5]
			b7=m0[j][6]
			s0=0
			If(r1==b1 || r1==b2 || r1==b3 || r1==b4 || r1==b5 || r1==b6)
				s0 +=1
			EndIf
			If(r2==b1 || r2==b2 || r2==b3 || r2==b4 || r2==b5 || r2==b6)
				s0 +=1
			EndIf
			If(r3==b1 || r3==b2 || r3==b3 || r3==b4 || r3==b5 || r3==b6)
				s0 +=1
			EndIf
			If(r4==b1 || r4==b2 || r4==b3 || r4==b4 || r4==b5 || r4==b6)
				s0 +=1
			EndIf
			If(r5==b1 || r5==b2 || r5==b3 || r5==b4 || r5==b5 || r5==b6)
				s0 +=1
			EndIf
			If(r6==b1 || r6==b2 || r6==b3 || r6==b4 || r6==b5 || r6==b6)
				s0 +=1
			EndIf
			If(s0==5)
				If(r1==b7 || r2==b7 || r3==b7 || r4==b7 || r5==b7 || r6==b7)
				s0 +=2	//will give 7
				OutWave[i][4] +=1
				EndIf
			EndIf
			
			If(s0==3)
				OutWave[i][0] +=1
			Elseif(s0==4)
				OutWave[i][1] +=1
			ElseIf(s0==5)
				OutWave[i][2] +=1
			ElseIf(s0==6)
				OutWave[i][3] +=1
			EndIf
				
		EndFor
	EndFor
End

Function FindLine(r1,r2,r3,r4,r5,r6)
	//Use this function to query specific set of numbers
	Variable r1,r2,r3,r4,r5,r6
	
	Variable s0=r1+r2+r3+r4+r5+r6
	Wave m0=OutWave
	Wave m1=M_Combinations
	MatrixOp/O sumWave=sumRows(m1)
	Variable nCr=Dimsize(m1,0)

	Variable b1,b2,b3,b4,b5,b6	// this time it means combination
	Variable s1=0
	
	Variable i
	
	For(i=0; i<nCr; i+=1)
		s1=0
		If(sumWave[i]==s0)
			b1=m1[i][0]
			b2=m1[i][1]
			b3=m1[i][2]
			b4=m1[i][3]
			b5=m1[i][4]
			b6=m1[i][5]
			
		If(r1==b1 || r1==b2 || r1==b3 || r1==b4 || r1==b5 || r1==b6)
			s1 +=1
		EndIf
		If(r2==b1 || r2==b2 || r2==b3 || r2==b4 || r2==b5 || r2==b6)
			s1 +=1
		EndIf
		If(r3==b1 || r3==b2 || r3==b3 || r3==b4 || r3==b5 || r3==b6)
			s1 +=1
		EndIf
		If(r4==b1 || r4==b2 || r4==b3 || r4==b4 || r4==b5 || r4==b6)
			s1 +=1
		EndIf
		If(r5==b1 || r5==b2 || r5==b3 || r5==b4 || r5==b5 || r5==b6)
			s1 +=1
		EndIf
		If(r6==b1 || r6==b2 || r6==b3 || r6==b4 || r6==b5 || r6==b6)
			s1 +=1
		EndIf
		
		If(s1==6)
		Print "Row is", i
		Print m0[i][0], "x3 balls,", m0[i][1], "x4 balls,", m0[i][2], "x5 balls,", m0[i][3], "x6 balls,", m0[i][4], "x5+b balls,"
		EndIf
		
		EndIf
	EndFor
	KillWaves sumWave
End
