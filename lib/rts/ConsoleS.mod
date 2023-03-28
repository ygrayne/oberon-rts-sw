(**
  The default console using device signals
  * Dev: buffered serial device
  * C: Texts.Writer, using device signals on buffer full
  --
  2020 - 2022 by Gray, gray@grayraven.org
  https://oberon-rts.org/licences
**)

MODULE ConsoleS;

  IMPORT Texts, RS232dev, RS232sig, DevSignals;

  VAR
    C*: Texts.Writer;
    Dev*: RS232dev.Device;

BEGIN
  NEW(Dev); RS232dev.Init(Dev, RS232dev.Dev0); (* default conditions used, no timeout for dev signals driver *)
  DevSignals.Assign(DevSignals.Dev0, RS232dev.RXBNE, RS232dev.TXBE);
  Texts.OpenWriter(C, Dev, RS232sig.PutChar)
END ConsoleS.
