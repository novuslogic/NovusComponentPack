unit NovusROOlympiaSessionManager;

interface

Uses Classes, uROOlympiaSessionManager, uROSessions;

type
  TNovusROOlympiaSessionManager = class(TROOlympiaSessionManager)
  private
  protected
  public
    function CheckSessionIsExpired(aSession : TROSession) : boolean;
  end;

procedure Register;

implementation

function TNovusROOlympiaSessionManager.CheckSessionIsExpired(aSession : TROSession) : boolean;
begin
  Result := DoCheckSessionIsExpired(aSession);
end;

procedure Register;
begin
  RegisterComponents('Novus Component Pack Remobjects DataAbstract', [TNovusROOlympiaSessionManager]);
end;


end.
