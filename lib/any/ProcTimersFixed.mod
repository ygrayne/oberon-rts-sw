(**
  Driver for the process period timer in the FPGA.
  --
  All times are in scheduler ticks.
  --
  2020 - 2023 Gray, gray@grayraven.org
  http://oberon-rts.org/licences
**)

MODULE ProcTimersFixed;

  IMPORT SYSTEM, DevAdr;

  CONST
    NumControllers = 32;
    Controllers = {0 .. NumControllers-1};

    (* hardware address for all operations *)
    Adr = DevAdr.ProcTimersFixedAdr;

    (* control data bits and shift values *)
    (* for tickers *)
    ResetTickersCtrl = 1;
    SetTickerPeriodCtrl = 2;

    (* for process timers *)
    SetProcTickerCtrl = 4;
    ClearReadyCtrl = 8;
    SetEnabledCtrl = 16;
    SetDisabledCtrl = 32;
    SetReadyCtrl = 64;

    SelectShift = 8;
    DataShift = 16;


  PROCEDURE Enable*(pn: INTEGER);
  BEGIN
    ASSERT(pn IN Controllers);
    SYSTEM.PUT(Adr, LSL(pn, SelectShift) + SetEnabledCtrl)
  END Enable;


  PROCEDURE Disable*(pn: INTEGER);
  BEGIN
    ASSERT(pn IN Controllers);
    SYSTEM.PUT(Adr, LSL(pn, SelectShift) + SetDisabledCtrl)
  END Disable;


  PROCEDURE* SetPeriod*(pn: INTEGER; timerNo: INTEGER);
  (* Select the period timer for process number 'pn'.*)
  (* This also resets the 'process ready' signal. *)
  BEGIN
    ASSERT(pn IN Controllers); (*ASSERT(timerNo IN Tickers);*)
    SYSTEM.PUT(Adr, LSL(timerNo, DataShift) + LSL(pn, SelectShift) + SetProcTickerCtrl)
  END SetPeriod;


  PROCEDURE* SetReady*(pn: INTEGER);
  (* Set process number 'pn' to ready, independent of the ready signal *)
  BEGIN
    ASSERT(pn IN Controllers);
    SYSTEM.PUT(Adr, LSL(pn, SelectShift) + SetReadyCtrl)
  END SetReady;


  PROCEDURE ClearReady*(pn: INTEGER);
  BEGIN
    ASSERT(pn IN Controllers);
    SYSTEM.PUT(Adr, LSL(pn, SelectShift) + ClearReadyCtrl)
  END ClearReady;


  PROCEDURE GetReadyStatus*(VAR ready: SET);
  BEGIN
    SYSTEM.GET(Adr, ready)
  END GetReadyStatus;


  PROCEDURE* Reset*;
  BEGIN
    SYSTEM.PUT(Adr, ResetTickersCtrl)
  END Reset;


  PROCEDURE* cfgTimer(timerNo, period: INTEGER);
  BEGIN
    SYSTEM.PUT(Adr, LSL(period, DataShift) + LSL(timerNo, SelectShift) + SetTickerPeriodCtrl)
  END cfgTimer;


  PROCEDURE Init*(p0, p1, p2, p3, p4, p5, p6, p7: INTEGER);
  BEGIN
    cfgTimer(0, p0);
    cfgTimer(1, p1);
    cfgTimer(2, p2);
    cfgTimer(3, p3);
    cfgTimer(4, p4);
    cfgTimer(5, p5);
    cfgTimer(6, p6);
    cfgTimer(7, p7);
    Reset
  END Init;

END ProcTimersFixed.
