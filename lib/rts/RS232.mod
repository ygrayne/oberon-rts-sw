(**
  Simple buffered IO via RS232.
  --
  * Reading from empty receive buffer resorts to busy waiting.
  * Writing to full transmit buffer resorts to busy waiting.
  --
  2020 - 2023 Gray, gray@grayraven.org
  https://oberon-rts.org/licences
**)

MODULE RS232;

  IMPORT SYSTEM, Texts, RS232dev;

  (*
  PROCEDURE Reset*(dev: RS232dev.Device);
  BEGIN
    SYSTEM.PUT(dev.statusAdr, RS232dev.RST)
  END Reset;
  *)

  PROCEDURE RxAvailable*(dev: RS232dev.Device): BOOLEAN;
  BEGIN
    RETURN SYSTEM.BIT(dev.statusAdr, RS232dev.RXBNE)
  END RxAvailable;


  PROCEDURE TxAvailable*(dev: RS232dev.Device): BOOLEAN;
  BEGIN
    RETURN SYSTEM.BIT(dev.statusAdr, RS232dev.TXBNF)
  END TxAvailable;


  PROCEDURE GetAvailable*(dev: RS232dev.Device; VAR ch: CHAR): BOOLEAN;
  (* If RETURN is FALSE, 'ch' is not valid. *)
    VAR avail: BOOLEAN;
  BEGIN
    avail := SYSTEM.BIT(dev.statusAdr, RS232dev.RXBNE);
    IF avail THEN
      SYSTEM.GET(dev.dataAdr, ch);
    END
    RETURN avail
  END GetAvailable;


  PROCEDURE TxEmpty*(dev: RS232dev.Device): BOOLEAN;
  BEGIN
    RETURN SYSTEM.BIT(dev.statusAdr, RS232dev.TXBE)
  END TxEmpty;


  PROCEDURE PutByte*(dev: RS232dev.Device; data: BYTE);
  BEGIN
    REPEAT UNTIL SYSTEM.BIT(dev.statusAdr, dev.txCond);
    SYSTEM.PUT(dev.dataAdr, data)
  END PutByte;


  PROCEDURE PutChar*(dev: Texts.TextDevice; ch: CHAR); (* note: TextDevice *)
  BEGIN
    PutByte(dev(RS232dev.Device), ORD(ch))
  END PutChar;


  PROCEDURE PutBytes*(dev: RS232dev.Device; data: ARRAY OF BYTE; n: INTEGER);
    VAR cnt: INTEGER;
  BEGIN
    ASSERT(LEN(data) >= n);
    cnt := 0;
    WHILE cnt < n DO
      IF SYSTEM.BIT(dev.statusAdr, dev.txCond) THEN
        SYSTEM.PUT(dev.dataAdr, data[cnt]); INC(cnt)
      END
    END
  END PutBytes;


  PROCEDURE PutString*(dev: RS232dev.Device; data: ARRAY OF CHAR);
    VAR cnt: INTEGER;
  BEGIN
    cnt := 0;
    WHILE (cnt < LEN(data)) & (data[cnt] # 0X) DO
      IF SYSTEM.BIT(dev.statusAdr, dev.txCond) THEN
        SYSTEM.PUT(dev.dataAdr, data[cnt]); INC(cnt)
      END
    END
  END PutString;

  PROCEDURE PutString2*(dev: Texts.TextDevice; data: ARRAY OF CHAR);
  BEGIN
    PutString(dev(RS232dev.Device), data)
  END PutString2;


  PROCEDURE GetByte*(dev: RS232dev.Device; VAR data: BYTE);
  BEGIN
    REPEAT UNTIL SYSTEM.BIT(dev.statusAdr, dev.rxCond);
    SYSTEM.GET(dev.dataAdr, data)
  END GetByte;

(*
  PROCEDURE GetChar*(dev: RS232dev.Device; VAR ch: CHAR);
  BEGIN
    REPEAT UNTIL SYSTEM.BIT(dev.statusAdr, dev.rxCond);
    SYSTEM.GET(dev.dataAdr, ch)
  END GetChar;
*)

  PROCEDURE GetBytes*(dev: RS232dev.Device; VAR data: ARRAY OF BYTE; n: INTEGER);
    VAR cnt: INTEGER;
  BEGIN
    ASSERT(LEN(data) >= n);
    cnt := 0;
    WHILE cnt < n DO
      IF SYSTEM.BIT(dev.statusAdr, dev.rxCond) THEN
        SYSTEM.GET(dev.dataAdr, data[cnt]); INC(cnt)
      END
    END
  END GetBytes;


  PROCEDURE GetString2*(dev: RS232dev.Device; VAR data: ARRAY OF CHAR; eol: CHAR; VAR cnt: INTEGER);
    VAR done: BOOLEAN; ch: CHAR;
  BEGIN
    cnt := 0; done := FALSE;
    WHILE ~done & (cnt < LEN(data)) DO
      IF SYSTEM.BIT(dev.statusAdr, dev.rxCond) THEN
        SYSTEM.GET(dev.dataAdr, ch);
        done := ch = eol;
        IF ~done & (ch >= " ") THEN
          data[cnt] := ch; INC(cnt)
        END
      END
    END
  END GetString2;

  PROCEDURE GetString*(dev: RS232dev.Device; VAR data: ARRAY OF CHAR; eol: CHAR; six: INTEGER; VAR cnt: INTEGER);
    VAR done: BOOLEAN; ch: CHAR;
  BEGIN
    cnt := six; done := FALSE;
    WHILE ~done & (cnt < LEN(data)) DO
      IF SYSTEM.BIT(dev.statusAdr, dev.rxCond) THEN
        SYSTEM.GET(dev.dataAdr, ch);
        done := ch = eol;
        IF ~done & (ch >= " ") THEN
          data[cnt] := ch; INC(cnt)
        END;
      END
    END
  END GetString;

END RS232.

