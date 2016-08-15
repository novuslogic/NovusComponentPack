unit NovusROOlympiaSessionManager;

interface

Uses Classes, uROOlympiaSessionManager, uROSessions, uROTypes, uROClasses;

type
  TNovusROOlympiaSessionManager = class(TROOlympiaSessionManager)
  private
  protected
  public
    function CheckSessionIsExpired(aSession : TROSession) : boolean;
    function UpdateSession(aSession : TROSession) : boolean;
    function CreateSession2(aSession : TROSession) : boolean;
  end;

procedure Register;

implementation

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



procedure Register;
begin
  RegisterComponents('Novus Component Pack Remobjects DataAbstract', [TNovusROOlympiaSessionManager]);
end;


end.
