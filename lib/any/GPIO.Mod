(* =========================================================================
   GPIO - General Purpose Input / Output

   (c) 2019-2021 CFB Software
   https://www.astrobe.com

  Permission to use, copy, modify, and/or distribute this software and its
  accompanying documentation (the "Software") for any purpose with or
  without fee is hereby granted, provided that the above copyright notice
  and this permission notice appear in all copies.

  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHORS DISCLAIM ALL WARRANTIES
  WITH REGARD TO THE SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF
  MERCHANTABILITY, FITNESS AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
  AUTHORS BE LIABLE FOR ANY CLAIM, SPECIAL, DIRECT, INDIRECT, OR
  CONSEQUENTIAL DAMAGES OR ANY DAMAGES OR LIABILITY WHATSOEVER, WHETHER IN
  AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
  CONNECTION WITH THE DEALINGS IN OR USE OR PERFORMANCE OF THE SOFTWARE.
  ========================================================================= *)

(**
  2023-04:
  * add address config from platform module DevAdr
  * add GetOutputs to read current input/output setting
  * remove Input and Output CONSTs
**)

MODULE GPIO;

  IMPORT SYSTEM, DevAdr;

  CONST
    GPIOAdr = DevAdr.GPIOAdr;
    GPOCAdr = GPIOAdr + 4;

  PROCEDURE Reset*(pin: INTEGER);
  VAR
    x: SET;
  BEGIN
    SYSTEM.GET(GPIOAdr, x);
    x := x - {pin};
    SYSTEM.PUT(GPIOAdr, x)
  END Reset;


  PROCEDURE Set*(pin: INTEGER);
  VAR
    x: SET;
  BEGIN
    SYSTEM.GET(GPIOAdr, x);
    x := x + {pin};
    SYSTEM.PUT(GPIOAdr, x)
  END Set;


  PROCEDURE Store*(pins: SET);
  BEGIN
    SYSTEM.PUT(GPIOAdr, pins)
  END Store;


  PROCEDURE Load*(VAR pins: SET);
  BEGIN
    SYSTEM.GET(GPIOAdr, pins)
  END Load;


  PROCEDURE Get*(pin: INTEGER; VAR x: BOOLEAN);
  BEGIN
    x := SYSTEM.BIT(GPIOAdr, pin)
  END Get;


  PROCEDURE SetOutputs*(pins: SET);
  BEGIN
    SYSTEM.PUT(GPOCAdr, pins)
  END SetOutputs;


  PROCEDURE GetOutputs*(VAR pins: SET);
  BEGIN
    SYSTEM.GET(GPOCAdr, pins)
  END GetOutputs;

END GPIO.
