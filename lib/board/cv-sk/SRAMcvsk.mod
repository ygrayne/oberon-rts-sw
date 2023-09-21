(**
  SRAM test interface via IO
  --
  (c) 2023 by Gray, gray@grayraven.org
  https://oberon-rts.org/licences
**)

MODULE SRAMcvsk;

  IMPORT SYSTEM;

  CONST
    DataAdr = -104;
    CtrlAdr = DataAdr + 4;

    Ready = 0;
    ReadCmd = 080000000H;

  PROCEDURE Put*(addr, data: INTEGER);
  BEGIN
    (*REPEAT UNTIL SYSTEM.BIT(CtrlAdr, Ready);*)
    SYSTEM.PUT(CtrlAdr, addr);
    SYSTEM.PUT(DataAdr, data)
  END Put;


  PROCEDURE PutB*(addr: INTEGER; data: BYTE);
    VAR x: INTEGER;
  BEGIN
    SYSTEM.PUT(CtrlAdr, addr);
    x := addr MOD 04H;
    SYSTEM.PUT(DataAdr + x, data)
  END PutB;


  PROCEDURE Get*(addr: INTEGER; VAR data: INTEGER);
  BEGIN
    (*REPEAT UNTIL SYSTEM.BIT(CtrlAdr, Ready);*)
    SYSTEM.PUT(CtrlAdr, addr);
    (*REPEAT UNTIL SYSTEM.BIT(CtrlAdr, Ready);*)
    SYSTEM.GET(DataAdr, data)
  END Get;


  PROCEDURE Put2*(data: INTEGER);
  BEGIN
    SYSTEM.PUT(DataAdr, data)
  END Put2;

END SRAMcvsk.
