(**
  LSB driver
  --
  Boards: DE2-115 (full functionality), and CV-SK, Arty A7-100 (reduced functionality)
  --
  Only red LEDs operated here, green ones are operated with procedure LED()
  --
  Using non-existing features on any board are simply no-ops.
  --
  * With Art A7-100:
    * eight system LEDs are wired to a Pmod card with eight LEDs
    * four green LEDs => first four red LEDs on the other boards
    * four switches => first four switches
    * four buttons => same as the other boards
    * no seven segment displays
  * With CV-SK:
    * eight green system LEDs => as DE2-115
    * ten switches => first ten switches of DE-115
    * four buttons => as DE2-115
    * seven segment displays:
      * two two-digit displays, or
      * one four-digit display
  --
  2020 - 2023 Gray, gray@grayraven.org
  https://oberon-rts.org/licences
**)

MODULE LSB;

  IMPORT SYSTEM, DevAdr;

  CONST
    IOadr = DevAdr.LsbAdr;

    Displays = {0 .. 7};
    Values = {0 .. 15};

    (* [31:30] *)
    RedLedsOn  = 080000000H;
    RedLedsOff = 040000000H;

    (* [29:26] *)
    DispBaseCtrl =  020000000H;
    DispStep = 004000000H;

    Unknown* = 0;
    ArtyA7100* = 1;
    DE2115* = 2;
    CVSK* = 3;

  VAR
    board: INTEGER;
    fourDigit0: INTEGER;
    twoDigit0: INTEGER;
    twoDigit1: INTEGER;


  (* toggle mechanism: set bits in 'leds' turn on, unset bits don't matter *)
  PROCEDURE SetRedLedsOn*(leds: SET);
  BEGIN
    SYSTEM.PUT(IOadr, RedLedsOn + LSL(ORD(leds), 8))
  END SetRedLedsOn;


  (* toggle mechanism: set bits in 'leds' turn off, unset bits don't matter *)
  PROCEDURE SetRedLedsOff*(leds: SET);
  BEGIN
    SYSTEM.PUT(IOadr, RedLedsOff + LSL(ORD(leds), 8))
  END SetRedLedsOff;


  (* single 7 segment displays, disp = 0 is the rightmost one *)
  PROCEDURE DisplayDigit*(disp, value: INTEGER);
  BEGIN
    ASSERT(disp IN Displays);
    ASSERT(value IN Values);
    SYSTEM.PUT(IOadr, (DispBaseCtrl + (disp * DispStep)) + LSL(value, 8))
  END DisplayDigit;


  (* display numbers across several displays *)
  PROCEDURE displayNum(firstDisp, numDisp, base, value: INTEGER);
    VAR x, i: INTEGER;
  BEGIN
    i := 0;
    REPEAT
      x := value MOD base;
      DisplayDigit(firstDisp + i, x);
      value := value DIV base; INC(i)
    UNTIL i = numDisp
  END displayNum;


  PROCEDURE DisplayNum4*(base, value:INTEGER);
  BEGIN
    displayNum(fourDigit0, 4, base, value)
  END DisplayNum4;


  PROCEDURE DisplayNum2Right*(base, value:INTEGER);
  BEGIN
    displayNum(twoDigit0, 2, base, value)
  END DisplayNum2Right;


  PROCEDURE DisplayNum2Left*(base, value:INTEGER);
  BEGIN
    displayNum(twoDigit1, 2, base, value)
  END DisplayNum2Left;


  PROCEDURE GetBoard*(VAR board: INTEGER);
  BEGIN
    SYSTEM.GET(IOadr, board);
    board := BFX(board, 31, 28);
  END GetBoard;

BEGIN
  GetBoard(board);
  IF board = DE2115 THEN
    fourDigit0 := 0; twoDigit0 := 4; twoDigit1 := 6
  ELSIF board = CVSK THEN
    fourDigit0 := 0; twoDigit0 := 0; twoDigit1 := 2
  ELSE
    fourDigit0 := 0; twoDigit0 := 0; twoDigit1 := 0
  END
END LSB.
