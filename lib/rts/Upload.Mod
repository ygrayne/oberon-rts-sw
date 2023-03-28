(**
  Serial file uploader
  --
  Based on
  CFB 12.12.2015
  Derived from PCLink NW 25.7.2013 for Oberon on RISC
  --
  The upload format appears to be:
  * The upload is announced and requested by REC = 21X (1 byte)
  then:
  * the file name, 0X-terminated, max 32 chars
  * the file date as INTEGER
  * a number of 256 data records, with the first byte indicating the length of the record
  * consequently, when the length is < 255, it's the last record
  --
  Handshaking:
  * The uploader in the IDE does not await any handshake from the board, but immediately
    starts to send the data after the REC request
  * The first ACK is awaited after the file name and file date are transmitted
    This ACK is sent after the file is opened, its date is set, and it's prepared for writing
  * After each record sent, an ACK is awaited by the IDE
    The ACK is sent after the record is written to the file
  * A final ACK is sent after the file is closed
  * Each ACK awaited by the IDE is guarded by a time-out
  --
  Issues:
  * The above works well, apart from multi-file uploads at times: the IDE will start to transmit
    immediately with REC etc., and expects the CPU to be ready to receive with an unbuffered serial device
  * In case a task was activated in between the files, the CPU might not be ready, and the awaited ACK times out
  * Even with a buffered serial device the ACK can time out, depending on the CPU load
  * Check Cmds.mod for a workaround for the multi-file timeout issue
**)

MODULE Upload;

  IMPORT Files, RS232dev, RS232 := RS232b;

  CONST
    FnLength = 32;
    BlockLength = 255;
    ACK = 10H;

  VAR
    dev: RS232dev.Device;

  PROCEDURE recInt(VAR n: INTEGER);
    VAR x: ARRAY 4 OF BYTE; i: INTEGER;
  BEGIN
    RS232.GetBytes(dev, x, 4);
    n := 0;
    FOR i := 0 TO 3 DO
      n := n + LSL(x[i], 8 * i)
    END
  END recInt;


  PROCEDURE recString(VAR s: ARRAY OF CHAR);
    VAR n: INTEGER;
  BEGIN
    RS232.GetString(dev, s, 0X, 0, n); s[n] := 0X
  END recString;


  PROCEDURE Run*;
    VAR
      fileDate: INTEGER; x: BYTE;
      fileName: ARRAY FnLength OF CHAR;
      F: Files.File; R: Files.Rider;
      buf: ARRAY BlockLength OF BYTE;
  BEGIN
    LED(30H);
    recString(fileName);
    recInt(fileDate);
    F := Files.New(fileName);
    IF F # NIL THEN
      Files.SetDate(F, fileDate);
      Files.Set(R, F, 0);
      RS232.PutByte(dev, ACK);
      REPEAT
        RS232.GetByte(dev, x);
        RS232.GetBytes(dev, buf, x);
        Files.WriteBytes(R, buf, x);
        RS232.PutByte(dev, ACK)
      UNTIL x < 255;
      Files.Register(F);
      RS232.PutByte(dev, ACK)
    END;
    LED(0)
  END Run;

BEGIN
  NEW(dev); RS232dev.Init(dev, RS232dev.Dev0); RS232dev.SetCond(dev, RS232dev.RXBNE, RS232dev.TXBNF)
END Upload.
