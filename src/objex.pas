PROGRAM OBJEX;

USES
  O_MENUS, O_DIR, O_DISK, O_DEBUG, DOS, SYSUTILS;

BEGIN
  // Open a debug file set to overwrite; comment this out if not needed
  OpenDebugFile('./debug.log', TRUE);

  // Get our current working directory
  GetDirectoryObjectList(GetCurrentDir());
  
  // Enter TUI loop
  ConstructAppInterface();
  
  // Close debug log
  CloseDebugFile;
END.