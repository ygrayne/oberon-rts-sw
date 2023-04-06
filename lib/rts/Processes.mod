(**
  Process Handling
  Based on coroutines
  --
  NEW
  --
  (c) 2020-2023 Gray gray@grayraven.org
  https://oberon-rts.org/licences
**)

MODULE Processes;

  IMPORT SYSTEM, Kernel, Coroutines, ProcTimers := ProcTimersFixed, Watchdog, SysCtrl;

  CONST
    MaxNumProcs* = 32;
    FirstProcNum = 1; (* 0 is reserved for the loop *)
    NameLen* = 4;
    NumTimers* = 8;
    OK* = 0;
    Failed* = 1;
    LoopStackSize = 256;
    LoopStackHotSize = 32;
    LoopId = 0;
    TrigNone = 0;
    TrigSome = 1;
    P0 = 5; P1 = 10; P2 = 20; P3 = 50; P4 = 100; P5 = 200; P6 = 500; P7 = 1000;

  TYPE
    PROC* = PROCEDURE;
    ProcName* = ARRAY NameLen OF CHAR;
    Process* = POINTER TO ProcessDesc;
    ProcessDesc* = RECORD
      proc: PROC;
      prio, pid: INTEGER;
      period: INTEGER;
      trigger: INTEGER;
      watchdog: BOOLEAN;
      name: ProcName;
      cor: Coroutines.Coroutine;
      next: Process
    END;
    ProcessData* = RECORD
      pid*, prio*: INTEGER;
      name*: ARRAY NameLen OF CHAR;
      stAdr*, stSize*, stHotSize*, stMin*: INTEGER;
      trigger*: INTEGER;
      period*: INTEGER
    END;

  VAR
    procs: ARRAY MaxNumProcs OF Process;
    NumProcs*: INTEGER;
    Cp*, cp: Process;
    queued: SET;
    loop: Coroutines.Coroutine;
    LoopStackTop*, LoopStackBottom*: INTEGER;

  (* process creation and queue mgmt *)

  PROCEDURE slotIn(p: Process);
    VAR p0, p1: Process;
  BEGIN
    p0 := cp; p1 := p0;
    WHILE (p0 # NIL) & (p0 # p) & (p0.prio <= p.prio) DO
      p1 := p0; p0 := p0.next
    END;
    IF p # p0 THEN (* if p was not already queued *)
      IF p1 = p0 THEN cp := p ELSE  p1.next := p END;
      p.next := p0
    ELSE
      (* overflow *)
    END
  END slotIn;


  PROCEDURE Init*(p: Process; proc: PROC; stAdr, stSize, stHotSize, prio: INTEGER; VAR pid, res: INTEGER);
    VAR i: INTEGER;
  BEGIN
    ASSERT(p # NIL);
    p.proc := proc;
    p.prio := prio;
    p.period := 0;
    p.trigger := TrigNone;
    p.watchdog := TRUE;
    p.name := "";
    IF NumProcs < MaxNumProcs THEN
      INC(NumProcs);
      i := FirstProcNum;
      WHILE procs[i] # NIL DO INC(i) END;
      p.pid := i; pid := i;
      procs[i] := p;
      NEW(p.cor); ASSERT(p.cor # NIL);
      Coroutines.Init(p.cor, p.proc, stAdr, stSize, stHotSize, p.pid);
      ProcTimers.Disable(p.pid);
      slotIn(p);
      res := OK
    ELSE
      res := Failed
    END
  END Init;

  PROCEDURE New*(p: Process; proc: PROC; stack: ARRAY OF BYTE; stHotSize, prio: INTEGER; VAR pid, res: INTEGER);
  BEGIN
    Init(p, proc, SYSTEM.ADR(stack), LEN(stack), stHotSize, prio, pid, res)
  END New;

  PROCEDURE Start*(p: Process);
  BEGIN
    slotIn(p)
  END Start;

  PROCEDURE Stop*(p: Process);
  BEGIN
    IF p.pid IN queued THEN
      (*slotOut(p)*);
      EXCL(queued, p.pid)
    END
  END Stop;

  (* in-process api *)

  PROCEDURE Next*;
    VAR me: Process;
  BEGIN
    me := cp;
    cp := cp.next;
    IF me.trigger = TrigNone THEN
      slotIn(me)
    ELSE
      EXCL(queued, me.pid);
    END;
    Coroutines.Transfer(me.cor, loop)
  END Next;


  PROCEDURE SetPeriod*(period: INTEGER);
  BEGIN
    cp.period := period;
    cp.trigger := TrigSome;
    ProcTimers.SetPeriod(cp.pid, period) (* also enables timer *)
  END SetPeriod;


  PROCEDURE SetName*(name: ARRAY OF CHAR);
  BEGIN
    cp.name := name
  END SetName;


  PROCEDURE SetNoWatchdog*;
  BEGIN
    cp.watchdog := FALSE
  END SetNoWatchdog;


  PROCEDURE GetName*(pid: INTEGER; VAR name: ProcName);
  BEGIN
    name := procs[pid].name
  END GetName;

  (* loop/scanner coroutine code *)

  PROCEDURE loopc;
    VAR pid: INTEGER; readyT: SET;
  BEGIN
    LED(0F8H);
    REPEAT
      Watchdog.Reset;
      ProcTimers.GetReadyStatus(readyT);
      IF readyT # {} THEN
        LED(0F9H);
        pid := 0;
        WHILE pid < MaxNumProcs DO
          IF pid IN readyT THEN
            ASSERT(procs[pid].trigger = TrigSome);
            slotIn(procs[pid]);
            INCL(queued, pid);
            ProcTimers.ClearReady(pid)
          END;
          INC(pid)
        END
      END;
      IF cp # NIL THEN
        LED(0FAH);
        IF ~cp.watchdog THEN Watchdog.Stop END;
        Cp := cp;
        SysCtrl.SetCpPid(cp.pid);
        Coroutines.Transfer(loop, cp.cor);
        Cp := NIL;
        SysCtrl.SetCpPid(0)
      END
    UNTIL FALSE
  END loopc;

  (* create loop/scanner coroutine *)

  PROCEDURE Go*;
    CONST SP = 14;
    VAR jump: Coroutines.Coroutine;
  BEGIN
    LED(0F6H);
    SYSTEM.LDREG(SP, LoopStackTop - 128);
    NEW(jump);
    Coroutines.Init(loop, loopc, LoopStackBottom, LoopStackSize, LoopStackHotSize, LoopId);
    LED(0F7H);
    Coroutines.Transfer(jump, loop)
  END Go;

  (* process info *)

  PROCEDURE GetProcData*(VAR pd: ProcessData; VAR pid: INTEGER);
    VAR p0: Process;
  BEGIN
    REPEAT
      INC(pid)
    UNTIL (pid = MaxNumProcs) OR (procs[pid] # NIL);
    IF pid = MaxNumProcs THEN
      pid := 0
    ELSE
      p0 := procs[pid];
      pd.pid := p0.pid;
      pd.prio := p0.prio;
      pd.name := p0.name;
      pd.trigger := p0.trigger;
      pd.period := p0.period;
      pd.stAdr := p0.cor.stAdr;
      pd.stSize := p0.cor.stSize;
      pd.stHotSize := p0.cor.stHotLimit - p0.cor.stAdr;
      pd.stMin := p0.cor.stMin;
    END
  END GetProcData;

  PROCEDURE GetLoopData*(VAR pd: ProcessData);
  BEGIN
    pd.stAdr := LoopStackBottom;
    pd.stSize := LoopStackSize;
    pd.stMin := loop.stMin;
    pd.stHotSize := LoopStackHotSize
  END GetLoopData;

  PROCEDURE GetTimerData*(VAR td: ARRAY OF INTEGER);
  BEGIN
    ASSERT(LEN(td) >= NumTimers);
    td[0] := P0; td[1] := P1; td[2] := P2; td[3] := P3;
    td[4] := P4; td[5] := P5; td[6] := P6; td[7] := P7
  END GetTimerData;

  (* module initialisation *)

  PROCEDURE initM;
    VAR i: INTEGER;
  BEGIN
    i := 0;
    WHILE i < MaxNumProcs DO
      procs[i] := NIL; INC(i)
    END;
    cp := NIL; Cp := NIL;
    queued := {};
    ProcTimers.Init(P0, P1, P2, P3, P4, P5, P6, P7);
    LoopStackTop := Kernel.stackOrg;
    LoopStackBottom := LoopStackTop - LoopStackSize;
    NEW(loop);
  END initM;

BEGIN
  initM
END Processes.
