(**
  Simple coroutines
  --
  2020 - 2023 Gray, gray@grayraven.org
  https://oberon-rts.org/licences
**)

MODULE Coroutines;

  IMPORT SYSTEM, StackMonitor, Calltrace;

  CONST SP = 14;

  TYPE
    Coroutine* = POINTER TO CoroutineDesc;
    CoroutineDesc* = RECORD
      sp: INTEGER; (* stored stack pointer when transferring *)
      id*: INTEGER; (* coroutine id *)
      proc: INTEGER;
      stAdr*, stSize*, stHotLimit*, stMin*: INTEGER (* only exported for reporting/debugging reasons *)
    END;


  PROCEDURE Init*(cor: Coroutine; proc: PROCEDURE; stAdr, stSize, stHotSize: INTEGER; id: INTEGER);
  BEGIN
    ASSERT(cor # NIL);
    (* set the params for the stack monitor, see Transfer *)
    cor.stAdr := stAdr;
    cor.stHotLimit := stAdr + stHotSize;
    cor.stSize := stSize;
    cor.stMin := stAdr + stSize;
    cor.id := id;
    cor.proc := SYSTEM.VAL(INTEGER, proc);

    (* set up the stack for the initial transfer *)
    cor.sp := stAdr + stSize;
    (* place 'cor' for the initial transfer to this coroutine, at SP + 4 with SP pointing to LNK, seet below *)
    DEC(cor.sp, 8);
    SYSTEM.PUT(cor.sp, SYSTEM.VAL(INTEGER, cor));
    (* store LNK = start address of coroutine *)
    (* put the code address at the starting SP address *)
    (* this corresponds to the LNK value on the stack *)
    DEC(cor.sp, 4);
    SYSTEM.PUT(cor.sp, cor.proc);
    (* now cor.sp is 3 * 4-byte addresses "down" from the top of the stack *)
    (* hence the initial Transfer's epilogue works *)
    Calltrace.Clear(cor.id)
  END Init;


  PROCEDURE Reset*(cor: Coroutine);
  BEGIN
    ASSERT(cor # NIL);
    cor.sp := cor.stAdr + cor.stSize;
    DEC(cor.sp, 8);
    SYSTEM.PUT(cor.sp, SYSTEM.VAL(INTEGER, cor));
    DEC(cor.sp, 4);
    SYSTEM.PUT(cor.sp, cor.proc);
    Calltrace.Clear(cor.id)
  END Reset;


  PROCEDURE Transfer*(f, t: Coroutine);
  BEGIN
    ASSERT(f # NIL);
    ASSERT(t # NIL);
    (* enter "as" f, f's stack in use *)
    (* prologue: push caller's LNK and parameters 'f' and 't' onto f's stack *)

    (* disarm stack monitor, get coroutine number *)
    StackMonitor.Disarm(f.id, f.stAdr, f.stHotLimit, f.stMin);

    (* stack switching *)
    (* save f's SP *)
    f.sp := SYSTEM.REG(SP);
    (* switch stack: load t's SP *)
    (* 't' is still accessible on f's stack here *)
    SYSTEM.LDREG(SP, t.sp);
    (* now in t's stack *)

    (* set calltrace stack and arm stack overflow monitor *)
    (* in this stack, parameter 't' is at SP + 4, set either initially by Reset, or *)
    (* by the the last transfer away from t -- when the parameter was actually 'f' *)
    (* hence we access 't' using 'f' here, so the compiler accesses 't' at 'SP + 4' *)

    Calltrace.Select(f.id);

    StackMonitor.Arm(f.id, f.stAdr, f.stHotLimit, f.stMin)

    (* epilogue: retrieve LNK from stack, adjust stack by +12 *)
    (* branch to LNK, ie. continue "as" t *)
  END Transfer;

END Coroutines.
