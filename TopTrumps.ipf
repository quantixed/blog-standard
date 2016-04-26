#pragma TextEncoding = "MacRoman"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//// @param	nGames	number of games in simulation
Function RunSim(nGames)
	Variable nGames
	
	FindRank()
	Variable/G game = nGames
	Make/O/N=(nGames) pg_WinnerWave,pg_GameLength
	Variable i
	
	for(i = 0; i < nGames; i += 1)
		game = i
		DealThem()
		PlayGame()
	endfor
	WhoWon()
End

Function FindRank()
	String wList = "tt_Strength;tt_Skill;tt_Size;tt_Wisecracks;tt_Mystique;tt_TTR;"
	String wName
	Variable nFields = itemsInList(wList)
	wName = StringFromList(0,wList)
	WAVE w0 = $wName
	Variable nCards = numpnts(w0)
	Variable tempvar,beat
	
	Variable i,j,k
	
	for(i = 0; i < nFields; i += 1)
		wName = StringFromList(i,wList)
		WAVE w0 = $wName
		Make/O/N=(nCards,nFields) m0
		for(j = 0; j < nCards; j += 1)
			tempvar = w0[j]
			beat = 0
			for(k = 0; k < nCards; k += 1)
				if(tempvar > w0[k])
					beat += 1
				endif
			endfor
			m0[j][i] = beat
		endfor
	endfor
	MatrixOp/O tt_beat = sumRows(m0)
	WAVE/T tt_Name
	Duplicate/O/T tt_Name best_Name
	Duplicate/O tt_beat best_beat
	Sort /R best_beat, best_Name,best_beat
	DoWindow/K bestTable
	Edit /N=bestTable best_Name,best_beat
End

Function DealThem()
	WAVE tt_AAN
	Variable nCards = numPnts(tt_AAN)
	Make/O/N=(nCards) tmpWaveN=enoise(1)
	Duplicate/O tt_AAN, randomOrderWave
	Sort tmpWaveN,randomOrderWave
	Make/O/N=(nCards / 2) Plyr1,Plyr2
	Plyr1 = randomOrderWave[p]
	Plyr2 = randomOrderWave[p + ((nCards / 2) - 1)]
	KillWaves/Z tmpWaveN,randomOrderWave
End

Function PlayGame()
	WAVE Plyr1,Plyr2
	WAVE m0 // matrix of how many cards will be beaten
	WAVE/T tt_Name
	String wList = "tt_Strength;tt_Skill;tt_Size;tt_Wisecracks;tt_Mystique;tt_TTR;"
	Concatenate/O wList, m1 // matrix of card values
	String wName
	Variable card1,card2
	Variable activePlayer=1
	Variable nCards1,nCards2
	Variable activePick,activePickValue,oppValue
	String cardName1, cardName2, pickName
	Make/O/N=0 BinWave,TempWave
	Variable i = 1
	
	do
		nCards1 = numpnts(Plyr1)
		nCards2 = numpnts(Plyr2)
		card1 = Plyr1[0]
		card2 = Plyr2[0]
		cardName1 = tt_Name[card1]
		cardName2 = tt_Name[card2]
		
		if(activePlayer == 1)
			MatrixOp/O activeRow = row(m0,card1)
			WaveStats/Q activeRow
			activePick = V_maxColLoc
			pickName = StringFromList(V_maxColLoc,wList)
			pickName = ReplaceString("tt_",pickName,"")
			activePickValue = m1[card1][activePick]
			oppValue = m1[card2][activePick]
		elseif(activePlayer == 2)
			MatrixOp/O activeRow = row(m0,card2)
			WaveStats/Q activeRow
			activePick = V_maxColLoc
			pickName = StringFromList(V_maxColLoc,wList)
			pickName = ReplaceString("tt_",pickName,"")
			activePickValue = m1[card2][activePick]
			oppValue = m1[card1][activePick]
		endif
		nCards1 = numpnts(Plyr1)
		nCards2 = numpnts(Plyr2)
