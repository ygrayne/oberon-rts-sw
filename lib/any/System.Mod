MODULE System; (*JG 3.10.90 / NW 12.10.93 / NW 18.5.2013 / CB 6.11.2016 *)
  (* CFB 28.4.2018 Added RTC. *)
(**
  Changes by Gray, gray@grayraven.org
  2020-05: * Texts.Writer writes to console
  2020-08: * Astrobe for RISC5, August 2020, compatible
  2020-11: * added data size, code size, and total module mem usage to ShowModules
  2021-03: * added command 'ShowProcesses'
           * moved abort and trap handlers to 'Errors'
  2021-04: * fixed System.Date
           * extended System.Watch with total numbers
  2021-05: * extended System.Watch with scheduler run-time data
           * extended System.ShowProcesses with process run-time data
  2021-10: * Date changed to v8.0 variant, with correction
  2023-04: * Remove process run-time data from System.Watch
**)

  IMPORT SYSTEM, Kernel, FileDir, Files, Modules, Texts, Oberon, Console := ConsoleC, Procs := Processes, GC;

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
    VAR
      S: Texts.Scanner;
      arg: ARRAY 6 OF LONGINT; (* day, month, year, hour, mins, secs *)
      dt, i: LONGINT;
  BEGIN
    Texts.WriteString(W, "System.Date"); EndLine;
    Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
    Texts.Scan(S);
    i := 0;
    WHILE (S.class = Texts.Int) & (i < 6) DO
      arg[i] := S.i; Texts.Scan(S); INC(i)
    END;
    IF i = 6 THEN
      IF (arg[0] >= 1) & (arg[0] <= 31) & (arg[1] >= 1) & (arg[1] <= 12) & (arg[2] >= 0) & (arg[2] <= 63)
        & (arg[3] >= 0) & (arg[3] <= 23) & (arg[4] >= 0) & (arg[4] <= 59) & (arg[5] >= 0) & (arg[5] <= 59) THEN
        dt := ((((arg[2]*16 + arg[1])*32 + arg[0])*32 + arg[3])*64 + arg[4])*64 + arg[5];
        Oberon.SetClock(dt)
      END
    END;
    dt := Oberon.Clock();
    Texts.WriteClock(W, dt); EndLine
  END Date;

  PROCEDURE Collect*;
  BEGIN Texts.WriteString(W, "System.Collect"); EndLine;
    GC.Collect
  END Collect;

  (* ------------- Toolbox for module management ---------------*)

  PROCEDURE Free1(VAR S: Texts.Scanner);
  BEGIN Texts.WriteString(W, S.s); Texts.WriteString(W, " unloading");
    Modules.Free(S.s);
    IF Modules.res # 0 THEN Texts.WriteString(W, " failed") END;
    EndLine
  END Free1;

  PROCEDURE Free*;
  VAR S: Texts.Scanner;
  BEGIN Texts.WriteString(W, "System.Free"); EndLine;
    Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    WHILE S.class = Texts.Name DO Free1(S); Texts.Scan(S) END;
    GC.Collect
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
  BEGIN
    Texts.WriteString(W, "System.Watch"); Texts.WriteLn(W);
    Texts.WriteString(W, "  Total RAM     "); Texts.WriteInt(W, Kernel.MemLim, 8); EndLine;
    Texts.WriteString(W, "  Modules space "); Texts.WriteInt(W, Kernel.heapOrg - Kernel.stackSize, 8);
    Texts.WriteInt(W, Modules.AllocPtr, 8);
    Texts.WriteInt(W, Modules.AllocPtr * 100 DIV (Kernel.heapOrg - Kernel.stackSize), 4); Texts.Write(W, "%"); EndLine;
    Texts.WriteString(W, "  Heap space    "); Texts.WriteInt(W, Kernel.heapLim - Kernel.heapOrg, 8);
    Texts.WriteInt(W, Kernel.allocated, 8);
    Texts.WriteInt(W, Kernel.allocated * 100 DIV (Kernel.heapLim - Kernel.heapOrg), 4); Texts.Write(W, "%"); EndLine;
    Texts.WriteString(W, "  Disk sectors  "); Texts.WriteInt(W, 10000H, 8);
    Texts.WriteInt(W, Kernel.NofSectors, 8);
    Texts.WriteInt(W, Kernel.NofSectors * 100 DIV 10000H, 4); Texts.Write(W, "%"); EndLine;
    Texts.WriteString(W, "  Procs         "); Texts.WriteInt(W, Procs.NumProcs, 8); EndLine;
    Texts.WriteString(W, "  MemLim       "); Texts.WriteHex(W, Kernel.MemLim); EndLine;
    Texts.WriteString(W, "  stackOrg     "); Texts.WriteHex(W, Kernel.stackOrg); EndLine;
    Texts.WriteString(W, "  stackSize    "); Texts.WriteHex(W, Kernel.stackSize);  Texts.WriteInt(W, Kernel.stackSize, 8); EndLine;
    Texts.WriteString(W, "  GC limit      "); Texts.WriteInt(W, GC.GClimit, 8); EndLine
  END Watch;

  PROCEDURE ShowModules*;
    VAR
      M: Modules.Module;
      total: INTEGER;
  BEGIN
    Texts.WriteString(W, "System.ShowModules"); EndLine;
    M := Modules.root;      (* address of last module loaded *)
    (*m := Modules.AllocPtr;  (* address of next free mem beyond Module.root *)*)
    Texts.WriteString(W, "  name"); Pad(4, 21);
    Texts.WriteString(W, "base adr");
    Texts.WriteString(W, " code adr");
    Texts.WriteString(W, " code end");
    Texts.WriteString(W, "  data");
    Texts.WriteString(W, "  code");
    Texts.WriteString(W, "  slot");
    Texts.WriteString(W, "  refs");
    Texts.WriteString(W, "   num");
    Texts.WriteLn(W);
    total := 0;
    WHILE M # NIL DO
      Texts.WriteString(W, "  ");
      IF M.name[0] = 0X THEN
        Texts.WriteString(W, "---"); Pad(3, 20);
      ELSE
        Texts.WriteString(W, M.name); Pad(Length(M.name), 20);
      END;
      Texts.WriteHex(W, SYSTEM.VAL(INTEGER, M));  (* base address of module *)
      Texts.WriteHex(W, M.code);                  (* start address of code segment *)
      Texts.WriteHex(W, M.imp);                   (* end address of code segment *)
      Texts.WriteInt(W, M.code - M.data, 6);      (* size of data segment *)
      Texts.WriteInt(W, M.imp - M.code, 6);       (* size of code segment *)
      INC(total, M.size);
      Texts.WriteInt(W, M.size, 6);               (* total size of module slot, can be larger than module size*)
      Texts.WriteInt(W, M.refcnt, 6);
      Texts.WriteInt(W, M.num, 6);
      Texts.WriteLn(W); (*m := ORD(M);*) M := M.next
    END;
    Pad(0, 44); Texts.WriteString(W, "total");
    Texts.WriteInt(W, total, 18); Texts.WriteLn(W)
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

  PROCEDURE ShowProcesses*;
    VAR j, pid: INTEGER; pd: Procs.ProcessData; td: ARRAY Procs.NumTimers OF INTEGER;
  BEGIN
    Texts.WriteString(W, "System.ShowProcesses"); Texts.WriteLn(W);
    Texts.WriteString(W, "  nm");
    Texts.WriteString(W, "  pid");
    Texts.WriteString(W, "  pr");
    Texts.WriteString(W, "  tr");
    Texts.WriteString(W, "  tm");
    Texts.WriteString(W, "    stk adr");
    Texts.WriteString(W, "    size");
    Texts.WriteString(W, "   hot");
    Texts.WriteString(W, "  used");
    Texts.WriteString(W, "  unused");
    Texts.WriteLn(W);
    pid := -1;
    Procs.GetProcData(pd, pid);
    WHILE pid # -1 DO
      Texts.WriteString(W, "  ");
      Texts.WriteString(W, pd.name);
      j := 0; WHILE pd.name[j] # 0X DO INC(j) END;
      WHILE j < Procs.NameLen-1 DO Texts.WriteString(W, " "); INC(j) END;
      Texts.WriteInt(W, pd.pid, 4);
      Texts.WriteInt(W, pd.prio, 4);
      Texts.WriteInt(W, pd.trigger, 4);
      IF pd.trigger > 0 THEN
        Texts.WriteInt(W, pd.period, 4)
      ELSE
        Texts.WriteString(W, "  --")
      END;
      Texts.WriteString(W, "  "); Texts.WriteHex(W, pd.stAdr); (* stack address *)
      Texts.WriteInt(W, pd.stSize, 8); (* stack size *)
      Texts.WriteInt(W, pd.stHotSize, 6); (* stack hot size *)
      Texts.WriteInt(W, pd.stAdr + pd.stSize - pd.stMin, 6); (* stack used *)
      Texts.WriteInt(W, pd.stMin - pd.stAdr, 8); (* stack unused *)
      Texts.WriteLn(W);
      Procs.GetProcData(pd, pid)
    END;

    Procs.GetTimerData(td);
    Texts.WriteString(W, "  timers: ");
    FOR j := 0 TO Procs.NumTimers - 1 DO
      Texts.Write(W, "t"); Texts.WriteInt(W, j, 0); Texts.WriteString(W, ": "); Texts.WriteInt(W, td[j], 0); Texts.WriteString(W, "  ")
    END;

    Texts.WriteLn(W)
  END ShowProcesses;

BEGIN
  W := Console.C
END System.
