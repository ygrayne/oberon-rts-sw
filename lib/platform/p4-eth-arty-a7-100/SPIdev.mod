(**
  SPI devices
  --
  As currently created and wired:
  * SPI Dev0: extended SPI, unbuffered
  --
  2020 - 2023 Gray, gray@grayraven.org
  https://oberon-rts.org/licences
**)

MODULE SPIdev;

  IMPORT DevAdr;

  CONST
    (*** device IDs *)
    Dev0* = 0;  (* unbuffered, used by file system *)
    Devices* = {Dev0 .. Dev0};

    (*** STATUS register bits: read via status addr *)
    (** unbuffered devices *)
    RDY* = 0;         (* ready, one transmission cycle done *)

    (** buffered devices *)
    RXBNE* = 0;       (* Rx buffer not empty, corresponds to RDY *)
    TXBNF* = 1;       (* Tx buffer not full *)
    RXBF*  = 2;       (* Rx buffer full *)
    TXBE*  = 3;       (* Tx buffer empty *)

    (*** CONTROL bits: write to status addr *)
    (** unbuffered and buffered devices *)
    (* Chip Select: wired is 0, range is 0..2 *)
    FSTE* = 3;    (* send/receive in fast mode *)
    (* Data width = {4..5}, defaults to {} => 8 bits *)
    D32*  = 4;    (* transmitted data = 32 bits *)
    D16*  = 5;    (* transmitted data = 16 bits *)
    MSBF* = 6;    (* send MSByte first *)
    CON*  = 8;    (* aux control bit *) (* not yet implemented on platform *)

    (** buffered devices *)
    NORX* = 7;    (* don't receive data into Rx buffer *)
    RST*  = 9;    (* reset the device *)

    (* CONFIG data *)
    Dev0DataAdr = DevAdr.SPIdev0DataAdr;
    Dev0StatusAdr = DevAdr.SPIdev0StatusAdr;

    (*
    Dev1DataAdr = DevAdr.SPIdev1DataAdr;
    Dev1StatusAdr = DevAdr.SPIdev1StatusAdr;

    Dev2DataAdr = DevAdr.SPIdev2DataAdr;
    Dev2StatusAdr = DevAdr.SPIdev2StatusAdr;
    *)

  TYPE
    Device* = POINTER TO DeviceDesc;
    DeviceDesc* = RECORD
      dataAdr*, statusAdr*: INTEGER;
      ctrlReg*: SET;
    END;

  PROCEDURE Init*(dev: Device; deviceNo: INTEGER);
  BEGIN
    ASSERT(deviceNo IN Devices);
    IF deviceNo = 0 THEN
      dev.dataAdr   := Dev0DataAdr;
      dev.statusAdr := Dev0StatusAdr;
    (*
    ELSIF deviceNo = 1 THEN
      dev.dataAdr   := Dev1DataAdr;
      dev.statusAdr := Dev1StatusAdr
    ELSIF deviceNo = 2 THEN
      dev.dataAdr   := Dev2DataAdr;
      dev.statusAdr := Dev2StatusAdr
    *)
    END
  END Init;

END SPIdev.
