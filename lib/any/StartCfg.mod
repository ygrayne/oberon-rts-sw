MODULE StartCfg;
(**
  Config tool for start command tables
  --
  (c) 2021 - 2023 Gray, gray@grayraven.org
  https://oberon-rts.org/licences
**)

  IMPORT Texts, Oberon, Console := ConsoleB, Start;

  VAR W: Texts.Writer;


  PROCEDURE SetTable*;
    VAR S: Texts.Scanner;
  BEGIN
    Texts.WriteString(W, "StartCfg.SetTable"); Texts.WriteLn(W);
    Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
    Texts.Scan(S);
    IF S.class = Texts.Int THEN
      IF S.i < Start.NumTables THEN
        Start.SetTable(S.i)
      ELSE
        Texts.WriteString(W, "  invalid table no: "); Texts.WriteInt(W, S.i, 0); Texts.WriteLn(W)
      END
    END
  END SetTable;


  PROCEDURE list(tbl: INTEGER);
    VAR
      valid: BOOLEAN; i, mode: INTEGER;
      cmd: ARRAY 64 OF CHAR;
  BEGIN
    FOR mode := 0 TO 1 DO
      FOR i := 0 TO Start.NumCmds - 1 DO
        Start.GetCmd(mode, tbl, i, cmd, valid);
        IF valid THEN
          Texts.WriteString(W, "  "); Texts.WriteInt(W, i, 0); Texts.WriteString(W, ": ");
          Texts.WriteString(W, cmd); Texts.WriteLn(W)
        END
      END;
      Texts.WriteLn(W)
    END
  END list;


  PROCEDURE List*;
    VAR i: INTEGER;
  BEGIN
    Texts.WriteString(W, "StartCfg.List"); Texts.WriteLn(W);
    Start.GetTable(i);
    Texts.WriteString(W, "  current table: "); Texts.WriteInt(W, i, 0); Texts.WriteLn(W);
    FOR i := 0 TO Start.NumTables - 1 DO
      Texts.WriteString(W, "  table: "); Texts.WriteInt(W, i, 0); Texts.WriteLn(W);
      list(i)
    END
  END List;

BEGIN
  W := Console.C
END StartCfg.


(*
  PROCEDURE List*;
    VAR S: Texts.Scanner;
  BEGIN
    Texts.WriteString(W, "StartCfg.List"); Texts.WriteLn(W);
    Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
    Texts.Scan(S);
    IF S.class = Texts.Int THEN
      IF S.i < Start.NumTables THEN
        list(S.i)
      ELSE
        Texts.WriteString(W, "  invalid table no: "); Texts.WriteInt(W, S.i, 0); Texts.WriteLn(W)
      END
    END
  END List;
*)
(*
  PROCEDURE Set*;
    VAR S: Texts.Scanner; tbl: INTEGER;
  BEGIN
    Texts.WriteString(W, "StartCfg.Set"); Texts.WriteLn(W);
    Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
    Texts.Scan(S);
    IF S.class = Texts.Int THEN
      IF S.i < Start.NumTables THEN
        Start.SetWriteTable(S.i); Start.Clear; tbl := S.i;
        Texts.Scan(S);
        WHILE S.class = Texts.Int DO
          IF S.i < Start.NumDefs THEN
            Start.AddCmd(S.i)
          ELSE
            Texts.WriteString(W, "  invalid cmd no: "); Texts.WriteInt(W, S.i, 0); Texts.WriteLn(W);
          END;
          Texts.Scan(S)
        END
      ELSE
        Texts.WriteString(W, "  invalid table no: "); Texts.WriteInt(W, S.i, 0); Texts.WriteLn(W)
      END
    END;
    Start.Disarm;
    list(tbl)
  END Set;


  PROCEDURE Clear*;
    VAR S: Texts.Scanner; tbl: INTEGER;
  BEGIN
    Texts.WriteString(W, "StartCfg.Clear"); Texts.WriteLn(W);
    Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
    Texts.Scan(S);
    IF S.class = Texts.Int THEN
      IF S.i < Start.NumTables THEN
        Start.SetWriteTable(S.i); Start.Clear
      ELSE
        Texts.WriteString(W, "  invalid table no: "); Texts.WriteInt(W, S.i, 0); Texts.WriteLn(W)
      END
    END
  END Clear;
*)
