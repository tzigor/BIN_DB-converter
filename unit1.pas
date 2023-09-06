unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ComCtrls, StdCtrls,
  Grids, ExtCtrls, StrUtils, LConvEncoding, Utils;

type

  { TBIN_DB }

  TBIN_DB = class(TForm)
    ConvertData: TButton;
    CloseApp: TButton;
    FileName: TEdit;
    Progress: TProgressBar;
    ToolInfo: TMemo;
    OpenDialog1: TOpenDialog;
    procedure CloseAppClick(Sender: TObject);
    procedure ConvertDataClick(Sender: TObject);
  private

  public

  end;

type String16 = String[16];
type String32 = String[32];
type String40 = String[40];
type String4 = String[4];
type String2 = String[2];
type String10 = String[10];
type String20 = String[20];

type TMeasurement = record
  ChannelName: String16;
  Sensor: String16;
  Phase: String16;
  MeasurementType: String32;
  MeasurementDescription: String[40];
  MeasurementValue: Single;
  MeasurementTime: longWord;
  Reference: Single;
  ReferenceLowTolerance: Single;
  ReferenceHighTolerance: Single;
  Limit: Single;
end;

type TDataChannel = record
  DLISName: String16;
  Units: String4;
  RepCode: String2;
  Samples: longInt;
  AbsentValue: String20;
end;

type TFrame = array of String;
Const Line = #13#10;

var
  Bytes: array of Byte;
  OutBytes: array of Byte;
  Counter, OutCounter: longWord;
  BIN_DB: TBIN_DB;
  Data: array of Byte;
  BinDbFile: File of Byte;
  DataChannels: array of TDataChannel;
  PrevValue: longWord;
  wStr: String;

implementation

{$R *.lfm}

{ TBIN_DB }

function LoadByteArray(const AFileName: string): TBytes;
var
  AStream: TStream;
  ADataLeft: Integer;
begin
  SetLength(result, 0);
  AStream:= TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
     AStream.Position:= 0;
     ADataLeft:= AStream.Size;
     SetLength(result, ADataLeft div SizeOf(Byte));
     AStream.Read(PByte(result)^, ADataLeft);
  finally
     AStream.Free;
  end;
end;

procedure SaveByteArray(AByteArray: TBytes; const AFileName: string);
var
  AStream: TStream;
begin
  if FileExists(AFileName) then DeleteFile(AFileName);
  AStream := TFileStream.Create(AFileName, fmCreate);
  try
     AStream.WriteBuffer(Pointer(AByteArray)^, Length(AByteArray));
  finally
     AStream.Free;
  end;
end;

procedure GetData(Len: longWord);
var i: longWord;
begin
  setLength(Data, Len);
  for i:= 1 to Len do begin
     Data[i-1]:= Bytes[Counter];
     Counter:= Counter + 1;
  end;
end;

function ParseMeasurement(): TMeasurement;
var i, n: Byte;
    Measurement: TMeasurement;
begin
  with Measurement do begin
     ChannelName:= '';
     Sensor:= '';
     Phase:= '';
     MeasurementType:= '';
     for i:=0 to 15 do if Data[i] > 0 then ChannelName:= ChannelName + Chr(Data[i])
                       else ChannelName:= ChannelName + ' ';
     for i:=0 to 15 do if Data[i+16] > 0 then Sensor:= Sensor + Chr(Data[i+16])
                       else Sensor:= Sensor + ' ';
     for i:=0 to 15 do if Data[i+32] > 0 then Phase:= Phase + Chr(Data[i+32])
                       else Phase:= Phase + ' ';
     for i:=0 to 31 do if Data[i+48] > 0 then MeasurementType:= MeasurementType + Chr(Data[i+48])
                       else MeasurementType:= MeasurementType + ' ';
     for i:=0 to 39 do if Data[i+80] > 0 then MeasurementDescription:= MeasurementDescription + Chr(Data[i+80])
                       else MeasurementDescription:= MeasurementDescription + ' ';
     MeasurementValue:= FillSingle(Data[123], Data[122], Data[121], Data[120]);
     MeasurementTime:= FillLongWord(Data[127], Data[126], Data[125], Data[124]);
     Reference:= FillSingle(Data[131], Data[130], Data[129], Data[128]);
     ReferenceLowTolerance:= FillSingle(Data[135], Data[134], Data[133], Data[132]);
     ReferenceHighTolerance:= FillSingle(Data[140], Data[139], Data[137], Data[136]);
     Limit:= FillSingle(Data[144], Data[143], Data[142], Data[141]);
  end;
  Result:= Measurement;
