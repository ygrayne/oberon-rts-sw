MODULE Texts; (*JG 21.11.90 / NW 11.7.90 / 24.12.95 / 22.11.10 / 20.3.2017*)
              (*CB 01.08.2017*)

  IMPORT SYSTEM;

  CONST (*scanner symbol classes*)
    Inval* = 0;         (*invalid symbol*)
    Name* = 1;          (*name s (length len)*)
    String* = 2;        (*literal string s (length len)*)
    Int* = 3;           (*integer i (decimal or hexadecimal)*)
    Real* = 4;          (*real number x*)
    Char* = 6;          (*special character c*)

    TAB = 9X; LF = 0AX;

  TYPE
    Text* = POINTER TO TextDesc;
    TextDesc* = RECORD
      len*: LONGINT;
      pos*: INTEGER;
      string*: ARRAY 256 OF CHAR;
    END;

    Scanner* = RECORD (TextDesc)
      nextCh*: CHAR;
      line*, class*: INTEGER;
      i*: LONGINT;
      x*: REAL;
      y*: LONGREAL;
      c*: CHAR;
      s*: ARRAY 32 OF CHAR;
    END;

    Writer* = RECORD buf*: ARRAY 2 OF CHAR END;

  (* ------------------ Access: Scanners (NW) ------------------------- *)

  PROCEDURE Read*(VAR S: Scanner; VAR ch: CHAR);
  BEGIN
    ch := S.string[S.pos];
    IF ch # 0X THEN INC(S.pos) END
  END Read;

  PROCEDURE SkipBlanks(VAR S: Scanner);
  BEGIN
    WHILE S.string[S.pos] = " " DO INC(S.pos) END
  END SkipBlanks;

  PROCEDURE OpenScanner* (VAR S: Scanner; T: Text; pos: LONGINT);
  VAR
    ch: CHAR;
  BEGIN
    S.string := T.string; S.line := 0; S.nextCh := " "; S.pos := 0;
    SkipBlanks(S);
    (* Skip module.command *)
    REPEAT Read(S, ch) UNTIL (ch = " ") OR (ch = 0X);
    S.nextCh := ch
  END OpenScanner;


  (*floating point formats:
    x = 1.m * 2^(e-127)   bit 0: sign, bits 1- 8: e, bits  9-31: m
    x = 1.m * 2^(e-1023)  bit 0: sign, bits 1-11: e, bits 12-63: m *)

  PROCEDURE Ten(n: INTEGER): REAL;
    VAR t, p: REAL;
  BEGIN t := 1.0; p := 10.0;   (*compute 10^n *)
    WHILE n > 0 DO
      IF ODD(n) THEN t := p * t END ;
      p := p*p; n := n DIV 2
    END ;
    RETURN t
  END Ten;

  PROCEDURE Scan* (VAR S: Scanner);
    CONST maxExp = 38; maxM = 16777216; (*2^24*)
    VAR ch: CHAR;
      neg, negE, hex: BOOLEAN;
      i, j, h, d, e, n, s: INTEGER;
      x: REAL;
  BEGIN ch := S.nextCh; i := 0;
    WHILE (ch = " ") OR (ch = TAB) DO
      Read(S, ch)
    END ;
    IF ("A" <= ch) & (ch <= "Z") OR ("a" <= ch) & (ch <= "z") THEN (*name*)
      REPEAT S.s[i] := ch; INC(i); Read(S, ch)
      UNTIL ((ch < "0") & (ch # ".") OR ("9" < ch) & (ch < "A") OR ("Z" < ch) & (ch < "a") OR ("z" < ch)) OR (i = 31);
      S.s[i] := 0X; S.len := i; S.class := Name
    ELSIF ch = 22X THEN (*string*)
      Read(S, ch);
      WHILE (ch # 22X) & (ch >= " ") & (i # 31) DO S.s[i] := ch; INC(i); Read(S, ch) END;
      S.s[i] := 0X; S.len := i+1; Read(S, ch); S.class := String
    ELSE hex := FALSE;
      IF ch = "-" THEN neg := TRUE; Read(S, ch) ELSE neg := FALSE END ;
      IF ("0" <= ch) & (ch <= "9") THEN (*number*)
        n := ORD(ch) - 30H; h := n; Read(S, ch);
        WHILE ("0" <= ch) & (ch <= "9") OR ("A" <= ch) & (ch <= "F") DO
          IF ch <= "9" THEN d := ORD(ch) - 30H ELSE d := ORD(ch) - 37H; hex := TRUE END ;
          n := 10*n + d; h := 10H*h + d; Read(S, ch)
        END ;
        IF ch = "H" THEN (*hex integer*) Read(S, ch); S.i := h; S.class := Int  (*neg?*)
        ELSIF ch = "." THEN (*real number*)
          Read(S, ch); x := 0.0; e := 0; j := 0;
          WHILE ("0" <= ch) & (ch <= "9") DO  (*fraction*)
            h := 10*n + (ORD(ch) - 30H);
            IF h < maxM THEN n := h; INC(j) END ;
            Read(S, ch)
          END ;
          IF ch = "E" THEN (*scale factor*)
            s := 0; Read(S, ch);
            IF ch = "-" THEN negE := TRUE; Read(S, ch)
            ELSE negE := FALSE;
              IF ch = "+" THEN Read(S, ch) END
            END ;
            WHILE ("0" <= ch) & (ch <= "9") DO
              s := s*10 + ORD(ch) - 30H; Read(S, ch)
            END ;
            IF negE THEN DEC(e, s) ELSE INC(e, s) END ;
          END ;
          x := FLT(n); DEC(e, j);
          IF e < 0 THEN
            IF e >= -maxExp THEN x := x / Ten(-e) ELSE x := 0.0 END
          ELSIF e > 0 THEN
            IF e <= maxExp THEN x := Ten(e) * x ELSE x := 0.0 END
          END ;
          IF neg THEN S.x := -x ELSE S.x := x END ;
          IF hex THEN S.class := 0 ELSE S.class := Real END
        ELSE (*decimal integer*)
          IF neg THEN S.i := -n ELSE S.i := n END;
          IF hex THEN S.class := Inval ELSE S.class := Int END
        END
      ELSE (*spectal character*) S.class := Char;
        IF neg THEN S.c := "-" ELSE S.c := ch; Read(S, ch) END
      END
    END ;
    S.nextCh := ch
  END Scan;

  PROCEDURE Write* (VAR W: Writer; ch: CHAR);
  CONST
    data = -56; stat = -52;
  BEGIN
    REPEAT UNTIL SYSTEM.BIT(stat, 1);
    SYSTEM.PUT(data, ORD(ch))
  END Write;

  PROCEDURE WriteLn* (VAR W: Writer);
  BEGIN Write(W, LF)
  END WriteLn;

  PROCEDURE WriteString* (VAR W: Writer; s: ARRAY OF CHAR);
    VAR i: INTEGER;
  BEGIN i := 0;
    WHILE s[i] >= " " DO Write(W, s[i]); INC(i) END
  END WriteString;

  PROCEDURE WriteInt* (VAR W: Writer; x, n: LONGINT);
    VAR i: INTEGER; x0: LONGINT;
      a: ARRAY 10 OF CHAR;
  BEGIN
    IF ROR(x, 31) = 1 THEN WriteString(W, " -2147483648")
    ELSE i := 0;
      IF x < 0 THEN DEC(n); x0 := -x ELSE x0 := x END;
      REPEAT
        a[i] := CHR(x0 MOD 10 + 30H); x0 := x0 DIV 10; INC(i)
      UNTIL x0 = 0;
      WHILE n > i DO Write(W, " "); DEC(n) END;
      IF x < 0 THEN Write(W, "-") END;
      REPEAT DEC(i); Write(W, a[i]) UNTIL i = 0
    END
  END WriteInt;

  PROCEDURE WriteHex* (VAR W: Writer; x: LONGINT);
    VAR i: INTEGER; y: LONGINT;
      a: ARRAY 10 OF CHAR;
  BEGIN i := 0; Write(W, " ");
    REPEAT y := x MOD 10H;
      IF y < 10 THEN a[i] := CHR(y + 30H) ELSE a[i] := CHR(y + 37H) END;
      x := x DIV 10H; INC(i)
    UNTIL i = 8;
    REPEAT DEC(i); Write(W, a[i]) UNTIL i = 0
  END WriteHex;

 PROCEDURE WriteReal* (VAR W: Writer; x: REAL; n: INTEGER);
    VAR e, i, m: INTEGER;
      d: ARRAY 16 OF CHAR;
  BEGIN e := ASR(SYSTEM.VAL(INTEGER,x), 23) MOD 100H;  (*binary exponent*)
    IF e = 0 THEN
      WriteString(W, "  0 ");
      WHILE n >= 3 DO Write(W, " "); DEC(n) END
    ELSIF e = 255 THEN WriteString(W, " NaN ")
    ELSE Write(W, " ");
      WHILE n >= 15 DO DEC(n); Write(W, " ") END ;
      (* 2 < n < 9 digits to be written*)
      IF x < 0.0 THEN Write(W, "-"); x := -x ELSE Write(W, " ") END ;
      e := (e - 127) * 77 DIV 256 - 6;  (*decimal exponent*)
      IF e >= 0 THEN x := x / Ten(e) ELSE x := Ten(-e) * x END ;
      m := FLOOR(x + 0.5); i := 0;
      IF m >= 10000000 THEN INC(e); m := m DIV 10 END ;
      REPEAT d[i] := CHR(m MOD 10 + 30H); m := m DIV 10; INC(i) UNTIL m = 0;
      DEC(i); Write(W, d[i]); Write(W, ".");
      IF i < n-7 THEN n := 0 ELSE n := 14 - n END ;
      WHILE i > n DO DEC(i); Write(W, d[i]) END ;
      Write(W, "E"); INC(e, 6);
       IF e < 0 THEN Write(W, "-"); e := -e ELSE Write(W, "+") END ;
      Write(W, CHR(e DIV 10 + 30H)); Write(W, CHR(e MOD 10 + 30H))
    END
  END WriteReal;

  PROCEDURE WriteRealFix* (VAR W: Writer; x: REAL; n, k: INTEGER);
    VAR i, m: INTEGER; neg: BOOLEAN;
      d: ARRAY 12 OF CHAR;
  BEGIN
    IF x = 0.0 THEN WriteString(W, "  0")
    ELSE
      IF x < 0.0 THEN x := -x; neg := TRUE ELSE neg := FALSE END ;
      IF k > 7 THEN k := 7 END ;
      x := Ten(k) * x; m := FLOOR(x + 0.5);
      i := 0;
      REPEAT d[i] := CHR(m MOD 10 + 30H); m := m DIV 10; INC(i) UNTIL m = 0;
      Write(W, " ");
      WHILE n > i+3 DO  Write(W, " "); DEC(n) END ;
      IF neg THEN Write(W, "-"); DEC(n) ELSE Write(W, " ") END ;
      WHILE i > k DO DEC(i); Write(W, d[i]) END ;
      Write(W, ".");
      WHILE k > i DO DEC(k); Write(W, "0") END ;
      WHILE i > 0 DO DEC(i); Write(W, d[i]) END
    END
  END WriteRealFix;

  PROCEDURE WritePair(VAR W: Writer; ch: CHAR; x: LONGINT);
  BEGIN Write(W, ch);
    Write(W, CHR(x DIV 10 + 30H)); Write(W, CHR(x MOD 10 + 30H))
  END WritePair;

  PROCEDURE WriteClock* (VAR W: Writer; d: LONGINT);
  BEGIN
    WritePair(W, " ", d DIV 20000H MOD 20H);   (*day*)
    WritePair(W, ".", d DIV 400000H MOD 10H); (*month*)
    WritePair(W, ".", d DIV 4000000H MOD 40H);   (*year*)
    WritePair(W, " ", d DIV 1000H MOD 20H);   (*hour*)
    WritePair(W, ":", d DIV 40H MOD 40H);  (*min*)
    WritePair(W, ":", d MOD 40H)  (*sec*)
  END WriteClock;
END Texts.
