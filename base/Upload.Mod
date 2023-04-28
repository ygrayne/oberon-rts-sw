MODULE Upload;
  (*CFB 12.12.2015 *)
  (*Derived from PCLink NW 25.7.2013 for Oberon on RISC *)
  IMPORT SYSTEM, Files;

  CONST data = -56; stat = -52;
    ACK = 10H;

  PROCEDURE Rec(VAR x: BYTE);
  BEGIN
    REPEAT UNTIL SYSTEM.BIT(stat, 0);
    SYSTEM.GET(data, x)
  END Rec;

  PROCEDURE RecInt(VAR n: INTEGER);
  VAR
    b: BYTE;
    i: INTEGER;
  BEGIN
    n := 0;
    FOR i := 0 TO 3 DO
      Rec(b);
      n := n + LSL(b, 8 * i)
    END
  END RecInt;

  PROCEDURE RecName(VAR s: ARRAY OF CHAR);
    VAR i: INTEGER; x: BYTE;
  BEGIN i := 0; Rec(x);
    WHILE x > 0 DO s[i] := CHR(x); INC(i); Rec(x) END ;
    s[i] := 0X
  END RecName;

  PROCEDURE Send(x: BYTE);
  BEGIN
    REPEAT UNTIL SYSTEM.BIT(stat, 1);
    SYSTEM.PUT(data, x)
  END Send;

  PROCEDURE Run*;
    VAR len, i, fileDate: INTEGER;
      x: BYTE;
      name: ARRAY 32 OF CHAR;
      F: Files.File; R: Files.Rider;
      buf: ARRAY 256 OF BYTE;
  BEGIN
    LED(30H);
    RecName(name);
    RecInt(fileDate);
    F := Files.New(name);
    IF F # NIL THEN
      Files.SetDate(F, fileDate);
      Files.Set(R, F, 0);
      Send(ACK);
      REPEAT Rec(x); len := x; i := 0;
        WHILE i < len DO Rec(x); buf[i] := x; INC(i) END ;
        i := 0;
        WHILE i < len DO Files.WriteByte(R, buf[i]); INC(i) END ;
        Send(ACK)
      UNTIL len < 255;
      Files.Register(F);
      Send(ACK)
    END;
    LED(0)
  END Run;

END Upload.
