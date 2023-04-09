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
    RedLedsOn = 080000000H;


  (* toggle mechanism: set bits in 'leds' turn on, unset bits don't matter *)
  PROCEDURE SetRedLedsOn*(leds: SET);
  BEGIN
    SYSTEM.PUT(IOadr, RedLedsOn + LSL(ORD(leds), 8))
  END SetRedLedsOn;

  (* toggle mechanism: set bits in 'leds' turn off, unset bits don't matter *)
  PROCEDURE SetRedLedsOff*(leds: SET);
  BEGIN
    SYSTEM.PUT(IOadr, LSL(ORD(leds), 8))
  END SetRedLedsOff;

END LSB.
