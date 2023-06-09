MODULE SRAMde2115;

  IMPORT SYSTEM;

  CONST
    DataAdr = -104;
    AdrAdr = DataAdr + 4;


  PROCEDURE Put*(addr, data: INTEGER);
  BEGIN
    SYSTEM.PUT(AdrAdr, addr);
    SYSTEM.PUT(DataAdr, data)
  END Put;


  PROCEDURE PutB*(addr: INTEGER; data: BYTE);
    VAR x: INTEGER;
  BEGIN
    SYSTEM.PUT(AdrAdr, addr);
    x := addr MOD 04H;
    SYSTEM.PUT(DataAdr + x, data)
  END PutB;


  PROCEDURE Get*(addr: INTEGER; VAR data: INTEGER);
  BEGIN
    SYSTEM.PUT(AdrAdr, addr);
    SYSTEM.GET(DataAdr, data)
  END Get;


  PROCEDURE Put2*(data: INTEGER);
  BEGIN
    SYSTEM.PUT(DataAdr, data)
  END Put2;

END SRAMde2115.
