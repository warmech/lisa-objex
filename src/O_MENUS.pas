UNIT O_MENUS;

INTERFACE

CONST
  SIDEBAR_WIDTH       = 32;
  MENU_VISIBLE_OFFSET = 13;
  HEX_LINES           = 16;

TYPE
  FOCUSED_MENU = (INPUT_FILE_SELECT, SUBFILE_SELECT);

VAR
  FocusedMenu             : FOCUSED_MENU = INPUT_FILE_SELECT;
  InputCharacter          : INTEGER;
  MaxRows, MaxCols        : INTEGER;
  CurrentSelection        : INTEGER = 0;
  SubfileCurrentSelection : INTEGER = 0;
  OutfileCurrentSelection : INTEGER = 0;
  ScrollOffset            : INTEGER = 0;
  SubfileScrollOffset     : INTEGER = 0;
  OutfileScrollOffset     : INTEGER = 0;
  VisibleRows             : INTEGER;
  HexViewFlag             : BOOLEAN = FALSE;
  FileViewFlag            : BOOLEAN = FALSE;
  ShowVolumeBanner        : BOOLEAN = FALSE;
  ShowSubfileBanner       : BOOLEAN = FALSE;
  SubfileSelected         : BOOLEAN = FALSE;

PROCEDURE ConstructAppInterface();
PROCEDURE DrawInterface();
PROCEDURE HandleFileMenuAction();
PROCEDURE BuildVolumeMetadataBanner();
PROCEDURE DrawInputFileSelectMenu();
PROCEDURE DrawMainWindow();
PROCEDURE DrawSubfileSelectMenu();
PROCEDURE DrawHexPreview();
PROCEDURE HandleSubfileMenuAction();
PROCEDURE BuildSubfileMetadataBanner();

IMPLEMENTATION

USES
  NCURSES, O_DIR, O_DISK, SYSUTILS, O_DEBUG;
  
// ----------------------------------------------
// Draws the disk image volume info to the banner
// ----------------------------------------------
PROCEDURE BuildVolumeMetadataBanner();
VAR
  Banner_VolumeName      : ANSISTRING;
  Banner_BootSector      : ANSISTRING;
  Banner_FirstDataSector : ANSISTRING;
  Banner_NumberBlocks    : ANSISTRING;
  Banner_NumberFiles     : ANSISTRING;
  Banner_VolTimeStamp    : ANSISTRING;
BEGIN
  // Assemble ANSI strings
  Banner_VolumeName      := 'Volume Name       : ' + VolumeHeader.VolName;
  Banner_BootSector      := 'Boot Sector       : 0x' + (WordToHex(VolumeHeader.BootSector));
  Banner_FirstDataSector := 'First Data Sector : 0x' + WordToHex(VolumeHeader.FirstDataSector);
  Banner_NumberBlocks    := 'Number Of Blocks  : ' + IntToStr(VolumeHeader.NumberBlocks);
  Banner_NumberFiles     := 'Number Of Files   : ' + IntToStr(VolumeHeader.NumberFiles);
  Banner_VolTimeStamp    := 'Vol Timestamp     : 0x' + WordToHex(VolumeHeader.VolTimeStamp);
  
  //Print ANSI strings
  MvPrintW(2, 3, PChar(Banner_VolumeName));
  MvPrintW(3, 3, PChar(Banner_BootSector));
  MvPrintW(4, 3, PChar(Banner_FirstDataSector));
  MvPrintW(2, 43, PChar(Banner_NumberBlocks));
  MvPrintW(3, 43, PChar(Banner_NumberFiles));
  MvPrintW(4, 43, PChar(Banner_VolTimeStamp));
END;

