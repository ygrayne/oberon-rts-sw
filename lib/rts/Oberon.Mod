MODULE Oberon;
(*JG 6.9.90 / 23.9.93 / 13.8.94 *)
(*NW 14.4.2013 / 22.12.2013 *)
(*CFB Software 2019-2021*)
  IMPORT SYSTEM, Texts, Files, Input, Kernel, Modules, Upload;

  CONST
    off = 0; idle = 1; active = 2;   (*task states*)
    BasicCycle = 20;
    REC = 21X;

  TYPE
    Task* = POINTER TO TaskDesc;

    Handler* = PROCEDURE;

    TaskDesc* = RECORD
      state, nextTime, period*: INTEGER;
      next: Task;
      handle: Handler
    END;

    ParDesc* = RECORD
      text*: Texts.Text;
      pos*: LONGINT
    END;

  VAR
    NofTasks*: INTEGER;
    Par*: ParDesc;
    W: Texts.Writer;

    CurTask: Task;
    ActCnt: INTEGER; (*action count for GC*)
    Mod: Modules.Module;

  PROCEDURE WriteLine(s: ARRAY OF CHAR);
  BEGIN
    Texts.WriteString(W, s);
    Texts.WriteLn(W)
  END WriteLine;

  PROCEDURE WriteError(res: INTEGER; command: ARRAY OF CHAR);
  BEGIN
    Texts.WriteLn(W);
    Texts.WriteString(W, "Command: ");
    WriteLine(command);
    Texts.WriteLn(W);
    IF res IN {1..4} THEN
      Texts.WriteString(W, "Importing: ");
      WriteLine(Modules.errName)
    END;
    Texts.WriteString(W, "Error ");
    Texts.WriteInt(W, res, 0);
    Texts.WriteString(W, ": ");
    IF res = 1 THEN
      WriteLine("File not found")
    ELSIF res = 2 THEN
      WriteLine("Import error")
    ELSIF res = 3 THEN
      WriteLine("Inconsistent import key")
    ELSIF res = 4 THEN
      WriteLine("Corrupted object file")
    ELSIF res = 5 THEN
      WriteLine("Unknown command")
    ELSIF res = 7 THEN
      WriteLine("Insufficient free memory")
    ELSE
      WriteLine("Unspecified")
    END
  END WriteError;

  PROCEDURE Clock*(): LONGINT;
  BEGIN RETURN Kernel.Clock()
  END Clock;

  PROCEDURE SetClock* (d: LONGINT);
  BEGIN Kernel.SetClock(d)
  END SetClock;

  PROCEDURE Time*(): LONGINT;
  BEGIN RETURN Kernel.Time()
  END Time;

  (*command interpretation*)
  PROCEDURE Call* (name: ARRAY OF CHAR; VAR res: INTEGER);
    VAR mod: Modules.Module; P: Modules.Command;
      i, j: INTEGER; ch: CHAR;
      Mname, Cname: ARRAY 32 OF CHAR;
  BEGIN i := 0; ch := name[0];
    WHILE (ch # ".") & (ch # 0X) DO Mname[i] := ch; INC(i); ch := name[i] END ;
    IF ch = "." THEN
      Mname[i] := 0X; INC(i);
      Modules.Load(Mname, mod); res := Modules.res;
      IF Modules.res = 0 THEN
        j := 0; ch := name[i]; INC(i);
        WHILE (ch # 0X) & (ch # " ") DO Cname[j] := ch; INC(j); ch := name[i]; INC(i) END ;
        Cname[j] := 0X;
        P := Modules.ThisCommand(mod, Cname); res := Modules.res;
        IF Modules.res = 0 THEN P END
      END
    ELSE
      res := 5
    END
  END Call;

  PROCEDURE GC;
    VAR mod: Modules.Module;
      heapSize: INTEGER;
  BEGIN
    heapSize := Kernel.heapLim - Kernel.heapOrg;
    IF (ActCnt <= 0) OR (Kernel.allocated >= heapSize - (heapSize DIV 8)) THEN
      mod := Modules.root; LED(21H);
      WHILE mod # NIL DO
        IF mod.name[0] # 0X THEN Kernel.Mark(mod.ptr) END ;
        mod := mod.next
      END ;
      LED(23H);
      Files.RestoreList; LED(27H);
      Kernel.Scan; LED(20H);
      ActCnt := BasicCycle
    END
  END GC;

  PROCEDURE NewTask*(h: Handler; period: INTEGER): Task;
    VAR t: Task;
  BEGIN NEW(t); t.state := off; t.next := t; t.handle := h; t.period := period; RETURN t
  END NewTask;

  PROCEDURE Install* (T: Task);
  BEGIN
    IF T.state = off THEN
      T.next := CurTask.next; CurTask.next := T; T.state := idle; T.nextTime := 0; INC(NofTasks)
    END
  END Install;

  PROCEDURE Remove* (T: Task);
    VAR t: Task;
  BEGIN
    IF T.state # off THEN t := T;
      WHILE t.next # T DO t := t.next END ;
      t.next := T.next; T.state := off; T.next := NIL; CurTask := t; DEC(NofTasks)
    END
  END Remove;

  PROCEDURE Collect* (count: INTEGER);
  BEGIN ActCnt := count
  END Collect;

  PROCEDURE GetCommand(ch: CHAR);
  VAR
    i: INTEGER;
  BEGIN
    i := 0;
    WHILE (ch # 0AX) DO
      IF ch >= " " THEN
        Par.text.string[i] := ch;
        INC(i)
      END;
      Input.Read(ch)
    END;
    Par.text.string[i] := 0X;
    Par.text.len := i
  END GetCommand;

  PROCEDURE Loop*;
    VAR t, res: INTEGER;
      ch: CHAR;
  BEGIN
    WriteLine("Embedded Project Oberon 07.10.2021");
    REPEAT
      IF Input.Available() > 0 THEN
        Input.Read(ch);
        IF ch = REC THEN
          Upload.Run()
        ELSE
          GetCommand(ch);
          IF Par.text.string[0] # 0X THEN
            Call(Par.text.string, res);
            IF res # 0 THEN
              WriteError(res, Par.text.string)
            END
          END
        END;
        DEC(ActCnt)
      ELSE
        CurTask := CurTask.next; t := Kernel.Time();
        IF (CurTask.nextTime - t) <= 0 THEN
          CurTask.nextTime := t + CurTask.period; CurTask.state := active; CurTask.handle; CurTask.state := idle
        END
      END
    UNTIL FALSE
  END Loop;

  PROCEDURE Reset*;
  BEGIN
    IF CurTask.state = active THEN Remove(CurTask) END ;
    SYSTEM.LDREG(14, Kernel.stackOrg); (*reset stack pointer*) Loop
  END Reset;

BEGIN
  ActCnt := 0;
  NEW(Par.text);
  CurTask := NewTask(GC, 1000); Install(CurTask);
  Modules.Load("System", Mod); Mod := NIL;
  Loop
END Oberon.
