(**
  FPGA-based event logger.
  --
  Works as circular buffer (FIFO), with the newest log entry overwriting the oldest.
  A print handler can be installed to also print out the log entry's meaning and values.
  Off by default.
  --
  The FIFO logic is in the software. The FPGA buffer can be written and read at random positions.
  Write position: 'putix', read position: 'getix'.
  'putix' and 'getix' can be stored in the FPGA as well, so they survive a system hw-reset.
  --
  Uses an 8 bit wide buffer in the FPGA. A 32 bit wide variant might be faster.
  --
  2021 -2023 Gray, gray@grayraven.org
  https://oberon-rts.org/licences
**)

MODULE Log;

  IMPORT SYSTEM, RTC, DevAdr;

  CONST
    NumEntries = 32; (* in the circular log buffer *)

    (* log events *)
    Trap* = 0;
    Abort* = 1;
    System* = 2;
    Process* = 3;

    (* system log causes *)
    SysInit* = 0;
    SysReset* = 1;
    SysRecover* = 2;
    SysRestart* = 3;
    SysHalt* = 4;
    SysFault* = 5;        (* internal error *)
    SysErrorAbort* = 6;   (* abort in error handling *)
    SysErrorTrap* = 7;    (* trap in error handling *)
    SysOK* = 8;
    SysProcsFull* = 9;    (* max num procs exceeded *)
    SysProcsChange* = 10; (* a proc was added or removed *)
    SysCollect* = 11;     (* GC run *)
    SysRTCinst* = 12;     (* RTC installed *)
    SysRTCnotinst* = 13;  (* RTC not installed *)
    SysMemStart* = 14;    (* memory values at startup *)
    SysStart* = 15;       (* error when using start tables *)

    (* process log causes *)
    ProcInstall* = 0;
    ProcRemove* = 1;
    ProcRecover* = 2;
    ProcReset* = 3;
    ProcOverflow* = 4;

    (* log buffer hw addresses *)
    DataAdr = DevAdr.LogDataAdr;
    IndexAdr = DevAdr.LogIndexAdr;

    EntrySize = 64; (* must ve the size in bytes of Entry *)

  TYPE
    (* each entry in the FPGA can hold 64 8-bit values *)
    Entry* = RECORD
      event*, cause*, more3*, more4*: BYTE;
      procId*: ARRAY 4 OF CHAR;
      when*: INTEGER;
      adr0*, adr1*: INTEGER;            (* error address, module address *)
      more0*, more1*, more2*: INTEGER;  (* additional data, event/cause-dependent *)
      str0*: ARRAY 32 OF CHAR
    END;
    EntryBlock = ARRAY EntrySize OF BYTE;

  VAR
    print: PROCEDURE(e: Entry);
    putix, getix: INTEGER;
    go: INTEGER;


  PROCEDURE putBlock(eb: EntryBlock);
    CONST EntrySize0 = EntrySize - 1;
    VAR i: INTEGER;
  BEGIN
    FOR i := 0 TO EntrySize0 DO
      SYSTEM.PUT(DataAdr, eb[i])
    END
  END putBlock;


  PROCEDURE getBlock(VAR eb: EntryBlock);
    CONST EntrySize0 = EntrySize - 1;
    VAR i: INTEGER;
  BEGIN
    FOR i := 0 TO EntrySize0 DO
      SYSTEM.GET(DataAdr, eb[i])
    END
  END getBlock;


  PROCEDURE putIndices(pix, gix: INTEGER);
    VAR indices: INTEGER;
  BEGIN
    indices := LSL(pix, 16) + gix;
    SYSTEM.PUT(IndexAdr, indices)
  END putIndices;


  PROCEDURE getIndices(VAR pix, gix: INTEGER);
    VAR indices: INTEGER;
  BEGIN
    SYSTEM.GET(IndexAdr, indices);
    pix := indices DIV 010000H MOD 010000H;
    gix := indices MOD 010000H;
  END getIndices;


  PROCEDURE Put*(VAR e: Entry);
  BEGIN
    getIndices(putix, getix);
    IF RTC.Installed THEN
      e.when := RTC.Clock()
    ELSE
      e.when := 0
    END;
    putBlock(e);
    putix := (putix + 1) MOD NumEntries;
    IF getix = putix THEN getix := (getix + 1) MOD NumEntries END;
    putIndices(putix, getix);
    IF print # NIL THEN print(e) END
  END Put;


  PROCEDURE BeginGet*;
  BEGIN
    getIndices(putix, getix);
    go := getix
  END BeginGet;


  PROCEDURE EndGet*;
  BEGIN
    putIndices(putix, getix);
  END EndGet;


  PROCEDURE GetNext*(VAR e: Entry);
  BEGIN
    getBlock(e);
    go := (go + 1) MOD NumEntries;
    putIndices(putix, go)
  END GetNext;


  PROCEDURE GetMore*(): BOOLEAN;
    RETURN go # putix
  END GetMore;


  PROCEDURE SetPrintHandler*(ph: PROCEDURE(le: Entry));
  BEGIN
    print := ph
  END SetPrintHandler;

BEGIN
  print := NIL; go := 0
END Log.
