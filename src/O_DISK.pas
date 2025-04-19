UNIT O_DISK;

INTERFACE

TYPE
  DIR_RECORD = RECORD 
    BootSector      : INTEGER;
	FirstDataSector : INTEGER;
	Unknown1        : INTEGER;
	VolName         : STRING[7];	{one lenght byte followed by seven character bytes}
	NumberBlocks    : INTEGER;
	NumberFiles     : INTEGER;
	Unknown2        : INTEGER;
	VolTimeStamp    : INTEGER;
    END;
	
  FILE_RECORD = RECORD
    StartingSector    : INTEGER;
	EndingSector      : INTEGER;
	FileType          : INTEGER;	{2:code; 3:text; 5:data}
	FileName          : STRING[15];	{15 bytes of characters preceeded by a length byte}
	BytesinLastSector :	INTEGER;
	FileTimestamp     : INTEGER;
	END;
	
CONST
  VOLNAME_LENGTH    = 7;
  FILENAME_LENGTH   = 15;
  INT_LENGTH        = 2;
  FILE_TABLE_OFFSET = 4;
  VOLUME_HDR_LENGTH = 22;  
  SECTOR_SIZE       = 512;

VAR
  DiskImage           : FILE OF BYTE;
  VolumeEntryPoint    : LONGINT;
  FileTableEntryPoint : LONGINT;
  VolumeHeader        : DIR_RECORD;
  FileTable           : ARRAY OF FILE_RECORD;
  FileInMemory        : ARRAY OF BYTE;

// Production routines
PROCEDURE OpenDiskImage(Filename: STRING);
PROCEDURE CloseDiskImage();
PROCEDURE SetVolumeEntryPoint();
PROCEDURE SetFileTableEntryPoint();
PROCEDURE BuildDirectoryStructure();
PROCEDURE SetFileListSize();
PROCEDURE BuildFileTable();
PROCEDURE ExtractFile(FileNumber: INTEGER);
PROCEDURE LoadFileIntoMemory(FileNumber: INTEGER);
PROCEDURE ExtractAllFiles();
FUNCTION WordToHex(WordIn: WORD): STRING;
FUNCTION ReadByte(Address: LONGINT): BYTE;
FUNCTION ReadWord(Address: LONGINT): WORD;
FUNCTION LongIntToHex(LongIn: LONGINT): STRING;
FUNCTION ByteToHex(ByteIn: BYTE): STRING;

// Debug routines
PROCEDURE DumpVolumeInfo();
PROCEDURE DumpFileTable();

IMPLEMENTATION

USES
  DOS, CRT, SYSUTILS, NCURSES, O_DEBUG;
  
// -------------------------------------------------------
// Convert default int values out of a word to hexadecimal
// -------------------------------------------------------
FUNCTION WordToHex(WordIn: WORD): STRING;
CONST
  HexDigits: ARRAY[0..15] OF CHAR = '0123456789ABCDEF';
BEGIN
  WordToHex := HexDigits[(WordIn SHR 12) AND $F] + HexDigits[(WordIn SHR 8) AND $F] + HexDigits[(WordIn SHR 4) AND $F] + HexDigits[WordIn AND $F];
END;

// -------------------------------------------------------
// Convert default int values out of a BYTE to hexadecimal
// -------------------------------------------------------
FUNCTION ByteToHex(ByteIn: BYTE): STRING;
CONST
  HexDigits: ARRAY[0..15] OF CHAR = '0123456789ABCDEF';
BEGIN
  ByteToHex := HexDigits[(ByteIn SHR 4) AND $F] + HexDigits[ByteIn AND $F];
END;

FUNCTION LongIntToHex(LongIn: LONGINT): STRING;
CONST
  HexDigits: ARRAY[0..15] of CHAR = '0123456789ABCDEF';
VAR
  ResultString : STRING;
  i            : INTEGER;
BEGIN
  ResultString := '';
  // Loop through 8 nibbles (32 bits = 8 hex digits)
  FOR i := 7 DOWNTO 0 DO
    ResultString := ResultString + HexDigits[(LongIn SHR (i * 4)) AND $F];
  LongIntToHex := ResultString;
END;

// -----------
// Read a byte
// -----------
FUNCTION ReadByte(Address: LONGINT): BYTE;
BEGIN
  Seek(DiskImage, Address);
  BlockRead(DiskImage, ReadByte, 1);
END;

// -----------
// Read a word
// -----------
FUNCTION ReadWord(Address: LONGINT): WORD;
BEGIN
  Seek(DiskImage, Address);
  BlockRead(DiskImage, ReadWord, 2);
	
  ReadWord := (ReadWord SHR 8) OR (ReadWord SHL 8);
END;

// -----------------
// Open a disk image
// -----------------
PROCEDURE OpenDiskImage(Filename: STRING);
BEGIN
  IF FileExists(Filename) THEN
  BEGIN
    Assign(DiskImage, Filename);
	Reset(DiskImage);
  END
  ELSE
    { INSERT ERROR HANDLING LOGIC HERE AT SOME POINT }
    WriteLn('DEBUG: File ',Filename,' does not exist.');
	EXIT;
  
  IF IOResult <> 0 THEN
  BEGIN
    { INSERT ERROR HANDLING LOGIC HERE AT SOME POINT }
	WriteLn('DEBUG: Error opening disk image.');
    EXIT;
  END;
