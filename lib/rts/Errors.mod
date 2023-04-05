(**
  Run-time error handling
  --
  Severely stripped down version just to get the minimal system running.
  --
  2021 - 2023 Gray, gray@grayraven.org
  http://oberon-rts.org/licences
**)

MODULE Errors;

  IMPORT
    SYSTEM, Kernel, Modules, SysCtrl, Procs := Processes, Log, Start, DebugOut;

  CONST
    LNK = 15;

  VAR
    le: Log.Entry;


  PROCEDURE resetSystem;
  BEGIN
    SysCtrl.ResetSystem;
    REPEAT UNTIL FALSE
  END resetSystem;

  PROCEDURE setModule(VAR le: Log.Entry);
    VAR mod: Modules.Module; adr: INTEGER;
  BEGIN
    mod := Modules.root; adr := le.adr0;
    WHILE (mod # NIL) & ((adr < mod.code) OR (adr >= mod.imp)) DO mod := mod.next END;
    IF mod # NIL THEN
      le.adr1 := SYSTEM.VAL(INTEGER, mod);
      le.str0 := mod.name;
      le.more1 := (adr - mod.code) DIV 4;
    ELSE
      le.adr1 := 0;
      le.str0 := "unknown module";
      le.more1 := 0
    END
  END setModule;

  PROCEDURE setProc(VAR le: Log.Entry);
  BEGIN
    IF Procs.Cp # NIL THEN
      Procs.Id(le.procId)
    ELSE
      le.procId := "---"
    END
  END setProc;


  PROCEDURE reset; (* SP = stackOrg *)
    VAR errorNo, addr, trapInstruction, abortNo, trapNo, trapPos: INTEGER;
  BEGIN
    SysCtrl.GetError(errorNo, addr);

    DebugOut.WriteLine("abort", "", "", -1);
    DebugOut.WriteLine("errorNo", "", "", errorNo);
    DebugOut.WriteLine("address", "", "", addr);

    IF addr # 0 THEN
      IF (errorNo = 0) OR (errorNo >= 010H) THEN (* abort *)
        (* note: trap 0 is not an error, so errorNo = 0 means abortNo = 0 *)
        abortNo := errorNo DIV 010H;
        DebugOut.WriteLine("abort no", "", "", abortNo);
        le.adr0 := addr;
        le.cause := abortNo;
        le.event := Log.Abort;
        setModule(le);
        le.procId := "***";
        Log.Put(le)
      ELSE (* trap *)
        SYSTEM.GET(addr, trapInstruction);
        trapNo := trapInstruction DIV 10H MOD 10H;
        trapPos := trapInstruction DIV 100H MOD 10000H;
        le.cause := trapNo;
        le.more0 := trapPos;
        le.adr0 := addr;
        setModule(le);
        le.procId := "***";
        Log.Put(le)
      END
    END;

    (* at this point we could also reset processes and whatnot, and just restart scheduling *)
    Start.Arm;
    SysCtrl.SetReload;
    resetSystem
  END reset;


  PROCEDURE trap(VAR a: INTEGER; b: INTEGER);
    VAR adr, trapNo, trapInstruction: INTEGER;
  BEGIN
    adr := SYSTEM.REG(LNK); (* trap was called via BL, hence LNK contains the return address = offending location + 4 *)
    DEC(adr, 4);
    SYSTEM.GET(adr, trapInstruction); trapNo := trapInstruction DIV 10H MOD 10H; (*trap number*)
    IF trapNo = 0 THEN (* execute NEW *)
      Kernel.New(a, b)
    ELSE (* error trap *)
      SysCtrl.SetError(0, trapNo, adr);
      SysCtrl.SetNoReload;
      resetSystem
    END
  END trap;


  PROCEDURE Install*;
  BEGIN
    Kernel.Install(SYSTEM.ADR(trap), 20H);
    Kernel.Install(SYSTEM.ADR(reset), 0H);
    SysCtrl.SetNoReload (* all resets go through reset proc above *)
  END Install;

  PROCEDURE Recover*;
  END Recover;

END Errors.

(*
  PROCEDURE error;
  BEGIN
    (* from here, the scheduler stack is used *)
    (* we need to get out of the error-inducing coroutine's stack, so any corrective measures, such as *)
    (* resetting the coroutine, and this code don't interfere with each other *)
    SYSTEM.LDREG(SP, Procs.SchedulerStackTop - 8); (* 8: for LNK, x; stacked LNK will contain garbage *)

    Start.Arm;
    restartSystem;

  END error;
*)

(*
  PROCEDURE abort;
  BEGIN
    (*
    Calltrace.Pop(x); (* remove the invalid LNK value *)
    *)
    (* could set the stack here, but let's be consistent with trap *)
    IF ~handlingError THEN
      handlingError := TRUE;

      le.adr0 := SysCtrl.AbortAdr; DEC(le.adr0, 4);
      le.cause := SysCtrl.AbortCause;
      le.event := Log.Abort;
      setModule(le); setProc(le);
      Log.Put(le);
      error;

      (* we should not return here *)
      le.event := Log.System; le.cause := Log.SysFault;
      Log.Put(le);
      le.cause := Log.SysRestart;
      Log.Put(le);
      restartSystem
    ELSE (* error in error handling, bail out *)
      le.event := Log.System; le.cause := Log.SysErrorAbort;
      Log.Put(le);
      (* restart logging done upon restart, cf. module Oberon *)
      restartSystem
    END
  END abort;
*)
