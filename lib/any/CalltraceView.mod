MODULE CalltraceView;
(**
  Print procedure calltrace from calltrace stack.
  --
  (c) 2021-2023 Gray, gray@grayraven.org
  https://oberon-rts.org/licences
**)

  IMPORT Calltrace, Console := ConsoleB, Texts, Modules;

  VAR W: Texts.Writer;

  (* The first call stack entry is the address of the coroutine code procedure. *)
  (* It was pushed there by this procedure's prologue, but the procedure was called *)
  (* by B LNK in Coroutines.Transfer's epilogue, not the usual BL call. For BL calls *)
  (* the pushed value minus 4 gives the BL call's address, which is printed in the trace, *)
  (* but for the coroutine's entry point, we don't want to subtract 4. *)
  (* Note, however, that the scheduler coroutine is actually started by a BL call, hence the *)
  (* reported address of its procedure 'Loop' will be off by 4. Nothing's perfect. *)

  PROCEDURE writeModuleName(name: ARRAY OF CHAR; padTo: INTEGER);
    VAR i, j: INTEGER;
  BEGIN
    Texts.WriteString(W, name);
    i := 0; WHILE name[i] # 0X DO INC(i) END;
    FOR j := i TO padTo DO Texts.Write(W, " ") END
  END writeModuleName;


  PROCEDURE writeTraceLine(adr: INTEGER);
    VAR mod: Modules.Module;
  BEGIN
    mod := Modules.root;
    WHILE (mod # NIL) & ((adr < mod.code) OR (adr >= mod.imp)) DO mod := mod.next END;
    IF mod # NIL THEN
      Texts.WriteString(W, "  "); writeModuleName(mod.name, 20); Texts.WriteHex(W, adr); Texts.WriteHex(W, adr - mod.code);
      Texts.WriteInt(W, (adr - mod.code) DIV 4, 8);
    ELSE
      Texts.WriteString(W, "  "); writeModuleName("unknown", 20); Texts.WriteHex(W, adr)
    END
  END writeTraceLine;


  PROCEDURE ShowTrace*(id: INTEGER);
    VAR i, x, sel, cnt: INTEGER;
  BEGIN
    (* Remove call to ShowTrace for negative id's used during error handling. *)
    (* For non-error calls, it's useful to see where or which call was done *)
    (* to see the exact location *)
    IF id < 0 THEN Calltrace.Pop(x) END;
    Calltrace.GetCurrent(sel);
    Texts.WriteLn(W); Texts.WriteString(W, "call trace stack: "); Texts.WriteInt(W, sel, 0);
    Texts.WriteString(W, " id: "); Texts.WriteInt(W, id, 0); Texts.WriteLn(W);
    Texts.WriteString(W, "  module                "); Texts.WriteString(W, "    addr");
    Texts.WriteString(W, "   m-addr"); Texts.WriteString(W, "    line"); Texts.WriteLn(W);
    Calltrace.GetCount(cnt);
    Calltrace.Freeze;
    i := 0;
    WHILE i < cnt DO
      Calltrace.Read(x);
      INC(i);
      IF i # cnt THEN DEC(x, 4) END; (* don't correct the address for the coroutine *)
      writeTraceLine(x);
      Texts.WriteLn(W)
    END;
    Calltrace.Unfreeze;
    Calltrace.GetMaxCount(cnt);
    Texts.WriteString(W, "max depth: "); Texts.WriteInt(W, cnt, 0); Texts.WriteLn(W)
  END ShowTrace;


  PROCEDURE SetWriter*(w: Texts.Writer);
  BEGIN
    W := w
  END SetWriter;

BEGIN
  SetWriter(Console.C)
END CalltraceView.