END;

// ------------------
// Close a disk image
// ------------------
PROCEDURE CloseDiskImage();
BEGIN
  Close(DiskImage);

  IF IOResult <> 0 THEN
  BEGIN
    { INSERT ERROR HANDLING LOGIC HERE AT SOME POINT }
	WriteLn('DEBUG: Error closing disk image.');
  END
  ELSE
    WriteLn('DEBUG: Disk image file closed.');
END;

// -----------------------------------------------
// Set UCSD directory structure record entry point
// -----------------------------------------------
PROCEDURE SetVolumeEntryPoint();
BEGIN
  VolumeEntryPoint := $0400;
END;

PROCEDURE SetFileTableEntryPoint();
BEGIN
  FileTableEntryPoint := (VolumeEntryPoint + VOLUME_HDR_LENGTH + FILE_TABLE_OFFSET);
END;

// -----------------------------------
// Populate directory structure record
// -----------------------------------
PROCEDURE BuildDirectoryStructure();
VAR
  CurrentAddress : LONGINT;
  VolNameLength  : INTEGER;
  i              : INTEGER;
BEGIN
  CurrentAddress := VolumeEntryPoint;
  
  // Boot sector
  VolumeHeader.BootSector := ReadWord(CurrentAddress);
  Inc(CurrentAddress, INT_LENGTH);
  
  // First data sector on disk
  VolumeHeader.FirstDataSector := ReadWord(CurrentAddress);
  Inc(CurrentAddress, INT_LENGTH);
  
  // It's a mystery to everyone
  VolumeHeader.Unknown1 := ReadWord(CurrentAddress);
  Inc(CurrentAddress, INT_LENGTH);
  
  // Volume name - limited to seven (7) characters, first byte is length
  VolNameLength := ReadByte(CurrentAddress);
  VolumeHeader.VolName[0] := Chr(ReadByte(CurrentAddress));
  Inc(CurrentAddress);
  FOR i := 1 TO VolNameLength DO
  BEGIN
    VolumeHeader.VolName[i] := Chr(ReadByte(CurrentAddress));
	Inc(CurrentAddress);
  END;
  CurrentAddress := CurrentAddress + (VOLNAME_LENGTH - VolNameLength);
  
  // Number of blocxks on disk
  VolumeHeader.NumberBlocks := ReadWord(CurrentAddress);
  Inc(CurrentAddress, INT_LENGTH);
  
  // Number of files on disk
  VolumeHeader.NumberFiles := (ReadWord(CurrentAddress) - 1);
  Inc(CurrentAddress, INT_LENGTH);
  
  // It's a mystery to everyone
  VolumeHeader.Unknown2 := ReadWord(CurrentAddress);
  Inc(CurrentAddress, INT_LENGTH);
  
  // It's a mystery to everyone (it's the timestamp, but the format is unknown - maybe LOS format?)
  VolumeHeader.VolTimeStamp := ReadWord(CurrentAddress);
END;

// ----------------------------------------
// Readout the directory structure metadata
// ----------------------------------------
PROCEDURE DumpVolumeInfo();
BEGIN
  WriteLn('Volume Name       : ',VolumeHeader.VolName);
  WriteLn('Boot Sector       : 0x',WordToHex(VolumeHeader.BootSector));
  WriteLn('First Data Sector : 0x',WordToHex(VolumeHeader.FirstDataSector));
  WriteLn('Unknown1          : 0x',WordToHex(VolumeHeader.Unknown1));
  WriteLn('Number Of Blocks  : ',VolumeHeader.NumberBlocks);
  WriteLn('Number Of Files   : ',VolumeHeader.NumberFiles);
  WriteLn('Unknown2          : 0x',WordToHex(VolumeHeader.Unknown2));
  WriteLn('Vol Timestamp     : 0x',WordToHex(VolumeHeader.VolTimeStamp));
END;

// ------------------------------------------------------
// Set the file table size based upon the volume metadata
// ------------------------------------------------------
PROCEDURE SetFileListSize();
BEGIN
  SetLength(FileTable, VolumeHeader.NumberFiles);
END;

// --------------------------
// Populate file table record
// --------------------------
PROCEDURE BuildFileTable();
VAR
  CurrentAddress    : LONGINT;
  FileNameLength    : INTEGER;
  i, j              : INTEGER;
  CurrentFileRecord : FILE_RECORD;