// ----------------------------------------------
// Draws the subfile info to the banner
// ----------------------------------------------
PROCEDURE BuildSubfileMetadataBanner();
VAR
  Banner_SubfileName       : ANSISTRING;
  Banner_StartingSector    : ANSISTRING;
  Banner_EndingSector      : ANSISTRING;
  Banner_FileSize          : ANSISTRING;
  Banner_FileType          : ANSISTRING;
  Banner_BytesinLastSector : ANSISTRING;
  Banner_FileTimestamp     : ANSISTRING;
  SubfileSize              : ANSISTRING;
  SubfileType              : ANSISTRING;
  SubfileStartingSector    : LONGINT;
  SubfileEndingSector      : LONGINT;
  
BEGIN
  // Calculate these to prevent the longest line in this damned project
  SubfileStartingSector := (FileTable[SubfileCurrentSelection].StartingSector * SECTOR_SIZE);
  SubfileEndingSector := ((FileTable[SubfileCurrentSelection].EndingSector * SECTOR_SIZE) - SECTOR_SIZE + FileTable[SubfileCurrentSelection].BytesinLastSector);
  SubfileSize := IntToStr(SubfileEndingSector - SubfileStartingSector);
  
  // Determine file type
  CASE (FileTable[SubfileCurrentSelection].FileType) OF
	  2: SubfileType := 'Code';
	  3: SubfileType := 'Text';
	  5: SubfileType := 'Data';
  END;

  // Assemble ANSI strings
  Banner_SubfileName       := 'Filename             : ' + FileTable[SubfileCurrentSelection].FileName;
  Banner_StartingSector    := 'Starting Sector      : 0x' + (WordToHex(FileTable[SubfileCurrentSelection].StartingSector));
  Banner_EndingSector      := 'Ending Sector        : 0x' + (WordToHex(FileTable[SubfileCurrentSelection].EndingSector));
  Banner_FileSize          := 'File Size (Bytes)    : ' + SubfileSize;
  Banner_FileType          := 'File Type            : ' + SubfileType;
  Banner_BytesinLastSector := 'Bytes in Last Sector : ' + IntToStr(FileTable[SubfileCurrentSelection].BytesinLastSector);
  Banner_FileTimestamp     := 'File Timestamp       : 0x' + WordToHex(FileTable[SubfileCurrentSelection].FileTimestamp);
  
  //Print ANSI strings
  MvPrintW(2, 3, PChar(Banner_SubfileName));
  MvPrintW(3, 3, PChar(Banner_StartingSector));
  MvPrintW(4, 3, PChar(Banner_EndingSector));
  MvPrintW(2, 43, PChar(Banner_FileSize));
  MvPrintW(3, 43, PChar(Banner_FileType));
  MvPrintW(4, 43, PChar(Banner_FileTimestamp));
END;

// -----------------------------------------------------
// Handle inputs regarding the input file selection menu
// -----------------------------------------------------
PROCEDURE HandleFileMenuAction();
VAR
  CurrentDirectory : ANSISTRING;
  LowerDirectory   : ANSISTRING;
  SelectedFile     : STRING;
BEGIN
  CASE DirectoryContents[CurrentSelection].Name OF
    '.': // Stay where we are
	  SetCurrentDir(GetCurrentDir());
	'..': // Move up a directory level
	  BEGIN
	    SetCurrentDir('..');
	    CurrentDirectory := GetCurrentDir();
	    GetDirectoryObjectList(CurrentDirectory);
		CurrentSelection := 0;
	  END;
  ELSE
    IF ((DirectoryContents[CurrentSelection].Attributes AND faDirectory) <> 0) THEN
	  BEGIN
	    // If the user selects a directory and hits enter, take them down a dir level and drop the current object selection back to zero
	    LowerDirectory := './' + DirectoryContents[CurrentSelection].Name;
	    SetCurrentDir(LowerDirectory);
	    CurrentDirectory := GetCurrentDir();
	    GetDirectoryObjectList(CurrentDirectory);
		
		// Reset selection and scroll values to zero (0)
		CurrentSelection := 0;
		ScrollOffset := 0;
	  END
	ELSE
	  BEGIN
	    // If the user selects a file and hits enter, build necessary blades
	    SelectedFile := DirectoryContents[CurrentSelection].Name;
	    OpenDiskImage(SelectedFile);
		SetVolumeEntryPoint();
		BuildDirectoryStructure();
		BuildVolumeMetadataBanner();
		SetFileTableEntryPoint();
		SetFileListSize();
		BuildFileTable();
		
		// Turn on subfile banners
		ShowVolumeBanner := True;
		ShowSubfileBanner := False;
		
		// Set focus to subfile menu
		FocusedMenu := SUBFILE_SELECT;
	  END;
  END;