end;

function MeasurementToStr(Measurement: TMeasurement): String;
var wStr: String;
begin
  wStr:= '';
  with Measurement do begin
     wStr:= wStr + ChannelName + ' ' + Sensor + ' ' + Phase + ' ' + MeasurementType + ' ' + MeasurementDescription + ' ';
     wStr:= wStr + FloatToStrF(MeasurementValue, ffFixed, 10, 2) + ' ';
     wStr:= wStr + IntToStr(MeasurementTime) + ' ';
     wStr:= wStr + FloatToStrF(MeasurementValue, ffFixed, 10, 2) + ' ';
     wStr:= wStr + FloatToStrF(Reference, ffFixed, 10, 2) + ' ';
     wStr:= wStr + FloatToStrF(ReferenceLowTolerance, ffFixed, 10, 2) + ' ';
     wStr:= wStr + FloatToStrF(ReferenceHighTolerance, ffFixed, 10, 2) + ' ';
     wStr:= wStr + FloatToStrF(Limit, ffFixed, 10, 2) + Line;
  end;
  Result:= wStr;
end;

function ParseDataChannel(RecordLength: longWord): TDataChannel;
var DataChannel: TDataChannel;
    i, DLISNameLen, UnitsLen, RepCodeLen, SamplesLen, AbsentValueLen, Shift: Byte;
    StrSamples: String;
begin
  DLISNameLen:= 10;
  UnitsLen:= 4;
  RepCodeLen:= 2;
  SamplesLen:= 10;
  AbsentValueLen:= 20;
  if RecordLength = 40 then SamplesLen:= 4;
  if RecordLength = 52 then DLISNameLen:= 16;
  with DataChannel do begin
     DLISName:= '';
     Units:= '';
     RepCode:= '';
     StrSamples:= '';
     AbsentValue:= '';
     Shift:= 0;
     for i:= 0 to DLISNameLen - 1 do if Data[i] > 0 then DLISName:= DLISName + Chr(Data[i])
                       else DLISName:= DLISName + ' ';
     Shift:= Shift + DLISNameLen;
     for i:= 0 to UnitsLen - 1 do if Data[i+Shift] > 0 then Units:= Units + Chr(Data[i+Shift])
                       else Units:= Units + ' ';
     Shift:= Shift + UnitsLen;
     for i:= 0 to RepCodeLen - 1 do if Data[i+Shift] > 0 then RepCode:= RepCode + Chr(Data[i+Shift])
                       else RepCode:= RepCode + ' ';
     Shift:= Shift + RepCodeLen;
     for i:= 0 to SamplesLen - 1 do if Data[i+Shift] > 0 then StrSamples:= StrSamples + Chr(Data[i+Shift]);
     TryStrToInt(Trim(StrSamples), Samples);
     Shift:= Shift + SamplesLen;
     for i:= 0 to AbsentValueLen - 1 do if Data[i+Shift] > 0 then AbsentValue:= AbsentValue + Chr(Data[i+Shift])
                        else AbsentValue:= AbsentValue + ' ';
  end;
  Result:= DataChannel;
end;

procedure ComposeDataChannelV3(DataChannel: TDataChannel);
var i, DLISNameLen, UnitsLen, RepCodeLen, SamplesLen, AbsentValueLen: Byte;
    sDLISNameLen, sUnitsLen, sRepCodeLen, sSamplesLen, sAbsentValueLen: Byte;
    wDLISName, wUnits, wRepCode, wSamples, wAbsentValue: String;
    ch: Char;
