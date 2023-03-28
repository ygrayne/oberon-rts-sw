(**
  The default console
  * Dev: buffered serial device, but used unbuffered
  * C: Texts.Writer, using busy waiting on each single char write
  --
  2020 - 2022 by Gray, gray@grayraven.org
  https://oberon-rts.org/licences
**)

MODULE ConsoleC;

  IMPORT Texts, RS232dev, RS232b;

  VAR
    C*: Texts.Writer;
    Dev*: RS232dev.Device;

BEGIN
  NEW(Dev); ASSERT(Dev # NIL);
  RS232dev.Init(Dev, RS232dev.Dev0);
  RS232dev.SetCond(Dev, RS232dev.RXNE, RS232dev.TXBE); (* set to non-buffered use *)
  Texts.OpenWriter(C, Dev, RS232b.PutChar)
END ConsoleC.
