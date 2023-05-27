(**
  Garbage collector process
  --
  Base/origin: (Embedded) Project Oberon, module Oberon
  --
  2021 - 2023 Gray, gray@grayraven.org
  https://oberon-rts.org/licences
**)

MODULE GC;

  IMPORT Modules, Kernel, Files, Procs := Processes, Log, LSB;

  CONST
    Period = 7;
    Name = "gc";
    Prio = 1;
    StackSize = 512;
    StackHotSize = 0;
    GClimitDiv = 4; (* kick in when only 1/4 of heap space is left *)
    LEDbase = 05H;

  VAR
    gc: Procs.Process;
    stack: ARRAY StackSize OF BYTE;
    count, heapSize, GClimit*: INTEGER;
    pid: INTEGER;


  PROCEDURE collect;
    VAR mod: Modules.Module; alloc, time: INTEGER; le: Log.Entry;
  BEGIN
    alloc := Kernel.allocated;
    time := Kernel.Time();
    mod := Modules.root; LED(LEDbase + 01H);
    WHILE mod # NIL DO
      IF mod.name[0] # 0X THEN Kernel.Mark(mod.ptr) END;
      mod := mod.next
    END;
    LED(LEDbase + 03H);
    Files.RestoreList; LED(LEDbase + 07H);
    Kernel.Scan; LED(LEDbase + 0H);
    le.event := Log.System; le.cause := Log.SysCollect; le.more0 := Kernel.Time() - time;
    le.more1 := alloc; le.more2 := Kernel.allocated;
    Log.Put(le)
  END collect;


  PROCEDURE gcc;
    VAR ledr: BOOLEAN;
  BEGIN
    ledr := FALSE;
    REPEAT
      Procs.Next;
      IF (count = 0) OR (Kernel.allocated >= GClimit) THEN
        collect;
        count := 1;
      END;
      ledr := ~ledr;
      IF ledr THEN LSB.SetRedLedsOn({0}) ELSE LSB.SetRedLedsOff({0}) END
    UNTIL FALSE
  END gcc;


  PROCEDURE Collect*;
  BEGIN
    count := 0
  END Collect;


  PROCEDURE Init*;
    VAR res: INTEGER;
  BEGIN
    heapSize := Kernel.heapLim - Kernel.heapOrg;
    GClimit := heapSize - (heapSize DIV GClimitDiv);
    count := 1;
    Procs.New(gc, gcc, stack, StackHotSize, pid, res);
    Procs.SetPrio(gc, Prio);
    Procs.SetPeriod(gc, Period);  (* enables timer *)
    Procs.SetName(gc, Name);
    Procs.SetOnError(gc, Procs.OnErrorReset, Procs.OnErrorHitRestart);
    Procs.Enable(gc);
    ASSERT(res = Procs.OK)
  END Init;


BEGIN
  NEW(gc); ASSERT(gc # NIL)
END GC.
