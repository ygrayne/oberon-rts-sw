MODULE System; (*JG 3.10.90 / NW 12.10.93 / NW 18.5.2013 / CB 6.11.2016 *)
  (* CFB 28.04.2018 Added RTC. *)
  (* CFB 05.08.2020 Changed date format and validated date *)
  IMPORT SYSTEM, Kernel, FileDir, Files, Modules, Texts, Oberon, RTC;

  VAR
    W: Texts.Writer;
    pat: ARRAY 32 OF CHAR;

  PROCEDURE Length(s: ARRAY OF CHAR): INTEGER;
  VAR
    i: INTEGER;
  BEGIN
    i := 0;
    WHILE s[i] # 0X DO INC(i) END;
    RETURN i
  END Length;

  PROCEDURE Pad(i1, i2: INTEGER);
  VAR
    i: INTEGER;
  BEGIN
    FOR i := i1 TO i2 DO Texts.Write(W, " ") END
  END Pad;

  PROCEDURE GetArg(VAR S: Texts.Scanner);
  BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
  END GetArg;

  PROCEDURE EndLine;
  BEGIN
    Texts.WriteLn(W);
  END EndLine;

  (* ------------- Toolbox for system control ---------------*)

  PROCEDURE Date*;
    VAR S: Texts.Scanner;
      dt, hr, min, sec, yr, mo, day: LONGINT;
  BEGIN
    Texts.WriteString(W, "System.Date ");
    Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    IF S.class = Texts.Int THEN (*set clock*)
      day := S.i; Texts.Scan(S); mo := S.i; Texts.Scan(S); yr := S.i; Texts.Scan(S);
      hr := S.i; Texts.Scan(S); min := S.i; Texts.Scan(S); sec := S.i;
      IF (day >= 1) & (day <= 31) & (mo >= 1) & (mo <= 12) & (yr >= 0) & (yr <= 63) THEN
        dt := ((((yr*16 + mo)*32 + day)*32 + hr)*64 + min)*64 + sec;
        Kernel.SetClock(dt)
      END
    ELSE (*read clock*)
      dt := Oberon.Clock()
    END;
    Texts.WriteClock(W, dt); EndLine
  END Date;

  PROCEDURE Collect*;
  BEGIN Texts.WriteString(W, "System.Collect"); EndLine;
    Oberon.Collect(0)
  END Collect;

  (* ------------- Toolbox for module management ---------------*)

  PROCEDURE Free1(VAR S: Texts.Scanner);
  BEGIN Texts.WriteString(W, S.s); Texts.WriteString(W, " unloading");
    Modules.Free(S.s);
    IF Modules.res # 0 THEN Texts.WriteString(W, " failed") END;
    EndLine
  END Free1;

  PROCEDURE Free*;
  VAR
    S: Texts.Scanner;
  BEGIN Texts.WriteString(W, "System.Free"); EndLine;
    Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    WHILE S.class = Texts.Name DO Free1(S); Texts.Scan(S) END;
    Oberon.Collect(0)
  END Free;

  (* ------------- Toolbox of file system ---------------*)

  PROCEDURE List(name: FileDir.FileName; adr: LONGINT; VAR cont: BOOLEAN);
    VAR i0, i, j0, j: INTEGER; hp: FileDir.FileHeader;
  BEGIN
    i := 0;
    WHILE (pat[i] > "*") & (pat[i] = name[i]) DO INC(i) END ;
    IF (pat[i] = 0X) & (name[i] = 0X) THEN i0 := i; j0 := i
    ELSIF pat[i] = "*" THEN
      i0 := i; j0 := i+1;
      WHILE name[i0] # 0X DO
        i := i0; j := j0;
        WHILE (name[i] # 0X) & (name[i] = pat[j]) DO INC(i); INC(j) END ;
        IF pat[j] = 0X THEN
          IF name[i] = 0X THEN (*match*) j0 := j ELSE INC(i0) END
        ELSIF pat[j] = "*" THEN i0 := i; j0 := j+1
        ELSE INC(i0)
        END
      END
    END ;
    IF (name[i0] = 0X) & (pat[j0] = 0X) THEN (*found*)
      Texts.WriteString(W, name);
      IF pat[j0+1] = "!" THEN (*option*)
        Pad(Length(name), 20);
        Kernel.GetSector(adr, hp);
        Texts.WriteClock(W, hp.date);
        Texts.WriteInt(W, hp.aleng*FileDir.SectorSize + hp.bleng - FileDir.HeaderSize, 8); (*length*)
      END;
      Texts.WriteLn(W)
    END
  END List;

  PROCEDURE Directory*;
    VAR
      S: Texts.Scanner;
      i: INTEGER;
      pre: ARRAY 32 OF CHAR;
      ch: CHAR;
  BEGIN
    Texts.WriteString(W, "System.Directory"); EndLine;
    Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Read(S, ch);
    WHILE ch = " " DO Texts.Read(S, ch) END;
    i := 0;
    WHILE ch > "!" DO pat[i] := ch; INC(i); Texts.Read(S, ch) END;
    pat[i] := 0X;
    IF ch = "!" THEN pat[i+1] := "!" END ;  (*directory option*)
    i := 0;
    WHILE pat[i] > "*" DO pre[i] := pat[i]; INC(i) END;
    pre[i] := 0X;
    IF pat[0] # 0X THEN FileDir.Enumerate(pre, List) END
  END Directory;

  PROCEDURE CopyFiles*;
    VAR f, g: Files.File; Rf, Rg: Files.Rider; ch: CHAR;
      name: ARRAY 32 OF CHAR;
      S: Texts.Scanner;
  BEGIN GetArg(S);
    Texts.WriteString(W, "System.CopyFiles"); EndLine;
    WHILE S.class = Texts.Name DO
    name := S.s; Texts.Scan(S);
      IF (S.class = Texts.Char) & (S.c = "=") THEN Texts.Scan(S);
        IF (S.class = Texts.Char) & (S.c = ">") THEN Texts.Scan(S);
          IF S.class = Texts.Name THEN
            Texts.WriteString(W, name); Texts.WriteString(W, " => "); Texts.WriteString(W, S.s);
            Texts.WriteString(W, " copying");
            f := Files.Old(name);
            IF f # NIL THEN g := Files.New(S.s);
              Files.Set(Rf, f, 0); Files.Set(Rg, g, 0); Files.Read(Rf, ch);
              WHILE ~Rf.eof DO Files.Write(Rg, ch); Files.Read(Rf, ch) END;
              Files.Register(g)
            ELSE Texts.WriteString(W, " failed")
            END ;
            EndLine
          END
        END
      END ;
      Texts.Scan(S)
    END
  END CopyFiles;

  PROCEDURE RenameFiles*;
    VAR res: INTEGER;
      name: ARRAY 32 OF CHAR;
      S: Texts.Scanner;
  BEGIN GetArg(S);
    Texts.WriteString(W, "System.RenameFiles"); EndLine;
    WHILE S.class = Texts.Name DO
      name := S.s; Texts.Scan(S);
      IF (S.class = Texts.Char) & (S.c = "=") THEN Texts.Scan(S);
        IF (S.class = Texts.Char) & (S.c = ">") THEN Texts.Scan(S);
          IF S.class = Texts.Name THEN
            Texts.WriteString(W, name); Texts.WriteString(W, " => "); Texts.WriteString(W, S.s);
            Texts.WriteString(W, " renaming"); Files.Rename(name, S.s, res);
            IF res > 1 THEN Texts.WriteString(W, " failed") END;
            EndLine
          END
        END
      END ;
      Texts.Scan(S)
    END
  END RenameFiles;

  PROCEDURE DeleteFiles*;
    VAR res: INTEGER; S: Texts.Scanner;
  BEGIN GetArg(S);
    Texts.WriteString(W, "System.DeleteFiles"); EndLine;
    WHILE S.class = Texts.Name DO
      Texts.WriteString(W, S.s); Texts.WriteString(W, " deleting");
      Files.Delete(S.s, res);
      IF res # 0 THEN Texts.WriteString(W, " failed") END;
      EndLine; Texts.Scan(S)
    END
  END DeleteFiles;

  PROCEDURE CompareFiles*;
    VAR f, g: Files.File; Rf, Rg: Files.Rider; chf, chg: CHAR;
      name: ARRAY 32 OF CHAR;
      match: BOOLEAN;
      S: Texts.Scanner;
  BEGIN GetArg(S);
    Texts.WriteString(W, "System.CompareFiles"); EndLine;
    WHILE S.class = Texts.Name DO
      name := S.s; Texts.Scan(S);
      IF (S.class = Texts.Char) & (S.c = "=") THEN Texts.Scan(S);
        IF (S.class = Texts.Char) & (S.c = ">") THEN Texts.Scan(S);
          IF S.class = Texts.Name THEN
            Texts.WriteString(W, name); Texts.WriteString(W, " => "); Texts.WriteString(W, S.s);
            Texts.WriteString(W, " comparing");
            f := Files.Old(name);
            g := Files.Old(S.s);
            IF (f # NIL) & (g # NIL) THEN
              IF Files.Length(f) # Files.Length(g) THEN
                Texts.WriteString(W, " lengths differ")
              ELSE
                Files.Set(Rf, f, 0); Files.Set(Rg, g, 0);
                match := TRUE;
                WHILE ~Rf.eof & match DO Files.Read(Rf, chf); Files.Read(Rg, chg); match := chf = chg END;
                IF match THEN Texts.WriteString(W, " identical") ELSE Texts.WriteString(W, " different") END;
              END
            ELSE Texts.WriteString(W, " open failed")
            END ;
            EndLine
          END
        END
      END ;
      Texts.Scan(S)
    END
  END CompareFiles;

    (* ------------- Toolbox for system inspection ---------------*)

  PROCEDURE Watch*;
  BEGIN Texts.WriteString(W, "System.Watch"); Texts.WriteLn(W);
    Texts.WriteString(W, "  Modules space "); Texts.WriteInt(W, Modules.AllocPtr, 8);
    Texts.WriteInt(W, Modules.AllocPtr * 100 DIV Kernel.heapOrg, 4); Texts.Write(W, "%"); EndLine;
    Texts.WriteString(W, "  Heap space    "); Texts.WriteInt(W, Kernel.allocated, 8);
    Texts.WriteInt(W, Kernel.allocated * 100 DIV (Kernel.heapLim - Kernel.heapOrg), 4); Texts.Write(W, "%"); EndLine;
    Texts.WriteString(W, "  Disk sectors  "); Texts.WriteInt(W, Kernel.NofSectors, 8);
    Texts.WriteInt(W, Kernel.NofSectors * 100 DIV 10000H, 4); Texts.Write(W, "%"); EndLine;
    Texts.WriteString(W, "  Tasks         "); Texts.WriteInt(W, Oberon.NofTasks, 8); EndLine
  END Watch;

  PROCEDURE ShowModules*;
    VAR M: Modules.Module;
  BEGIN
    Texts.WriteString(W, "System.ShowModules"); EndLine;
    M := Modules.root;
    WHILE M # NIL DO
      IF M.name[0] # 0X THEN
        Texts.WriteString(W, M.name); Pad(Length(M.name), 20); Texts.WriteHex(W, SYSTEM.VAL(INTEGER, M));
        Texts.WriteHex(W, M.code); Texts.WriteInt(W, M.refcnt, 4)
      ELSE Texts.WriteString(W, "---")
      END ;
      Texts.WriteLn(W); M := M.next
    END
  END ShowModules;

  PROCEDURE ShowCommands*;
    VAR M: Modules.Module;
      comadr: INTEGER; ch: CHAR;
      S: Texts.Scanner;
  BEGIN
    Texts.WriteString(W, "System.ShowCommands"); EndLine;
    GetArg(S);
    IF S.class = Texts.Name THEN
      Modules.Load(S.s, M);
      IF M # NIL THEN
        comadr := M.cmd; SYSTEM.GET(comadr, ch); INC(comadr);
        WHILE ch # 0X DO
          Texts.WriteString(W, S.s); Texts.Write(W, ".");
          REPEAT Texts.Write(W, ch); SYSTEM.GET(comadr, ch); INC(comadr)
          UNTIL ch = 0X;
          WHILE comadr MOD 4 # 0 DO INC(comadr) END ;
          Texts.WriteLn(W); INC(comadr, 4); SYSTEM.GET(comadr, ch); INC(comadr)
        END
      END
    END
  END ShowCommands;

  PROCEDURE Trap(VAR a: INTEGER; b: INTEGER);
    VAR u, v, w: INTEGER; mod: Modules.Module;
  BEGIN u := SYSTEM.REG(15); SYSTEM.GET(u - 4, v); w := v DIV 10H MOD 10H; (*trap number*)
    IF w = 0 THEN Kernel.New(a, b)
    ELSE (*trap*) Texts.WriteLn(W); Texts.WriteString(W, "  pos "); Texts.WriteInt(W, v DIV 100H MOD 10000H, 4);
      Texts.WriteString(W, "  TRAP"); Texts.WriteInt(W, w, 4); mod := Modules.root;
      WHILE (mod # NIL) & ((u < mod.code) OR (u >= mod.imp)) DO mod := mod.next END ;
      IF mod # NIL THEN Texts.WriteString(W, " in "); Texts.WriteString(W, mod.name) END ;
      Texts.WriteString(W, " at"); Texts.WriteHex(W, u);
      Texts.WriteLn(W); Oberon.Reset
    END
  END Trap;

  PROCEDURE Abort;
    VAR n: INTEGER;
  BEGIN n := SYSTEM.REG(15); Texts.WriteString(W, "  ABORT  "); Texts.WriteHex(W, n);
    Texts.WriteLn(W); Oberon.Reset
  END Abort;

BEGIN
  RTC.Install();
  Kernel.Install(SYSTEM.ADR(Trap), 20H); Kernel.Install(SYSTEM.ADR(Abort), 0)
END System.
