(**
  Unbuffered SPI device driver
  --
  2020 - 2023 Gray, gray@grayraven.org
  https://oberon-rts.org/licences
**)

MODULE SPIu;

  IMPORT
    SYSTEM, SPIdev;

  CONST
    (* status *)
    RDY = SPIdev.RDY;

    (* control *)
    FSTE* = {SPIdev.FSTE};
    MSBF* = {SPIdev.MSBF};
    D8*  = {};
    D16* = {SPIdev.D16};
    D32* = {SPIdev.D32};
    Dn   = D8 + D16 + D32;
    CON* = {SPIdev.CON};
    COFF* = {};


  PROCEDURE* SetControl*(dev: SPIdev.Device; ctrlReg: SET);
  (* Set CS [2:0], FSTE, MSBF *)
  BEGIN
    dev.ctrlReg := ctrlReg - Dn - CON (* these bits are being set by put/get procs below *)
  END SetControl;


  PROCEDURE* Select*(dev: SPIdev.Device; ctrl: SET);
  (* Ready the SPI device by writing the status register with the value as
  set by 'SetControl', plus the additional ctrl bits, in particular the transmitted
  data length (8, 16, 32 bits), plus the auxiliary control line (CON).
  The status register remains set until the transmission/reception is terminated
  using 'Deselect', across one ore more 'Put' or 'Get' operations. *)
  BEGIN
    ASSERT(ctrl - Dn - CON = {});
    SYSTEM.PUT(dev.statusAdr, dev.ctrlReg + ctrl)
  END Select;


  PROCEDURE* Deselect*(dev: SPIdev.Device; ctrl: SET);
  (* Deselect the SPI device, ending a transmission *)
  BEGIN
    ASSERT(ctrl - CON = {});
    SYSTEM.PUT(dev.statusAdr, ctrl)
  END Deselect;


  PROCEDURE* Put*(dev: SPIdev.Device; data: INTEGER);
  (* Transmit 'data', as selected by 'Select' *)
  BEGIN
    SYSTEM.PUT(dev.dataAdr, data);
    REPEAT UNTIL SYSTEM.BIT(dev.statusAdr, RDY);
  END Put;


  PROCEDURE* Get*(dev: SPIdev.Device; VAR data: INTEGER);
  (* Get 'data', as selected by 'Select' *)
  BEGIN
    SYSTEM.PUT(dev.dataAdr, 0F0AACCAAH);
    REPEAT UNTIL SYSTEM.BIT(dev.statusAdr, RDY);
    SYSTEM.GET(dev.dataAdr, data)
  END Get;


  (* For consistency reasons across the API, also use 'Select' and 'Deselect' in the following cases, *)
  (* even though the data sizes are defined, hence Select and Deselect could be integrated here. *)

  PROCEDURE PutBytes*(dev: SPIdev.Device; data: ARRAY OF BYTE; n: INTEGER);
    VAR i: INTEGER;
  BEGIN
    ASSERT(n <= LEN(data));
    FOR i := 0 TO n - 1 DO
      SYSTEM.PUT(dev.dataAdr, data[i]);
      REPEAT UNTIL SYSTEM.BIT(dev.statusAdr, RDY)
    END
  END PutBytes;


  PROCEDURE GetBytes*(dev: SPIdev.Device; VAR data: ARRAY OF BYTE; n: INTEGER);
    VAR i: INTEGER;
  BEGIN
    ASSERT(n <= LEN(data));
    FOR i := 0 TO n - 1 DO
      SYSTEM.PUT(dev.dataAdr, 0F0AACCAAH);
      REPEAT UNTIL SYSTEM.BIT(dev.statusAdr, RDY);
      SYSTEM.GET(dev.dataAdr, data[i])
    END
  END GetBytes;


  PROCEDURE PutWords*(dev: SPIdev.Device; data: ARRAY OF INTEGER; n: INTEGER);
    VAR i: INTEGER;
  BEGIN
    ASSERT(n <= LEN(data));
    FOR i := 0 TO n - 1 DO
      SYSTEM.PUT(dev.dataAdr, data[i]);
      REPEAT UNTIL SYSTEM.BIT(dev.statusAdr, RDY)
    END
  END PutWords;


  PROCEDURE GetWords*(dev: SPIdev.Device; data: ARRAY OF INTEGER; n: INTEGER);
    VAR i: INTEGER;
  BEGIN
    ASSERT(n <= LEN(data));
    FOR i := 0 TO n - 1 DO
      SYSTEM.PUT(dev.dataAdr, 0F0AACCAAH);
      REPEAT UNTIL SYSTEM.BIT(dev.statusAdr, RDY);
      SYSTEM.GET(dev.dataAdr, data[i])
    END
  END GetWords;

END SPIu.
