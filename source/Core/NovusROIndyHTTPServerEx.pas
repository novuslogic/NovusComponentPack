unit NovusROIndyHTTPServerEx;

interface

uses
  SysUtils, Classes, uROClient, uROServer, uROIndyTCPServer, uROIndyHTTPServer,
  IdCustomHTTPServer, uROClientIntf;

type
  TNovusROIndyHTTPServerEx = class(TROIndyHTTPServer)
  private
    { Private declarations }

  protected
    { Protected declarations }
     procedure InternalServerCommandGet(AThread: TIdThreadClass;
       RequestInfo: TIdHTTPRequestInfo; ResponseInfo: TIdHTTPResponseInfo); override;

  public
    { Public declarations }
  published
    { Published declarations }

  end;

procedure Register;

implementation

procedure TNovusROIndyHTTPServerEx.InternalServerCommandGet(AThread: TIdThreadClass;
  RequestInfo: TIdHTTPRequestInfo; ResponseInfo: TIdHTTPResponseInfo);
begin
//
  inherited;
end;

procedure Register;
begin
  RegisterComponents('Novus Component Pack RemObjects SDK', [TNovusROIndyHTTPServerEx]);
end;

end.
