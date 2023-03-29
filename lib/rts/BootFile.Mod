(*
  load the prelinked boot file Modules.bin created
  by the Astrobe linker onto the boot area of the local disk

  Ref: Oberon Building Tools, Andreas Pirklbauer
  https://github.com/andreaspirklbauer/Oberon-building-tools

  gray 2022-02: add Console output
*)

MODULE BootFile;

  IMPORT Files, Texts, Kernel, Console := ConsoleC;

  CONST
   BootFilename = "Modules.bin";
   BootSector = 2;

  VAR
   W: Texts.Writer;

  PROCEDURE Load*;
  VAR i, sectorNo: INTEGER; b: BYTE;
    f: Files.File; r: Files.Rider;
    buf: ARRAY Kernel.SectorLength OF BYTE;
  BEGIN
    Texts.WriteString(W, "Loading "); Texts.WriteString(W, BootFilename);
    f := Files.Old(BootFilename);
    IF f = NIL THEN
      Texts.WriteString(W, " not found")
    ELSE
      sectorNo := BootSector;
      Files.Set(r, f, 0);
      Files.ReadByte(r, b);
      i := 0;
      WHILE ~r.eof DO buf[i] := b; INC(i);
        IF i = Kernel.SectorLength THEN Kernel.PutSector(sectorNo*29, buf); INC(sectorNo); i := 0 END ;
        Files.ReadByte(r, b)
      END ;
      IF i > 0 THEN
        WHILE i < Kernel.SectorLength DO buf[i] := 0; INC(i) END ;
        Kernel.PutSector(sectorNo*29, buf)
      END;
      Texts.WriteString(W, " finished")
    END;
    Texts.WriteLn(W)
  END Load;

BEGIN
  W := Console.C
END BootFile.
