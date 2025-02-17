unit NovusROOlympiaSessionManager;

interface

Uses Classes, uROOlympiaSessionManager, uROSessions, uROTypes, uROClasses, SysUtils;

type
  TNovusROOlympiaSessionManager = class(TROOlympiaSessionManager)
  private
  protected
  public
    function CheckSessionIsExpired(aSession : TROSession) : boolean;
    function UpdateSession(aSession : TROSession) : boolean;
    function CreateSession2(aSession : TROSession) : boolean;
    function CheckSessionIsExists(aSessionID: String): boolean;
  end;

  function GUIDToAnsiString(const GUID: TGUID): Ansistring; // temp

procedure Register;

implementation

function GUIDToAnsiString(const GUID: TGUID): Ansistring;
begin
{$IFDEF UNICODE}
  SetLength(Result, 38);
  {$IFDEF DELPHIXE4UP}AnsiStrings.{$ENDIF}StrLFmt(PAnsiChar(Result),
    38,'{%.8x-%.4x-%.4x-%.2x%.2x-%.2x%.2x%.2x%.2x%.2x%.2x}',   // do not localize
    [GUID.D1, GUID.D2, GUID.D3, GUID.D4[0], GUID.D4[1], GUID.D4[2], GUID.D4[3],
    GUID.D4[4], GUID.D4[5], GUID.D4[6], GUID.D4[7]]);
{$ELSE}
  Result := GUIDToString(GUID);
{$ENDIF}
end;

function TNovusROOlympiaSessionManager.CheckSessionIsExpired(aSession : TROSession) : boolean;
begin
  Result := DoCheckSessionIsExpired(aSession);
end;

function TNovusROOlympiaSessionManager.UpdateSession(aSession : TROSession) : boolean;
var
  data : Binary;
begin
  data := Binary.Create;
  try
    aSession.SaveToStream(data, TRUE);

    SessionManager.UpdateSession(GUIDToAnsiString(aSession.SessionID), data);
  finally
    data.Free;
  end;
end;

function TNovusROOlympiaSessionManager.CreateSession2(aSession : TROSession) : boolean;
var
  data : Binary;
  fApplicationID_Ansi: AnsiString;
begin
  data := Binary.Create;
  try
    aSession.SaveToStream(data, TRUE);

    fApplicationID_Ansi:= GUIDToAnsiString(ApplicationID);

    SessionManager.CreateSession(GUIDToAnsiString(aSession.SessionID),fApplicationID_Ansi, data)
  finally
    data.Free;
  end;
end;

function TNovusROOlympiaSessionManager.CheckSessionIsExists(aSessionID: String) : boolean;
begin
  Result := SessionManager.CheckSession(aSessionID);
end;


procedure Register;
begin
  RegisterComponents('Novus Component Pack Remobjects DataAbstract', [TNovusROOlympiaSessionManager]);
end;


end.
