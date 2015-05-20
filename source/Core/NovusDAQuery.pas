unit NovusDAQuery;

interface

Uses
  uDARemoteDataAdapter, uDAMemDataTable, uDABin2DataStreamer, uRORemoteService,
  uRODL, uROTypes, Classes, DB,NovusUtilities, Dialogs,SysUtils, uDAInterfaces,
  uDAClasses, DataAbstract4_Intf, uDADataTable;

type
  TNovusDAQuery = class(TComponent)
  private
    fbPrepared : Boolean;
    fsSQLExecuteCommandMethodName: String;
    FsSQLGetDataMethodName: String;
    FSQL: tStringList;
    fbIncludeSchema: Boolean;
    fiMaxRecords: Integer;
    FRemoteService: TRORemoteService;
    FDataStreamer: TDABin2DataStreamer;
    FDARemoteDataAdapter: TDARemoteDataAdapter;
    FDADataTable: TDAMemDataTable;
    fbFetching: Boolean;
    fbFetchRequired: Boolean;
  protected
    function GetSQL: tStringList;
    procedure SetSQL(Value: tStringList);
    procedure SetRemoteService(Value: TRORemoteService);
    procedure ParseParams(var ASQL: string; AParams: TParams);
    function GetLocalSchema: TDASchema;
    procedure AfterScroll(DataTable: TDADataTable);
    procedure SetFetching(Value: Boolean);

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure Open;
    procedure ExecSQL;
    procedure Close;

    procedure Prepare;

    function GetVCLFields: TFields;

    property LocalSchema: TDASchema
      read GetLocalSchema;

    property DADataTable: TDAMemDataTable
      read FDADataTable
      write FDADataTable;

    property DARemoteDataAdapter: TDARemoteDataAdapter
       read FDARemoteDataAdapter;

    Published
      property MaxRecords: Integer
         read fiMaxRecords
         write fiMaxRecords;

      property IncludeSchema: Boolean
         read fbIncludeSchema
         write fbIncludeSchema;

      property SQL: tStringlist
        read GetSQL
        write SetSQL;

      property RemoteService: TRORemoteService
        read FRemoteService
        write SetRemoteService;

      property SQLExecuteCommandMethodName: String
        read fsSQLExecuteCommandMethodName
        write fsSQLExecuteCommandMethodName;

      property SQLGetDataMethodName: String
        read FsSQLGetDataMethodName
        write FsSQLGetDataMethodName;

      property Fetching: Boolean
         read fbFetching
         write SetFetching;

  end;

procedure Register;

implementation

constructor TNovusDAQuery.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  fbFetching := False;
  fbFetchRequired := False;
  
  fbPrepared := false;

  fsSQLGetDataMethodName := 'SQLGetData';
  fsSQLExecuteCommandMethodName := 'SQLExecuteCommand';

  FSQL := tStringlist.Create;
  fiMaxRecords := -1;

  fbIncludeSchema := True;
end;

destructor TNovusDAQuery.destroy;
begin
  FSQL.Free;

  if Assigned(FDARemoteDataAdapter) then FDARemoteDataAdapter.Free;
  if Assigned(FDADataTable) then FDADataTable.Free;
  if Assigned(FDataStreamer) then FDataStreamer.Free;

  inherited destroy;
end;

procedure TNovusDAQuery.Open;
Var
  loField: tDAField;
begin
 Try
   if SQL.text = '' then Exit;

   If fbPrepared = false then Prepare;

   FDADataTable.Active := True;
 Except
   Showmessage(TNovusUtilities.GetExceptMess);
 End;
end;

procedure TNovusDAQuery.ExecSQL;
begin
   if SQL.text = '' then Exit;

   with FDADataTable do
    begin
      Close;
      FDARemoteDataAdapter.UpdateDataCall.ParamByName('aSQLText').AsString := SQL.Text;

      FDARemoteDataAdapter.UpdateDataCall.Execute();
    end;
end;

procedure TNovusDAQuery.SetRemoteService(Value: TRORemoteService);
begin
  FRemoteService := Value;

  FDARemoteDataAdapter := TDARemoteDataAdapter.Create(NIL);
  FDADataTable := TDAMemDataTable.Create(NIL);

  FDADataTable.AfterScroll := AfterScroll;
  
  FDataStreamer := TDABin2DataStreamer.Create(NIL);

  FDARemoteDataAdapter.DataStreamer := FDataStreamer;

  FDADataTable.RemoteDataAdapter := FDARemoteDataAdapter;
  FDARemoteDataAdapter.RemoteService := FRemoteService;

  FDADataTable.LogicalName := 'DynamicDataset';

  with FDARemoteDataAdapter.GetDataCall do
    begin
      Default := False;
      MethodName := SQLGetDataMethodName;
      RefreshParams;
      ParamByName('aSQLText').AsString := '';
      ParamByName('aIncludeSchema').AsBoolean := fbIncludeSchema;
      ParamByName('aMaxRecords').AsInteger := -1;
    end;

  with FDARemoteDataAdapter.UpdateDataCall do
    begin
      Default := False;

      MethodName := SQLExecuteCommandMethodName;
      RefreshParams;

      ParamByName('aSQLText').AsString := '';
      ParamByName('Result').AsInteger := 0;
    end;
end;

procedure TNovusDAQuery.Close;
begin
  if Assigned(FDADataTable) then FDADataTable.Close;
end;

function TNovusDAQuery.GetSQL: tStringlist;
begin
  Result := FSQL;
end;

procedure TNovusDAQuery.SetSQL(Value: tStringList);
begin
  FSQL := Value;
end;

procedure TNovusDAQuery.ParseParams(var ASQL: string; AParams: TParams);
var
i, p: integer;
ident: string;
begin
  if Trim(ASQL) = '' then Exit;

  for i := 0 to Aparams.Count - 1 do
    begin
      ident := ':' + Aparams[i].Name;
      p := Pos(ident, ASQL);
      if p > 0 then
        begin
          Delete(ASQL, p, Length(ident));
          Insert(Aparams[i].AsString, ASQL, p);
        end;
  end;
end;

function TNovusDAQuery.GetLocalSchema: TDASchema;
begin
  Result := FDADataTable.LocalSchema;
end;


procedure TNovusDAQuery.Prepare;
begin
  Try
    if SQL.text = '' then Exit;

    with FDADataTable do
     begin
       Close;

       FDARemoteDataAdapter.GetDataCall.ParamByName('aIncludeSchema').AsBoolean := fbIncludeSchema;

       FDARemoteDataAdapter.GetDataCall.ParamByName('aSQLText').AsString := SQL.Text;

       MaxRecords := FiMaxRecords;
       
       FDARemoteDataAdapter.Fill([FDADataTable], True, fbIncludeSchema);
     end;

    fbPrepared := True;

 Except
   Showmessage(TNovusUtilities.GetExceptMess);
 End;
end;


procedure TNovusDAQuery.AfterScroll(
  DataTable: TDADataTable);
begin
end;

procedure TNovusDAQuery.SetFetching(Value: Boolean);
begin
  fbFetching := Value;

  fbFetchRequired := fbFetching;
end;

function TNovusDAQuery.GetVCLFields: TFields;
begin
  Result := FDADataTable.Dataset.Fields;
end;

procedure Register;
begin
  RegisterComponents('Novus Component Pack Remobjects DataAbstract', [TNovusDAQuery]);
end;


end.
