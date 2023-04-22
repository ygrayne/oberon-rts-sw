(**
  Run-time error handling
  plus trap handler for NEW (trap 0)
  --

  --
  (c) 2021 - 2023 Gray, gray@grayraven.org
  http://oberon-rts.org/licences
**)

MODULE Errors;

  IMPORT
    SYSTEM, Kernel, Modules, SysCtrl, Procs := Processes, Log, Start, Calltrace, CalltraceView, Console := ConsoleB, Texts;

  CONST
    (* traps *)
    ArrayIndex* = 1;
    TypeGuard* = 2;
    CopyOverflow* = 3;
    NilPointer* = 4;
    IllegalCall* = 5;
    DivZero* = 6;
    Assertion* = 7;

    (* aborts *)
    Kill* = 08H + SysCtrl.Kill;
    Watchdog* = 08H + SysCtrl.Watchdog;
    StackOverflowLim* = 08H + SysCtrl.StackOverflowLim;
    StackOverflowHot* = 08H + SysCtrl.StackOverflowLim;


  VAR
    ForceRestart*: SET; (* system will always be restarted upon these errors *)
    le: Log.Entry;
    handlingError: BOOLEAN;
    W: Texts.Writer;

  PROCEDURE SetForceRestart*(errors: SET);
  BEGIN
    ForceRestart := errors
  END SetForceRestart;


  PROCEDURE resetSystem;
  (* hardware-reset the system *)
  (* will result in restart via SysCtrl.SetRestart *)
  BEGIN
    SysCtrl.ResetSystem;
    REPEAT UNTIL FALSE
  END resetSystem;


  PROCEDURE addModuleInfo(addr: INTEGER; VAR le: Log.Entry);
    VAR mod: Modules.Module;
  BEGIN
    mod := Modules.root;
    WHILE (mod # NIL) & ((addr < mod.code) OR (addr >= mod.imp)) DO mod := mod.next END;
    IF mod # NIL THEN
      le.str0 := mod.name;
      le.more1 := (addr - mod.code) DIV 4;
    ELSE
      le.str0 := "unknown module";
      le.more1 := 0
    END
  END addModuleInfo;

  (*
  Entry point after the bootloader if the system is not reloaded from disk.
  At this point, the system has been hardware-reset, nothing else.

  That is:
  * the ready queue and Cp on Processes are as per the error occurrence
  * the processes' state is as per the error occurrence
  * which includes the error-inducing process, or the one interrupted
    by the hardware-error-signal, which may or may not be the one
    producing the error, eg. in the case of the kill buttons

  NOT hardware reset, ie. values are still set in the hardware, as per the hw design:
  * enable and ticker assigments of process timers
  * error register and parts of the system control and status register
  * calltrace stacks

  The bootloader:
  * allocates the stack in the memory area starting from Kernel.stackOrg down
  * disables he stack monitor
  * disables the watchdog

  This code is called by loading its address into the PC, not via BL, hence
  its prologue's push of the LNK register onto the stack pushes
  * in the abort case, the LNK value of the last call of the interrupted process,
  * in the trap case, the LNK value of calling SysCtrl.ResetSystem.
  This value needs to be popped from the calltrace.
  *)

  PROCEDURE reset;
    VAR x, errorNo, addr, pid, trapInstr, abortNo, trapNo, trapPos: INTEGER;
  BEGIN
    (* pop invalid LNK value *)
    Calltrace.Pop(x);

    (* provided by trap handler (below), or by the hardware for aborts *)
    SysCtrl.GetError(errorNo, addr);

    (* set by Coroutines.Transfer *)
    SysCtrl.GetCpPid(pid);

    (* for the processes to enquire after they return from error handling *)
    SysCtrl.SetErrPid(pid);

    (* error logging and call trace stack "corrections" *)
    IF errorNo >= 08H THEN (* abort *)
      (* In the trap case, the LNK address of the trap handler call is on top, ie. *)
      (* the error location. Let's also push the error location for the abort case, *)
      (* even though it's not a LNK value. *)
      Calltrace.Push(addr);
      abortNo := errorNo MOD 08H;
      le.event := Log.Abort;
      le.cause := abortNo;
      DEC(addr, 4);
      le.adr0 := addr;
      addModuleInfo(addr, le);
      Procs.GetName(pid, le.name);
      Log.Put(le)
    ELSE (* trap *)
      SYSTEM.GET(addr, trapInstr);
      trapNo := trapInstr DIV 10H MOD 10H;
      trapPos := trapInstr DIV 100H MOD 10000H;
      le.event := Log.Trap;
      le.cause := trapNo;
      le.adr0 := addr;
      le.more0 := trapPos;
      addModuleInfo(addr, le);
      Procs.GetName(pid, le.name);
      Log.Put(le);
      (* For traps, we have also the LNK values for resetSystem and *)
      (* SysCtrl.ResetSystem on the calltrace stack. *)
      Calltrace.Pop(x);
      Calltrace.Pop(x)
    END;

    CalltraceView.ShowTrace(-1);

    (* error handling and logging *)
    IF ~handlingError THEN
      handlingError := TRUE;
      (* let's contaminate Pid 0's calltrace stack, it will be reset *)
      (* anyway upon Processes.Go *)
      SysCtrl.SetCpPid(0);
      IF (errorNo IN ForceRestart) OR Procs.ForceRestart(pid) THEN
        (* logging *)
        le.event := Log.System;
        le.cause := Log.SysRestart;
        SysCtrl.GetReg(le.more0);
        SysCtrl.GetError(le.more1, addr);
        Log.Put(le);
        (* actions *)
        Start.Arm;
        SysCtrl.SetRestart;
        resetSystem
      ELSE
        (* logging *)
        le.event := Log.System;
        le.cause := Log.SysReset;
        SysCtrl.GetReg(le.more0);
        SysCtrl.GetError(le.more1, addr);
        Log.Put(le);
        (* actions *)
        Procs.Recover;
        Procs.OnError(pid);
        SysCtrl.SetNoRestart;
        Start.Disarm;
        handlingError := FALSE;
        Procs.Go;

        (* we'll not return here, but... *)
        (* logging *)
        le.event := Log.System;
        le.cause := Log.SysFault;
        Log.Put(le);
        (* actions *)
        Start.Arm;
        SysCtrl.SetRestart;
        resetSystem
      END
    ELSE
      (* error in error handling *)
      (* logging *)
      le.event := Log.System;
      le.cause := Log.SysErrorInError;
      Log.Put(le);
      (* actions *)
      Start.Arm;
      SysCtrl.SetRestart;
      resetSystem
    END
  END reset;


  PROCEDURE trap(VAR a: INTEGER; b: INTEGER); (* uses process stack *)
    CONST LNK = 15;
    VAR adr, trapNo, trapInstr: INTEGER;
  BEGIN
    adr := SYSTEM.REG(LNK); (* trap was called via BL, hence LNK contains the return address = offending location + 4 *)
    DEC(adr, 4);
    SYSTEM.GET(adr, trapInstr); trapNo := trapInstr DIV 10H MOD 10H; (*trap number*)
    IF trapNo = 0 THEN (* execute NEW *)
      Kernel.New(a, b)
    ELSE (* error trap *)
      SysCtrl.SetError(trapNo, adr);
      SysCtrl.SetNoRestart;
      resetSystem (* will arrive at 'reset' above via boot loader *)
    END
  END trap;


  PROCEDURE Init*;
  BEGIN
    Kernel.Install(SYSTEM.ADR(trap), 20H);
    Kernel.Install(SYSTEM.ADR(reset), 0H);
    SysCtrl.SetNoRestart; (* all resets go through reset proc above *)
    ForceRestart := {StackOverflowLim};
    handlingError := FALSE
  END Init;

BEGIN
  W := Console.C
END Errors.
