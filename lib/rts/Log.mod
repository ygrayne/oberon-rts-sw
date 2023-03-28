(**
  FPGA-based event logger.
  --
  Works as circular buffer (FIFO), with the newest log entry overwriting the oldest.
  A print handler can be installed to also print out the log entry's meaning and values. Off by default.
  --
  The FIFO logic is in the software. The FPGA buffer can be written and read at random positions.
  Write position: 'putIndex', read position: 'getIndex'.
  'putIndex' and 'getIndex' can be stored in the FPGA as well, so they survive a system hw-reset.
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
    PutIndexAdr = DevAdr.LogPutIndexAdr;
    GetIndexAdr = DevAdr.LogGetIndexAdr;

    EntrySize = 64;

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
    putIndex, getIndex: INTEGER;
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


  PROCEDURE Put*(VAR e: Entry);
  (* boot *)
  BEGIN
    SYSTEM.GET(PutIndexAdr, putIndex);
    SYSTEM.PUT(PutIndexAdr, putIndex);
    IF RTC.Installed THEN
      e.when := RTC.Clock()
    ELSE
      e.when := 0
    END;
    putBlock(e);
    SYSTEM.GET(GetIndexAdr, getIndex);
    putIndex := (putIndex + 1) MOD NumEntries;
    IF getIndex = putIndex THEN getIndex := (getIndex + 1) MOD NumEntries END;
    SYSTEM.PUT(PutIndexAdr, putIndex);
    SYSTEM.PUT(GetIndexAdr, getIndex);
    IF print # NIL THEN print(e) END
  END Put;


  PROCEDURE BeginGet*;
  BEGIN
    SYSTEM.GET(PutIndexAdr, putIndex);
    SYSTEM.GET(GetIndexAdr, getIndex);
    go := getIndex
  END BeginGet;


  PROCEDURE EndGet*;
  BEGIN
    SYSTEM.PUT(GetIndexAdr, getIndex)
  END EndGet;


  PROCEDURE GetNext*(VAR e: Entry);
  BEGIN
    getBlock(e);
    go := (go + 1) MOD NumEntries;
    SYSTEM.PUT(GetIndexAdr, go);
  END GetNext;


  PROCEDURE GetMore*(): BOOLEAN;
  BEGIN
    RETURN go # putIndex
  END GetMore;


  PROCEDURE SetPrintHandler*(ph: PROCEDURE(le: Entry));
  BEGIN
    print := ph
  END SetPrintHandler;

BEGIN
  print := NIL; go := 0
END Log.
