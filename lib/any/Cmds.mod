(**
  Command and upload process
  Execute commands from the startup tables
  --
  * Process installed in Oberon.mod
  --
  Command interpretation as well as the corresponding data structure for the parameters
  have been extracted from the original Oberon module. Oberon aliases 'Call' and 'Par'
  for compatibility with existing modules.
  --
  The processes' stack takes over most of the original stack space after loading.
  The loop/scanner will only use the top of the stack space, see KoopStackSize in the Processes module.
  --
  2020 - 2023 by Gray, gray@grayraven.org
  https://oberon-rts.org/licences
**)

MODULE Cmds;

  IMPORT Texts, Modules, Console := ConsoleB, RS232, Procs := Processes, Log, Upload, Start;

  CONST
    Prio = 3;
    Name = "cmd";

  TYPE
    ParRef* = POINTER TO ParDesc;
    ParDesc* = RECORD
      text*: Texts.Text;
      pos*: INTEGER
    END;

  VAR
    W: Texts.Writer;
    Par*: ParRef;
    cmd: Procs.Process;
    le: Log.Entry;
    pid: INTEGER;


  PROCEDURE writeError(res: INTEGER; command: ARRAY OF CHAR);
  (* 'res' as set by Module.mod *)
  BEGIN
    Texts.WriteLn(W);
    Texts.WriteString(W, "Command: "); Texts.WriteString(W, command); Texts.WriteLn(W);
    IF res IN {1..4, 6} THEN
      Texts.WriteString(W, "Importing: "); Texts.WriteString(W, Modules.errName); Texts.WriteLn(W);
    END;
    Texts.WriteString(W, "Error "); Texts.WriteInt(W, res, 0); Texts.WriteString(W, ": ");
    IF res = Modules.ResFileNotFound THEN
      Texts.WriteString(W, "file not found")
    ELSIF res = Modules.ResImpErr THEN
      Texts.WriteString(W, "import error")
    ELSIF res = Modules.ResKeyInconsistent THEN
      Texts.WriteString(W, "inconsistent import key")
    ELSIF res = Modules.ResFileCorrupt THEN
      Texts.WriteString(W, "corrupted object file")
    ELSIF res = Modules.ResCmdUnknown THEN
      Texts.WriteString(W, "unknown command")
    ELSIF res = Modules.ResTooManyImp THEN
      Texts.WriteString(W, "too many imports")
    ELSIF res = Modules.ResNoMem THEN
      Texts.WriteString(W, "insufficient free module memory")
    ELSE
      Texts.WriteString(W, "unspecified")
    END;
    Texts.WriteLn(W)
  END writeError;


  PROCEDURE logError(res, table, no: INTEGER);
  BEGIN
    le.event := Log.System; le.cause := Log.SysStartTableError; le.more0 := res;
    le.more1 := table; le.more2 := no; Log.Put(le)
  END logError;

  PROCEDURE logUse(table, set: INTEGER);
  BEGIN
    le.event := Log.System; le.cause := Log.SysStartTableUsed;
    le.more0 := table; le.more1 := set; Log.Put(le)
  END logUse;


  PROCEDURE Call*(name: ARRAY OF CHAR; VAR res: INTEGER);
    VAR
      mod: Modules.Module; P: Modules.Command;
      i, j: INTEGER; ch: CHAR;
      Mname, Cname: ARRAY 32 OF CHAR;
  BEGIN
    i := 0; ch := name[0];
    WHILE (ch # ".") & (ch # 0X) DO Mname[i] := ch; INC(i); ch := name[i] END ;
    IF ch = "." THEN
      Mname[i] := 0X; INC(i);
      Modules.Load(Mname, mod); res := Modules.res;
      IF res = 0 THEN
        j := 0; ch := name[i]; INC(i);
        WHILE (ch # 0X) & (ch # " ") DO Cname[j] := ch; INC(j); ch := name[i]; INC(i) END ;
        Cname[j] := 0X;
        P := Modules.ThisCommand(mod, Cname); res := Modules.res;
        IF res = 0 THEN P END
      END
    ELSE
      res := 5
    END
  END Call;


  PROCEDURE getCommand(pos: INTEGER);
    CONST LF = 0AX;
    VAR cnt: INTEGER;
  BEGIN
    RS232.GetString(Console.Dev, Par.text.string, LF, pos, cnt);
    Par.text.string[cnt] := 0X;  (* the Astrobe console sends max 255 chars *)
    Par.text.len := cnt
  END getCommand;


  PROCEDURE cmdc;
    CONST REC = 21X;
    VAR res, cnt, set: INTEGER; ch: CHAR; valid: BOOLEAN; i, table: INTEGER;
  BEGIN
    REPEAT
      Procs.Next;
      IF RS232.GetAvailable(Console.Dev, ch) THEN
        IF ch = REC THEN
          REPEAT
            LED(09H);
            Upload.Run;
            cnt := 1000000; (* workaround for upload timeout issue with multiple files *)
            REPEAT
              valid := RS232.GetAvailable(Console.Dev, ch) & (ch = REC); DEC(cnt);
              LED(0BH);
            UNTIL valid OR (cnt = 0);
          UNTIL cnt = 0;
          LED(0FH);
        ELSE
          Par.text.string[0] := ch;
          getCommand(1);
          IF Par.text.string[0] # 0X THEN
            Call(Par.text.string, res);
            IF res # 0 THEN
              writeError(res, Par.text.string)
            END
          END
        END
      ELSIF Start.Armed() THEN
        Start.GetSet(set);
        Start.GetTable(table);
        logUse(table, set);
        Texts.WriteLn(W);
        FOR i := 0 TO Start.NumCmds - 1 DO
          Start.GetCmd(set, table, i, Par.text.string, valid);
          IF valid THEN
            Call(Par.text.string, res);
            IF res # 0 THEN
              logError(res, table, i);
            END
          END
        END;
        Start.Disarm
      END

    UNTIL FALSE
  END cmdc;


  PROCEDURE Init*(stackAdr, stackSize, stackHotSize: INTEGER);
    VAR res: INTEGER;
  BEGIN
    Procs.Init(cmd, cmdc, stackAdr, stackSize, stackHotSize, pid, res);
    ASSERT(res = Procs.OK);
    Procs.SetPrio(cmd, Prio);
    Procs.SetOnError(cmd, Procs.OnErrorReset, Procs.OnErrorHitDefault);
    Procs.SetNoWatchdog(cmd);
    Procs.SetName(cmd, Name);
    Procs.Enable(cmd)
  END Init;


BEGIN
  NEW(cmd); ASSERT(cmd # NIL);
  NEW(Par); ASSERT(Par # NIL);
  NEW(Par.text); ASSERT(Par.text # NIL);
  W := Console.C
END Cmds.
