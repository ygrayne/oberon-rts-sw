(**
  Interface to the System Control and Status Register
  --
  2020 - 2023 Gray, gray@grayraven.org
  https://oberon-rts.org/licences
**)

MODULE SysCtrl;

  IMPORT SYSTEM, DevAdr;

  CONST
    SysCtrlRegAdr = DevAdr.SysCtrlRegAdr;  (* SCR *)
    (*SPCadr = DevAdr.SysCtrlSPCadr;        (* stored PC value while handling interrupt, ie. SPC *)*)

    (* bits *)
    SysReset*        = 0;    (* = 1: reset system *)
    SysResetAll*     = 1;    (* = 1: reset all systems *)
    SysIntAbort*     = 3;

    ErrorState0 = 4;  (* lowest bit of error state value *)
    ErrorState1 = 5;  (* highest bit *)

    RestartCnt0 = 8;  (* lowest bit of the system restart counter *)
    RestartCnt1 = 9;  (* highest bit *)

    RestartCause0 = 12; (* lowest bit of the system restart cause value *)
    RestartCause1 = 15; (* highest bit *)

    (* abort causes *)
    WatchdogAbort* = 0;
    KillAbort* = 1;
    StackOverflowAbort* = 2;
    NotAliveAbort* = 3;

    (* restart causes *)
    RestartFPGA* = 0;
    RestartRstBtn* = 1;
    RestartSW* = 2;
    RestartSWother* = 4;
    RestartStackOvfl* = 8;

  VAR
    AbortAdr*: INTEGER;     (* address where abort occurred + 4 *)
    AbortCause*: INTEGER;   (* abort cause as reported by 'AbortInt' *)


  (* raw register ops *)
  PROCEDURE GetReg*(VAR reg: INTEGER);
  BEGIN
    SYSTEM.GET(SysCtrlRegAdr, reg)
  END GetReg;


  PROCEDURE SetReg*(reg: INTEGER);
  BEGIN
    SYSTEM.PUT(SysCtrlRegAdr, reg)
  END SetReg;


  (* system restart *)
  PROCEDURE RestartSystem*;
    VAR x: INTEGER;
  BEGIN
    SYSTEM.GET(SysCtrlRegAdr, x);
    SYSTEM.PUT(SysCtrlRegAdr, ORD(BITS(x) + {SysReset}))
  END RestartSystem;


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

END SysCtrl.
