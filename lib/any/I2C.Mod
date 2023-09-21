MODULE I2C;
(* =========================================================================
   I2C - Peripheral Interface Driver

   Target: RISC5 Embedded Project Oberon

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
  Gray, 2023-05-27 (search for "gray" for change markers):
  * reduce IO addresses to four
  * clock frequency CONST to be set to the system clock frequency
    to get the correct serial clock freq (was hard-coded to 50 Mhz)
**)

IMPORT SYSTEM;

CONST
  (* Control bits *)
  AA*  = 2;
  SI*  = 3;
  STO* = 4;
  STA* = 5;
  ENA* = 6;

  WRITE = 0;
  READ  = 1;

  (* Result codes *)
  OK*    = 1;
  Error* = 0;
  Empty* = -1;

  (* Status codes *)
  StartTransmit*     = 008H;
  StartRepeat*       = 010H;
  SlaveWriteTxAck*   = 018H;
  SlaveWriteTxNoAck* = 020H;
  DataTxAck*         = 028H;
  DataTxNoAck*       = 030H;
  SlaveReadTxAck*    = 040H;
  SlaveReadTxNoAck*  = 048H;
  MasterRxAck*       = 050H;
  MasterRxNoAck*     = 058H;
  NoInfo*            = 0F8H;

  (* IO addresses *)
  (* gray *)
  I2CConClr = -4;     (* write I2CONCLR *)
  I2CStat   = -4;     (* read status *)
  I2CScl    = -8;     (* write and read I2SCLH and I2SCLL as 32 bits *)
  I2CDat    = -12;    (* write and read data *)
  I2CConSet = -16;    (* write and read I2CONSET *)

  (* gray *)
  ClockFreq = 25000000; (* MHz *)


PROCEDURE GetStatus(VAR status: INTEGER);
BEGIN
  REPEAT UNTIL SYSTEM.BIT(I2CConSet, SI);
  SYSTEM.GET(I2CStat, status)
END GetStatus;


PROCEDURE DoStart(): INTEGER;
VAR
  result, status: INTEGER;
