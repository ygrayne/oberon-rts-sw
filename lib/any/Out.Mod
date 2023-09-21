MODULE Out;
(* =========================================================================
   Astrobe Library Functions for Formatted Output
   Ref: Programming in Oberon - Reiser & Wirth, ACM Press 1992

   (c) 2008-2021 CFB Software
   http://www.astrobe.com

   ========================================================================= *)

  (**
    gray: 1) added 'SetWriter', 2) by default, set 'W = Console.C'
  **)

  IMPORT Texts, Console := ConsoleB;

  VAR
    W: Texts.Writer;

  (* gray begin *)
  PROCEDURE SetWriter*(w: Texts.Writer);
  BEGIN
    W := w
  END SetWriter;
  (* gray end *)


  PROCEDURE Char*(ch: CHAR);
  BEGIN
    Texts.Write(W, ch)
  END Char;


  PROCEDURE String*(s: ARRAY OF CHAR);
  BEGIN
    Texts.WriteString(W, s);
  END String;


  PROCEDURE Ln*();
  BEGIN
    Texts.WriteLn(W);
  END Ln;


  PROCEDURE Int*(n, width: INTEGER);
  BEGIN
    Texts.WriteInt(W, n, width);
  END Int;


  PROCEDURE Hex*(n, width: INTEGER);
  BEGIN
    Texts.WriteHex(W, n);
  END Hex;


  PROCEDURE Real*(x: REAL; n: INTEGER);
  BEGIN
  	Texts.WriteReal(W, x, n)
  END Real;


  PROCEDURE RealFix*(x: REAL; n, f: INTEGER);
  BEGIN
  	Texts.WriteRealFix(W, x, n, f)
  END RealFix;

BEGIN
  W := Console.C
END Out.
