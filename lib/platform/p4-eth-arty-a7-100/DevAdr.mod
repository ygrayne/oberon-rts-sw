(**
  IO device configurations
  --
  Platform: p4-eth-arty-a7-100
  --
  2023 Gray gray@grayraven.org
  https://oberon-rts.org/licences
**)

MODULE DevAdr;

  CONST
    (* note: the LSB address is fixed at -60 by the compiler *)

    (* millisecond timer *)
    MsTimerAdr* = -64;

    (* logs *)
    LogDataAdr* = -224;
    LogIndexAdr* = -220;

    (* process periodic timing *)
    ProcTimersFixedAdr* = -132;

    (* start tables *)
    StartAdr* = -188;

    (* system ctrl register *)
    SysCtrlRegAdr* = -68;

    (* watchdog *)
    WatchdogAdr* = -112;

    (* RS232 devices *)
    RS232dev0DataAdr* = -56;
    RS232dev0StatusAdr* = -52;

    (* SPI devices *)
    SPIdev0DataAdr* = -48;
    SPIdev0StatusAdr* = -44;

END DevAdr.