END;

// --------------------------------------------------
// Handle inputs regarding the subfile selection menu
// --------------------------------------------------
PROCEDURE HandleSubfileMenuAction();
BEGIN
  HexViewFlag := TRUE;
  LoadFileIntoMemory(SubfileCurrentSelection);
  ShowSubfileBanner := True;
END;

// ---------------------------------------------------------------------------
// Draws the hex preview blade on the right of the terminal view
// ---------------------------------------------------------------------------
PROCEDURE DrawHexPreview();
VAR
  AddressReadout : ANSISTRING;
  HexReadout     : ANSISTRING;
  ASCIIReadout   : ANSISTRING;
  HexViewLine    : ANSISTRING;
  i, j           : INTEGER;
  LineStart      : INTEGER;
  SubfileLength  : LONGINT;
  ByteValue      : BYTE;
BEGIN
  // Do nothing if FileInMemory is uninitialized or empty
  IF ((NOT Assigned(FileInMemory)) OR (Length(FileInMemory) = 0)) THEN
  BEGIN
    EXIT;
  END;
  
  // Check subfile length
  SubfileLength := Length(FileInMemory);
  
  // We're only going to handle 16 lines (or fewer - files CAN be smaller than 256 bytes, after all)
  FOR i := 0 TO 15 DO
  BEGIN
    LineStart := i * HEX_LINES;
	
    // Stay within bounds of the the subfile size
    IF LineStart >= SubfileLength THEN
	BEGIN
      BREAK;
	END;
		
	// Initialize the row's output variables
    AddressReadout := LongIntToHex(LineStart);
    HexReadout := '';
    ASCIIReadout := '';

    // Read 16 bytes (or fewer if we hit end of file - see previous note)
    FOR j := 0 TO 15 DO
    BEGIN
      IF (LineStart + j) >= SubfileLength THEN
      BEGIN
        HexReadout := HexReadout + '   '; // Pad out with whitespace if no byte is read
        ASCIIReadout := ASCIIReadout + ' ';
      END
      ELSE
      BEGIN
        ByteValue := FileInMemory[LineStart + j];
        HexReadout := HexReadout + ByteToHex(ByteValue) + ' ';
		
		// We're only interested in printing ASCII text
        IF (ByteValue < 32) OR (ByteValue > 126) THEN
          ASCIIReadout := ASCIIReadout + '.'
        ELSE
          ASCIIReadout := ASCIIReadout + Chr(ByteValue);
      END;
    END;

    // Remove trailing space from HexReadout
    IF Length(HexReadout) > 0 THEN
      Delete(HexReadout, Length(HexReadout), 1);
	
	// Assemble and print out - MvAddStr MUST be used, as some ASCII data pulled from Monitor subfiles contains unescaped control characters (you don't want to know how long it took me to realize that...)
    HexViewLine := AddressReadout + ':    ' + HexReadout + '    ' + ASCIIReadout;
	MvAddStr(12 + i, 35, PChar(HexViewLine));
  END;
END;

// ------------------------------------------
// Draws the main window of the terminal view
// ------------------------------------------
PROCEDURE DrawMainWindow();
BEGIN
  Box(StdScr, 0, 0);
  MvPrintW(0, 2, ' OBJEX - File Extractor for Lisa Monitor Disk Images ');
  MvPrintW(MaxRows - 1, 2, ' (Q): Quit ');
  MvHLine(6, 1, ACS_HLINE, MaxCols - 2);
  MvHLine(10, 1, ACS_HLINE, MaxCols - 2);
  MvVLine(11, SIDEBAR_WIDTH, ACS_VLINE, MaxRows - 12);
  MvPrintW(60, 3, PChar(SubfileCurrentSelection));
