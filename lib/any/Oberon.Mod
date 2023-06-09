(**
  Entry point for the outer core of the system, loaded my Modules.
  --
  Based on Project Oberon and Embedded Project Oberon
  (*JG 6.9.90 / 23.9.93 / 13.8.94 *)
  (*NW 14.4.2013 / 22.12.2013 *)
  (*CB 01/07/2019 *)
  --
  Changes by Gray, gray@grayraven.org, 2020 - 2023
  https://oberon-rts.org/licences
**)

MODULE Oberon;

  IMPORT
     SYSTEM, Kernel, Procs := Processes, GC, Cmds, Audit, Log, SysCtrl, RTC, SPIdev, StackMonitor, Errors;

  CONST
    SP = 14;
    LEDbase = 0B0H;

    LoopStackSize = 512;
    LoopStackHotSize = 32;
    CmdsStackHotSize = 512;

    (* RTC connection *)
    RTCspiDevice = SPIdev.Dev0; (* unbuffered, shared with SD card *)
    RTCchipselect = 1;

  VAR
    (* EO compatibility, eg. as used by System *)
    Par*: Cmds.ParRef;
    Call*: PROCEDURE(name: ARRAY OF CHAR; VAR res: INTEGER);
    stackSize, stackAddr: INTEGER;


  PROCEDURE Clock*(): INTEGER;
    RETURN Kernel.Clock()
  END Clock;


  PROCEDURE SetClock* (d: INTEGER);
  BEGIN
    Kernel.SetClock(d)
  END SetClock;


  PROCEDURE Time*(): INTEGER;
    RETURN Kernel.Time()
  END Time;


  (* start-up stuff *)

  PROCEDURE logRestart;
    VAR le: Log.Entry; scr, addr: INTEGER;
  BEGIN
    SysCtrl.GetReg(scr);
    IF scr = 0 THEN
      le.event := Log.System;
      le.cause := Log.SysColdStart;
      SysCtrl.GetReg(le.more0);
      SysCtrl.GetError(le.more1, addr);
      Log.Put(le);
      le.event := Log.System;
    END;
    IF RTC.Installed THEN
      le.event := Log.System; le.cause := Log.SysRTCinst; le.more0 := RTCspiDevice; le.more1 := RTCchipselect
    ELSE
      le.event := Log.System; le.cause := Log.SysRTCnotinst
    END;
    Log.Put(le)
  END logRestart;


  PROCEDURE logMemData;
    VAR x, stackPtr: INTEGER; le: Log.Entry;
  BEGIN
    le.event := Log.System; le.cause := Log.SysMemStart;
    stackPtr := SYSTEM.REG(SP);
    StackMonitor.GetMin(x); (* lowest stack pointer value during startup *)
    le.more0 := Kernel.stackOrg - x; (* startup stack used *)
    le.more1 := Kernel.stackOrg - stackPtr; (* stack pointer before loading system processes *)
    le.more2 := Kernel.allocated;  (* startup heap used *)
    Log.Put(le)
  END logMemData;

BEGIN
  (* entry point for the outer core, loaded by Modules *)
  (* the temp trap handler is still installed *)
  (* no abort interrupts and abort handler are installed *)
  (* running with SP down from stackOrg *)
  LED(LEDbase + 01H);
  Par := Cmds.Par; Call := Cmds.Call; (* EPO command handling compatibility *)

  RTC.Install(RTCspiDevice, RTCchipselect); (* nice for logging *)

  LED(LEDbase + 02H);
  logRestart;
  logMemData;

  (* loop/scanner will use the top part of the original stack area *)
  (* LoopStackSize bytes *)
  stackAddr := Kernel.stackOrg - LoopStackSize;
  Procs.Install(stackAddr, LoopStackSize, LoopStackHotSize);
  LED(LEDbase + 03H);

  Errors.Init;
  LED(LEDbase + 04H);

  GC.Init;
  LED(LEDbase + 05H);

  Audit.Init;
  LED(LEDbase + 06H);

  (* Cmds will use the part of the original stack below the loop *)
  stackAddr := Kernel.stackOrg - Kernel.stackSize;
  stackSize := Kernel.stackOrg - LoopStackSize - stackAddr;
  Cmds.Init(stackAddr, stackSize, CmdsStackHotSize);
  LED(LEDbase + 07H);

  (* this runs still in the original stack *)
  GC.Collect; (* make sure we have all heap space available for startup loading by Cmds *)
  LED(LEDbase + 08H);
  Procs.Go; (* start loop/scanner *)
  (* we'll not return here *)
END Oberon.
