unit Utils;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;

function FillSingle(H1, H0, L1, L0: Byte): Single;
function FillDouble(H3, H2, H1, H0, L3, L2, L1, L0: Byte): Double;
function FillInteger(H, L: Byte): Integer;
function FillLongInt(H1, H0, L1, L0: Byte): longInt;
function FillWord(H, L: Byte): Word;
function FillLongWord(H1, H0, L1, L0: Byte): longWord;

implementation

function FillSingle(H1, H0, L1, L0: Byte): Single;
var Flt: Single;
    FltBytes: array[1..3] of Byte absolute Flt;
begin
   FltBytes[1]:= L0;
   FltBytes[2]:= L1;
   FltBytes[3]:= H0;
   FltBytes[4]:= H1;
   Result:= Flt;
end;

function FillDouble(H3, H2, H1, H0, L3, L2, L1, L0: Byte): Double;
var Flt: Double;
    FltBytes: array[1..8] of Byte absolute Flt;
begin
   FltBytes[1]:= L0;
   FltBytes[2]:= L1;
   FltBytes[3]:= L2;
   FltBytes[4]:= L3;
   FltBytes[5]:= H0;
   FltBytes[6]:= H1;
   FltBytes[7]:= H2;
   FltBytes[8]:= H3;
   Result:= Flt;
end;

function FillInteger(H, L: Byte): Integer;
var lW: Integer;
    lWBytes: array[1..2] of Byte absolute lW;
begin
   lWBytes[1]:= L;
   lWBytes[2]:= H;
   Result:= lW;
end;

function FillLongInt(H1, H0, L1, L0: Byte): longInt;
var lW: longInt;
    lWBytes: array[1..4] of Byte absolute lW;
begin
   lWBytes[1]:= L0;
   lWBytes[2]:= L1;
   lWBytes[3]:= H0;
   lWBytes[4]:= H1;
   Result:= lW;
end;

function FillWord(H, L: Byte): Word;
var lW: Word;
    lWBytes: array[1..2] of Byte absolute lW;
begin
   lWBytes[1]:= L;
   lWBytes[2]:= H;
   Result:= lW;
end;

function FillLongWord(H1, H0, L1, L0: Byte): longWord;
var lW: longWord;
    lWBytes: array[1..4] of Byte absolute lW;
begin
   lWBytes[1]:= L0;
   lWBytes[2]:= L1;
   lWBytes[3]:= H0;
   lWBytes[4]:= H1;
   Result:= lW;
end;

end.


