(**
  Audit process
  --
  Does not a lot of auditing now...
  --
  2021 - 2023 Gray, gray@grayraven.org
  https://oberon-rts.org/licences
**)

MODULE Audit;

  IMPORT Procs := Processes, SysCtrl, Log, LSB;

  CONST
    Period = 7;
    Prio = 0;
    Name = "adt";
    StackHotSize = 0;
    Count = 5; (* times Period *)

  VAR
    audit: Procs.Process;
    stack: ARRAY 256 OF BYTE;
    le: Log.Entry;
    pid: INTEGER;


  PROCEDURE auditc;
    VAR logged, ledr: BOOLEAN; auditCnt: INTEGER;
  BEGIN
    logged := FALSE;
    auditCnt := Count;
    ledr := FALSE;
    REPEAT
      Procs.Next;
      DEC(auditCnt);
      LSB.DisplayNum2Left(10, Procs.NumProcs);
      LSB.DisplayNum2Right(10, auditCnt);
      LSB.DisplayNum4(16, 06F12H);
      IF auditCnt = 0 THEN
        IF ~logged THEN
          SysCtrl.SetError(0, 0);
          SysCtrl.SetErrPid(0);
          le.event := Log.System; le.cause := Log.SysOK;
          SysCtrl.GetReg(le.more0);
          Log.Put(le);
          logged := TRUE
        END;
        auditCnt := Count;
        ledr := ~ledr;
        IF ledr THEN LSB.SetRedLedsOn({1}) ELSE LSB.SetRedLedsOff({1}) END
      END
    UNTIL FALSE
  END auditc;


  PROCEDURE Init*;
    VAR res: INTEGER;
  BEGIN
    Procs.New(audit, auditc, stack, StackHotSize, pid, res);
    Procs.SetPrio(audit, Prio);
    Procs.SetPeriod(audit, Period); (* enables timer *)
    Procs.SetName(audit, Name);
    Procs.SetOnError(audit, Procs.OnErrorReset, Procs.OnErrorHitDefault);
    Procs.Enable(audit);
    ASSERT(res = Procs.OK)
  END Init;


BEGIN
  NEW(audit); ASSERT(audit # NIL)
END Audit.
