UNIT O_DEBUG;

INTERFACE

VAR
  DebugFile   : TEXT;
  DebugString : STRING;

PROCEDURE OpenDebugFile(CONST DebugFileName: STRING; OverwriteMode: BOOLEAN);
PROCEDURE WriteDebug(CONST DebugMessage: STRING);
PROCEDURE CloseDebugFile;

IMPLEMENTATION

USES
  DOS, SYSUTILS;
  
// ---------------------
// Open a debug log file
// ---------------------
PROCEDURE OpenDebugFile(CONST DebugFileName: STRING; OverwriteMode: BOOLEAN);
BEGIN
  Assign(DebugFile, DebugFileName);
  
  IF (OverwriteMode) THEN
    Rewrite(DebugFile)
  ELSE
    Append(DebugFile);
END;

// -------------------------------
// Write to an open debug log file
// -------------------------------
PROCEDURE WriteDebug(CONST DebugMessage: STRING);
BEGIN
  WriteLn(DebugFile, DebugMessage);
  // Write immediately - we're not playing around here!
  Flush(DebugFile); 
END;

// ----------------------
// Close a debug log file
// ----------------------
PROCEDURE CloseDebugFile;
BEGIN
  Close(DebugFile);
END;

INITIALIZATION

BEGIN

END;

FINALIZATION

END.