unit NovusROSessionManager;

interface

uses
  SysUtils, Classes, uROClient, uROSessions;

type
  TBeforeCheckSessionIsExpired = procedure(Sender: TObject; aSession : TROSession) of object;
  TAfterCheckSessionIsExpired = procedure(Sender: TObject; aSession : TROSession; aSessionIDString: String; Var IsExpired: Boolean) of object;

  TNovusROSessionManager = class(TROInMemorySessionManager)
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

procedure Register;

implementation

function TNovusROSessionManager.DoCheckSessionIsExpired(aSession : TROSession) : boolean;
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

procedure Register;
begin
  RegisterComponents('Novus Component Pack RemObjects SDK', [TNovusROSessionManager]);
end;

end.
