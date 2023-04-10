(**
  LSB driver
  --
  Board: DE2-115
  --
  Works with Arty A7-100 for the overlapping functionality:
  * system leds (the green LEDs on DE2-115)
  * four board LEDs (the first four red LEDs on DE2-115)
  * four switches (the first four switches on DE2-115)
  * four buttons (same as DE2-115)
  --
  * Only red LEDs operated here, green ones are operated with procedure LED()
  * No 7-segment display yet
  * Button and switches missing
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
    displayNum(0, 4, base, value)
  END DisplayNum4;


  PROCEDURE DisplayNum2Right*(base, value:INTEGER);
  BEGIN
    displayNum(4, 2, base, value)
  END DisplayNum2Right;


  PROCEDURE DisplayNum2Left*(base, value:INTEGER);
  BEGIN
    displayNum(6, 2, base, value)
  END DisplayNum2Left;

END LSB.
