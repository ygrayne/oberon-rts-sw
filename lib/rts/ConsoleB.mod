(**
  The default console
  * Dev: Buffered serial device
  * C: Texts.Writer, using busy waiting on buffer full
  --
  2020 - 2022 by Gray, gray@grayraven.org
  https://oberon-rts.org/licences
**)

MODULE ConsoleB;

  IMPORT Texts, RS232dev, RS232b;

  VAR
    C*: Texts.Writer;
    Dev*: RS232dev.Device;

BEGIN
  NEW(Dev); RS232dev.Init(Dev, RS232dev.Dev0); (* default conditions used *)
  Texts.OpenWriter(C, Dev, RS232b.PutChar)
END ConsoleB.
