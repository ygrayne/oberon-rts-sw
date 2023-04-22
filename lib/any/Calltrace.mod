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

    (* control *)
    ClearCtrl = 2;
    FreezeCtrl = 4;
    UnfreezeCtrl = 8;
    BlockCtrl = 16;
    UnblockCtrl = 32;

    CtrlDataShift = 8;

    (* status bits *)
    EmptyBit = 0;
    FullBit = 1;
    OverflowBit = 2;
    FrozenBit = 3;

    (* status value ranges *)
    Count0 = 8;
    Count1 = 15;
    MaxCount0 = 16;
    MaxCount1 = 23;
    Selected0 = 24;
    Selected1 = 29;

    (* config *)
    NumStacks = 32;
    Stacks = {0 .. NumStacks-1};


  (* target: stack 'stkNo' *)

  PROCEDURE Clear*(stkNo: INTEGER);
  BEGIN
    ASSERT(stkNo IN Stacks);
    SYSTEM.PUT(StatusAdr, LSL(stkNo, CtrlDataShift) + ClearCtrl);
  END Clear;

  (* target: all stacks (global block/unblock, only for hw/push/pop *)

  PROCEDURE Block*;
    VAR x: INTEGER;
  BEGIN
    SYSTEM.GET(DataAdr, x); (* pop top element hw-pushed by entering this procedure *)
    SYSTEM.PUT(StatusAdr, BlockCtrl)
  END Block;


  PROCEDURE Unblock*;
  BEGIN
    SYSTEM.PUT(StatusAdr, UnblockCtrl);
    SYSTEM.PUT(DataAdr, 0) (* push dummy value, will be hw-popped upon exiting this procedure *)
  END Unblock;

  (* target: current stack controlled by process id in SCS *)

  PROCEDURE Freeze*;
    VAR x: INTEGER;
  BEGIN
    SYSTEM.GET(DataAdr, x); (* pop top element hw-pushed by entering this procedure *)
    SYSTEM.PUT(StatusAdr, FreezeCtrl)
  END Freeze;


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


  PROCEDURE GetCurrent*(VAR stkNo: INTEGER);
    VAR x: INTEGER;
  BEGIN
    SYSTEM.GET(DataAdr, x);
    SYSTEM.GET(StatusAdr, stkNo);
    SYSTEM.PUT(DataAdr, x);
    stkNo := BFX(stkNo, Selected1, Selected0)
  END GetCurrent;


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


  PROCEDURE Overflow*(): BOOLEAN;
    VAR x: INTEGER; ovfl: BOOLEAN;
  BEGIN
    SYSTEM.GET(DataAdr, x);
    ovfl := SYSTEM.BIT(StatusAdr, OverflowBit);
    SYSTEM.PUT(DataAdr, x);
    RETURN ovfl
  END Overflow;

  (* target: frozen stack *)

  PROCEDURE Read*(VAR value: INTEGER);
  BEGIN
    SYSTEM.GET(DataAdr, value)
  END Read;


  PROCEDURE Unfreeze*;
  BEGIN
    SYSTEM.PUT(StatusAdr, UnfreezeCtrl);
    SYSTEM.PUT(DataAdr, 0) (* push dummy value, will be hw-popped upon exiting this procedure *)
  END Unfreeze;


END Calltrace.
