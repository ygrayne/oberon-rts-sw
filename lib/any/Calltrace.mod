MODULE Calltrace;
(**
  Driver for the backtrace "shadow" stack.
  --
  There is one stack per process.
  --
  (c) 2021-2023 Gray gray@grayraven.org
  https://oberon-rts.org/licences
**)

  IMPORT SYSTEM, DevAdr;

  CONST
    DataAdr = DevAdr.CalltraceDataAdr;
    StatusAdr = DataAdr + 4;

    SelectCtrl = 1;
    ClearCtrl = 2;
    FreezeCtrl = 4;
    UnfreezeCtrl = 8;

    CtrlDataShift = 8;

    Empty = 0;
    Full = 1;
    Frozen = 2;
    Count0 = 8;
    Count1 = 15;
    MaxCount0 = 16;
    MaxCount1 = 23;
    Selected0 = 24;
    Selected1 = 29;

    NumStacks = 32;

  (* target stack 'stkNo' *)

  PROCEDURE Select*(stkNo: INTEGER);
  BEGIN
    ASSERT(stkNo < NumStacks);
    SYSTEM.PUT(StatusAdr, LSL(stkNo, CtrlDataShift) + SelectCtrl)
  END Select;


  PROCEDURE GetSelected*(VAR stkNo: INTEGER);
  BEGIN
    SYSTEM.GET(StatusAdr, stkNo);
    stkNo := BFX(stkNo, Selected1, Selected0)
  END GetSelected;


  PROCEDURE Clear*(stkNo: INTEGER);
  BEGIN
    SYSTEM.PUT(StatusAdr, LSL(stkNo, CtrlDataShift) + ClearCtrl);
  END Clear;


  PROCEDURE Freeze*(stkNo: INTEGER);
    VAR x: INTEGER;
  BEGIN
    SYSTEM.GET(DataAdr, x); (* pop top element hw-pushed by entering this procedure *)
    SYSTEM.PUT(StatusAdr, LSL(stkNo, CtrlDataShift) + FreezeCtrl)
  END Freeze;


  PROCEDURE Unfreeze*(stkNo: INTEGER);
  BEGIN
    SYSTEM.PUT(StatusAdr, LSL(stkNo, CtrlDataShift) + UnfreezeCtrl);
    SYSTEM.PUT(DataAdr, 0) (* push dummy value, will be hw-removed upon exiting this procedure *)
  END Unfreeze;


  (* target selected stack *)

  PROCEDURE Pop*(VAR value: INTEGER);
    VAR x: INTEGER;
  BEGIN
    SYSTEM.GET(DataAdr, x); (* pop this procedure entry *)
    SYSTEM.GET(DataAdr, value);
    SYSTEM.PUT(DataAdr, x)  (* push it back *)
  END Pop;


  PROCEDURE Push*(value: INTEGER);
    VAR x: INTEGER;
  BEGIN
    SYSTEM.GET(DataAdr, x);
    SYSTEM.PUT(DataAdr, value);
    SYSTEM.PUT(DataAdr, x)

  END Push;

  (* use on frozen selected stack *)

  PROCEDURE Read*(VAR value: INTEGER);
  BEGIN
    SYSTEM.GET(DataAdr, value)
  END Read;

  PROCEDURE GetStatus*(VAR status: INTEGER);
  BEGIN
    SYSTEM.GET(StatusAdr, status)
  END GetStatus;


  PROCEDURE GetCount*(VAR count: INTEGER);
  BEGIN
    SYSTEM.GET(StatusAdr, count);
    count := BFX(count, Count1, Count0)
  END GetCount;


  PROCEDURE GetMaxCount*(VAR count: INTEGER);
  BEGIN
    SYSTEM.GET(StatusAdr, count);
    count := BFX(count, MaxCount1, MaxCount0)
  END GetMaxCount;

END Calltrace.

