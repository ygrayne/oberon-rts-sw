(**
  Device IO addresses
  --
  Platform: ANY
  --
  (c) 2023 Gray gray@grayraven.org
  https://oberon-rts.org/licences
**)

MODULE DevAdr;

  CONST
    (* LSB -- leds, switches, buttons *)
    (* one address *)
    (* note: fixed in the compiler for LED procedure *)
    LsbAdr* = -60;

    (* millisecond timer *)
    (* one address *)
    MsTimerAdr* = -64;

    (* logs *)
    (* two addresses *)
    LogDataAdr* = -224;

    (* calltrace *)
    (* two addresses *)
    CalltraceDataAdr* = -80;

    (* process periodic timing *)
    (* one address *)
    ProcTimersFixedAdr* = -132;

    (* start tables *)
    (* one address *)
    StartAdr* = -188;

    (* system ctrl and status register *)
    (* two addresses *)
    (* adapt BootLoad.mod if you change this *)
    SysCtrlRegAdr* = -72;

    (* watchdog *)
    (* one address *)
    (* adapt BootLoad.mod if you change this *)
    WatchdogAdr* = -112;

    (* stack monitor *)
    (* four addresses *)
    (* adapt BootLoad.mod if you change this *)
    StackMonAdr* = -96;

    (* RS232 devices *)
    (* two addresses *)
    RS232dev0DataAdr* = -56;

    (* SPI devices *)
    (* two addresses *)
    SPIdev0DataAdr* = -48;

    (* GPIO *)
    (* two addresses *)
    GPIOAdr* = -32;

END DevAdr.
