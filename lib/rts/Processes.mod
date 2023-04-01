(**
  Process Handling
  Based on coroutines
  --
  * Thread creation and installation for scheduling
  * Thread scheduling procedures, eg. delays, suspension, yield control
  * Thread reset, recover, kill, finalise
  * Cooperative scheduler (Loop)
  * Audit process
  --
  2020-2021 Gray gray@grayraven.org
  https://oberon-rts.org/licences
**)

MODULE Processes;

  IMPORT
    SYSTEM, Kernel, Coroutines, ProcTimers := ProcTimersFixed, SysCtrl, Log, Watchdog;

  CONST
    (* process states *)
    StateOff = 0; (* not installed *)
    StateReady* = 2; (* marked ready to run by scheduler *)
    StateRunning* = 3; (* current process *)
    StateActive* = 4; (* Install, Enable => unconditionally ready-d during next scheduler evaluation => State Ready *)
    StateAwaiting* = 5; (* Wait => awaiting activation using Enable by other process, or timeout => StateActive *)
    StateTimed* = 6; (* Next => awaiting activation by periodic timer, or timeout => StateReady *)
    StateDelayed* = 7; (* DelayMe => awaiting activation by delay timer => StateReady *)
    StateAwaitingDevSig* = 8; (* AwaitDevSignal => awaiting activation by dev signal, or timeout => StateReady *)
    StateReset = 9; (* ResetMe => will be reset by scheduler after yielding => StateActive *)
    MaxState = StateReset;

    (* process types *)
    SystemProc* = 0; EssentialProc* = 1; OtherProc* = 2;
    ProcTypes = {SystemProc .. OtherProc};

    (* OK/error codes *)
    OK* = 0; Error* = -1;

    (* process return values *)
    (* the return value is the process state from which the process was set ready to run *)
    (* unless there was a timeout *)
    Timeout* = -1;

    (* config *)
    (* note: currently, there are 16 process controllers instantiated in HW *)
    (* with the current HW design, max 32 process controllers are possible *)
    IdLen* = 4;
    MaxNumProcs* = 15;
    FirstProcNum = 1; (* 0 is reserved for the scheduler *)

    SchedulerStackSize = 512;
    SchedulerStackHotSize = 0;
    ClockFreqAdr = -200;

    (* process timers *)
    NumTimers* = 8;
    P0 = 5; P1 = 10; P2 = 20; P3 = 50; P4 = 100; P5 = 200; P6 = 500; P7 = 1000; (* timer periods, in ms *)
    NotTimed = -1; (* with fixed timers, else use 0 *)

    (* audit process config *)
    AuditPeriod = 7;
    AuditPrio = 0;
    AuditPrId = "adt";
    AuditStackHotSize = 0;
    AuditCount = 5; (* times AuditPeriod *)

    (* not-alive interrupt, software-triggered *)
    NotAliveIntNum = 3;

    SP = 14;

  TYPE
    Process* = POINTER TO ProcessDesc;
    ProcCode* = PROCEDURE;
    Handler* = PROCEDURE(p: Process);
    ProcId* = ARRAY IdLen OF CHAR;
    ProcessDesc* = RECORD
      state, period, ptype, prio: INTEGER;
      id: ProcId;
      watchdogOff: BOOLEAN;
      pn, retVal, maxRunTime, runTime, ovflCnt: INTEGER;
      code: ProcCode;
      cor: Coroutines.Coroutine;
      stackAdr, stackSize, stackHotSize: INTEGER;
      finalise: Handler;
      next, parent, link*: Process
    END;
    ProcessData* = POINTER TO ProcessDataDesc;
    ProcessDataDesc* = RECORD
      ptype*, prio*, period*, pn*, state*, cn*: INTEGER;
      id*: ProcId;
      stackAdr*, stackSize*, stackMax*, stackHotSize*: INTEGER;
      maxRunTime*, runTime*, ovflCnt*: INTEGER
    END;

  VAR
    procs: Process; (* all installed procs, NIL-terminated list *)
    Cp*: Process;  (* current process *)
    loop: Coroutines.Coroutine; (* scheduler *)
    NumProcs*: INTEGER;
    installedP, activeP: SET;
    SchedulerStackTop*, SchedulerStackBottom*: INTEGER;
    audit: Process;
    auditStack: ARRAY 256 OF BYTE;
    auditCnt: INTEGER;
    le: Log.Entry;
    Eval*, Exec*, MaxEval*, MaxExec*: INTEGER; (* clock cycles *)
    ClockFreq*, ClockPeriod*: INTEGER; (* Hz, nanoseconds *)

