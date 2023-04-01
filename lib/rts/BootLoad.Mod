MODULE* BootLoad;
  (* NW 20.10.2013 / PR 4.2.2014 *)
  (* CFB 02.09.2015 Boot from SDHC disk only*)
  (* CFB 30.04.2018 Artix-7 XC7A35T, Spartan-7 XC7S50. 192KB BRAM: 160KB Code, 32KB Data *)
  (* CFB 06.08.2019 Up to SPI x 3, shift SPIFAST *)
  (* CFB 03.06.2020 512 KB RAM *)
  (* CFB 04.06.2020 SPIWORD option *)
(**
  Changes by Gray, gray@grayraven.org
  2020-04: InitSPI: await until card accepts init, LEDs show progress
  2020-08: SPIWORD for 32 bit transfer, independent of SPIFAST option
  2021-07: Added stack monitor to measure start-up stack usage
  2021-08: Added call trace monitor
  2023-03: Disable stack monitor and calltrace monitor for min system
**)

  IMPORT SYSTEM;
  CONST MT = 12; SP = 14;
    MTOrg = 20H;
    spiData = -48; spiCtrl = -44;
    CARD0 = 1; SPIFAST = 8; SPIWORD = 16;
    FSoffset = 80000H;   (*block offset*)

    (***
    (* stack monitor *)
    StackMonMaxAdr = -204;

    (* call trace *)
    CalltraceStatusAdr = -272;
    SelectCtrl = 1;
    ClearCtrl = 4;
    *)

    (* MemLim: total, stackOrg: address of boundary between modules/stack and heap space *)
    (* the stack space is set in module Kernel *)
    (* total: 192k, heap: 32k *) (* MemLim = 030000H; stackOrg = 028000H; *)
    (* total: 256k, heap: 64k *) (* MemLim = 040000H; stackOrg = 030000H; *)
    (* total: 256k, heap: 32k *) (* MemLim = 040000H; stackOrg = 037F00H; *)
    (* total: 384k, heap: 64k *) (* MemLim = 060000H; stackOrg = 050000H; *)
    (* total: 512k, heap: 64k *) MemLim = 080000H; stackOrg = 070000H;


  PROCEDURE SPIIdle(n: INTEGER); (*send n FFs slowly with no card selected*)
  BEGIN
    SYSTEM.PUT(spiCtrl, 0);
    WHILE n > 0 DO DEC(n); SYSTEM.PUT(spiData, -1);
      REPEAT UNTIL SYSTEM.BIT(spiCtrl, 0)
    END
  END SPIIdle;

  PROCEDURE SPI(n: INTEGER); (*send&rcv byte slowly with card selected*)
  BEGIN
    SYSTEM.PUT(spiCtrl, CARD0); SYSTEM.PUT(spiData, n);
    REPEAT UNTIL SYSTEM.BIT(spiCtrl, 0)
  END SPI;

  PROCEDURE SPICmd(n, arg: INTEGER);
    VAR i, data, crc: INTEGER;
  BEGIN (*send cmd*)
    REPEAT SPIIdle(1); SYSTEM.GET(spiData, data) UNTIL data = 255; (*flush while unselected*)
    REPEAT SPI(255); SYSTEM.GET(spiData, data) UNTIL data = 255; (*flush while selected*)
    IF n = 8 THEN crc := 135 ELSIF n = 0 THEN crc := 149 ELSE crc := 255 END;
    SPI(n MOD 64 + 64); (*send command*)
    FOR i := 24 TO 0 BY -8 DO SPI(ROR(arg, i)) END; (*send arg*)
    SPI(crc);
    i := 32;
    REPEAT SPI(255); SYSTEM.GET(spiData, data); DEC(i) UNTIL (data < 80H) OR (i = 0)
  END SPICmd;

  PROCEDURE InitSPI;
    VAR res: INTEGER;
  BEGIN
    SPIIdle(10); (*first, idle for at least 80 clks*)
    LED(080H + 1);
    REPEAT (* gray: until card accepts init *)
      SPICmd(0, 0); (*CMD0 when card selected, sets MMC SPI mode*)
      SYSTEM.GET(spiData, res);
    UNTIL res = 1H;
    LED(080H + 2);
    SPICmd(8, 1AAH); SPI(-1); SPI(-1); SPI(-1); (*CMD8 for SD cards*)
    REPEAT (*until card becomes ready*)
      (*ACMD41, optionally with high-capacity (HCS) bit set, starts init*)
      SPICmd(55, 0); (*APP cmd follows*)
      SPICmd(41, LSL(1(*HCS*), 30));
      SYSTEM.GET(spiData, res);
      SPI(-1); SPI(-1); SPI(-1); (*flush response*)
      SPIIdle(10000)
    UNTIL res = 0;
    LED(080H + 3);
    (*CMD16 set block size as a precaution (should default)*)
    SPICmd(16, 512); SPIIdle(1)
  END InitSPI;

  PROCEDURE SDShift(VAR n: INTEGER);
    VAR data: INTEGER;
  BEGIN SPICmd(58, 0);  (*CMD58 get card capacity bit*)
    SYSTEM.GET(spiData, data); SPI(-1);
    IF (data # 0) OR ~SYSTEM.BIT(spiData, 6) THEN n := n * 512 END ;  (*non-SDHC card*)
    SPI(-1); SPI(-1); SPIIdle(1)  (*flush response*)
  END SDShift;

  PROCEDURE ReadSD(src, dst: INTEGER);
    VAR i, data: INTEGER;
  BEGIN SDShift(src); SPICmd(17, src); (*CMD17 read one block*)
    i := 0; (*wait for start data marker*)
    LED(080H + 4);
    REPEAT SPI(-1); SYSTEM.GET(spiData, data); INC(i) UNTIL data = 254;
    SYSTEM.PUT(spiCtrl, SPIWORD + SPIFAST + CARD0);
    LED(080H + 5);
    FOR i := 0 TO 508 BY 4 DO
      SYSTEM.PUT(spiData, -1);
      REPEAT UNTIL SYSTEM.BIT(spiCtrl, 0);
      SYSTEM.GET(spiData, data); SYSTEM.PUT(dst, data); INC(dst, 4)
    END;
    LED(080H + 6);
    SPI(255); SPI(255); SPIIdle(1) (*may be a checksum; deselect card*)
  END ReadSD;

  PROCEDURE LoadFromDisk;
    VAR src, dst, lim: INTEGER;
  BEGIN src := FSoffset + 4;   (*start at boot block*)
    ReadSD(src, 0); SYSTEM.GET(16, lim);
    INC(src); dst := 512;
    WHILE dst < lim DO ReadSD(src, dst); INC(src); INC(dst, 512) END
  END LoadFromDisk;


BEGIN
  SYSTEM.LDREG(SP, stackOrg); SYSTEM.LDREG(MT, MTOrg);
  (***
  SYSTEM.PUT(StackMonMaxAdr, stackOrg); (* set max address to start to monitor stack usage for system start *)
  SYSTEM.PUT(CalltraceStatusAdr, SelectCtrl); (* select call trace stack 0 *)
  SYSTEM.PUT(CalltraceStatusAdr, ClearCtrl);
  *)
  LED(080H + 0CH);
  InitSPI;
  LoadFromDisk;
  LED(080H + 0DH);
  SYSTEM.PUT(12, MemLim); SYSTEM.PUT(24, stackOrg);
  LED(080H + 0FH)
END BootLoad.
