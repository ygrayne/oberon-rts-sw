(**
  RS232 devices
  --
  As currently instantiated and wired in the RISC5 processor:
  * RS232 Dev0: buffered RS232
  --
  2020 - 2023 by Gray, gray@grayraven.org
  https://oberon-rts.org/licences
**)

MODULE RS232dev;

  IMPORT Texts, DevAdr;

  CONST
    (* device IDs *)
    Dev0* = 0;
    Devices* = {Dev0 .. Dev0};

    (*** STATUS register bits: read via status addr *)
    (** unbuffered devices *)
    RXNE* = 0;    (* Rx reg non empty, ie. byte received *)
    TXE* = 1;     (* Tx reg empty, ie. ready to send *)

    (* buffered devices *)
    RXBNE* = 0;       (* Rx buffer not empty *)
    TXBE* = 1;        (* Tx buffer empty *)
    RXBF* = 2;        (* Rx buffer full *)
    TXBNF* = 3;       (* Tx buffer not full *)

    (*** CONTROL bits: write to status addr *)
    (* unbuffered and buffered devices *)
    SLOW* = 0;   (* slow mode, fast = 0 is default mode *)

    (*** CONFIG *)
    Dev0DataAdr = DevAdr.RS232dev0DataAdr;
    Dev0StatusAdr = DevAdr.RS232dev0StatusAdr;

    (*
    Dev1DataAdr = DevAdr.RS232dev1DataAdr;
    Dev1StatusAdr = DevAdr.RS232dev1StatusAdr;

    Dev2DataAdr = DevAdr.RS232dev2DataAdr;
    Dev2StatusAdr = DevAdr.RS232dev2StatusAdr;
    *)

  TYPE
    Device* = POINTER TO DeviceDesc;
    DeviceDesc* = RECORD(Texts.TextDeviceDesc)
      dataAdr*, statusAdr*: INTEGER;
      rxTimeout*, txTimeout*: INTEGER;
      rxCond*, txCond*: BYTE
    END;

  PROCEDURE Init*(dev: Device; deviceNo: INTEGER);
  BEGIN
    ASSERT(deviceNo IN Devices);
    IF deviceNo = 0 THEN
      dev.dataAdr := Dev0DataAdr;
      dev.statusAdr := Dev0StatusAdr;
      dev.rxCond := RXBNE;
      dev.txCond := TXBNF;
      dev.rxTimeout := 0;
      dev.txTimeout := 0
    (*
    ELSIF deviceNo = 1 THEN
      dev.dataAdr := Dev1DataAdr;
      dev.statusAdr := Dev1StatusAdr;
      dev.rxCond := RXBNE;
      dev.txCond := TXBNF;
      dev.rxTimeout := 0;
      dev.txTimeout := 0
    ELSIF deviceNo = 2 THEN
      dev.dataAdr := Dev2DataAdr;
      dev.statusAdr := Dev2StatusAdr;
      dev.rxCond := RXBNE;
      dev.txCond := TXBNF;
      dev.rxTimeout := 0;
      dev.txTimeout := 0
    *)
    END
  END Init;


  PROCEDURE SetCond*(dev: Device; rxCond, txCond: INTEGER);
  BEGIN
    dev.rxCond := rxCond;
    dev.txCond := txCond
  END SetCond;


  PROCEDURE SetTimeouts*(dev: Device; rxTimeout, txTimeout: INTEGER);
  BEGIN
    ASSERT(txTimeout >= 0); ASSERT(rxTimeout >= 0);
    dev.rxTimeout := rxTimeout;
    dev.txTimeout := txTimeout
  END SetTimeouts;

END RS232dev.
