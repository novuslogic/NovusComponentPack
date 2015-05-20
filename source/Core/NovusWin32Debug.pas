unit NovusWin32Debug;

interface

uses Windows, classes, NovusExceptions, NovusWin32DebugBase;

Type

  TNovusWin32Debug =  class(TNovusWin32DebugBase)
  Private
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published

  end;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('Novus Component Pack Win32 Debug', [TNovusWin32Debug]);
end;


constructor TNovusWin32Debug.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
end;

destructor  TNovusWin32Debug.Destroy;
begin
  inherited Destroy;
end;

initialization
  TNovusWin32Exception.AttachExceptionHandlers;

end.