BEGIN
  result := 0;
  WHILE (result = 0) DO
    GetStatus(status);
    IF (status = StartTransmit) OR (status = StartRepeat) THEN
      result := OK
    ELSIF (status # NoInfo) THEN
      result := status
    ELSE
      SYSTEM.PUT(I2CConClr, {SI})
    END
  END;
  SYSTEM.PUT(I2CConClr, {STA});
  RETURN result
END DoStart;


PROCEDURE Start(): INTEGER;
BEGIN
  SYSTEM.PUT(I2CConSet, {STA});
  RETURN DoStart()
END Start;


PROCEDURE RepeatStart(): INTEGER;
BEGIN
  SYSTEM.PUT(I2CConSet, {STA});
  SYSTEM.PUT(I2CConClr, {SI});
  RETURN DoStart()
END RepeatStart;


PROCEDURE Stop();
BEGIN
  SYSTEM.PUT(I2CConSet, {STO});
  SYSTEM.PUT(I2CConClr, {SI});
  WHILE SYSTEM.BIT(I2CConSet, STO) DO END
END Stop;


PROCEDURE SendByte(c: BYTE);
BEGIN
  REPEAT UNTIL SYSTEM.BIT(I2CConSet, SI);
  SYSTEM.PUT(I2CDat, c);
  SYSTEM.PUT(I2CConClr, {SI})
END SendByte;


PROCEDURE ReceiveByte(VAR b: BYTE);
BEGIN
  REPEAT UNTIL SYSTEM.BIT(I2CConSet, SI);
  SYSTEM.GET(I2CDat, b)
END ReceiveByte;


PROCEDURE GenAck0;
BEGIN
  SYSTEM.PUT(I2CConSet, {AA});
  SYSTEM.PUT(I2CConClr, {SI})
END GenAck0;


PROCEDURE GenAck1;
BEGIN
  SYSTEM.PUT(I2CConClr, {AA});
  SYSTEM.PUT(I2CConClr, {SI})
END GenAck1;


PROCEDURE Wait(): INTEGER;
VAR
  result, status: INTEGER;
BEGIN
  result := Error;
  REPEAT
    GetStatus(status);
    IF (status = SlaveWriteTxAck) OR (status = DataTxAck) THEN
      result := OK
    END;
  UNTIL status # NoInfo
  RETURN result
END Wait;


PROCEDURE SendAddress(addr: BYTE; rw: INTEGER);
VAR
  result: INTEGER;
BEGIN
  addr := LSL(addr, 1) + rw;
  SendByte(addr);
  result := Wait()
END SendAddress;


PROCEDURE Ready*(addr: BYTE): INTEGER;
VAR
  result, status: INTEGER;
  ready: BOOLEAN;
BEGIN
  ASSERT(addr <= 07FH);
  (* Writing: the LSB (R/W) bit is zero *)
  addr := LSL(addr, 1);
  ready := FALSE;
  result := OK;
  WHILE ~ready DO
    result := Start();
    IF result = OK THEN
      SendByte(addr);
      GetStatus(status);
      IF status = SlaveWriteTxAck THEN
        ready := TRUE
      ELSIF status = SlaveWriteTxNoAck THEN
        ready := FALSE
      ELSIF status # NoInfo THEN
        result := Error;
        ready := TRUE
      END
    END;
    Stop()
  END;
  RETURN result
END Ready;


PROCEDURE WriteBytes(data: ARRAY OF BYTE): INTEGER;
VAR
  i, result: INTEGER;
BEGIN
  result := OK;
  i := 0;
  WHILE (i < LEN(data)) & (result = OK) DO
    SendByte(data[i]);
    result := Wait();
    INC(i)
  END
  RETURN result
END WriteBytes;


PROCEDURE Write*(addr: BYTE; data: ARRAY OF BYTE);
VAR
  result: INTEGER;
BEGIN
  result := Start();
  IF result = OK THEN
    SendAddress(addr, WRITE);
    result := WriteBytes(data)
  END;
  Stop()
END Write;


PROCEDURE WriteByte*(addr, b: BYTE);
VAR
  result: INTEGER;
BEGIN
  result := Start();
  IF result = OK THEN
    SendAddress(addr, WRITE);
    SendByte(b);
    result := Wait()
  END;
  Stop()
END WriteByte;


PROCEDURE ReadNextByte(VAR b: BYTE; lastByte: BOOLEAN): INTEGER;
VAR
  status, result: INTEGER;
BEGIN
  result := Empty;
  WHILE (result = Empty) DO
    GetStatus(status);
    IF (status = SlaveReadTxAck) OR (status = SlaveReadTxNoAck) OR (status = MasterRxAck) THEN
      IF lastByte THEN
        GenAck1()
      ELSE
        GenAck0()
      END;
      ReceiveByte(b);
      result := OK
    ELSIF (status # NoInfo) THEN
      result := Error
    END
  END;
  RETURN result
END ReadNextByte;


PROCEDURE Read*(addr: BYTE; VAR data: ARRAY OF BYTE);
VAR
  result, i, limit: INTEGER;
  lastByte: BOOLEAN;
BEGIN
  result := RepeatStart();
  IF result = OK THEN
    SendAddress(addr, READ)
  END;
  limit := LEN(data);
  i := 0;
  WHILE (i < limit) & (result = OK) DO
    lastByte := (i = limit - 1);
    result := ReadNextByte(data[i], lastByte);
    INC(i)
  END;
  Stop()
END Read;


PROCEDURE ReadByte*(addr: BYTE; VAR b: BYTE);
VAR
  result: INTEGER;
BEGIN
  result := RepeatStart();
  IF result = OK THEN
    SendAddress(addr, READ)
  END;
  result := ReadNextByte(b, TRUE);
  Stop()
END ReadByte;


PROCEDURE Init*(freq: INTEGER);
VAR
  scl, sclh, scll: INTEGER;
BEGIN

  (* Clear flags *)
  SYSTEM.PUT(I2CConClr, {AA, SI, STA, ENA});

  (* Set the data rate and duty cycle *)
  (* gray *)
  scl := ClockFreq DIV freq;    (* serial clock period length *)
  sclh := (scl + 1) DIV 2;      (* "high" half-period length *)
  scll := scl DIV 2;            (* "low" half-period length *)
  SYSTEM.PUT(I2CScl, LSL(sclh, 16) + scll);

  (* Enable I2C *)
  SYSTEM.PUT(I2CConSet, {ENA})
END Init;

END I2C.
