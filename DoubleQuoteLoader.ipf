#pragma TextEncoding = "MacRoman"		// For details execute DisplayHelpTopic "The TextEncoding Pragma"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
//Written by Howard Rodstein http://www.igorexchange.com/node/6880
//Edited by Steve Royle to read in csv files from Web of Science
//Works but is quite slow and fails on very long strings. 

// The LoadDoubleQuotedTextDataFile procedure loads data files in which text is double-quoted, like this:
//	"<ColumnName>"<comma>"<ColumnName>"
//	"<string possibly containing comma>"<comma>"<string possibly containing comma>"...
//
// The file may also contain numeric columns, like this:
//	"<string possibly containing comma>"<comma><number>...
//
// LoadWave by itself does not handle this because the comma inside the double-quoted string is taken as a column delimiter.
// To load this, LoadDoubleQuotedTextDataFile does the following:
//	1.	Create a temporary file in which the true comma delimiters (those outside the quotes) are replaced by tabs
//		and the quotes are removed.
//	2.	Load the temporary file.
//	3.	Delete the temporary file.
//
// This also works on tab-delimited test files containing double-quotes that you don't want to load, e.g.:
//	"<ColumnName>"<comma>"<ColumnName>"
//	"<string>"<tab>"<string>"...
 
// These set the initial values in the dialog displayed by LoadDoubleQuotedTextDataFile.
// You can customize them for your file if you like.
static Constant kDefaultNameLine = 0
static Constant kDefaultFirstDataLine = 0
static Constant kDefaultNumDataLines = 0
static Constant kDefaultFirstColumnToLoad = 0
static Constant kDefaultNumColumnsToLoad = 0
 
Menu "Load Waves"
	"Load Double-Quoted Text Data File . . .", LoadDoubleQuotedTextDataFile("", "")
End
 
static Function/S CleanupText(origText, cleanedText)
	String origText							// Input
	String& cleanedText						// Output
 
	Variable numOrigBytes = strlen(origText)
 
	// This speeds things up by avoiding resizing the output string over and over again
	cleanedText = PadString("", numOrigBytes, 32)
 
	Variable numOutputBytes = 0
	String doubleQuoteStr = "\""
	String commaStr = ",", tabStr = "\t"
	Variable inDoubleQuote = 0
 
	Variable i
	for(i=0; i<numOrigBytes; i+=1)
		Variable skip = 0
		String byte = origText[i]
		if (CmpStr(byte,doubleQuoteStr) == 0)
			skip = 1
			inDoubleQuote = !inDoubleQuote	// We are either entering or leaving a double-quoted string
		else
			if (CmpStr(byte,commaStr) == 0)
				if (!inDoubleQuote)
					// This is a delimiter comma - replace it with tab
					byte = tabStr
				endif
			endif
		endif
 
		if (!skip)
			cleanedText[numOutputBytes] = byte
			numOutputBytes += 1
		endif	
	endfor
 
	cleanedText = cleanedText[0,numOutputBytes-1]
 
	return cleanedText
End
 
static Function TestCleanupText()
	String origText = "\"Quick brown, fox\",\"0\""
	String cleanedText
	CleanupText(origText, cleanedText)
	Print cleanedText
End
 
static Function CreateCleanedUpTempFile(pathName, origFileName, tempFileName)
	String pathName						// Symbolic path name
	String origFileName
	String tempFileName						// Name to use for temporary file
 
	Variable origRefNum
	Open /R /P=$pathName /Z origRefNum as origFileName
	if (V_flag != 0)
		Print "Error opening " + origFileName
		return -1							// Error of some kind
	endif
 
	FStatus origRefNum
	Variable numBytesInOrigFile = V_logEOF
	String origText = PadString("", numBytesInOrigFile, 32)
	FBinRead origRefNum, origText 
	Close origRefNum
 
	String cleanedText = CleanupText(origText, cleanedText)
 
	Variable tempRefNum
	Open /P=$pathName /Z tempRefNum as tempFileName
	if (V_flag != 0)
		Print "Error opening " + tempFileName
		return -1						// Error of some kind
	endif
	FBinWrite tempRefNum, cleanedText
	Close tempRefNum
 
	return 0	
End
 
static StrConstant kExtensionStr = "????"		// Shows files with any extension. Change to, e.g., ".dat", to show just .dat files.
 
// LoadDoubleQuotedTextDataFile(pathName, fileName, [nameLine, firstDataLine, numDataLines, firstColumn, numColumns])
// nameLine, firstDataLine, numDataLines, firstColumn and numColumns are optional parameters.
// If you omit them, LoadDoubleQuotedTextDataFile displays a dialog in which the user can enter them
Function LoadDoubleQuotedTextDataFile(pathName, fileName, [nameLine, firstDataLine, numDataLines, firstColumn, numColumns])
	String pathName		// Name of an Igor symbolic path or ""
	String fileName			// Name of file or full path to file
 
	// Optional parameters
	Variable nameLine
	Variable firstDataLine
	Variable numDataLines
	Variable firstColumn
	Variable numColumns
 
	if (ParamIsDefault(nameLine) || ParamIsDefault(firstDataLine) || ParamIsDefault(numDataLines) || ParamIsDefault(firstColumn) || ParamIsDefault(numColumns))
		// The caller did not supply optional parameters so display dialog
 
		// These set the initial values displayed in the dialog
		nameLine = kDefaultNameLine
		firstDataLine = kDefaultFirstDataLine
		numDataLines = kDefaultNumDataLines
		firstColumn = kDefaultFirstColumnToLoad
		numColumns = kDefaultNumColumnsToLoad
 
		// Display dialog
		Prompt nameLine, "Line containing column names (zero-based - 0 if no column names): "
		Prompt firstDataLine, "First line containing data (zero-based): "
		Prompt numDataLines, "Number of data lines to load (zero for all): "
		Prompt firstColumn, "First column to load (zero-based): "
		Prompt numColumns, "Number of columns to load (zero for all): "
		DoPrompt "Enter LoadWave Parameters", nameLine, firstDataLine, numDataLines, firstColumn, numColumns
		if (V_Flag)
			return -1								// User canceled
		endif
	endif
 
	Variable refNum
 
	String message
 
	// First get a valid reference to a file.
	if ((strlen(pathName)==0) || (strlen(fileName)==0))
		// Display dialog looking for file.
		message = "Select double-quoted text data file"
		Open /D /R /P=$pathName /T=kExtensionStr /M=message refNum as fileName
		fileName = S_fileName				// S_fileName is set by Open/D
		if (strlen(fileName) == 0)			// User cancelled?
			return -1
		endif
	endif
 
	String tempFileName = fileName + "_tmp"
	if (CreateCleanedUpTempFile(pathName, fileName, tempFileName) != 0)
		return -1							// Error
	endif
 
	// Remove /D if you want to load as single-precision floating point
	String delimiters = "\t"
	LoadWave /O /J /W /D /K=0 /V={delimiters, "", 0, 0} /L={nameLine, firstDataLine, numDataLines, firstColumn, numColumns} /E=1 /Q /P=$pathName tempFileName
 
	if (V_flag > 0)
		Printf "Loaded double-quoted data from \"%s\"\r", fileName
	endif
 
	DeleteFile /P=$pathName tempFileName
 
	return 0
End
