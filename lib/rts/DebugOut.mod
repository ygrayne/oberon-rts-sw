(**
  Very simple diagnostic output to RS232 device
  --
  Can be also used in Inner Core to in case of boot issues.
  --
  2023 by Gray, gray@grayraven.org
  https://oberon-rts.org/licences
**)

MODULE DebugOut;

  IMPORT SYSTEM;

  CONST
    (* RS232 dev 0 for diagnostic output via writeLine *)
    RS232DataAdr = -56; RS232StatusAdr = -52; TXBE = 1; LF = 0AX;
    (* switch to toggle diagnostic output *)
    SwiAdr = -60; CheckSwitchBit = 0;

  PROCEDURE switchOn(): BOOLEAN;
    RETURN SYSTEM.BIT(SwiAdr, CheckSwitchBit)
  END switchOn;


  PROCEDURE WriteString*(str: ARRAY OF CHAR);
    VAR cnt: INTEGER;
  BEGIN
    cnt := 0;
    WHILE (cnt < LEN(str)) & (str[cnt] # 0X) DO
      IF SYSTEM.BIT(RS232StatusAdr, TXBE) THEN
        SYSTEM.PUT(RS232DataAdr, str[cnt]); INC(cnt)
      END
    END
  END WriteString;


  PROCEDURE WriteChar*(ch: CHAR);
  BEGIN
    REPEAT UNTIL SYSTEM.BIT(RS232StatusAdr, TXBE);
    SYSTEM.PUT(RS232DataAdr, ch)
  END WriteChar;


  PROCEDURE WriteHex* (x: INTEGER);
    VAR i, y: INTEGER; a: ARRAY 10 OF CHAR;
  BEGIN
    i := 0;
    REPEAT
      y := x MOD 10H;
      IF y < 10 THEN a[i] := CHR(y + ORD("0")) ELSE a[i] := CHR(y + 37H) END;
      x := x DIV 10H; INC(i)
    UNTIL i = 8;
    REPEAT DEC(i); WriteChar(a[i]) UNTIL i = 0
  END WriteHex;


  PROCEDURE WriteLine*(s0, s1, s2: ARRAY OF CHAR; x: INTEGER);
  BEGIN
    IF switchOn() THEN
      WriteString(s0);
      WriteChar(" ");
      WriteString(s1);
      WriteChar(" ");
      WriteString(s2);
      IF x > -1 THEN
        WriteChar(" "); WriteHex(x)
      END;
      WriteChar(LF)
    END
  END WriteLine;

END DebugOut.
