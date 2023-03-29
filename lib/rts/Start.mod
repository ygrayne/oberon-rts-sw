(**
  Driver for the start command tables.
  --
  2021 - 2023 Gray, gray@grayraven.org
  https://oberon-rts.org/licences
**)

MODULE Start;

  IMPORT SYSTEM, DevAdr;

  CONST
    Adr = DevAdr.StartAdr;
    NumCmds* = 4;
    NumTables* = 4;
    NumCmdChars = 64;
    InitTable* = 0;

    SetTableCtrl = 1;
    SetArmedCtrl = 2;
    SetDisarmedCtrl = 4;

    DataShift = 8;

    ArmedStatus = 8;

  TYPE
    Cmd = ARRAY NumCmdChars OF CHAR;
    CmdTable = ARRAY NumCmds OF Cmd;

  VAR
    cmds: ARRAY NumTables OF CmdTable;


  PROCEDURE SetTable*(tbl: INTEGER);
  BEGIN
    ASSERT(tbl < NumTables);
    SYSTEM.PUT(Adr, LSL(tbl, DataShift) + SetTableCtrl)
  END SetTable;


  PROCEDURE RecallTable*(VAR tbl: INTEGER);
  BEGIN
    SYSTEM.GET(Adr, tbl);
    tbl := tbl MOD 100H;
    IF tbl >= NumTables THEN tbl := 0 END
  END RecallTable;


  PROCEDURE GetCmd*(tbl, no: INTEGER; VAR cmd: ARRAY OF CHAR; VAR valid: BOOLEAN);
    VAR i: INTEGER; ch: CHAR;
  BEGIN
    ASSERT(no < NumCmds); ASSERT(LEN(cmd) >= NumCmdChars);
    ch := cmds[tbl][no][0];
    valid := ch # 0X;
    IF valid THEN
      i := 0;
      REPEAT
        cmd[i] := ch; INC(i);
        ch := cmds[tbl][no][i];
      UNTIL ch = 0X;
      cmd[i] := 0X
    END
  END GetCmd;


  PROCEDURE Arm*;
  BEGIN
    SYSTEM.PUT(Adr, SetArmedCtrl)
  END Arm;


  PROCEDURE Disarm*;
  BEGIN
    SYSTEM.PUT(Adr, SetDisarmedCtrl)
  END Disarm;


  PROCEDURE Armed*(): BOOLEAN;
    RETURN SYSTEM.BIT(Adr, ArmedStatus)
  END Armed;


  PROCEDURE SetCmd*(tbl, no: INTEGER; cmd: Cmd);
  BEGIN
    ASSERT(tbl < NumTables); ASSERT(no < NumCmds);
    cmds[tbl][no] := cmd
  END SetCmd;

BEGIN
  cmds[0][0] := "";
  cmds[0][1] := "System.ShowProcesses";
  cmds[0][2] := "";
  cmds[0][3] := "";

  (***
  cmds[0][0] := "LogView.InstallLogPrint";
  cmds[0][1] := "System.ShowProcesses";
  cmds[0][2] := "";
  cmds[0][3] := "LogView.z3";
  *)

  cmds[1][0] := "LogView.InstallLogPrint";
  cmds[1][1] := "System.Date";
  cmds[1][2] := "";
  cmds[1][3] := "";

  cmds[2][0] := "x.y";
  cmds[2][1] := "x";
  cmds[2][2] := "";
  cmds[2][3] := "";

  cmds[3][0] := "";
  cmds[3][1] := "";
  cmds[3][2] := "";
  cmds[3][3] := ""
END Start.
