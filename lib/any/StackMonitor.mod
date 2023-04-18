(**
  Stack monitor driver
  --
  (c) 2020 - 2023 Gray gray@grayraven.org
  https://oberon-rts.org/licences
**)

MODULE StackMonitor;

  IMPORT SYSTEM, DevAdr;

  CONST
    BaseAdr = DevAdr.StackMonAdr;
    StackLimitAdr = BaseAdr;
    HotZoneAdr = BaseAdr + 4;
    MinValueAdr = BaseAdr + 8;
    CorNumAdr = BaseAdr + 12;

    IsEnabled = TRUE;


  PROCEDURE ResetMin*(top: INTEGER);
  BEGIN
    SYSTEM.PUT(MinValueAdr, top)
  END ResetMin;


  PROCEDURE GetMin*(VAR max: INTEGER);
  BEGIN
    SYSTEM.GET(MinValueAdr, max)
  END GetMin;


  PROCEDURE Disarm*(VAR stackAdr, hotAdr, stackMin: INTEGER);
  BEGIN
    SYSTEM.GET(StackLimitAdr, stackAdr);
    SYSTEM.GET(HotZoneAdr, hotAdr);
    SYSTEM.GET(MinValueAdr, stackMin);

    SYSTEM.PUT(StackLimitAdr, 0); (* set the limits to the bottom of the RAM, hence no stack overflow detection *)
    SYSTEM.PUT(HotZoneAdr, 0)
  END Disarm;


  PROCEDURE Arm*(stackAdr, hotAdr, stackMin: INTEGER);
  BEGIN
    SYSTEM.PUT(StackLimitAdr, stackAdr);
    SYSTEM.PUT(HotZoneAdr, hotAdr);
    SYSTEM.PUT(MinValueAdr, stackMin)
  END Arm;


  PROCEDURE Enabled*(): BOOLEAN;
  BEGIN
    RETURN IsEnabled
  END Enabled;

END StackMonitor.
