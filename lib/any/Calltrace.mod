MODULE Calltrace;
(**
  Driver for the calltrace "shadow" stack.
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

    EmptyBit = 0;
    FullBit = 1;
    FrozenBit = 2;
    Count0 = 8;
    Count1 = 15;
    MaxCount0 = 16;
    MaxCount1 = 23;
    Selected0 = 24;
    Selected1 = 29;

    NumStacks = 32;

  (* target: stack 'stkNo' *)

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


  (* target: selected stack *)

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


  PROCEDURE GetStatus*(VAR status: INTEGER);
    VAR x: INTEGER;
  BEGIN
    SYSTEM.GET(DataAdr, x);
    SYSTEM.GET(StatusAdr, status);
    SYSTEM.PUT(DataAdr, x)
  END GetStatus;


  PROCEDURE GetCount*(VAR count: INTEGER);
    VAR x: INTEGER;
  BEGIN
    SYSTEM.GET(DataAdr, x);
    SYSTEM.GET(StatusAdr, count);
    SYSTEM.PUT(DataAdr, x);
    count := BFX(count, Count1, Count0)
  END GetCount;


  PROCEDURE GetMaxCount*(VAR count: INTEGER);
    VAR x: INTEGER;
  BEGIN
    SYSTEM.GET(DataAdr, x);
    SYSTEM.GET(StatusAdr, count);
    SYSTEM.PUT(DataAdr, x);
    count := BFX(count, MaxCount1, MaxCount0)
  END GetMaxCount;


  PROCEDURE Frozen*(): BOOLEAN;
    RETURN SYSTEM.BIT(StatusAdr, FrozenBit)
  END Frozen;


  PROCEDURE Empty*(): BOOLEAN;
    VAR x: INTEGER; empty: BOOLEAN;
  BEGIN
    SYSTEM.GET(DataAdr, x);
    empty := SYSTEM.BIT(StatusAdr, EmptyBit);
    SYSTEM.PUT(DataAdr, x);
    RETURN empty
  END Empty;


  PROCEDURE Full*(): BOOLEAN;
    VAR x: INTEGER; full: BOOLEAN;
  BEGIN
    SYSTEM.GET(DataAdr, x);
    full := SYSTEM.BIT(StatusAdr, FullBit);
    SYSTEM.PUT(DataAdr, x);
    RETURN full
  END Full;

  (* target: frozen stack *)

  PROCEDURE Read*(VAR value: INTEGER);
  BEGIN
    SYSTEM.GET(DataAdr, value)
  END Read;


  PROCEDURE Unfreeze*(stkNo: INTEGER);
  BEGIN
    SYSTEM.PUT(StatusAdr, LSL(stkNo, CtrlDataShift) + UnfreezeCtrl);
    SYSTEM.PUT(DataAdr, 0) (* push dummy value, will be hw-popped upon exiting this procedure *)
  END Unfreeze;

END Calltrace.

