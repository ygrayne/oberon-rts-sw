(**
  Textual output of log events.
  --
  (c) 2021-2022 Gray, gray@grayraven.org
  https://oberon-rts.org/licences
**)

MODULE LogView;

  IMPORT SYSTEM, Log, Modules, Texts, Console := ConsoleC, SysCtrl;

  VAR
    W: Texts.Writer;

  PROCEDURE reportAbort(le: Log.Entry);
    VAR mod: Modules.Module;
  BEGIN
    mod := SYSTEM.VAL(Modules.Module, le.adr1);
    Texts.WriteClock(W, le.when);
    Texts.WriteString(W, " ABORT proc "); Texts.WriteString(W, le.procId);
    Texts.WriteString(W, " in "); Texts.WriteString(W, le.str0);
    Texts.WriteString(W, " at"); Texts.WriteHex(W, le.adr0);
    Texts.WriteString(W, " line "); Texts.WriteInt(W, le.more1, 0);
    IF le.cause = SysCtrl.WatchdogAbort THEN
      Texts.WriteString(W, " watchdog")
    ELSIF le.cause = SysCtrl.KillAbort THEN
      Texts.WriteString(W, " kill button")
    ELSIF le.cause = SysCtrl.StackOverflowAbort THEN
      Texts.WriteString(W, " stack overflow");
    ELSIF le.cause = SysCtrl.NotAliveAbort THEN
      Texts.WriteString(W, " not alive procs")
    ELSE
      Texts.WriteString(W, " SYS ERROR: inconsistent data: invalid abort log cause")
    END;
    Texts.WriteLn(W)
  END reportAbort;


  PROCEDURE reportTrap(le: Log.Entry);
    VAR mod: Modules.Module;
  BEGIN
    mod := SYSTEM.VAL(Modules.Module, le.adr1);
    Texts.WriteClock(W, le.when);
    Texts.WriteString(W, " TRAP "); Texts.WriteInt(W, le.cause, 0);
    Texts.WriteString(W, " proc "); Texts.WriteString(W, le.procId);
    Texts.WriteString(W, " in "); Texts.WriteString(W, le.str0);
    Texts.WriteString(W, " at"); Texts.WriteHex(W, le.adr0);
    Texts.WriteString(W, " pos "); Texts.WriteInt(W, le.more0, 0);
    Texts.WriteString(W, " line "); Texts.WriteInt(W, le.more1, 0);
    Texts.WriteLn(W)
  END reportTrap;


  PROCEDURE reportSystem(le: Log.Entry);
  BEGIN
    Texts.WriteClock(W, le.when);
    IF le.cause = Log.SysInit THEN
      Texts.WriteString(W, " SYS INIT: kill non-system procs, reset system procs.")
    ELSIF le.cause = Log.SysRecover THEN
      Texts.WriteString(W, " SYS RECOVER: kill non-vital procs, reset vital procs.")
    ELSIF le.cause = Log.SysReset THEN
      Texts.WriteString(W, " SYS RESET: reset all procs.")
    ELSIF le.cause = Log.SysRestart THEN
      Texts.WriteString(W, " SYS RESTART: load system.");
      Texts.WriteString(W, " SCR:"); Texts.WriteHex(W, le.more0);
      Texts.WriteString(W, " error state: "); Texts.WriteInt(W, le.more2, 0);
      Texts.WriteString(W, "  ");
      IF le.more1 = SysCtrl.RestartFPGA THEN
        Texts.WriteString(W, "FPGA")
      ELSIF le.more1 = SysCtrl.RestartRstBtn THEN
        Texts.WriteString(W, "RSTB")
      ELSIF le.more1 = SysCtrl.RestartSW THEN
        Texts.WriteString(W, "SW")
      ELSIF le.more1 = SysCtrl.RestartSWother THEN
        Texts.WriteString(W, "SWOTH")
      ELSIF le.more1 = SysCtrl.RestartStackOvfl THEN
        Texts.WriteString(W, "STOVFL")
      ELSE
        Texts.WriteString(W, "unknown")
      END;
    ELSIF le.cause = Log.SysHalt THEN
      Texts.WriteString(W, " SYS HALT")
    ELSIF le.cause = Log.SysFault THEN
      Texts.WriteString(W, " SYS FAULT: internal error")
    ELSIF le.cause = Log.SysErrorAbort THEN
      Texts.WriteString(W, " SYS ERROR: abort in error handling")
    ELSIF le.cause = Log.SysErrorTrap THEN
      Texts.WriteString(W, " SYS ERROR: trap in error handling in ");
      Texts.WriteString(W, le.str0);
      Texts.WriteString(W, " trap "); Texts.WriteInt(W, le.more0, 0);
      Texts.WriteString(W, " pos "); Texts.WriteInt(W, le.more2, 0);
      Texts.WriteString(W, " line "); Texts.WriteInt(W, le.more1, 0)
    ELSIF le.cause = Log.SysOK THEN
      Texts.WriteString(W, " SYS OK SCR:"); Texts.WriteHex(W, le.more0)
    ELSIF le.cause = Log.SysProcsFull THEN
      Texts.WriteString(W, " SYS too many procs: "); Texts.WriteString(W, le.procId);
    ELSIF le.cause = Log.SysProcsChange THEN
      Texts.WriteString(W, " SYS procs:"); Texts.WriteHex(W, le.more0); Texts.WriteHex(W, le.more1); Texts.WriteHex(W, le.more2)
    ELSIF le.cause = Log.SysCollect THEN
      Texts.WriteString(W, " SYS GC: "); Texts.WriteInt(W, le.more0, 0); Texts.WriteInt(W, le.more1, 7); Texts.WriteInt(W, le.more2, 7)
    ELSIF le.cause = Log.SysRTCinst THEN
      Texts.WriteString(W, " SYS RTC installed: "); Texts.WriteInt(W, le.more0, 0); Texts.WriteInt(W, le.more1, 3)
    ELSIF le.cause = Log.SysRTCnotinst THEN
      Texts.WriteString(W, " SYS RTC not installed")
    ELSIF le.cause = Log.SysMemStart THEN
      Texts.WriteString(W, " SYS start stack: "); Texts.WriteInt(W, le.more0, 0); Texts.WriteString(W, " heap: ");
      Texts.WriteInt(W, le.more2, 0); Texts.WriteString(W, " SP: "); Texts.WriteInt(W, le.more1, 0);
    ELSIF le.cause = Log.SysStart THEN
      Texts.WriteString(W, " SYS start error: "); Texts.WriteInt(W, le.more0, 0); Texts.WriteString(W, " table: ");
      Texts.WriteInt(W, le.more1, 0); Texts.WriteString(W, " entry: "); Texts.WriteInt(W, le.more2, 0)
    ELSE
      Texts.WriteString(W, " SYS ERROR: inconsistent data: sys log cause")
    END;
    Texts.WriteLn(W)
  END reportSystem;


  PROCEDURE reportProcess(le: Log.Entry);
  BEGIN
    Texts.WriteClock(W, le.when);
    IF le.cause = Log.ProcInstall THEN
      Texts.WriteString(W, " PROC INST: "); Texts.WriteString(W, le.procId); Texts.WriteInt(W, le.more0, 3)
    ELSIF le.cause = Log.ProcRemove THEN
      Texts.WriteString(W, " PROC RM: "); Texts.WriteString(W, le.procId); Texts.WriteInt(W, le.more0, 3)
    ELSIF le.cause = Log.ProcRecover THEN
      Texts.WriteString(W, " PROC RCVR: "); Texts.WriteString(W, le.procId); Texts.WriteInt(W, le.more0, 3)
    ELSIF le.cause = Log.ProcReset THEN
      Texts.WriteString(W, " PROC RST: "); Texts.WriteString(W, le.procId); Texts.WriteInt(W, le.more0, 3)
     ELSIF le.cause = Log.ProcOverflow THEN
      Texts.WriteString(W, " PROC OVFL: "); Texts.WriteString(W, le.procId); Texts.WriteInt(W, le.more0, 3)
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
    END
  END PrintEntry;


  PROCEDURE ShowLog*;
    VAR le: Log.Entry;
  BEGIN
    Texts.WriteString(W, "LogView.List "); Texts.WriteLn(W);
    Log.BeginGet;
    WHILE Log.GetMore() DO
      Log.GetNext(le);
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

(*
    VersionAdr = -128;  (* IO address to read processor version information *)

  (* processor version as read from FPGA *)
  PROCEDURE getProcVersion(VAR creator, model, major, minor, dev: INTEGER);
    VAR x: INTEGER;
  BEGIN
    SYSTEM.GET(VersionAdr, x);
    creator := BFX(x, 31, 26);
    model := BFX(x, 25, 20);
    major := BFX(x, 19, 14);
    minor := BFX(x, 13, 8);
    dev := BFX(x, 7, 0)
  END getProcVersion;

  PROCEDURE printProcVersion;
    VAR creator, model, major, minor, dev: INTEGER;
  BEGIN
    getProcVersion(creator, model, major, minor, dev);
    Texts.WriteInt(W, creator, 0); Texts.WriteString(W, "-");
    Texts.WriteInt(W, model, 0); Texts.WriteString(W, "-");
    Texts.WriteInt(W, major, 0); Texts.WriteString(W, ".");
    Texts.WriteInt(W, minor, 0); Texts.WriteString(W, "-");
    Texts.WriteInt(W, dev, 0)
  END printProcVersion;
*)
