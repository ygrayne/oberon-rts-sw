(**
  Interface to the System Control and Status Register
  --
  SCS:
  [0]: bootloader will skip loading from disk
  [1]: trigger system reset
  [7:3]: unused
  [12:8]: current process id
  [17:13]: error process id

  Error register:
  [7:0]: error number
  [31:8]: error address
  --
  2020 - 2023 Gray, gray@grayraven.org
  https://oberon-rts.org/licences
**)

MODULE SysCtrl;

  IMPORT SYSTEM, DevAdr;

  CONST
    SysCtrlRegAdr = DevAdr.SysCtrlRegAdr;  (* SCR *)
    SysCtrlErrAdr = SysCtrlRegAdr + 4;

    (* SCS bits *)
    SysNoRestart* = 0;    (* bootloader will skip loading from disk *)
    SysReset*     = 1;    (* reset system *)
    SysError*     = 2;    (* currently handling error *)

    (* bit ranges *)
    CpPid0 = 8;
    CpPid1 = 12;
    ErrPid0 = 13;
    ErrPid1 = 17;

    ErrNo0 = 0;
    ErrNo1 = 7;
    ErrAddr0 = 8;
    ErrAddr1 = 31;

    (* abort causes -- wired in FPGA, see sys ctrl and status *)
    Kill* = 0;
    Watchdog* = 2;
    StackOverflowLim* = 3;
    StackOverflowHot* = 4;


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

  PROCEDURE SetNoRestart*;
    VAR x: INTEGER;
  BEGIN
    SYSTEM.GET(SysCtrlRegAdr, x);
    SYSTEM.PUT(SysCtrlRegAdr, ORD(BITS(x) + {SysNoRestart}))
  END SetNoRestart;

  PROCEDURE SetRestart*;
    VAR x: INTEGER;
  BEGIN
    SYSTEM.GET(SysCtrlRegAdr, x);
    SYSTEM.PUT(SysCtrlRegAdr, ORD(BITS(x) - {SysNoRestart}))
  END SetRestart;


  (* error handling *)

  PROCEDURE SetErrorDone*;
    VAR x: INTEGER;
  BEGIN
    SYSTEM.GET(SysCtrlRegAdr, x);
    SYSTEM.PUT(SysCtrlRegAdr, ORD(BITS(x) - {SysError}))
  END SetErrorDone;

  PROCEDURE SetError*(errorNo, addr: INTEGER);
  (* triggers a hw-reset *)
  BEGIN
    SYSTEM.PUT(SysCtrlErrAdr, LSL(addr, ErrAddr0) + errorNo);
  END SetError;

  PROCEDURE GetError*(VAR errorNo, addr: INTEGER);
    VAR x: INTEGER;
  BEGIN
    SYSTEM.GET(SysCtrlErrAdr, x);
    errorNo := BFX(x, ErrNo1, ErrNo0);
    addr := BFX(x, ErrAddr1, ErrAddr0)
  END GetError;

  PROCEDURE SetCpPid*(pid: INTEGER);
    VAR x: INTEGER;
  BEGIN
    SYSTEM.GET(SysCtrlRegAdr, x);
    BFI(x, CpPid1, CpPid0, pid);
    SYSTEM.PUT(SysCtrlRegAdr, x)
  END SetCpPid;

  PROCEDURE GetCpPid*(VAR pid: INTEGER);
    VAR x: INTEGER;
  BEGIN
    SYSTEM.GET(SysCtrlRegAdr, x);
    pid := BFX(x, CpPid1, CpPid0)
  END GetCpPid;

  PROCEDURE SetErrPid*(pid: INTEGER);
    VAR x: INTEGER;
  BEGIN
    SYSTEM.GET(SysCtrlRegAdr, x);
    BFI(x, ErrPid1, ErrPid0, pid);
    SYSTEM.PUT(SysCtrlRegAdr, x)
  END SetErrPid;

  PROCEDURE GetErrPid*(VAR pid: INTEGER);
    VAR x: INTEGER;
  BEGIN
    SYSTEM.GET(SysCtrlRegAdr, x);
    pid := BFX(x, ErrPid1, ErrPid0)
  END GetErrPid;

END SysCtrl.