begin
  DLISNameLen:= 10;
  UnitsLen:= 4;
  RepCodeLen:= 2;
  SamplesLen:= 10;
  AbsentValueLen:= 20;

  OutBytes[OutCounter]:= 47;
  OutCounter:= OutCounter + 1;
  OutBytes[OutCounter]:= 0;
  OutCounter:= OutCounter + 1;
  OutBytes[OutCounter]:= Ord('D');
  OutCounter:= OutCounter + 1;

  with DataChannel do begin
     wDLISName:= Trim(DLISName);
     wUnits:= Trim(Units);
     if wUnits = '' then wUnits:= '---';
     wRepCode:= Trim(RepCode);
     wSamples:= Trim(IntToStr(Samples));
     wAbsentValue:= Trim(AbsentValue);
     if wAbsentValue = '7FFFFFFF' then wAbsentValue:='4294967295';

     sDLISNameLen:= length(wDLISName);
     sUnitsLen:= length(wUnits);
     sRepCodeLen:= length(wRepCode);
     sSamplesLen:= length(wSamples);
     sAbsentValueLen:= length(wAbsentValue);

     for i:= 1 to DLISNameLen do begin
        if (sDLISNameLen >= i) And (wDLISName <> '') then begin
           OutBytes[OutCounter]:= Ord(wDLISName[i]);
           ch:= wDLISName[i];
        end
        else OutBytes[OutCounter]:= 0;
        OutCounter:= OutCounter + 1;
     end;
     for i:= 1 to UnitsLen do begin
        if (sUnitsLen >= i) And (wUnits <> '') then OutBytes[OutCounter]:= Ord(wUnits[i])
        else OutBytes[OutCounter]:= 0;
        OutCounter:= OutCounter + 1;
     end;
     for i:= 1 to RepCodeLen do begin
        if (sRepCodeLen >= i) And (wRepCode <> '') then OutBytes[OutCounter]:= Ord(wRepCode[i])
        else OutBytes[OutCounter]:= 0;
        OutCounter:= OutCounter + 1;
     end;
     for i:= 1 to SamplesLen do begin
        if (sSamplesLen >= i) And (wSamples <> '') then OutBytes[OutCounter]:= Ord(wSamples[i])
        else OutBytes[OutCounter]:= 0;
        OutCounter:= OutCounter + 1;
     end;
     for i:= 1 to AbsentValueLen do begin
        if (sAbsentValueLen >= i) And (wAbsentValue <> '') then OutBytes[OutCounter]:= Ord(wAbsentValue[i])
        else OutBytes[OutCounter]:= 0;
        OutCounter:= OutCounter + 1;
     end;
  end;
end;

function DataChannelToStr(DataChannel: TDataChannel): String;
var wStr: String;
begin
  wStr:= '';
  with DataChannel do
     wStr:= wStr + DLISName + ' ' + Units + ' ' + RepCode + ' ' + IntToStr(Samples) + ' ' + AbsentValue + Line;
  Result:= wStr;
end;

function ParseFrame(DataChannels: array of TDataChannel): TFrame;
var i, ChannelsCount: Word;
    Frame: TFrame;
    FrameStr: String20;
    DataCount: longWord;
begin
   DataCount:= 0;
   ChannelsCount:= length(DataChannels);
   insert('', Frame, 1);
   for i:=0 to ChannelsCount - 1 do begin
      FrameStr:= '';
      case DataChannels[i].RepCode of
        'F4': begin
                FrameStr:= FloatToStrF(FillSingle(Data[DataCount+3], Data[DataCount+2], Data[DataCount+1], Data[DataCount]), ffFixed, 10, 3);
                DataCount:= DataCount + 4;
              end;
        'F8': begin
                FrameStr:= FloatToStrF(FillDouble(Data[DataCount+7], Data[DataCount+6], Data[DataCount+5], Data[DataCount+4], Data[DataCount+3], Data[DataCount+2], Data[DataCount+1], Data[DataCount]), ffFixed, 10, 3);
                DataCount:= DataCount + 8;
              end;
        'I1', 'U1': begin
                       Frame[i]:= IntToStr(Data[DataCount]);
                       DataCount:= DataCount + 1;
                    end;
        'I2': begin
                 FrameStr:= IntToStr(FillInteger(Data[DataCount+1], Data[DataCount]));
                 DataCount:= DataCount + 2;
              end;
        'U2': begin
                 FrameStr:= IntToStr(FillWord(Data[DataCount+1], Data[DataCount]));
                 DataCount:= DataCount + 2;
              end;
        'U4': begin
                 FrameStr:= IntToStr(FillLongWord(Data[DataCount+3], Data[DataCount+2], Data[DataCount+1], Data[DataCount]));
                 DataCount:= DataCount + 4;
              end;
        'I4': begin
                 FrameStr:= IntToStr(FillLongInt(Data[DataCount+3], Data[DataCount+2], Data[DataCount+1], Data[DataCount]));
                 DataCount:= DataCount + 4;
              end
      end;
      insert(FrameStr, Frame, i + 1);
   end;
   Result:= Frame;
