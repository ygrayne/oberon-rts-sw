(**
  Interface to the System Control and Status Register
  --
  [0]: bootloader will skip loading from disk
  [1]: trigger system reset
  [7:3] : unused
  [8:13]: current process id
  --
  2020 - 2023 Gray, gray@grayraven.org
  https://oberon-rts.org/licences
**)

MODULE SysCtrl;

  IMPORT SYSTEM, DevAdr;

  CONST
    SysCtrlRegAdr = DevAdr.SysCtrlRegAdr;  (* SCR *)
    SysCtrlErrAdr = SysCtrlRegAdr + 4;

    (* SCR bits *)
    SysNoReload*     = 0;    (* = 1: bootloader will skip loading from disk *)
    SysReset*        = 1;    (* = 1: reset system *)

    (* abort causes -- wired in FPGA, see sys ctrl*)
    WatchdogAbort* = 0;
    KillAbort* = 1;
    StackOverflowAbort* = 2;
    NotAliveAbort* = 3;


  (* raw register ops *)
  PROCEDURE GetReg*(VAR reg: INTEGER);
  BEGIN
    SYSTEM.GET(SysCtrlRegAdr, reg)
  END GetReg;

  PROCEDURE SetReg*(reg: INTEGER);
  BEGIN
    SYSTEM.PUT(SysCtrlRegAdr, reg)
  END SetReg;


  (* reset and restart *)
  PROCEDURE ResetSystem*;
    VAR x: INTEGER;
  BEGIN
    SYSTEM.GET(SysCtrlRegAdr, x);
    SYSTEM.PUT(SysCtrlRegAdr, ORD(BITS(x) + {SysReset}))
  END ResetSystem;

  PROCEDURE SetNoReload*;
    VAR x: INTEGER;
  BEGIN
    SYSTEM.GET(SysCtrlRegAdr, x);
    SYSTEM.PUT(SysCtrlRegAdr, ORD(BITS(x) + {SysNoReload}))
  END SetNoReload;

  PROCEDURE SetReload*;
    VAR x: INTEGER;
  BEGIN
    SYSTEM.GET(SysCtrlRegAdr, x);
    SYSTEM.PUT(SysCtrlRegAdr, ORD(BITS(x) - {SysNoReload}))
  END SetReload;


  (* error handling *)
  PROCEDURE SetError*(abortNo, trapNo, addr: INTEGER);
  BEGIN
    SYSTEM.PUT(SysCtrlErrAdr, LSL(addr, 8) + LSL(abortNo, 4) + trapNo);
  END SetError;

  PROCEDURE GetError*(VAR errorNo, addr: INTEGER);
    VAR x: INTEGER;
  BEGIN
    SYSTEM.GET(SysCtrlErrAdr, x);
    errorNo := BFX(x, 7, 0);
    addr := BFX(x, 31, 8);
    (*
    errorNo := x MOD 0100H;
    addr := LSR(x, 8)
    *)
  END GetError;


  PROCEDURE SetCpPid*(pid: INTEGER);
    VAR x: INTEGER;
  BEGIN
    SYSTEM.GET(SysCtrlRegAdr, x);
    BFI(x, 12, 8, pid);
    SYSTEM.PUT(SysCtrlRegAdr, x)
  END SetCpPid;

  PROCEDURE GetCpPid*(VAR pid: INTEGER);
    VAR x: INTEGER;
  BEGIN
    SYSTEM.GET(SysCtrlRegAdr, x);
    pid := BFX(x, 12, 8)
  END GetCpPid;

END SysCtrl.

(***
  PROCEDURE RestartAllSystems*;
    VAR x: INTEGER;
  BEGIN
    SYSTEM.GET(SysCtrlRegAdr, x);
    SYSTEM.PUT(SysCtrlRegAdr, ORD(BITS(x) + {SysResetAll}))
  END RestartAllSystems;


  PROCEDURE GetRestartCause*(VAR cause: INTEGER);
  BEGIN
    SYSTEM.GET(SysCtrlRegAdr, cause);
    cause := BFX(cause, RestartCause1, RestartCause0)
  END GetRestartCause;


  PROCEDURE IncNumRestarts*;
    VAR x, cnt: INTEGER;
  BEGIN
    SYSTEM.GET(SysCtrlRegAdr, x);
    cnt := BFX(x, RestartCnt1, RestartCnt0);
    INC(cnt);
    BFI(x, RestartCnt1, RestartCnt0, cnt);
    SYSTEM.PUT(SysCtrlRegAdr, x)
  END IncNumRestarts;


  PROCEDURE GetNumRestarts*(VAR num: INTEGER);
  BEGIN
    SYSTEM.GET(SysCtrlRegAdr, num);
    num := BFX(num, RestartCnt1, RestartCnt0)
  END GetNumRestarts;


  PROCEDURE ResetNumRestarts*;
    VAR x: INTEGER;
  BEGIN
    SYSTEM.GET(SysCtrlRegAdr, x);
    BFI(x, RestartCnt1, RestartCnt0, 0);
    SYSTEM.PUT(SysCtrlRegAdr, x)
  END ResetNumRestarts;


  (* error state *)
  PROCEDURE IncErrorState*;
    VAR x, state: INTEGER;
  BEGIN
    SYSTEM.GET(SysCtrlRegAdr, x);
    state := BFX(x, ErrorState1, ErrorState0);
    INC(state);
    BFI(x, ErrorState1, ErrorState0, state);
    SYSTEM.PUT(SysCtrlRegAdr, x)
  END IncErrorState;


  PROCEDURE GetErrorState*(VAR state: INTEGER);
  BEGIN
    SYSTEM.GET(SysCtrlRegAdr, state);
    state := BFX(state, ErrorState1, ErrorState0)
  END GetErrorState;


  PROCEDURE ResetErrorState*;
    VAR x: INTEGER;
  BEGIN
    SYSTEM.GET(SysCtrlRegAdr, x);
    BFI(x, ErrorState1, ErrorState0, 0);
    SYSTEM.PUT(SysCtrlRegAdr, x)
  END ResetErrorState;

  (*
  (* abort interrupts *)
  PROCEDURE AbortInt*(cause: INTEGER);
    VAR x: INTEGER;
  BEGIN
    SYSTEM.GET(SPCadr, AbortAdr); (* read return address of interrupt = error address + 4 *)
    AbortCause := cause;
    SYSTEM.GET(SysCtrlRegAdr, x);
    x := ORD(BITS(x) + {SysIntAbort});
    SYSTEM.PUT(SysCtrlRegAdr, x)
  END AbortInt;
  *)

  PROCEDURE Decode*(scr: INTEGER; VAR rstCnt, rstCause, errStat: INTEGER);
  BEGIN
    rstCnt := BFX(scr, RestartCnt1, RestartCnt0);
    rstCause := BFX(scr, RestartCause1, RestartCause0);
    errStat := BFX(scr, ErrorState1, ErrorState0)
  END Decode;
  *)
