UNIT O_DIR;

INTERFACE

TYPE
  FILEINFO = RECORD
    Name       : ANSISTRING;
	Size       : INT64;
	Attributes : LONGINT;
  END;

VAR
  DirectoryContents: ARRAY OF FILEINFO;

PROCEDURE SetDirectoryContentsSize(ObjectCount: LONGINT);
PROCEDURE GetDirectoryObjectCount(Directory: STRING);
PROCEDURE GetDirectoryObjectList(Directory: STRING);
PROCEDURE DumpDirectoryContents();
PROCEDURE ArraySwap(VAR A, B: FILEINFO);
PROCEDURE QuickSort(ArrayStart, ArrayEnd: INTEGER);

IMPLEMENTATION

USES
  DOS, SYSUTILS;

// -------------------------------------------
// Set the array length for directory contents
// -------------------------------------------
PROCEDURE SetDirectoryContentsSize(ObjectCount: LONGINT);
BEGIN
  SetLength(DirectoryContents, ObjectCount);
END;

// ------------------------------
// Get the directory object count
// ------------------------------
PROCEDURE GetDirectoryObjectCount(Directory: STRING);
VAR
  FileSearchResult : TSearchRec;
  ObjectCount      : LONGINT = 0;  
BEGIN
  IF FindFirst((IncludeTrailingPathDelimiter(Directory) + '*'), faAnyFile, FileSearchResult) = 0 THEN
    BEGIN
      REPEAT
	    Inc(ObjectCount);
	  UNTIL (FindNext(FileSearchResult) <> 0);
	  FindClose(FileSearchResult);
    END
    ELSE
      WriteLn('Error opening directory: ',Directory);
	  // INSERT DEBUG/ERROR HANDLING HERE
  SetDirectoryContentsSize(ObjectCount);
END;

// ----------------------------------
// Populate the directory object list
// ----------------------------------
PROCEDURE GetDirectoryObjectList(Directory: STRING);
VAR
  FileSearchResult : TSearchRec;
  CurrentRecord    : FILEINFO;
  i                : INTEGER = 0;
BEGIN
  GetDirectoryObjectCount(Directory);
  IF FindFirst((IncludeTrailingPathDelimiter(Directory) + '*'), faAnyFile, FileSearchResult) = 0 THEN
    BEGIN
      REPEAT
	    IF (((FileSearchResult.Attr AND faDirectory) <> 0) AND (FileSearchResult.Name <> '.') AND (FileSearchResult.Name <> '..')) THEN
		  CurrentRecord.Name := ('/' + FileSearchResult.Name)
		ELSE
		  CurrentRecord.Name := FileSearchResult.Name;
		
		CurrentRecord.Size := FileSearchResult.Size;
		CurrentRecord.Attributes := FileSearchResult.Attr;
		DirectoryContents[i] := CurrentRecord;
		Inc(i);
	  UNTIL (FindNext(FileSearchResult) <> 0);
	  FindClose(FileSearchResult);
    END
    ELSE
      WriteLn('Error opening directory: ',Directory); 
  
  QuickSort(0, High(DirectoryContents));
END;

// ----------------------
// Dump DirectoryContents
// ----------------------
PROCEDURE DumpDirectoryContents();
VAR
  i: INTEGER;
BEGIN
  FOR i := 0 TO High(DirectoryContents) DO
  BEGIN
    WriteLn('Object: ',DirectoryContents[i].Name);
  END;
END;

// ------------------------
// Array swap for quicksort
// ------------------------
PROCEDURE ArraySwap(VAR A, B: FILEINFO);
VAR
  Temp: FILEINFO;
BEGIN
  Temp := A;
  A := B;
  B := Temp;
END;

// ------------------------
// Quicksort by object name
// ------------------------
PROCEDURE QuickSort(ArrayStart, ArrayEnd: INTEGER);
VAR
  Pivot : STRING;
  i, j  : INTEGER;
BEGIN
  IF ArrayStart < ArrayEnd THEN
  BEGIN
    i := ArrayStart;
    j := ArrayEnd;
    Pivot := DirectoryContents[(ArrayStart + ArrayEnd) DIV 2].Name;

    REPEAT
      WHILE DirectoryContents[i].Name < Pivot DO 
	    Inc(i);
      WHILE DirectoryContents[j].Name > Pivot DO
	    Dec(j);

      IF i <= j THEN
      BEGIN
        ArraySwap(DirectoryContents[i], DirectoryContents[j]);
        INC(i);
        DEC(j);
      END;
    UNTIL i > j;

    IF ArrayStart < j THEN
	  QuickSort(ArrayStart, j);
    IF i < ArrayEnd THEN
	  QuickSort(i, ArrayEnd);
  END;
END;

INITIALIZATION

BEGIN

END;

FINALIZATION

END.