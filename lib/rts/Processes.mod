(**
  Process Handling
  Based on coroutines
  --
  * Process creation and installation for scheduling
  * Process scheduling procedures, eg. delays, suspension, yield control
  * Process reset, recover, kill, ...
  * Cooperative scheduling
  --
  (c) 2020-2023 Gray gray@grayraven.org
  https://oberon-rts.org/licences
**)

MODULE Processes;

  IMPORT SYSTEM, Kernel, Coroutines, ProcTimers := ProcTimersFixed, Watchdog, SysCtrl, Log;

  CONST
    MaxNumProcs* = 32;
    FirstProcNum = 1; (* 0 is reserved for the loop *)
    ProcNums = {0 .. 31};
    NameLen* = 4;
    NumTimers* = 8;

    (* process timers in milliseconds *)
    P0 = 5; P1 = 10; P2 = 20; P3 = 50; P4 = 100; P5 = 200; P6 = 500; P7 = 1000;

    (* loop config *)
    LoopStackSize = 256;
    LoopStackHotSize = 32;
    loopPid = 0;

    (* result codes *)
    OK* = 0;
    Failed* = 1;

    (* process triggers, if any *)
    TrigNone* = 0;
    TrigSome = 1;

    (* process states *)
    StateEnabled* = 0;    (* triggered: will be queued at next trigger event; non-triggered: will be run from queue asap *)
    StateSuspended* = 1;  (* must be (re-) enabled before it can run *)

    (* process handling on errors *)
    (* if another process has caused the error or was hit by the error *)
    OnErrorCont* = 0;     (* continue process from state at error occurence *)
    OnErrorReset* = 1;    (* reset process *)
    (* if this process has caused the error or was hit by the error *)
    OnErrorHitDefault* = 0;  (* normal error handling *)
    OnErrorHitRestart* = 1;  (* mandatory restart of the the system *)

  TYPE
    PROC* = PROCEDURE;
    ProcName* = ARRAY NameLen OF CHAR;
    Process* = POINTER TO ProcessDesc;
    ProcessDesc* = RECORD
      proc: PROC;
      prio, pid: INTEGER;
      state: INTEGER;
      period: INTEGER;
      trigger: INTEGER;
      onError, onErrorHit: INTEGER;
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
    le: Log.Entry;


  (* manage the ready queue *)

  PROCEDURE slotIn(p: Process);
    VAR p0, p1: Process;
  BEGIN
    IF ~(p.pid IN queued) THEN
      p0 := cp; p1 := p0;
      WHILE (p0 # NIL) & (p0.prio <= p.prio) DO
        p1 := p0; p0 := p0.next
      END;
      IF p1 = p0 THEN cp := p ELSE  p1.next := p END;
      p.next := p0
    ELSE
      (* overflow *)
    END
  END slotIn;

  PROCEDURE slotOut(p: Process);
    VAR p0, p1: Process;
  BEGIN
    IF p.pid IN queued THEN
      p0 := cp; p1 := p0;
      WHILE (p0 # NIL) & (p0 # p) DO p1 := p0; p0 := p0.next END;
      IF p0 = p1 THEN cp := p.next ELSE p1.next := p.next END
    END
  END slotOut;

  (* process creation and queue mgmt *)

  PROCEDURE Init*(p: Process; proc: PROC; stAdr, stSize, stHotSize: INTEGER; VAR pid, res: INTEGER);
    VAR i: INTEGER;
  BEGIN
    ASSERT(p # NIL);
    p.proc := proc;
    p.prio := 0;
    p.period := 0;
    p.onError := OnErrorReset;
    p.onErrorHit := OnErrorHitDefault;
    p.trigger := TrigNone;
    p.state := StateSuspended;
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
      ProcTimers.Disable(i);
      res := OK
    ELSE
      res := Failed
    END;
    (* logging *)
    le.event := Log.Process;
    le.cause := Log.ProcNew;
    le.more0 := p.pid;
    le.more1 := res;
    Log.Put(le)
  END Init;

  PROCEDURE New*(p: Process; proc: PROC; stack: ARRAY OF BYTE; stHotSize: INTEGER; VAR pid, res: INTEGER);
  BEGIN
    Init(p, proc, SYSTEM.ADR(stack), LEN(stack), stHotSize, pid, res)
  END New;


  PROCEDURE Enable*(p: Process);
  BEGIN
    ASSERT(p # NIL);
    p.state := StateEnabled;
    IF p.trigger = TrigNone THEN (* else wait for trigger *)
      slotIn(p);
      INCL(queued, p.pid)
    END;
    (* logging *)
    le.event := Log.Process;
    le.cause := Log.ProcEnable;
    le.name := p.name;
    le.more0 := p.pid;
    le.more1 := p.trigger;
    le.more2 := p.period;
    Log.Put(le)
  END Enable;


  PROCEDURE Suspend*(p: Process);
  BEGIN
    ASSERT(p # NIL);
    p.state := StateSuspended;
    slotOut(p);
    EXCL(queued, p.pid)
  END Suspend;


  PROCEDURE Reset*(p: Process);
  BEGIN
    ASSERT(p # NIL);
    (* logging *)
    le.event := Log.Process;
    le.cause := Log.ProcReset;
    le.name := p.name;
    le.more0 := p.pid;
    Log.Put(le);

    Coroutines.Reset(p.cor)
  END Reset;


  PROCEDURE OnError*(pid: INTEGER);
    VAR i: INTEGER; p0: Process;
  BEGIN
    i := 1;
    WHILE i < MaxNumProcs DO
      IF procs[i] # NIL THEN
        p0 := procs[i];
        IF i = pid THEN (* the error-inducing or error-interrupted process *)
          Reset(p0);
          Enable(p0)
        ELSE
          IF p0.onError = OnErrorReset THEN
            Reset(p0);
            Enable(p0)
          ELSIF p0.onError = OnErrorCont THEN
            Enable(p0)
          END
        END
      END;
      INC(i)
    END
  END OnError;


  (* manage processes *)

  PROCEDURE SetPrio*(p: Process; prio: INTEGER);
  BEGIN
    ASSERT(p # NIL);
    p.prio := prio
  END SetPrio;


  PROCEDURE SetPeriod*(p: Process; period: INTEGER);
  BEGIN
    ASSERT(p # NIL);
    p.period := period;
    p.trigger := TrigSome;
    ProcTimers.SetPeriod(p.pid, period) (* also enables timer *)
  END SetPeriod;


  PROCEDURE SetName*(p: Process; name: ARRAY OF CHAR);
  BEGIN
    ASSERT(p # NIL);
    p.name := name
  END SetName;


  PROCEDURE GetName*(pid: INTEGER; VAR name: ProcName);
  BEGIN
    ASSERT(pid IN ProcNums);
    ASSERT(procs[pid] # NIL);
    name := procs[pid].name
  END GetName;


  PROCEDURE SetNoWatchdog*(p: Process);
  BEGIN
    ASSERT(p # NIL);
    p.watchdog := FALSE
  END SetNoWatchdog;


  PROCEDURE SetOnError*(p: Process; onErr, onErrHit: INTEGER);
  BEGIN
    ASSERT(p # NIL);
    p.onError := onErr;
    p.onErrorHit := onErrHit
  END SetOnError;


  PROCEDURE ForceRestart*(pid: INTEGER): BOOLEAN;
    VAR force: BOOLEAN;
  BEGIN
    ASSERT(pid IN ProcNums);
    force := FALSE;
    IF pid > 0 THEN
      ASSERT(procs[pid] # NIL);
      force := procs[pid].onErrorHit = OnErrorHitRestart
    END;
    RETURN force
  END ForceRestart;


  (* in-process api *)

  PROCEDURE Next*;
  BEGIN
    IF Cp.trigger = TrigNone THEN
      slotIn(Cp);
      INCL(queued, Cp.pid)
    ELSE
      slotOut(Cp);
      EXCL(queued, Cp.pid)
    END;
    Coroutines.Transfer(Cp.cor, loop)
  END Next;


  PROCEDURE SuspendMe*;
  BEGIN
    Cp.state := StateSuspended;
    slotOut(Cp);
    EXCL(queued, Cp.pid);
    Coroutines.Transfer(Cp.cor, loop)
  END SuspendMe;


  PROCEDURE GetStatus*(VAR errNo, errPid: INTEGER);
    VAR addr: INTEGER;
  BEGIN
    SysCtrl.GetError(errNo, addr);
    SysCtrl.GetErrPid(errPid)
  END GetStatus;


  (* loop/scanner coroutine code *)
  (* scan for hw signals to schedule processes *)
  (* is also the "idle process" *)

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
            IF procs[pid].state = StateEnabled THEN
              ASSERT(procs[pid].trigger = TrigSome);
              slotIn(procs[pid]);
              INCL(queued, pid);
              ProcTimers.ClearReady(pid)
            END
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
    Coroutines.Init(loop, loopc, LoopStackBottom, LoopStackSize, LoopStackHotSize, loopPid);
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

  (* module initialisation and recovery *)

  PROCEDURE Install*;
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
  END Install;

  PROCEDURE Recover*;
  (* note: Process.Go will init the loop *)
  BEGIN
    cp := NIL; Cp := NIL;
    queued := {};
    ProcTimers.Init(P0, P1, P2, P3, P4, P5, P6, P7)
  END Recover;

END Processes.