END;

// ---------------------------------------------------------------------------
// Draws the main input file selection blade on the left of the terminal view
// ---------------------------------------------------------------------------
PROCEDURE DrawInputFileSelectMenu();
VAR
  CurrentDirectory   : ANSISTRING;
  DirectoryLine      : ANSISTRING;
  AttenuatedFilename : ANSISTRING;
  i                  : INTEGER;
BEGIN
  // Get current directory and display it
  CurrentDirectory := GetCurrentDir();
  DirectoryLine := ('Current Directory: ' + PChar(CurrentDirectory));
  MvPrintW(8, 3, PChar(DirectoryLine));

  // Iterate though directory contents and allow user to move through them
  FOR i := 0 TO VisibleRows - MENU_VISIBLE_OFFSET DO
  BEGIN
    IF (ScrollOffset + i > High(DirectoryContents)) THEN
      BREAK;
	
    // Attenuate the filename if too long (e.g. THIS_IS_A_TEST.FILE becomes THIS_IS_A_T...)
	IF (Length(DirectoryContents[ScrollOffset + i].Name) > 24) THEN
	  AttenuatedFilename := Copy(DirectoryContents[ScrollOffset + i].Name, 1, 24) + '...'
	ELSE
	  AttenuatedFilename := DirectoryContents[ScrollOffset + i].Name;
	
	// Highlight selected file
    IF ((ScrollOffset + i) = CurrentSelection) THEN
    BEGIN
      attron(A_REVERSE);
      MvPrintW(12 + i, 3, '%s', PChar(AttenuatedFilename));
      attroff(A_REVERSE);
    END
    ELSE
      MvPrintW(12 + i, 3, '%s', PChar(AttenuatedFilename));
  END;
  
  // Scroll indicators at top and bottom
  IF (ScrollOffset + (VisibleRows - MENU_VISIBLE_OFFSET) <= High(DirectoryContents) + 1) THEN
    MvAddStr(VisibleRows - 1, 22, '(MORE)');
    
  IF (ScrollOffset > 0) THEN
    MvAddStr(12, 22, '(MORE)');
END;

// ------------------------------------------------------------------
// Draws the subfile selection blade on the left of the terminal view
// ------------------------------------------------------------------
PROCEDURE DrawSubfileSelectMenu();
VAR
  Instructions    : ANSISTRING;
  ANSIFileName    : ANSISTRING;
  FilenameLine    : ANSISTRING;
  SubfileSize     : ANSISTRING;
  i, DisplayIndex : INTEGER;
BEGIN
  // Display keyboard shortcuts
  Instructions := '(ESC): Return to Input File Select    (ENTER): Export Subfile from Disk Image    (A): Export All Subfiles';
  MvPrintW(8, 3, PChar(Instructions));
  
  // Draw subfile list
  FOR i := 0 TO VisibleRows - MENU_VISIBLE_OFFSET DO
  BEGIN
    
    IF (SubfileScrollOffset + i > High(FileTable)) THEN
      BREAK;
	  
	ANSIFileName := FileTable[SubfileScrollOffset + i].FileName;
	
	// Highlight selected file
    IF ((SubfileScrollOffset + i) = SubfileCurrentSelection) THEN
    BEGIN
      attron(A_REVERSE);
      MvPrintW(12 + i, 3, '%s', PChar(ANSIFileName));
      attroff(A_REVERSE);
    END
    ELSE
      MvPrintW(12 + i, 3, '%s', PChar(ANSIFileName));
  END;
  
  // Scroll indicators at top and bottom
  IF (SubfileScrollOffset + (VisibleRows - MENU_VISIBLE_OFFSET) <= High(FileTable) + 1) THEN
    MvAddStr(VisibleRows - 1, 22, '(MORE)');
    
  IF (SubfileScrollOffset > 0) THEN
    MvAddStr(12, 22, '(MORE)');
