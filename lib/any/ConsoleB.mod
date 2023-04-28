(**
  The default console
  * Dev: Buffered serial device
  * C: Texts.Writer, using busy waiting on buffer full
  --
  2020 - 2022 by Gray, gray@grayraven.org
  https://oberon-rts.org/licences
**)

MODULE ConsoleB;

  IMPORT Texts, RS232dev, RS232;

  VAR
    C*: Texts.Writer;
    Dev*: RS232dev.Device;

BEGIN
  NEW(Dev); ASSERT(Dev # NIL);
  RS232dev.Init(Dev, RS232dev.Dev0);
  RS232dev.SetCond(Dev, RS232dev.RXBNE, RS232dev.TXBNF); (* set to buffered use *)
  Texts.OpenWriter(C, Dev, RS232.PutChar)
END ConsoleB.
