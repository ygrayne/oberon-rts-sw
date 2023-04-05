(**
  Garbage collector
  --
  Base/origin: Embedded Project Oberon, module Oberon
  --
  2012 - 2023 Gray, gray@grayraven.org
  https://oberon-rts.org/licences
**)

MODULE GC;

  IMPORT Modules, Kernel, Files, Procs := Processes, Log;

  CONST
    GCperiod = 7;
    GCid = "gc";
    GCprio = 0;
    GCptype = Procs.SystemProc;
    GCstackSize = 512;
    GCstackHot = 0;
    GClimitDiv = 4; (* kick in when only 1/4 of heap space is left *)

  VAR
    gc: Procs.Process;
    gcstack: ARRAY GCstackSize OF BYTE;
    gcCount, heapSize, GClimit*: INTEGER;


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
    le.event := Log.System; le.cause := Log.SysCollect; le.more0 := Kernel.Time() - time;
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


  PROCEDURE Collect*;
  BEGIN
    gcCount := 0
  END Collect;


  PROCEDURE Install*;
    VAR res: INTEGER;
  BEGIN
    heapSize := Kernel.heapLim - Kernel.heapOrg;
    GClimit := heapSize - (heapSize DIV GClimitDiv);
    gcCount := 1;
    NEW(gc);
    Procs.Init(gc, gcc, gcstack, GCstackHot, GCptype, GCprio, GCid);
    Procs.Install(gc, res)
  END Install;

  PROCEDURE Recover*;
  BEGIN
    Install
  END Recover;

END GC.