BEGIN
  CurrentAddress := FileTableEntryPoint;
  SetLength(FileTable, (VolumeHeader.NumberFiles + 1));
  
  FOR i := 0 TO (VolumeHeader.NumberFiles) DO
  BEGIN
    // File starting sector
    CurrentFileRecord.StartingSector := ReadWord(CurrentAddress);
	Inc(CurrentAddress, INT_LENGTH);
	
	// Sector which serves as the file boundary (i.e. the highest possible byte of the file is the final byte of the sector that precedes this one)
	CurrentFileRecord.EndingSector := ReadWord(CurrentAddress);
	Inc(CurrentAddress, INT_LENGTH);
	
	// File type: 2: Code / 3: Text / 5: Data
	CurrentFileRecord.FileType := ReadWord(CurrentAddress);
	Inc(CurrentAddress, INT_LENGTH);
	
	// File name: limited to 15 characters, first byte is the length
	FileNameLength := ReadByte(CurrentAddress);
	CurrentFileRecord.FileName[0] := Chr(ReadByte(CurrentAddress));
	Inc(CurrentAddress);
	FOR j := 1 TO FileNameLength DO
    BEGIN
      CurrentFileRecord.FileName[j] := Chr(ReadByte(CurrentAddress));
	  Inc(CurrentAddress);
    END;
    CurrentAddress := CurrentAddress + (FILENAME_LENGTH - FileNameLength);
	
	// Number of bytes in the sector before the sector boundary from above
	CurrentFileRecord.BytesinLastSector := ReadWord(CurrentAddress);
	Inc(CurrentAddress, INT_LENGTH);
	
	// It's a mystery to everyone (it's the timestamp, but the format is unknown - maybe LOS format?)
	CurrentFileRecord.FileTimestamp := ReadWord(CurrentAddress);
	Inc(CurrentAddress, INT_LENGTH);
	
	// Add to FileTable
	FileTable[i] := CurrentFileRecord;
  END;
END;

// ----------------------
// Readout the file table
// ----------------------
PROCEDURE DumpFileTable();
VAR
  FileType : STRING;
  i        : INTEGER;
BEGIN
  FOR i:= 0 TO VolumeHeader.NumberFiles DO
  BEGIN
    CASE (FileTable[i].FileType) OF
	  2: FileType := 'Code';
	  3: FileType := 'Text';
	  5: FileType := 'Data';
	END;
    WriteLn('Filename: ',FileTable[i].FileName,' (',i,')');
	WriteLn('    ','╠═══','Starting Sector   : 0x',WordToHex(FileTable[i].StartingSector));
	WriteLn('    ','╠═══','Ending Sector     : 0x',WordToHex(FileTable[i].EndingSector));
	WriteLn('    ','╠═══','FileType          : ',FileType);
	WriteLn('    ','╠═══','BytesinLastSector : ',FileTable[i].BytesinLastSector);
	WriteLn('    ','╚═══','File Timestamp    : 0x',WordToHex(FileTable[i].FileTimestamp));
  END;
END;

// ---------------------------------
// Load file into memory for viewing
// ---------------------------------
PROCEDURE LoadFileIntoMemory(FileNumber: INTEGER);
VAR
  StartAddress : LONGINT;
  EndAddress   : LONGINT;
  FileLength   : LONGINT;
  SectorCount  : INTEGER;
  i            : INTEGER;
  
BEGIN
  // Get file from disk image and calculate addressing and size
  StartAddress := (FileTable[FileNumber].StartingSector * SECTOR_SIZE);
  EndAddress := ((FileTable[FileNumber].EndingSector * SECTOR_SIZE) - SECTOR_SIZE + FileTable[FileNumber].BytesinLastSector);
  FileLength := (EndAddress - StartAddress);
  
  // Set dynamic array length
  SetLength(FileInMemory, FileLength);
  
  // Copy file into memory
  Seek(DiskImage, StartAddress);
  BlockRead(DiskImage, FileInMemory[0], FileLength);
END;


// ------------------------
// Extract a file from disk
// ------------------------
PROCEDURE ExtractFile(FileNumber: INTEGER);
VAR
  StartAddress:   LONGINT;
  EndAddress:     LONGINT;
  FileLength:     LONGINT;
  SectorCount:    INTEGER;
  OutputFileName: STRING;
  OutputFile:     FILE OF BYTE;
  FileBuffer:     ARRAY OF BYTE;
  i:              INTEGER;
  
BEGIN
  // Get file from disk image and calculate addressing and size
  StartAddress := (FileTable[FileNumber].StartingSector * SECTOR_SIZE);
  EndAddress := ((FileTable[FileNumber].EndingSector * SECTOR_SIZE) - SECTOR_SIZE + FileTable[FileNumber].BytesinLastSector);
  FileLength := (EndAddress - StartAddress);
  
  // Open output file
  OutputFileName := FileTable[FileNumber].FileName;
  Assign(OutputFile, OutputFileName);
  Rewrite(OutputFile, 1);
  
  // Set dynamic array length
  SetLength(FileBuffer, FileLength);
  
  // Transfer data from image to output file
  Seek(DiskImage, StartAddress);
  BlockRead(DiskImage, FileBuffer[0], FileLength);
  BlockWrite(OutputFile, FileBuffer[0], FileLength);
  
  // Close output file
  Close(OutputFile);
END;

// ---------------------------
// Extract all files from disk
// ---------------------------
PROCEDURE ExtractAllFiles();
VAR
  i: INTEGER;
BEGIN
  FOR i := 0 TO (Length(FileTable)) DO
  BEGIN
    ExtractFile(i);
  END;
END;

INITIALIZATION

BEGIN

END;

FINALIZATION

END.