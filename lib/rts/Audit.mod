(**
  Audit process
  --
  Does not a lot of auditing now...
  --
  2021 - 2023 Gray, gray@grayraven.org
  https://oberon-rts.org/licences
**)

MODULE Audit;

  IMPORT Procs := Processes, SysCtrl, Log;

  CONST
    AuditPeriod = 7;
    AuditPrio = 0;
    AuditPrId = "adt";
    AuditStackHotSize = 0;
    AuditCount = 5; (* times AuditPeriod *)

  VAR
    audit: Procs.Process;
    auditStack: ARRAY 256 OF BYTE;
    auditCnt: INTEGER;
    le: Log.Entry;


  PROCEDURE auditc;
    VAR logged: BOOLEAN; addr: INTEGER;
  BEGIN
    logged := FALSE;
    auditCnt := AuditCount;
    Procs.SetPeriod(AuditPeriod);
    REPEAT
      Procs.Next;
      DEC(auditCnt);
      IF auditCnt = 0 THEN
        IF ~logged THEN
          SysCtrl.SetError(0, 0, 0);
          le.event := Log.System; le.cause := Log.SysOK;
          SysCtrl.GetReg(le.more0);
          Log.Put(le);
          logged := TRUE
        END;
        auditCnt := AuditCount
      END
    UNTIL FALSE
  END auditc;


  PROCEDURE Install*;
    VAR res: INTEGER;
  BEGIN
    NEW(audit);
    Procs.Init(audit, auditc, auditStack, AuditStackHotSize, Procs.SystemProc, AuditPrio, AuditPrId);
    Procs.Install(audit, res)
  END Install;


  PROCEDURE Recover*;
  BEGIN
  END Recover;

END Audit.
