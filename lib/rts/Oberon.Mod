(**
  Entry point for the outer core of the system, loaded my Modules.
  --
  Based on Project Oberon and Embedded Project Oberon
  (*JG 6.9.90 / 23.9.93 / 13.8.94 *)
  (*NW 14.4.2013 / 22.12.2013 *)
  (*CB 01/07/2019 *)
  --
  Changes by Gray, gray@grayraven.org, 2020 - 2023
  https://oberon-rts.org/licences
**)

MODULE Oberon;

  IMPORT
     SYSTEM, Procs := Processes, Modules, Files, Kernel, Cmds, Errors, Log, SysCtrl, RTC, SPIdev;

  CONST
    SP = 14;

    (* RTC connection *)
    RTCspiDevice = SPIdev.Dev0; (* unbuffered, shared with SD card *)
    RTCchipselect = 1;

    (* GC process config *)
    GCperiod = 7;
    GCid = "gc";
    GCprio = 0;
    GCptype = Procs.SystemProc;
    GCstackSize = 512;
    GCstackHot = 0;
    GClimitDiv = 4; (* kick in when only 1/4 of heap space is left *)

  VAR
    (* EO compatibility, eg. as used by System *)
    Par*: Cmds.ParRef;
    Call*: PROCEDURE(name: ARRAY OF CHAR; VAR res: INTEGER);

    (* GC *)
    gc: Procs.Process;
    gcstack: ARRAY GCstackSize OF BYTE;
    gcCount, heapSize, GClimit*: INTEGER;


  PROCEDURE Clock*(): INTEGER;
    VAR x: INTEGER;
  BEGIN
    x := Kernel.Clock()
    RETURN x
  END Clock;


  PROCEDURE SetClock* (d: INTEGER);
  BEGIN
    Kernel.SetClock(d)
  END SetClock;


  PROCEDURE Time*(): INTEGER;
  BEGIN
    RETURN Kernel.Time()
  END Time;


  (* garbage collector *)
  PROCEDURE collect;
    VAR mod: Modules.Module; alloc, time: INTEGER; le: Log.Entry;
  BEGIN
    alloc := Kernel.allocated;
    time := Procs.Time();
    mod := Modules.root; LED(21H);
    WHILE mod # NIL DO
      IF mod.name[0] # 0X THEN Kernel.Mark(mod.ptr) END;
      mod := mod.next
    END;
    LED(23H);
    Files.RestoreList; LED(27H);
    Kernel.Scan; LED(20H);
    le.event := Log.System; le.cause := Log.SysCollect; le.more0 := Time() - time;
    le.more1 := alloc; le.more2 := Kernel.allocated;
    Log.Put(le)
  END collect;

  PROCEDURE gcc;
  BEGIN
    Procs.SetPeriod(GCperiod);
    REPEAT
      Procs.Next;
      IF (gcCount = 0) OR (Kernel.allocated >= GClimit) THEN
        collect;
        gcCount := 1;
      END
    UNTIL FALSE
  END gcc;

  PROCEDURE installGC;
    VAR res: INTEGER;
  BEGIN
    heapSize := Kernel.heapLim - Kernel.heapOrg;
    GClimit := heapSize - (heapSize DIV GClimitDiv);
    gcCount := 1;
    NEW(gc);
    Procs.Init(gc, gcc, gcstack, GCstackHot, GCptype, GCprio, GCid);
    Procs.Install(gc, res)
  END installGC;


  PROCEDURE Collect*;
  BEGIN
    gcCount := 0
  END Collect;

  (* start-up stuff *)

  PROCEDURE logRestart;
    VAR le: Log.Entry;
  BEGIN
    le.event := Log.System; le.cause := Log.SysRestart;
    SysCtrl.GetReg(le.more0);
    SysCtrl.GetRestartCause(le.more1);
    SysCtrl.GetErrorState(le.more2);
    Log.Put(le);
    le.event := Log.System;
    IF RTC.Installed THEN
      le.cause := Log.SysRTCinst; le.more0 := RTCspiDevice; le.more1 := RTCchipselect
    ELSE
      le.event := Log.System; le.cause := Log.SysRTCnotinst
    END;
    Log.Put(le)
  END logRestart;


  PROCEDURE logMemData(SP: INTEGER);
    VAR x: INTEGER; le: Log.Entry;
  BEGIN
    le.event := Log.System; le.cause := Log.SysMemStart;
    (***
    StackMonitor.GetMax(x);
    *)
    x := 0;
    le.more0 := Kernel.stackOrg - x; (* startup stack used *)
    le.more1 := Kernel.stackOrg - SP; (* stack pointer before loading cmds *)
    le.more2 := Kernel.allocated;  (* startup heap used *)
    Log.Put(le)
  END logMemData;

BEGIN
  (* entry point for the outer core, loaded by Modules *)
  (* the temp trap handler is still installed *)
  (* no abort interrupts and abort handler are installed *)
  LED(0F1H);
  Par := Cmds.Par; Call := Cmds.Call; (* EO command handling compatibility *)
  (***
  RTC.Install(RTCspiDevice, RTCchipselect); (* needed for logging *)
  *)
  logRestart;
  LED(0F2H);
  installGC;
  LED(0F3H);
  Procs.InstallAudit;
  LED(0F4H);
  logMemData(SYSTEM.REG(SP));
  LED(0F5H);
  Cmds.Install;
  LED(0F6H);
  (* from here, cmds will use most of the original stack, the scheduler (Loop) only keeps a small part
  at the top, see Procs.SchedulerStackSize *)
  Errors.Install; (* installs trap and abort handlers, as well as error interrupt handlers *)
  LED(0F7H);
  (*Console.WriteLine(""); Console.WriteLine(RTSversion);*)
  (*Calltrace.Select(0);*)
  collect; (* make sure we have all heap space available for startup loading by Cmds *)
  Procs.Go (* start scheduler *)
  (* we'll not return here *)
END Oberon.
