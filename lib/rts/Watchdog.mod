MODULE Watchdog;
(**
  Watchdog interface
  --
  The watchdog is wired to trigger an asynchronous action, eg. an interrupt or a system reset.
  Times are in system ticks, usually one millisecond.
  --
  2020 - 2023 Gray, gray@grayraven.org
  https://oberon-rts.org/licences
**)

  IMPORT SYSTEM, DevAdr;

  CONST
    Adr = DevAdr.WatchdogAdr;
    Timeout = 100;
    IsEnabled = TRUE;

  VAR
    timeout: INTEGER;

  PROCEDURE Reset*;
  BEGIN
    SYSTEM.PUT(Adr, timeout)
  END Reset;


  PROCEDURE* SetTimeout*(to: INTEGER);
  BEGIN
    timeout := to;
    SYSTEM.PUT(Adr, timeout)
  END SetTimeout;


  PROCEDURE* Stop*;
  BEGIN
    SYSTEM.PUT(Adr, 0)
  END Stop;


  PROCEDURE Enabled*(): BOOLEAN;
  BEGIN
    RETURN IsEnabled
  END Enabled;

BEGIN
  timeout := Timeout
END Watchdog.

