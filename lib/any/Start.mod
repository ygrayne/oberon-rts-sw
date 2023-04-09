(**
  Driver for the start command tables.
  --
  (c) 2021 - 2023 Gray, gray@grayraven.org
  https://oberon-rts.org/licences
**)

MODULE Start;

  IMPORT SYSTEM, DevAdr;

  CONST
    Adr = DevAdr.StartAdr;
    NumCmds* = 4;
    Commands = {0..3};
    NumTables* = 4;
    Tables = {0..3};
    NumCmdChars = 64;
    InitTable* = 0;
    Sets = {0..1};

    SetTableCtrl = 0100H;
    SetArmedCtrl = 0200H;
    SetSetCtrl = 0400H;

    DataMask = 040H;
    SetSelectionBit = 6;
    ArmedStatusBit = 7;

  TYPE
    Cmd = ARRAY NumCmdChars OF CHAR;
    CmdTable = ARRAY NumCmds OF Cmd;

  VAR
    cmds: ARRAY 2 OF ARRAY NumTables OF CmdTable;


  PROCEDURE SetTable*(tbl: INTEGER);
  BEGIN
    ASSERT(tbl IN Tables);
    SYSTEM.PUT(Adr, SetTableCtrl + tbl)
  END SetTable;


  PROCEDURE GetTable*(VAR tbl: INTEGER);
  BEGIN
    SYSTEM.GET(Adr, tbl);
    tbl := tbl MOD DataMask;
    ASSERT(tbl IN Tables)
  END GetTable;


  PROCEDURE SetSet*(set: INTEGER);
  BEGIN
    ASSERT(set IN Sets);
    SYSTEM.PUT(Adr, SetSetCtrl + LSL(set, SetSelectionBit))
  END SetSet;


  PROCEDURE GetSet*(VAR set: INTEGER);
  BEGIN
    IF SYSTEM.BIT(Adr, SetSelectionBit) THEN
      set := 1
    ELSE
      set := 0
    END
  END GetSet;


  PROCEDURE Arm*;
  BEGIN
    (*SYSTEM.PUT(Adr, SetArmedCtrl + LSL(1, ArmedStatusBit));*)
    SYSTEM.PUT(Adr, SetArmedCtrl + 080H);
  END Arm;


  PROCEDURE Disarm*;
  BEGIN
    SYSTEM.PUT(Adr, SetArmedCtrl)
  END Disarm;


  PROCEDURE Armed*(): BOOLEAN;
    RETURN SYSTEM.BIT(Adr, ArmedStatusBit)
  END Armed;


  PROCEDURE GetCmd*(set, tbl, no: INTEGER; VAR cmd: ARRAY OF CHAR; VAR valid: BOOLEAN);
    VAR i: INTEGER; ch: CHAR;
  BEGIN
    ASSERT(set IN Sets);
    ASSERT(tbl IN Tables);
    ASSERT(no IN Commands);
    ASSERT(LEN(cmd) >= NumCmdChars);
    ch := cmds[set][tbl][no][0];
    valid := ch # 0X;
    IF valid THEN
      i := 0;
      REPEAT
        cmd[i] := ch; INC(i);
        ch := cmds[set][tbl][no][i];
      UNTIL ch = 0X;
      cmd[i] := 0X
    END
  END GetCmd;


  PROCEDURE SetCmd*(mode, tbl, no: INTEGER; cmd: Cmd);
  BEGIN
    ASSERT(tbl < NumTables); ASSERT(no < NumCmds);
    cmds[mode][tbl][no] := cmd
  END SetCmd;


BEGIN
  (* table 0 *)
  (* set one *)
  cmds[0][0][0] := "LogView.InstallLogPrint";
  cmds[0][0][1] := "System.ShowProcesses";
  cmds[0][0][2] := "";
  cmds[0][0][3] := "LogView.z3"; (* deliberate error *)
  (* set two *)
  cmds[1][0][0] := "LogView.InstallLogPrint";
  cmds[1][0][1] := "System.ShowModules";
  cmds[1][0][2] := "";
  cmds[1][0][3] := "";

  (* table 1 *)
  (* set one *)
  cmds[0][1][0] := "LogView.InstallLogPrint";
  cmds[0][1][1] := "System.Date";
  cmds[0][1][2] := "";
  cmds[0][1][3] := "";
  (* set two *)
  cmds[1][1][0] := "LogView.InstallLogPrint";
  cmds[1][1][1] := "System.Date";
  cmds[1][1][2] := "";
  cmds[1][1][3] := "";

  (* table 2 *)
  (* set one *)
  cmds[0][2][0] := "x.y";
  cmds[0][2][1] := "x";
  cmds[0][2][2] := "";
  cmds[0][2][3] := "";
  (* set two *)
  cmds[1][2][0] := "x.y";
  cmds[1][2][1] := "x";
  cmds[1][2][2] := "";
  cmds[1][2][3] := "";

  (* table 3 *)
  (* set one *)
  cmds[0][3][0] := "";
  cmds[0][3][1] := "";
  cmds[0][3][2] := "";
  cmds[0][3][3] := "";
  (* set two *)
  cmds[1][3][0] := "";
  cmds[1][3][1] := "";
  cmds[1][3][2] := "";
  cmds[1][3][3] := ""
END Start.
