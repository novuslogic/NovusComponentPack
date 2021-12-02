unit NovusRODBSessionManager;

interface

uses
  SysUtils, Classes, uROClient, uROSessions, uDADBSessionManager, uDAInterfaces,
  uDAServerInterfaces, uDAFields;

type
  TAfterCheckSessionIsExpired = procedure(Sender: TObject; aSession : TROSession; aSessionIDString: String; Var IsExpired: Boolean) of object;

  TNovusRODBSessionManager = class(TDADBSessionManager)
  private
    { Private declarations }
    FAfterCheckSessionIsExpired: TAfterCheckSessionIsExpired;
    FNeedTransactionAction: Boolean;

    { Private declarations }
    procedure BeginTransaction(AConnection: IDAConnection);
    procedure CommitTransaction(AConnection: IDAConnection);
    procedure RollbackTransaction(AConnection: IDAConnection);
    function GetConnection: IDAConnection;

  protected
    { Protected declarations }
    function DoCheckSessionIsExpired(aSession : TROSession) : boolean; override;
    function DoFindSession(const aSessionID: TGUID; aUpdateTime: Boolean): TROSession; override;

  public
    { Public declarations }
  published
    { Published declarations }
     property OnAfterCheckSessionIsExpired: TAfterCheckSessionIsExpired
        read FAfterCheckSessionIsExpired
        write FAfterCheckSessionIsExpired;

    property SessionDuration;
    property SessionCheckInterval;


  end;

procedure Register;

implementation

uses
  uROTypes, uROClasses;

procedure Register;
begin
  RegisterComponents('Novus Component Pack Remobjects DataAbstract', [TNovusRODBSessionManager]);
end;

function TNovusRODBSessionManager.DoCheckSessionIsExpired(aSession : TROSession) : boolean;
Var
  FIsExpired: Boolean;
  FSessionIDString: String;
begin
  FIsExpired := inherited DoCheckSessionIsExpired(aSession);

  if Assigned(FAfterCheckSessionIsExpired) then
    begin
      FSessionIDString := GUIDToString(aSession.SessionID);

      FAfterCheckSessionIsExpired(Self, aSession, FSessionIDString, FIsExpired);
      Result := fIsExpired;
    end;

  Result := FIsExpired;
end;

function TNovusRODBSessionManager.DoFindSession(const aSessionID: TGUID; aUpdateTime: Boolean): TROSession;
var
  lDataSet: IDADataset;
  lData: Binary;
  lDataField: TDAField;
  lConnection: IDAConnection;
begin
  {$IFDEF FPC}
  if aUpdateTime then result := nil else //remove warning
  {$ENDIF}
  result := nil;

  lConnection := GetConnection;
  lDataSet := Schema.NewDataset(lConnection, GetSessionDataSet);
  lDataSet.ParamByName(FieldNameSessionID).AsString := DoConvertGUID(aSessionID);

  BeginTransaction(lConnection);
  try
    lDataSet.Open;
    if not lDataSet.EOF then begin
      result := DoCreateSession(aSessionID);
      result.Created := lDataSet.FieldByName(FieldNameCreated).AsDateTime;
      result.LastAccessed := lDataSet.FieldByName(FieldNameLastAccessed).AsDateTime;
      lData := Binary.Create;
      try
        lDataField := lDataSet.FieldByName(FieldNameData);

        if (lDataField.Size = 0) and (lDataField.BlobSize <> 0) then                // BG 02/12/2015 - fix to handle underlying blob returning Size = 0, which causes stream copies to be empty. - see SQLDirect
        begin
          lData.LoadFromString(lDataField.AsAnsiString);
        end
        else
        begin
          lDataField.SaveToStream(NewROStream(lData, false));                       // BG 02/12/2015 - default behaviour copied from ancestor
        end;
        //lData := BinaryFromVariant(lDataSet.FieldByName(FieldNameData).Value);
        //try
        lData.Seek(0, soFromBeginning);
        result.LoadFromStream(lData, true);
      finally
        lData.Free;
      end;
    end;
    lDataSet.Close();
    CommitTransaction(lConnection);
  except
    RollbackTransaction(lConnection);
    raise;
  end;
end;

procedure TNovusRODBSessionManager.BeginTransaction(AConnection: IDAConnection);
begin
  FNeedTransactionAction := AutoTransaction and not AConnection.InTransaction;
  if FNeedTransactionAction then AConnection.BeginTransaction;
end;

procedure TNovusRODBSessionManager.CommitTransaction(AConnection: IDAConnection);
begin
  if FNeedTransactionAction then AConnection.CommitTransaction;
end;

procedure TNovusRODBSessionManager.RollbackTransaction(AConnection: IDAConnection);
begin
 if FNeedTransactionAction then AConnection.RollbackTransaction;
end;

function TNovusRODBSessionManager.GetConnection: IDAConnection;
begin
  CheckProperties;
  Result := Schema.ConnectionManager.NewConnection(Connection);
end;

end.