END;

// -----------------------------
// Handles drawing the interface
// -----------------------------
PROCEDURE DrawInterface();  
BEGIN
  GetMaxYX(StdScr, MaxRows, MaxCols);
  VisibleRows := MaxRows - 2; // Leave room for padding
  Clear;
  
  DrawMainWindow();
  
  // Which menu is in focus and needs drawing?
  CASE FocusedMenu OF
    INPUT_FILE_SELECT:
	  BEGIN
	    DrawInputFileSelectMenu();
	  END;
	SUBFILE_SELECT:
	  BEGIN
	    DrawSubfileSelectMenu();
	  END;
  END;
  
  // Show the appropriate banner
  IF ShowVolumeBanner THEN
    BuildVolumeMetadataBanner();

  IF ShowSubfileBanner THEN
    BuildSubfileMetadataBanner();

  // Show the hex preview
  IF (HexViewFlag) THEN
    DrawHexPreview();
	
  Refresh;
END;

// --------------------
// Input handling, etc.
// --------------------
PROCEDURE ConstructAppInterface();
BEGIN
  InitScr;
  NoEcho;
  CBreak;
  Keypad(StdScr, True);
  Curs_Set(0);

  DrawInterface();
  
  REPEAT
    DrawInterface();
    InputCharacter := GetCh;
    
	CASE FocusedMenu OF
	  INPUT_FILE_SELECT:
	    CASE InputCharacter OF
          KEY_UP:
            IF CurrentSelection > 0 THEN
			BEGIN
              Dec(CurrentSelection);
			  IF (CurrentSelection < ScrollOffset) THEN
                Dec(ScrollOffset);
			END;
          KEY_DOWN:
            IF CurrentSelection < High(DirectoryContents) THEN
			BEGIN
              Inc(CurrentSelection);
			  IF (CurrentSelection >= ScrollOffset + (VisibleRows - 12)) THEN
                Inc(ScrollOffset);
			END;
	      10,13:
		    BEGIN
		      FileViewFlag := TRUE;
	          HandleFileMenuAction();
		    END;
        END;
      SUBFILE_SELECT:
	    CASE InputCharacter OF
          KEY_UP:
            IF SubfileCurrentSelection > 0 THEN
			BEGIN
              Dec(SubfileCurrentSelection);
			  IF (SubfileCurrentSelection < SubfileScrollOffset) THEN
                Dec(SubfileScrollOffset);
			  HandleSubfileMenuAction();
			END;
          KEY_DOWN:
            IF SubfileCurrentSelection < High(FileTable) THEN
			BEGIN
              Inc(SubfileCurrentSelection);
			  IF (SubfileCurrentSelection >= SubfileScrollOffset + (VisibleRows - 12)) THEN
                Inc(SubfileScrollOffset);
			  HandleSubfileMenuAction();
			END;
	      10,13:
		    BEGIN
			  ExtractFile(SubfileCurrentSelection);
	        END;
		  Ord('A'), Ord('a'):
		    BEGIN
			  // This borks the ncurses renderer; no clue why; it works, it just blows the display all to hell... Uncomment to use, but you'll have to restart your terminal afterwards
		      //ExtractAllFiles();
		    END;
		  27:
		    BEGIN
			  // Clear flags and return to input file menu
		      SubfileCurrentSelection := 0;
			  SubfileScrollOffset := 0;
		      FocusedMenu := INPUT_FILE_SELECT;
			  HexViewFlag := FALSE;
			  FocusedMenu := INPUT_FILE_SELECT;
			  ShowSubfileBanner := False;
		    END;
        END;

	END;
	
    IF is_term_resized(MaxRows, MaxCols) THEN
    BEGIN
      resize_term(0, 0);
    END;
	
  UNTIL ((InputCharacter = Ord('q')) OR (InputCharacter = Ord('Q')));
  EndWin;
END;

INITIALIZATION

BEGIN

END;

FINALIZATION

END.