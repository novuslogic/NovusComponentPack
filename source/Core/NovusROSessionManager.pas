unit NovusROSessionManager;

interface

uses
  SysUtils, Classes, uROClient, uROSessions;

type
  TBeforeCheckSessionIsExpired = procedure(Sender: TObject; aSession : TROSession) of object;

  TAfterCreateSession2 = procedure(Sender: TObject; aSession : TROSession) of object;

  TAfterCheckSessionIsExpired = procedure(Sender: TObject; aSession : TROSession; aSessionIDString: String; Var IsExpired: Boolean) of object;

  TNovusROInMemorySessionManager = class(TROInMemorySessionManager)
  private
    { Private declarations }
    FBeforeCheckSessionIsExpired: TBeforeCheckSessionIsExpired;
    FAfterCheckSessionIsExpired: TAfterCheckSessionIsExpired;
  protected
    { Protected declarations }
    function DoCheckSessionIsExpired(aSession : TROSession) : boolean; override;
  public
    { Public declarations }
  published
    { Published declarations }
    property OnBeforeCheckSessionIsExpired: TBeforeCheckSessionIsExpired
        read FBeforeCheckSessionIsExpired
        write FBeforeCheckSessionIsExpired;

    property OnAfterCheckSessionIsExpired: TAfterCheckSessionIsExpired
        read FAfterCheckSessionIsExpired
        write FAfterCheckSessionIsExpired;

    property SessionDuration;
    property SessionCheckInterval;


  end;

  TNovusROEventSessionManager = class(TROEventSessionManager)
  private
    { Private declarations }
    FAfterCreateSession2: TAfterCreateSession2;
    FBeforeCheckSessionIsExpired: TBeforeCheckSessionIsExpired;
    FAfterCheckSessionIsExpired: TAfterCheckSessionIsExpired;
  protected
    { Protected declarations }
    function DoCheckSessionIsExpired(aSession : TROSession) : boolean; override;
  public
    { Public declarations }
     function CreateSession(const aSessionID: TGUID): TROSession;
     procedure CreateSession2(aSession: TROSession);
  published
    { Published declarations }
    property OnBeforeCheckSessionIsExpired: TBeforeCheckSessionIsExpired
        read FBeforeCheckSessionIsExpired
        write FBeforeCheckSessionIsExpired;

    property OnAfterCheckSessionIsExpired: TAfterCheckSessionIsExpired
        read FAfterCheckSessionIsExpired
        write FAfterCheckSessionIsExpired;

    property OnAfterCreateSession2: tAfterCreateSession2
      read FAfterCreateSession2
      write FAfterCreateSession2;

    property SessionDuration;
    property SessionCheckInterval;


  end;

procedure Register;

implementation

function TNovusROInMemorySessionManager.DoCheckSessionIsExpired(aSession : TROSession) : boolean;
Var
  FIsExpired: Boolean;
  FSessionIDString: String;
begin
  If Assigned(FBeforeCheckSessionIsExpired) then
    FBeforeCheckSessionIsExpired(Self, aSession);

  FIsExpired := inherited DoCheckSessionIsExpired(aSession);

  if Assigned(FAfterCheckSessionIsExpired) then
    begin
      FSessionIDString := GUIDToString(aSession.SessionID);

      FAfterCheckSessionIsExpired(Self, aSession, FSessionIDString, FIsExpired);
      Result := fIsExpired;
    end;

  Result := FIsExpired;
end;

function TNovusROEventSessionManager.DoCheckSessionIsExpired(aSession : TROSession) : boolean;
Var
  FIsExpired: Boolean;
  FSessionIDString: String;
begin
  If Assigned(FBeforeCheckSessionIsExpired) then
    FBeforeCheckSessionIsExpired(Self, aSession);

  FIsExpired := inherited DoCheckSessionIsExpired(aSession);

  if Assigned(FAfterCheckSessionIsExpired) then
    begin
      FSessionIDString := GUIDToString(aSession.SessionID);

      FAfterCheckSessionIsExpired(Self, aSession, FSessionIDString, FIsExpired);
      Result := fIsExpired;
    end;

  Result := FIsExpired;
end;


function TNovusROEventSessionManager.CreateSession(const aSessionID: TGUID): TROSession;
begin
  result := DoCreateSession(aSessionID);
end;

procedure TNovusROEventSessionManager.CreateSession2(aSession: TROSession);
begin
  If Assigned(FAfterCreateSession2) then
    FAfterCreateSession2(Self, aSession);

end;



procedure Register;
begin
  RegisterComponents('Novus Component Pack RemObjects SDK', [TNovusROInMemorySessionManager, TNovusROEventSessionManager]);
end;
end.