//		Print "Round", i, "Number of Cards", nCards1, "vs", nCards2
//		Print "1:", cardName1, "vs 2:", cardName2
//		Print "Player", activePlayer, "picks", pickName, "......", activePickValue, "vs", oppValue
			
		if(ActivePickValue > oppvalue)
			if(activePlayer == 1)
//				Print "Player 1 wins"
				DeletePoints 0, 1, Plyr1,Plyr2
				Make/O/N=2 TempWave=NaN
				TempWave[0] = card1
				TempWave[1] = card2
				Concatenate/NP {TempWave}, Plyr1
				if(numpnts(BinWave) > 0)
					Concatenate/NP {BinWave}, Plyr1
					Make/O/N=0 BinWave
				endif
			elseif(activePlayer == 2)
//				Print "Player 2 wins"
				DeletePoints 0, 1, Plyr1,Plyr2
				Make/O/N=2 TempWave=NaN
				TempWave[0] = card1
				TempWave[1] = card2
				Concatenate/NP {TempWave}, Plyr2
				if(numpnts(BinWave) > 0)
					Concatenate/NP {BinWave}, Plyr2
					Make/O/N=0 BinWave
				endif
			endif
		elseif(activePickValue < oppvalue)
			if(activePlayer == 1)
//				Print "Player 1 loses"
				DeletePoints 0, 1, Plyr1,Plyr2
				Make/O/N=2 TempWave=NaN
				TempWave[0] = card1
				TempWave[1] = card2
				Concatenate/NP {TempWave}, Plyr2
				activePlayer = 2
				if(numpnts(BinWave) > 0)
					Concatenate/NP {BinWave}, Plyr2
					Make/O/N=0 BinWave
				endif
			elseif(activePlayer == 2)
//				Print "Player 2 loses"
				DeletePoints 0, 1, Plyr1,Plyr2
				Make/O/N=2 TempWave=NaN
				TempWave[0] = card1
				TempWave[1] = card2
				Concatenate/NP {TempWave}, Plyr1
				activePlayer = 1
				if(numpnts(BinWave) > 0)
					Concatenate/NP {BinWave}, Plyr1
					Make/O/N=0 BinWave
				endif
			endif
		elseif(activePickValue == oppValue)
//			Print "It's a draw"
			DeletePoints 0, 1, Plyr1,Plyr2
			Make/O/N=2 TempWave=NaN
			TempWave[0] = card1
			TempWave[1] = card2
			Concatenate/NP {TempWave}, BinWave
		endif
		nCards1 = numpnts(Plyr1)
		nCards2 = numpnts(Plyr2)
//		Print "Number of Cards", nCards1, "vs", nCards2
		if(nCards1 == 0 || nCards2 == 0)
//			Print "Game Over"
			break
		endif
		i += 1
	while (nCards1 != 0 || nCards2 != 0)
	
	WAVE pg_WinnerWave,pg_GameLength
	NVAR j = root:game
	
	if(nCards1 == 0)
		pg_WinnerWave[j] = 2
	elseif(nCards2 == 0)
		pg_WinnerWave[j] = 1
	endif
	pg_GameLength[j] = i
End

Function WhoWon()
	WAVE pg_WinnerWave,pg_GameLength
	Variable nGames = numpnts(pg_WinnerWave)
	Duplicate/O pg_WinnerWave, tempW
	tempW = (pg_WinnerWave == 1) ? tempW : NaN
	WaveTransform zapnans tempW
	Variable p1win = numpnts(tempW)
	Variable p2win = nGames - p1win
	Print "Player 1 won", p1win, "games, and Player 2 won", p2win
	Print "That is", (p1win/nGames) * 100, "% and", (p2win/nGames) * 100, "%"
	Variable last = 1 + wavemax(pg_GameLength)
	Make/N=(last)/O pg_GameLength_Hist
	Histogram/B={0,1,last} pg_GameLength,pg_GameLength_Hist
	DoWindow/K gameHist
	Display /N=gameHist pg_GameLength_Hist
	ModifyGraph /W=gameHist mode=5,hbFill=4
End