(*
  PROCEDURE CHECK(pid: ARRAY OF CHAR; state: INTEGER; allowedStates: SET);
    CONST BtnSwiAdr = -84; SwiFirst = 0; SwiLast = 3; CheckSwitch = 3;
    VAR i: INTEGER; swi: SET;
  BEGIN
    SYSTEM.GET(BtnSwiAdr, swi);
    swi := BITS(BFX(ORD(swi), SwiLast, SwiFirst));
    IF CheckSwitch IN swi THEN
      IF ~(state IN allowedStates) THEN
        Texts.WriteLn(W);
        Texts.WriteString(W, pid);
        Texts.WriteString(W, " state: "); Texts.WriteInt(W, state, 0);
        Texts.WriteString(W, " allowed: ");
        FOR i := 0 TO MaxState DO
          IF i IN allowedStates THEN Texts.WriteInt(W, i, 3) END
        END;
        Texts.WriteLn(W)
      END
    END
  END CHECK;
*)
(*
  PROCEDURE CHECK(p: Process; allowedStates: SET);
    CONST BtnSwiAdr = -84; SwiFirst = 0; SwiLast = 3; CheckSwitch = 3;
    VAR i: INTEGER; swi: SET;
  BEGIN
    SYSTEM.GET(BtnSwiAdr, swi);
    swi := BITS(BFX(ORD(swi), SwiLast, SwiFirst));
    IF CheckSwitch IN swi THEN
      IF ~(p.state IN allowedStates) THEN
        Texts.WriteLn(W);
        Texts.WriteString(W, p.id);
        Texts.WriteString(W, " state: "); Texts.WriteInt(W, p.state, 0);
        Texts.WriteString(W, " allowed: ");
        FOR i := 0 TO MaxState DO
          IF i IN allowedStates THEN Texts.WriteInt(W, i, 3) END
        END;
        Texts.WriteLn(W)
      END
    END
  END CHECK;
*)

  PROCEDURE InitRaw*(p: Process; code: ProcCode; stackAdr, stackSize, stackHotSize, ptype, prio: INTEGER; id: ARRAY OF CHAR);
  BEGIN
    ASSERT(ptype IN ProcTypes); ASSERT(LEN(id) <= IdLen);
    p.code := code; p.stackAdr := stackAdr; p.stackSize := stackSize; p.stackHotSize := stackHotSize;
    NEW(p.cor); ASSERT(p.cor # NIL);
    p.period := NotTimed; p.ptype := ptype; p.id := id; p.prio := prio; p.maxRunTime := 0; p.runTime := 0;
    p.watchdogOff := FALSE;
    p.finalise := NIL; p.parent := NIL;
    p.state := StateOff
  END InitRaw;


  PROCEDURE Init*(p: Process; code: ProcCode; stack: ARRAY OF BYTE; stackHotSize, ptype, prio: INTEGER; id: ARRAY OF CHAR);
  BEGIN
    ASSERT(ptype IN ProcTypes); ASSERT(LEN(id) <= IdLen);
    InitRaw(p, code, SYSTEM.ADR(stack), LEN(stack), stackHotSize, ptype, prio, id)
  END Init;


  PROCEDURE slotIn(p: Process);
    VAR p0, p1: Process;
  BEGIN
    p0 := procs; p1 := p0;
    WHILE (p0 # NIL) & (p0.prio < p.prio) DO
      p1 := p0; p0 := p0.next
    END;
    IF p1 = p0 THEN procs := p ELSE p1.next := p END;
    p.next := p0
  END slotIn;


  PROCEDURE Install*(p: Process; VAR res: INTEGER);
    VAR i: INTEGER;
  BEGIN
    res := Error;
    IF p.state = StateOff THEN
      IF NumProcs < MaxNumProcs THEN
        slotIn(p);
        INC(NumProcs);
        i := FirstProcNum; WHILE i IN installedP DO INC(i) END; (* one must be available due to IF NumProcs < MaxNumProcs *)
        p.pn := i;
        INCL(installedP, i);
        p.state := StateActive; INCL(activeP, i);
        Coroutines.Init(p.cor, p.code, p.stackAdr, p.stackSize, p.stackHotSize, p.pn);
        res := OK;
        le.event := Log.Process; le.cause := Log.ProcInstall; le.procId := p.id; le.more0 := p.pn;
        Log.Put(le)
      ELSE
        le.event := Log.System; le.cause := Log.SysProcsFull; le.procId := p.id;
        Log.Put(le)
      END
    END
  END Install;


  PROCEDURE ResetMax*;
  BEGIN
    (*
    ProcMonitor.ResetProcMax
    *)
  END ResetMax;


  PROCEDURE SetParent*(p, parent: Process);
  BEGIN
    p.parent := parent
  END SetParent;


  PROCEDURE slotOut(p: Process);
    VAR p0, p1: Process;
  BEGIN
    p0 := procs; p1 := p0;
    WHILE (p0 # NIL) & (p0 # p) DO p1 := p0; p0 := p0.next END;
    IF p0 = p1 THEN procs := p.next ELSE p1.next := p.next END
  END slotOut;


  PROCEDURE Remove*(p: Process);
  BEGIN
    IF (p.state # StateOff) & (p.pn IN installedP) THEN
      slotOut(p);
      p.state := StateOff;
      DEC(NumProcs);
      EXCL(installedP, p.pn); EXCL(activeP, p.pn);
      ProcTimers.Disable(p.pn);
      (***
      ProcDevsig.Disable(p.pn);
      ProcDelay.Disable(p.pn);
      *)
      IF p.finalise # NIL THEN p.finalise(p) END;
      le.event := Log.Process; le.cause := Log.ProcRemove; le.procId := p.id; le.more0 := p.pn;
      Log.Put(le)
    END
  END Remove;


  PROCEDURE RemoveMe*;
  BEGIN
    Remove(Cp);
    Coroutines.Transfer(Cp.cor, loop)
  END RemoveMe;


  PROCEDURE Reset*(p: Process);
  BEGIN
    IF p.parent = NIL THEN
      ProcTimers.Disable(p.pn);
      (***
      ProcDelay.Disable(p.pn);
      ProcDevsig.Disable(p.pn);
      **)
      p.state := StateActive; INCL(activeP, p.pn);
      le.event := Log.Process; le.cause := Log.ProcReset; le.procId := p.id; le.more0 := p.pn;
      Log.Put(le);
      Coroutines.Init(p.cor, p.code, p.stackAdr, p.stackSize, p.stackHotSize, p.pn)
    ELSE
      (* the process was installed by a parent process *)
      (* hence we need to allow that parent to re-install it properly *)
      Remove(p)
    END
  END Reset;


  PROCEDURE ResetMe*;
  BEGIN
    Cp.state := StateReset;
    Coroutines.Transfer(Cp.cor, loop)
  END ResetMe;


  PROCEDURE ForAll*(system, essential, other: PROCEDURE(p: Process));
    VAR p0: Process;
  BEGIN
    p0 := procs;
    WHILE p0 # NIL DO
      IF p0.ptype = SystemProc THEN
        system(p0)
      ELSIF p0.ptype = EssentialProc THEN
        essential(p0)
      ELSE
        other(p0)
      END;
      p0 := p0.next
    END;
  END ForAll;


  PROCEDURE SetFinaliser*(p: Process; finalise: Handler);
  BEGIN
    p.finalise := finalise
  END SetFinaliser;


  PROCEDURE SetPeriod*(period: INTEGER);
  BEGIN
    ASSERT(period > NotTimed);
    Cp.period := period;
    ProcTimers.SetPeriod(Cp.pn, period)
  END SetPeriod;


  PROCEDURE SetPrio*(prio: INTEGER);
  (* changes process chain link order -- costly! *)
  BEGIN
    Cp.prio := prio;
    slotOut(Cp); slotIn(Cp)
  END SetPrio;


  PROCEDURE SetWatchdogOff*;
  BEGIN
    Cp.watchdogOff := TRUE
  END SetWatchdogOff;


  PROCEDURE Next*;
  BEGIN
    IF Cp.period > NotTimed THEN
      Cp.state := StateTimed
    ELSE
      Cp.state := StateActive; INCL(activeP, Cp.pn)
    END;
    Coroutines.Transfer(Cp.cor, loop)
  END Next;


  PROCEDURE DelayMe*(delay: INTEGER);
  BEGIN
    Cp.state := StateDelayed;
    (***
    ProcDelay.SetDelay(Cp.pn, delay); (* also enables controller *)
    *)
    Coroutines.Transfer(Cp.cor, loop)
  END DelayMe;


  PROCEDURE Wait*;
  (* note: let ProcTimers running *)
  BEGIN
    (***
    CHECK(Cp, {3});
    *)
    Cp.state := StateAwaiting;
    (***
    ProcDevsig.Disable(Cp.pn);
    *)
    Coroutines.Transfer(Cp.cor, loop)
  END Wait;


  PROCEDURE AwaitDevSignal*(devSig: INTEGER);
  (* note: let ProcTimers running *)
  BEGIN
    (***
    CHECK(Cp, {3});
    *)
    Cp.state := StateAwaitingDevSig;
    (*
    ProcDevsig.SetSignal(Cp.pn, devSig); (* enables controller *)
    *)
    Coroutines.Transfer(Cp.cor, loop)
  END AwaitDevSignal;


  PROCEDURE Activate*(p: Process);
  BEGIN
    (***
    CHECK(p, {5});
    *)
    p.state := StateActive; INCL(activeP, p.pn)
  END Activate;


  PROCEDURE SetTimeout*(timeout: INTEGER);
  BEGIN
    ASSERT(timeout > 0);
    (***
    ProcDelay.SetDelay(Cp.pn, timeout)
    *)
  END SetTimeout;


  PROCEDURE TriggerNotAlive*;
  BEGIN
    (***
    Interrupts.Trigger(NotAliveIntNum)
    *)
  END TriggerNotAlive;


  PROCEDURE RetVal*(): INTEGER;
  BEGIN
    RETURN Cp.retVal
  END RetVal;


  PROCEDURE Id*(VAR id: ProcId);
  BEGIN
    IF Cp # NIL THEN
      id := Cp.id
    ELSE
      id := "---"
    END
  END Id;


  PROCEDURE No*(): INTEGER;
  BEGIN
    RETURN Cp.pn
  END No;


  PROCEDURE Time*(): LONGINT;
  BEGIN
    RETURN Kernel.Time()
  END Time;


  PROCEDURE nextReady(VAR cp: Process): Process;
  BEGIN
    WHILE (cp # NIL) & (cp.state # StateReady) DO cp := cp.next END;
    RETURN cp
  END nextReady;


  PROCEDURE Loop;
    CONST SamplingTime = 1000;
    VAR
      readyT, readyS, readyD: SET;
      p0, cp: Process;
      pn: INTEGER;
  BEGIN
    cp := NIL;
    (***
    ProcMonitor.StartSampling(SamplingTime);
    *)
    (*Texts.WriteString(W, "loop"); Texts.WriteLn(W);*)
    REPEAT
      (***
      ProcMonitor.ResetEvalMon;
      *)
      ProcTimers.GetReadyStatus(readyT);
      (***
      ProcDevsig.GetReadyStatus(readyS);
      ProcDelay.GetReadyStatus(readyD);
      IF (readyT + readyS + readyD + activeP) # {} THEN
      *)
      readyS := {}; readyD := {};
      IF (readyT + activeP) # {} THEN
        p0 := procs;
        WHILE p0 # NIL DO
          pn := p0.pn;

          (* temp "solution" *)
          IF p0.state = StateReady THEN
            INC(p0.ovflCnt)
          END;

          (* delays and timeouts *)
          IF pn IN readyD THEN
            (***
            CHECK(p0, {StateDelayed, StateAwaiting, StateAwaitingDevSig, StateTimed});
            *)
            (***
            ProcDelay.Disable(pn); (* also resets ready signal *)
            *)
            IF p0.state = StateDelayed THEN
              p0.retVal := p0.state; p0.state := StateReady
            ELSE
              p0.retVal := Timeout; p0.state := StateReady
            END
          END;

          (* device signals *)
          IF pn IN readyS THEN
            (***
            CHECK(p0, {StateAwaitingDevSig});
            *)
            (***
            ProcDelay.Disable(pn); (* also resets ready signal *)
            ProcDevsig.Disable(pn); (* also resets ready signal *)
            *)
            p0.retVal := p0.state; p0.state := StateReady
          END;

          (* periodic timing *)
          IF pn IN readyT THEN
            (***
            CHECK(p0, {StateTimed, StateDelayed, StateAwaiting, StateAwaitingDevSig});
            *)
            ProcTimers.ClearReady(pn);
            IF p0.state = StateTimed THEN
              (***
              ProcDelay.Disable(pn);
              *)
              p0.retVal := p0.state; p0.state := StateReady
            END
          END;

          (* active processes *)
          IF pn IN activeP THEN
            (***
            CHECK(p0, {StateActive});
            *)
            (***
            ProcDelay.Disable(pn);
            *)
            EXCL(activeP, pn);
            p0.retVal := p0.state; p0.state := StateReady
          END;

          p0 := p0.next
        END;
        cp := procs;
      END;
      (***
      ProcMonitor.CaptureEvalMon;
      ProcMonitor.ResetExecMon;
      *)
      Watchdog.Reset;
      Cp := nextReady(cp);
      IF Cp # NIL THEN
        IF Cp.watchdogOff THEN Watchdog.Stop END;
        Cp.state := StateRunning;
        (***
        ProcMonitor.StartProcMon(Cp.maxRunTime);
        *)
        Coroutines.Transfer(loop, Cp.cor);
        (***
        ProcMonitor.GetProcMon(Cp.maxRunTime, Cp.runTime);
        *)
        IF Cp.state = StateReset THEN Reset(Cp) END; (* allows procs to reset themselves, see 'ResetMe' *)
        (* Cp.state is set by yielding7reset procedure *)
        (***
        CHECK(Cp, {StateActive, StateTimed, StateDelayed, StateAwaiting, StateAwaitingDevSig});
        *)
        Cp := NIL
      END;
      (***
      ProcMonitor.CaptureExecMon;
      IF ProcMonitor.ValuesReady() THEN
        ProcMonitor.GetMax(Eval, Exec);
        IF Eval > MaxEval THEN MaxEval := Eval END;
        IF Exec > MaxExec THEN MaxExec := Exec END;
        ProcMonitor.StartSampling(SamplingTime)
      END
      *)
      Eval := 1; Exec := 1; MaxEval := 1; MaxExec := 1;
    UNTIL FALSE
  END Loop;


  PROCEDURE GetProcData*(VAR p: Process; pd: ProcessData);
  (* p = NIL as passed indicates the start of a series of queries.
  Then the client uses p as indicator if the returned values are valid,
  and will pass the same p back on the next query *)
  BEGIN
    IF p = NIL THEN p := procs ELSE p := p.next END;
    IF p # NIL THEN
      pd.id := p.id;
      pd.pn := p.pn;
      pd.cn := p.cor.id;
      pd.prio := p.prio;
      pd.period := p.period;
      pd.ptype := p.ptype;
      pd.state := p.state;
      pd.stackAdr := p.cor.stackAdr;
      pd.stackSize := p.cor.stackSize;
      pd.stackMax := p.cor.stackMax;
      pd.stackHotSize := p.cor.stackHotLimit - p.cor.stackAdr;
      pd.maxRunTime := p.maxRunTime;
      pd.runTime := p.runTime;
      pd.ovflCnt := p.ovflCnt;
      p.ovflCnt := 0
    END
  END GetProcData;


  PROCEDURE GetSchedulerData*(pd: ProcessData);
  BEGIN
    pd.stackAdr := SchedulerStackBottom;
    pd.stackSize := SchedulerStackSize;
    pd.stackMax := loop.stackMax;
    pd.stackHotSize := SchedulerStackHotSize;
    pd.cn := loop.id;
  END GetSchedulerData;


  PROCEDURE GetTimerData*(VAR td: ARRAY OF INTEGER);
  BEGIN
    ASSERT(LEN(td) >= NumTimers);
    td[0] := P0; td[1] := P1; td[2] := P2; td[3] := P3;
    td[4] := P4; td[5] := P5; td[6] := P6; td[7] := P7
  END GetTimerData;


  PROCEDURE auditc;
    VAR logged: BOOLEAN;
  BEGIN
    logged := FALSE;
    auditCnt := AuditCount;
    SetPeriod(AuditPeriod);
    REPEAT
      Next;
      DEC(auditCnt);
      IF auditCnt = 0 THEN
        SysCtrl.ResetNumRestarts; SysCtrl.ResetErrorState;
        IF ~logged THEN le.event := Log.System; le.cause := Log.SysOK; SysCtrl.GetReg(le.more0); Log.Put(le); logged := TRUE END;
        auditCnt := AuditCount
      END
    UNTIL FALSE
  END auditc;


  PROCEDURE InstallAudit*;
    VAR res: INTEGER;
  BEGIN
    Init(audit, auditc, auditStack, AuditStackHotSize, SystemProc, AuditPrio, AuditPrId);
    Install(audit, res)
  END InstallAudit;


  PROCEDURE Go*;
    VAR jump: Coroutines.Coroutine; (* will be collected *)
  BEGIN
    (* Shift stack pointer down, so Coroutines.Reset can set up the top of the stack for the scheduler. *)
    (* Called from Oberon body and Errors.error, which both use the stack area just below the heap *)
    (* which is also the scheduler stack, which we want to initialise... *)
    SYSTEM.LDREG(SP, SchedulerStackTop - 128);
    (*Texts.WriteString(W, "go ");*)
    NEW(jump);
    Coroutines.Init(loop, Loop, SchedulerStackBottom, SchedulerStackSize, SchedulerStackHotSize, 0);
    (*
    Texts.WriteString(W, "reset");
    Texts.WriteHex(W, loop.stackAdr); Texts.WriteHex(W, loop.stackHotLimit); Texts.WriteHex(W, SYSTEM.REG(SP));
    Texts.WriteHex(W, SchedulerStackTop);  Texts.WriteLn(W);
    *)
    Coroutines.Transfer(jump, loop);
    (* we'll not return here *)
  END Go;


  PROCEDURE initM;
  BEGIN
    (* set up basic values *)
    procs := NIL;
    Cp := NIL;
    NumProcs := 0;
    installedP := {}; activeP := {};
    NEW(audit);

    (* configure process timers *)
    ProcTimers.Init(P0, P1, P2, P3, P4, P5, P6, P7);

    (* the scheduler coroutine *)
    (* the scheduler stack is at the top of the stack area *)
    SchedulerStackTop := Kernel.stackOrg;
    SchedulerStackBottom := SchedulerStackTop - SchedulerStackSize;
    NEW(loop); ASSERT(loop # NIL);
    INCL(installedP, 0);
    (***
    SYSTEM.GET(ClockFreqAdr, ClockFreq);
    IF ClockFreq # 0 THEN
      ClockPeriod := 1000000 DIV (ClockFreq DIV 1000) (* nanoseconds *)
    END
    *)
  END initM;

BEGIN
  initM
END Processes.


(*
  PROCEDURE Suspend*(p: Process);
  BEGIN
    p.state := StateAwaiting;
    ProcTimers.Disable(p.pn);
    ProcDelay.Disable(p.pn);
    ProcDevsig.Disable(p.pn);
  END Suspend;


  PROCEDURE SuspendMe*;
  BEGIN
    Suspend(Cp);
    Coroutines.Transfer(Cp.cor, loop)
  END SuspendMe;
*)

(*
  PROCEDURE SetTimeout*(timeout: INTEGER);
  BEGIN
    ProcDelay.SetDelay(Cp.pn, timeout)
  END SetTimeout;


  PROCEDURE CancelTimeout*;
  BEGIN
    ProcDelay.CancelDelay(Cp.pn)
  END CancelTimeout;
*)
(*
  PROCEDURE TimedOut(): BOOLEAN;
    VAR ready: SET;
  BEGIN
    ProcDelay.GetReadyStatus(ready);
    RETURN Cp.pn IN ready
  END TimedOut;
*)

