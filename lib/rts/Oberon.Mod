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
     SYSTEM, Procs := Processes, GC, Kernel, Cmds, SysInstall, Log, SysCtrl, RTC, SPIdev, StackMonitor;

  CONST
    SP = 14;

    (* RTC connection *)
    RTCspiDevice = SPIdev.Dev0; (* unbuffered, shared with SD card *)
    RTCchipselect = 1;

  VAR
    (* EO compatibility, eg. as used by System *)
    Par*: Cmds.ParRef;
    Call*: PROCEDURE(name: ARRAY OF CHAR; VAR res: INTEGER);


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
    VAR le: Log.Entry;
  BEGIN
    le.event := Log.System; le.cause := Log.SysRestart;
    SysCtrl.GetReg(le.more0);
    SysCtrl.GetRestartCause(le.more1);
    SysCtrl.GetErrorState(le.more2);
    Log.Put(le);
    le.event := Log.System;
    IF RTC.Installed THEN
      le.cause := Log.SysRTCinst; le.more0 := RTCspiDevice; le.more1 := RTCchipselect
    ELSE
      le.event := Log.System; le.cause := Log.SysRTCnotinst
    END;
    Log.Put(le)
  END logRestart;


  PROCEDURE logMemData(SP: INTEGER);
    VAR x: INTEGER; le: Log.Entry;
  BEGIN
    le.event := Log.System; le.cause := Log.SysMemStart;
    StackMonitor.GetMin(x);
    le.more0 := Kernel.stackOrg - x; (* startup stack used *)
    le.more1 := Kernel.stackOrg - SP; (* stack pointer before loading cmds *)
    le.more2 := Kernel.allocated;  (* startup heap used *)
    Log.Put(le)
  END logMemData;

BEGIN
  (* entry point for the outer core, loaded by Modules *)
  (* the temp trap handler is still installed *)
  (* no abort interrupts and abort handler are installed *)
  LED(0F1H);
  Par := Cmds.Par; Call := Cmds.Call; (* EPO command handling compatibility *)
  (***
  RTC.Install(RTCspiDevice, RTCchipselect); (* needed for logging *)
  *)
  logRestart;
  LED(0F2H);
  logMemData(SYSTEM.REG(SP));
  LED(0F3H);
  SysInstall.Install;
  LED(0F4H);
  (* from here, cmds will use most of the original stack, the scheduler (Loop) only keeps a small part
  at the top, see Procs.SchedulerStackSize *)
  (*
  Errors.Install; (* installs trap and abort handlers, as well as error interrupt handlers *)
  LED(0F7H);
  *)
  (*Console.WriteLine(""); Console.WriteLine(RTSversion);*)
  (*Calltrace.Select(0);*)
  GC.Collect; (* make sure we have all heap space available for startup loading by Cmds *)
  Procs.Go (* start scheduler *)
  (* we'll not return here *)
END Oberon.