end;

function FrameToStr(Frame: TFrame): String;
var i, ChCount: Word;
    wStr: String;
begin
   ChCount:= length(Frame);
   wStr:= '';
   for i:= 0 to ChCount - 1 do wStr:= wStr + AddCharR(' ', Frame[i], 10);
   Result:= wStr + Line;
end;

function DataToStr(): String;
var len, i: Word;
    wStr: String;
begin
  wStr:= '';
  len:= length(Data);
  for i:=1 to len do
    if Data[i-1] > 0 then wStr:= wStr + Chr(Data[i-1]);
  Result:= wStr;
end;

procedure CopyRecord(RecType: Char; RecordLength: Word);
var i, StartIndex: Word;
begin
  OutBytes[OutCounter]:= (RecordLength + 1) And $00FF;
  OutCounter:= OutCounter + 1;
  OutBytes[OutCounter]:= (RecordLength + 1) >> 8;
  OutCounter:= OutCounter + 1;
  OutBytes[OutCounter]:= Ord(RecType);
  OutCounter:= OutCounter + 1;
  StartIndex:= 0;

  for i:=StartIndex to RecordLength - 1 do begin
    OutBytes[OutCounter]:= Data[i];
    OutCounter:= OutCounter + 1;
  end;
end;

procedure TBIN_DB.CloseAppClick(Sender: TObject);
begin
   BIN_DB.Close;
end;

procedure TBIN_DB.ConvertDataClick(Sender: TObject);
var fileLen, ProgressCounter: longWord;
    RecordLength: Word;
    RecordType: Char;
begin
  if OpenDialog1.Execute then begin
     FileName.Text:= OpenDialog1.FileName;
     setLength(DataChannels, 0);
     Bytes:= LoadByteArray(OpenDialog1.FileName);
     fileLen:= length(Bytes);
     SetLength(OutBytes, fileLen);
     ToolInfo.Text:= '';
     Counter:= 0;
     OutCounter:= 0;
     Progress.Position:= 0;
     Progress.Max:= fileLen;
     ProgressCounter:= 0;
     repeat
        RecordLength:= Bytes[Counter];
        Counter:= Counter + 1;
        RecordLength:= (RecordLength or (Bytes[Counter] shl 8)) - 1;
        Counter:= Counter + 1;
        RecordType:= Chr(Bytes[Counter]);
        Counter:= Counter + 1;
        GetData(RecordLength);
        if RecordType = 'P' then begin
           CopyRecord('P', RecordLength);
           ToolInfo.Text:= ToolInfo.Text + DataToStr + Line;
        end
        else if RecordType = 'M' then CopyRecord('M', RecordLength)
             else if RecordType = 'F' then CopyRecord('F', RecordLength)
                  else if RecordType = 'B' then
                  CopyRecord('B', RecordLength)
                       else if RecordType = 'D' then begin
                               ComposeDataChannelV3(ParseDataChannel(RecordLength));
                            end;
        ProgressCounter:= ProgressCounter + 1;
        Progress.Position:= Progress.Position + 1;
        if ProgressCounter > 100 then begin
           Progress.Position:= Counter;
           ProgressCounter:= 0;
        end;
     until Counter >= fileLen;
     SetLength(OutBytes, OutCounter);
     SaveByteArray(OutBytes, ReplaceText(OpenDialog1.FileName,'.bin_db','') + '_converted.bin_db');
     //ShowMessage('File converted');
  end;
end;

end.

