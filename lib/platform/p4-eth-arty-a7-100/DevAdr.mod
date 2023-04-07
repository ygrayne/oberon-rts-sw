(**
  Device IO addresses
  --
  Platform: p4-eth-arty-a7-100
  --
  (c) 2023 Gray gray@grayraven.org
  https://oberon-rts.org/licences
**)

MODULE DevAdr;

  CONST
    (* note: the LSB address is fixed at -60 by the compiler *)

    (* millisecond timer *)
    (* one address *)
    MsTimerAdr* = -64;

    (* logs *)
    (* two addresses *)
    LogDataAdr* = -224;

    (* process periodic timing *)
    (* one address *)
    ProcTimersFixedAdr* = -132;

    (* start tables *)
    (* one address *)
    StartAdr* = -188;

    (* system ctrl register *)
    (* two addresses *)
    SysCtrlRegAdr* = -72;

    (* watchdog *)
    (* one address *)
    WatchdogAdr* = -112;

    (* stack monitor *)
    (* four addresses *)
    StackMonAdr* = -96;

    (* RS232 devices *)
    (* two addresses *)
    RS232dev0DataAdr* = -56;

    (* SPI devices *)
    (* two addresses *)
    SPIdev0DataAdr* = -48;

END DevAdr.
