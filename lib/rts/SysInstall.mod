MODULE SysInstall;

  IMPORT Processes, Cmds, GC, Errors;

  PROCEDURE Install*;
  BEGIN
    GC.Install;
    Processes.InstallAudit;
    Cmds.Install;
    Errors.Install
  END Install;


  PROCEDURE Recover*;
  BEGIN
    GC.Recover;
    Processes.RecoverAudit;
    Cmds.Recover;
    Errors.Recover
  END Recover;

END SysInstall.
