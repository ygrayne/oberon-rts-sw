MODULE SysInstall;

  IMPORT Cmds, GC, Errors, Audit;

  PROCEDURE Install*;
  BEGIN
    GC.Install;
    Audit.Install;
    Cmds.Install;
    Errors.Install
  END Install;


  PROCEDURE Recover*;
  BEGIN
    GC.Recover;
    Audit.Recover;
    Cmds.Recover;
    Errors.Recover
  END Recover;

END SysInstall.
