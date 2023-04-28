MODULE RTC;
(* =========================================================================
   RTC - Maxim DS3234 Real-Time Clock SPI Driver

   Target: RISC5 Embedded Project Oberon

   (c) 2017-2021 CFB Software
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

IMPORT Kernel, SPI;

CONST
  (* DS3234 Address Registers *)
  TimeAdr* = 00H;
  DateAdr* = 04H;
  Alarm1Adr* = 07H;
  Alarm2Adr* = 0BH;
  ControlAdr* = 0EH;
  StatusAdr* = 0FH;
  CrystalAdr* = 10H;
  TempAdr* = 11H;
  SRAMAdr* = 18H;
  SRAMDataAdr* = 19H;

  SPI1    = {1};
  SPINone = {};
  SPIFast = {3};

PROCEDURE BCDToByte(bcd: BYTE): BYTE;
BEGIN
  RETURN (bcd DIV 16) * 10 + (bcd MOD 16)
END BCDToByte;


PROCEDURE ByteToBCD(b: BYTE): BYTE;
BEGIN
  RETURN (b DIV 10) * 16 + (b MOD 10)
END ByteToBCD;


PROCEDURE ReadReg*(adr: BYTE; VAR r: BYTE);
BEGIN
  SPI.Select(SPI1 + SPIFast);
  SPI.SendByte(adr);
  SPI.ReceiveByte(r);
  SPI.Select(SPINone)
END ReadReg;


PROCEDURE WriteReg*(adr: BYTE; r: BYTE);
BEGIN
  SPI.Select(SPI1 + SPIFast);
  SPI.SendByte(adr + 80H);
  SPI.SendByte(r);
  SPI.Select(SPINone)
END WriteReg;


PROCEDURE ReadRegs*(adr: BYTE; VAR r: ARRAY OF BYTE);
BEGIN
  SPI.Select(SPI1 + SPIFast);
  SPI.SendByte(adr);
  SPI.Receive(r);
  SPI.Select(SPINone)
END ReadRegs;


PROCEDURE WriteRegs*(adr: BYTE; r: ARRAY OF BYTE);
BEGIN
  SPI.Select(SPI1 + SPIFast);
  SPI.SendByte(adr + 80H);
  SPI.Send(r);
  SPI.Select(SPINone)
END WriteRegs;


PROCEDURE GetHMS*(VAR hrs, mins, secs: INTEGER);
VAR
  r: ARRAY 3 OF BYTE;
BEGIN
  ReadRegs(TimeAdr, r);
  secs := BCDToByte(r[0]);
  mins := BCDToByte(r[1]);
  hrs  := BCDToByte(r[2])
END GetHMS;


PROCEDURE SetHMS*(hrs, mins, secs: INTEGER);
VAR
  r: ARRAY 3 OF BYTE;
BEGIN
  r[0] := ByteToBCD(secs);
  r[1] := ByteToBCD(mins);
  r[2] := ByteToBCD(hrs);
  WriteRegs(TimeAdr, r)
END SetHMS;


PROCEDURE GetDMY*(VAR dd, mm, yy: INTEGER);
VAR
  r: ARRAY 3 OF BYTE;
BEGIN
  ReadRegs(DateAdr, r);
  dd   := BCDToByte(r[0]);
  mm   := BCDToByte(r[1]);
  yy   := BCDToByte(r[2])
END GetDMY;


PROCEDURE SetDMY*(dd, mm, yy: INTEGER);
VAR
  r: ARRAY 3 OF BYTE;
BEGIN
  r[0] := ByteToBCD(dd);
  r[1] := ByteToBCD(mm);
  r[2] := ByteToBCD(yy);
  WriteRegs(DateAdr, r)
END SetDMY;


PROCEDURE SetClock*(dt: INTEGER);
VAR
  dd, mm, yy, hrs, mins, secs: BYTE;
  r: ARRAY 7 OF BYTE;
BEGIN
  secs := BFX(dt, 5, 0);
  mins := BFX(dt, 11, 6);
  hrs  := BFX(dt, 16, 12);
  dd   := BFX(dt, 21, 17);
  mm   := BFX(dt, 25, 22);
  yy   := BFX(dt, 31, 26);
  r[0] := ByteToBCD(secs);
  r[1] := ByteToBCD(mins);
  r[2] := ByteToBCD(hrs);
  r[3] := 1;
  r[4] := ByteToBCD(dd);
  r[5] := ByteToBCD(mm);
  r[6] := ByteToBCD(yy);
  WriteRegs(TimeAdr, r)
END SetClock;


PROCEDURE Clock*(): INTEGER;
VAR
  dd, mm, yy, hrs, mins, secs: BYTE;
  r: ARRAY 7 OF BYTE;
  dt: INTEGER;
BEGIN
  ReadRegs(TimeAdr, r);
  secs := BCDToByte(r[0]);
  mins := BCDToByte(r[1]);
  hrs  := BCDToByte(r[2]);
  dd   := BCDToByte(r[4]);
  mm   := BCDToByte(r[5]);
  yy   := BCDToByte(r[6]);
  dt := secs;
  BFI(dt, 11,  6, mins);
  BFI(dt, 16, 12, hrs);
  BFI(dt, 21, 17, dd);
  BFI(dt, 25, 22, mm);
  BFI(dt, 31, 26, yy);
  RETURN dt
END Clock;


PROCEDURE Active(): BOOLEAN;
(* If the RTC is active, the seconds counter should
   tick over in less than 1010 ticks (msecs)
*)
VAR
  hh, mm, ss, nextSecond, ticks0, ticks1: INTEGER;
  ok: BOOLEAN;
BEGIN
  GetHMS(hh, mm, ss);
  nextSecond := (ss + 1) MOD 60;
  ticks0 := Kernel.Time();
  REPEAT
    ticks1 := Kernel.Time();
    GetHMS(hh, mm, ss);
    ok := (ss = nextSecond)
  UNTIL ok OR ((ticks1 - ticks0) > 1010)
  RETURN ok
END Active;


PROCEDURE Install*();
BEGIN
  IF Active() THEN
    Kernel.InstallClock(Clock);
    Kernel.InstallSetClock(SetClock)
  END
END Install;

BEGIN
  SPI.Select(SPINone);
END RTC.
