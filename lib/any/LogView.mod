(**
  Textual output of log events.
  --
  (c) 2021-2023 Gray, gray@grayraven.org
  https://oberon-rts.org/licences
**)

MODULE LogView;

  IMPORT Log, Texts, Console := ConsoleB, RS232, Procs := Processes, Errors;

  VAR
    W: Texts.Writer;

  PROCEDURE reportAbort(le: Log.Entry);
  BEGIN
    Texts.Write(W, " "); Texts.WriteClock(W, le.when);
    Texts.WriteString(W, " ABORT:");
    IF le.cause = Errors.Watchdog THEN
      Texts.WriteString(W, " WDOG")
    ELSIF le.cause = Errors.Kill THEN
      Texts.WriteString(W, " KILLB")
    ELSIF le.cause = Errors.StackOverflowLim THEN
      Texts.WriteString(W, " SOFL")
    ELSIF le.cause = Errors.StackOverflowHot THEN
      Texts.WriteString(W, " SOFH")
    ELSE
      Texts.WriteString(W, " ???")
    END;
    Texts.WriteString(W, " in "); Texts.WriteString(W, le.name);
    Texts.WriteString(W, " in "); Texts.WriteString(W, le.str0);
    Texts.WriteString(W, " at"); Texts.WriteHex(W, le.adr0);
    Texts.WriteString(W, " line "); Texts.WriteInt(W, le.more1, 0);
    Texts.WriteLn(W)
  END reportAbort;

  PROCEDURE reportTrap(le: Log.Entry);
  BEGIN
    Texts.Write(W, " "); Texts.WriteClock(W, le.when);
    Texts.WriteString(W, " TRAP: "); Texts.WriteInt(W, le.cause, 0);
    IF le.cause = Errors.ArrayIndex THEN
      Texts.WriteString(W, " ARRI")
    ELSIF le.cause = Errors.TypeGuard THEN
      Texts.WriteString(W, " TYGD")
    ELSIF le.cause = Errors.CopyOverflow THEN
      Texts.WriteString(W, " CPOF")
    ELSIF le.cause = Errors.NilPointer THEN
      Texts.WriteString(W, " NILP")
    ELSIF le.cause = Errors.IllegalCall THEN
      Texts.WriteString(W, " ILCL")
    ELSIF le.cause = Errors.DivZero THEN
      Texts.WriteString(W, " DIVZ")
    ELSIF le.cause = Errors.Assertion THEN
      Texts.WriteString(W, " ASRT")
    ELSE
      Texts.WriteString(W, " ????")
    END;
    Texts.WriteString(W, " in "); Texts.WriteString(W, le.name);
    Texts.WriteString(W, " in "); Texts.WriteString(W, le.str0);
    Texts.WriteString(W, " at"); Texts.WriteHex(W, le.adr0);
    Texts.WriteString(W, " pos "); Texts.WriteInt(W, le.more0, 0);
    Texts.WriteString(W, " line "); Texts.WriteInt(W, le.more1, 0);
    Texts.WriteLn(W)
  END reportTrap;


  PROCEDURE reportSystem(le: Log.Entry);
  BEGIN
    Texts.Write(W, " "); Texts.WriteClock(W, le.when);
    IF le.cause = Log.SysColdStart THEN
      Texts.WriteString(W, " SYS COLD START");
      Texts.WriteString(W, " SCR:"); Texts.WriteHex(W, le.more0);
      Texts.WriteString(W, " ERR:"); Texts.WriteHex(W, le.more1);
    ELSIF le.cause = Log.SysRestart THEN
      Texts.WriteString(W, " SYS RESTART");
      Texts.WriteString(W, " SCR:"); Texts.WriteHex(W, le.more0);
      Texts.WriteString(W, " ERR:"); Texts.WriteHex(W, le.more1);
    ELSIF le.cause = Log.SysReset THEN
      Texts.WriteString(W, " SYS RESET");
      Texts.WriteString(W, " SCR:"); Texts.WriteHex(W, le.more0);
      Texts.WriteString(W, " ERR:"); Texts.WriteHex(W, le.more1);
    ELSIF le.cause = Log.SysHalt THEN
      Texts.WriteString(W, " SYS HALT")
    ELSIF le.cause = Log.SysFault THEN
      Texts.WriteString(W, " SYS FAULT: internal error, restarting")
    ELSIF le.cause = Log.SysErrorInError THEN
      Texts.WriteString(W, " SYS ERROR: error in error handling, restarting")
    ELSIF le.cause = Log.SysOK THEN
      Texts.WriteString(W, " SYS AUDIT OK SCR:"); Texts.WriteHex(W, le.more0);
      Texts.WriteString(W, " ERR:"); Texts.WriteHex(W, le.more1)
    ELSIF le.cause = Log.SysProcsFull THEN
      Texts.WriteString(W, " SYS too many procs: "); Texts.WriteString(W, le.name);
    ELSIF le.cause = Log.SysProcsChange THEN
      Texts.WriteString(W, " SYS procs:"); Texts.WriteHex(W, le.more0); Texts.WriteHex(W, le.more1); Texts.WriteHex(W, le.more2)
    ELSIF le.cause = Log.SysCollect THEN
      Texts.WriteString(W, " SYS GC: "); Texts.WriteInt(W, le.more0, 0); Texts.WriteInt(W, le.more1, 7); Texts.WriteInt(W, le.more2, 7)
    ELSIF le.cause = Log.SysRTCinst THEN
      Texts.WriteString(W, " SYS RTC installed: "); Texts.WriteInt(W, le.more0, 0); Texts.WriteInt(W, le.more1, 3)
    ELSIF le.cause = Log.SysRTCnotinst THEN
      Texts.WriteString(W, " SYS RTC not installed")
    ELSIF le.cause = Log.SysMemStart THEN
      Texts.WriteString(W, " SYS startup stack: "); Texts.WriteInt(W, le.more0, 0); Texts.WriteString(W, " heap: ");
      Texts.WriteInt(W, le.more2, 0); Texts.WriteString(W, " SP: "); Texts.WriteInt(W, le.more1, 0);
    ELSIF le.cause = Log.SysStartTableError THEN
      Texts.WriteString(W, " SYS start table error: "); Texts.WriteInt(W, le.more0, 0); Texts.WriteString(W, " table: ");
      Texts.WriteInt(W, le.more1, 0); Texts.WriteString(W, " entry: "); Texts.WriteInt(W, le.more2, 0)
    ELSIF le.cause = Log.SysStartTableUsed THEN
      Texts.WriteString(W, " SYS start table: "); Texts.WriteInt(W, le.more0, 0); Texts.WriteString(W, " set: ");
      Texts.WriteInt(W, le.more1, 0);
    ELSE
      Texts.WriteString(W, " SYS ERROR: inconsistent data: sys log cause")
    END;
    Texts.WriteLn(W)
  END reportSystem;


  PROCEDURE reportProcess(le: Log.Entry);
  BEGIN
    Texts.Write(W, " "); Texts.WriteClock(W, le.when);
    IF le.cause = Log.ProcNew THEN
      Texts.WriteString(W, " PROC NEW: "); Texts.WriteInt(W, le.more0, 0);
      IF le.more1 = Procs.OK THEN
        Texts.WriteString(W, " OK")
      ELSE
        Texts.WriteString(W, " FAIL")
      END
    ELSIF le.cause = Log.ProcEnable THEN
      Texts.WriteString(W, " PROC EN: "); Texts.WriteInt(W, le.more0, 0);
      Texts.WriteString(W, " "); Texts.WriteString(W, le.name);
      Texts.WriteString(W, " trig: "); Texts.WriteInt(W, le.more1, 0);
      IF le.more1 # Procs.TrigNone THEN Texts.WriteString(W, " tm: "); Texts.WriteInt(W, le.more2, 0) END;
    ELSIF le.cause = Log.ProcReset THEN
      Texts.WriteString(W, " PROC RST: "); Texts.WriteInt(W, le.more0, 0);
      Texts.WriteString(W, " "); Texts.WriteString(W, le.name)
     ELSIF le.cause = Log.ProcNilProcHardware THEN
      Texts.WriteString(W, " PROC NIL: "); Texts.WriteInt(W, le.more0, 0);
      Texts.WriteString(W, " has HW allocated")
    ELSE
      Texts.WriteString(W, " SYS ERROR: inconsistent data: proc log cause")
    END;
    Texts.WriteLn(W)
  END reportProcess;


  PROCEDURE PrintEntry*(le: Log.Entry);
  BEGIN
    IF le.event = Log.Abort THEN
      reportAbort(le)
    ELSIF le.event = Log.Trap THEN
      reportTrap(le)
    ELSIF le.event = Log.System THEN
      reportSystem(le)
    ELSIF le.event = Log.Process THEN
      reportProcess(le)
    ELSE
      Texts.WriteString(W, " SYS ERROR: inconsistent data: log event")
    END;
    REPEAT UNTIL RS232.TxEmpty(Console.Dev)
  END PrintEntry;


  PROCEDURE ShowLog*;
    VAR le: Log.Entry;
  BEGIN
    Texts.WriteString(W, "LogView.ShowLog "); Texts.WriteLn(W);
    Log.BeginGet;
    WHILE Log.More() DO
      Log.Get(le);
      PrintEntry(le)
    END;
    Log.EndGet
  END ShowLog;


  PROCEDURE InstallLogPrint*;
  BEGIN
    Log.SetPrintHandler(PrintEntry)
  END InstallLogPrint;

  PROCEDURE UninstallLogPrint*;
  BEGIN
    Log.SetPrintHandler(NIL)
  END UninstallLogPrint;

BEGIN
  W := Console.C
END LogView.
