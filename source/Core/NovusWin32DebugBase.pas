unit NovusWin32DebugBase;

interface

uses Classes, Sysutils, Contnrs, Windows;

{$ALIGN 4}

const
  DbgHelpDll = 'dbghelp.dll';
  MaxStackDepth      = 99;
  Unwinding          = 2;
  UnwindingForExit   = 4;
  UnwindInProgress   = Unwinding or UnwindingForExit;
  DelphiException    = $0EEDFADE;
  DelphiReRaise      = $0EEDFADF;
  SYMBOL_PATH = '_NT_SYMBOL_PATH';
  ALTERNATE_SYMBOL_PATH = '_NT_ALT_SYMBOL_PATH';
  SYMOPT_CASE_INSENSITIVE  = $00000001;
  SYMOPT_UNDNAME           = $00000002;
  SYMOPT_DEFERRED_LOADS    = $00000004;
  SYMOPT_NO_CPP            = $00000008;
  SYMOPT_LOAD_LINES        = $00000010;
  SYMOPT_OMAP_FIND_NEAREST = $00000020;
  SYMOPT_DEBUG             = $80000000;

  MAX_SYMNAME_SIZE = 1024;


Type
  GetExceptionObjectProc = function(P: PExceptionRecord): Exception;


  pimagehlp_linerec = ^imagehlp_linerec;
  imagehlp_linerec = record
    SizeOfStruct: DWORD;           // set to sizeof(IMAGEHLP_LINE)
    Key: Pointer;                    // internal
    LineNumber: DWORD;             // line number in file
    FileName: PChar;               // full filename
    Address: DWORD;                // first instruction of line
  end;


  pimagehlp_symbolrec = ^imagehlp_symbolrec;
  imagehlp_symbolrec = record
    SizeOfStruct: DWORD;           // set to sizeof(IMAGEHLP_SYMBOL)
    Address: DWORD;                // virtual address including dll base address
    Size: DWORD;                   // estimated size of symbol, can be zero
    Flags: DWORD;                  // info about the symbols, see the SYMF defines
    MaxNameLength: DWORD;          // maximum size of symbol name in 'Name'
    Name: array[0..1] of char;                // symbol name (null terminated string)
  end;

  Address_Mode = (AddrMode1616, AddrMode1632, AddrModeReal, AddrModeFlat);


  TExceptionInformation = class;
  TStackTracer = class;

  TDelphiExceptionEvent = procedure (Sender: TObject; E: Exception; EI: TExceptionInformation; StackTracer: TStackTracer) of object;
  TSystemExceptionEvent = procedure (Sender: TObject; EI: TExceptionInformation; StackTracer: TStackTracer) of object;
  TDelphiSafeCallExceptionEvent = procedure (Sender: TObject; Target: TObject; E: Exception; EI: TExceptionInformation; StackTracer: TStackTracer) of object;
  TSystemSafeCallExceptionEvent = procedure (Sender: TObject; Target: TObject; EI: TExceptionInformation; var NotifyTarget: Boolean; StackTracer: TStackTracer) of object;

  pkdhelpRec = ^kdhelpRec;
  kdhelpRec = record
    Thread: DWORD;
    ThCallbackStack: DWORD;
    NextCallback: DWORD;
    FramePointer: DWORD;
    KiCallUserMode: DWORD;
    KeUserCallbackDispatcher: DWORD;
    SystemRangeStart: DWORD;
    ThCallbackBStore: DWORD;
    Reserved: array[0..7] of DWORD;
  end;

  pAddressRec = ^AddressRec;
  AddressRec = record
    Offset: DWORD;
    Segment: WORD;
    Mode: DWORD;
  end;

  pStackframeRec = ^StackframeRec;
  StackframeRec = record
    AddrPC: AddressRec;                // program counter
    AddrReturn: AddressRec;            // return address
    AddrFrame: AddressRec;             // frame pointer
    AddrStack: AddressRec;             // stack pointer
    FuncTableEntry: Pointer;        // pointer to pdata/fpo or NULL
    Params: array[0..3] of DWORD;   // possible arguments to the function
    bFar: LONGBOOL;                 // WOW far call
    bVirtual: LONGBOOL;             // is this a virtual frame?
    Reserved: array[0..2] of DWORD;
    KdHelp: kdhelprec;
    AddrBStore: AddressRec;            // backing store pointer
  end;
                     
  TStackFrame = class
  public
    ModuleName: string;
    CallAddress: Pointer;
    FunctionName: string;
    SourceName: string;
    LineNumber: Cardinal;
    procedure Assign(Source: TStackFrame);
  end;

  TStackFrames = class
  private
    FFrameList: TObjectList;
    function GetFrames(Index: Integer): TStackFrame;
    function GetCount: Integer;
  protected
    procedure AddFrame(AFrame: TStackFrame);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    function Clone: TStackFrames;
    property Count: Integer read GetCount;
    property Frames[Index: Integer]: TStackFrame read GetFrames; default;
  end;

  TStackTracer = class
  private
    FFrames: TStackFrames;
    procedure FillFunctionInfo(AFrame: TStackFrame);
    procedure InternalGetCallStack(pContext: PContext; Address: Pointer);
  protected
    procedure Prepare(pContext: PContext); virtual; abstract;
    function GetNextStackFrame(pContext: PContext): TStackFrame; virtual; abstract;
    function GetFunctionName(pFunc: Pointer): string; virtual; abstract;
    function GetSourceInfo(var nLine: Cardinal; pProc: Pointer): string; virtual; abstract;
  public
    constructor Create;
    destructor Destroy; override;
    function GetCallStack(EI: TExceptionInformation): TStackFrames;
    function GetCurrentCallStack: TStackFrames;
  end;

  TExceptionInformation = class
  private
    FExcContext: TContext;
    FExcRecord: TExceptionRecord;
  public
    constructor Create(ExcContext: TContext; ExcRecord: TExceptionRecord);
    property ExceptionContext: TContext read FExcContext;
    property ExceptionRecord: TExceptionRecord read FExcRecord;
  end;

  TDbgHelpStackTracer = class(TStackTracer)
  private
    FStack: StackframeRec;
    procedure LoadSym(pProc: Pointer);
    function GetSymbolSearchPath: string;
    procedure Init;
    procedure Uninit;
  protected
    procedure Prepare(pContext: PContext); override;
    function GetFunctionName(pFunc: Pointer): string; override;
    function GetSourceInfo(var nLine: Cardinal; pProc: Pointer): string; override;
    function GetNextStackFrame(pContext: PContext): TStackFrame; override;
  public
    constructor Create;
    destructor Destroy; override;
  end;

  TNovusWin32DebugBase = class(TComponent)
  private
    FbActive: Boolean;
    FStackTracer: TStackTracer;
    FLastExceptionInformation: TExceptionInformation;
    FOnDelphiException: TDelphiExceptionEvent;
    FOnSystemException: TSystemExceptionEvent;
    FOnSafeCallException: TSystemSafeCallExceptionEvent;
    FOnDelphiSafeCallException: TDelphiSafeCallExceptionEvent;
  protected
    procedure SetActive(const Value: Boolean);
    procedure DoDelphiException(E: Exception); dynamic;
    procedure SetStackTracer(const Value: TStackTracer);
    function GetStackTracer: TStackTracer;
    function GetLastDelphiException: Exception;
    function DoSystemSafeCallException(Target: TObject): Boolean; dynamic;
    procedure DoDelphiSafeCallException(Target: TObject; E: Exception); dynamic;
  public
    procedure ClearLastExceptionInformation;
    procedure NotifyException(ExcContext: PContext; ExcRecord: PExceptionRecord);
    procedure SetLastExceptionInfo(ExcContext: PContext; ExcRecord: PExceptionRecord);
    procedure DoSystemException; dynamic;
    property StackTracer: TStackTracer read GetStackTracer write SetStackTracer;
    property LastExceptionInformation: TExceptionInformation read FLastExceptionInformation;
    function NotifySafeCallException(Sender: TObject; ExcContext: PContext; ExcRecord: PExceptionRecord): HRESULT;
    constructor Create(AOwner: TComponent); override;
published
    property OnSystemException: TSystemExceptionEvent read FOnSystemException write FOnSystemException;
    property OnDelphiException: TDelphiExceptionEvent read FOnDelphiException write FOnDelphiException;
    property OnDelphiSafeCallException: TDelphiSafeCallExceptionEvent read FOnDelphiSafeCallException write FOnDelphiSafeCallException;
    property OnSystemSafeCallException: TSystemSafeCallExceptionEvent read FOnSafeCallException write FOnSafeCallException;
    property Active: Boolean read FbActive write SetActive default True;

  end;

  PREAD_PROCESS_MEMORY_ROUTINE = function(hProcess: THandle; lpBaseAddress: DWORD;
    lpBuffer: Pointer; nSize: DWORD; var lpNumberOfBytesRead: DWORD): Boolean; stdcall;
  PFUNCTION_TABLE_ACCESS_ROUTINE = function(hProcess: THandle; AddrBase: DWORD): Pointer; stdcall;
  PGET_MODULE_BASE_ROUTINE = function(hProcess: THandle; Address: DWORD): DWORD; stdcall;
  PTRANSLATE_ADDRESS_ROUTINE = function(hProcess, hThread: THandle; lpaddr: pAddressRec): DWORD; stdcall;

  function SymSetOptions(SymOptions: DWORD): DWORD; stdcall;
  function SymGetSymFromAddr(hProcess: THandle; dwAddr: DWORD; var dwDisplacement: DWORD; pSymbol: pimagehlp_symbolrec): Boolean; stdcall;
  function SymLoadModule(hProcess, hFile: THandle; ImageName, ModuleName: PChar; BaseOfDll, SizeOfDll :DWORD): DWORD; stdcall;
  function StackWalk(MachineType: DWORD; hProcess, hThread: THandle;
    StackFrame: pstackframerec; ContextRecord: Pointer;
    ReadMemoryRoutine: PREAD_PROCESS_MEMORY_ROUTINE;
    FunctionTableAccessRoutine: PFUNCTION_TABLE_ACCESS_ROUTINE;
    GetModuleBaseRoutine: PGET_MODULE_BASE_ROUTINE;
    TranslateAddress: PTRANSLATE_ADDRESS_ROUTINE): Integer; stdcall;
  function SymFunctionTableAccess(hProcess: THandle; AddrBase: DWORD): Pointer; stdcall;
  function SymGetModuleBase(hProcess: THandle; Address: DWORD): DWORD; stdcall;
  function SymGetLineFromAddr(hProcess: THandle; dwAddr: DWORD; var dwDisplacement: DWORD; Line: pimagehlp_linerec): Boolean; stdcall;
  function clSymInitialize(hProcess: THandle; UserSearchPath: string; fInvadeProcess: Boolean): Boolean; stdcall;
  function SymCleanup(hProcess: THandle): Boolean; stdcall;

implementation

uses NovusExceptions;

procedure TNovusWin32DebugBase.DoSystemException;
begin
  if Assigned(OnSystemException) then
  begin
    OnSystemException(Self, LastExceptionInformation, StackTracer);
  end;
end;

procedure TNovusWin32DebugBase.NotifyException(ExcContext: PContext; ExcRecord: PExceptionRecord);
begin
  SetLastExceptionInfo(ExcContext, ExcRecord);
  if (ExcRecord^.ExceptionCode <> DelphiException)
    and (ExcRecord^.ExceptionCode <> DelphiReRaise) then
  begin
    DoSystemException;
  end else
  begin
    DoDelphiException(GetLastDelphiException);
  end;
end;

procedure TNovusWin32DebugBase.SetLastExceptionInfo(ExcContext: PContext; ExcRecord: PExceptionRecord);
begin
  ClearLastExceptionInformation;
  FLastExceptionInformation := TExceptionInformation.Create(ExcContext^, ExcRecord^);
end;

procedure TNovusWin32DebugBase.SetStackTracer(const Value: TStackTracer);
begin
  FreeAndNil(FStackTracer);
  FStackTracer := Value;
end;

function TNovusWin32DebugBase.GetLastDelphiException: Exception;
begin
  Result := nil;
  if (LastExceptionInformation <> nil) and
    (LastExceptionInformation.ExceptionRecord.ExceptionCode = DelphiException) and
    (LastExceptionInformation.ExceptionRecord.NumberParameters > 1) then
  begin
    Result := Exception(LastExceptionInformation.ExceptionRecord.ExceptionInformation[1]);
  end;
end;

procedure TNovusWin32DebugBase.ClearLastExceptionInformation;
begin
  FreeAndNil(FLastExceptionInformation);
end;

procedure TNovusWin32DebugBase.DoDelphiException(E: Exception);
begin
  if Assigned(OnDelphiException) then
  begin
    OnDelphiException(Self, E, LastExceptionInformation, StackTracer);
  end;
end;

procedure TStackFrame.Assign(Source: TStackFrame);
begin
  ModuleName := Source.ModuleName;
  CallAddress := Source.CallAddress;
  FunctionName := Source.FunctionName;
  SourceName := Source.SourceName;
  LineNumber := Source.LineNumber;
end;

function TStackFrames.GetFrames(Index: Integer): TStackFrame;
begin
  Result := TStackFrame(FFrameList[Index]);
end;

function TStackFrames.GetCount: Integer;
begin
  Result := FFrameList.Count;
end;

procedure TStackFrames.AddFrame(AFrame: TStackFrame);
begin
  FFrameList.Add(AFrame);
end;

procedure TStackFrames.Clear;
begin
  FFrameList.Clear;
end;

function TStackFrames.Clone: TStackFrames;
var
  i: Integer;
  Frame: TStackFrame;
begin
  Result := TStackFrames.Create;
  for i := 0 to Count - 1 do
  begin
    Frame := TStackFrame.Create;
    Frame.Assign(Frames[i]);
    Result.AddFrame(Frame);
  end;
end;

constructor TStackFrames.Create;
begin
  FFrameList := TObjectList.Create;
end;

destructor TStackFrames.Destroy;
begin
  FFrameList.Free;
  inherited Destroy;
end;

procedure TStackTracer.FillFunctionInfo(AFrame: TStackFrame);
var
  sName: array[0..$FF] of char;
  mbi: MEMORY_BASIC_INFORMATION;
begin
	if (VirtualQuery(AFrame.CallAddress, mbi, sizeof(mbi)) = 0) or (mbi.State <> MEM_COMMIT) then
		Exit;
	if (GetModuleFileName(HMODULE(mbi.AllocationBase), @sName, 256) = 0) then
		Exit;
  AFrame.ModuleName := PChar(@sName);
  AFrame.FunctionName := GetFunctionName(AFrame.CallAddress);
  AFrame.CallAddress := Pointer(Integer(AFrame.CallAddress) - 5); //sizeof 'call xxx'
  AFrame.SourceName := '';
  AFrame.LineNumber := 0;
end;

procedure TStackTracer.InternalGetCallStack(pContext: PContext; Address: Pointer);
var
  i: Integer;
  Frame: TStackFrame;
begin
  FFrames.Clear();
  if (pContext = nil) then
    Exit;
  Prepare(pContext);
  for i := 0 to MaxStackDepth do
  begin
    Frame := GetNextStackFrame(pContext);
    if (Frame = nil) then
      Break;
    FillFunctionInfo(Frame);
    FFrames.AddFrame(Frame);
  end;
  if (Address <> nil) and (FFrames.Count = 0) then
  begin
    Frame := TStackFrame.Create();
    Frame.CallAddress := Address;
    FillFunctionInfo(Frame);
    FFrames.AddFrame(Frame);
  end;
end;

constructor TStackTracer.Create;
begin
  inherited Create;
  FFrames := TStackFrames.Create;
end;

destructor TStackTracer.Destroy;
begin
  FreeAndNil(FFrames);
  inherited Destroy();
end;

function TStackTracer.GetCallStack(EI: TExceptionInformation): TStackFrames;
begin
  InternalGetCallStack(@EI.ExceptionContext, EI.ExceptionRecord.ExceptionAddress);
  Result := FFrames;
end;


function TStackTracer.GetCurrentCallStack: TStackFrames;
var
  Context: TContext;
begin
  Context.ContextFlags := CONTEXT_FULL;
  GetThreadContext(GetCurrentThread, Context);
  InternalGetCallStack(@Context, nil);
  Result := FFrames;
end;

constructor TExceptionInformation.Create(ExcContext: TContext; ExcRecord: TExceptionRecord);
begin
  inherited Create();
  FExcContext := ExcContext;
  FExcRecord := ExcRecord;
end;

function TNovusWin32DebugBase.GetStackTracer: TStackTracer;
begin
  if (FStackTracer = nil) then
    FStackTracer := TDbgHelpStackTracer.Create();
  Result := FStackTracer;
end;

procedure TDbgHelpStackTracer.LoadSym(pProc: Pointer);
var
  sPath: array[0..4095] of char;
  mbi: MEMORY_BASIC_INFORMATION;
begin
	VirtualQuery(pProc, mbi, sizeof(mbi));
	GetModuleFileName(Cardinal(mbi.AllocationBase), sPath, MAX_PATH);
	SymLoadModule(GetCurrentProcess(), 0, sPath, nil, DWORD(mbi.AllocationBase), 0);
end;



procedure TDbgHelpStackTracer.Prepare(pContext: PContext);
begin
  ZeroMemory(@FStack, sizeof(stackframerec));
  FStack.AddrPC.Offset := pContext.Eip;
  FStack.AddrPC.Mode := DWORD(AddrModeFlat);
  FStack.AddrStack.Offset := pContext.Esp;
  FStack.AddrStack.Mode   := DWORD(AddrModeFlat);
  FStack.AddrFrame.Offset := pContext.Ebp;
  FStack.AddrFrame.Mode   := DWORD(AddrModeFlat);
end;

function TDbgHelpStackTracer.GetNextStackFrame(pContext: PContext): TStackFrame;
begin
  Result := nil;
  if (0 = StackWalk(IMAGE_FILE_MACHINE_I386,	GetCurrentProcess, GetCurrentThread,
      @FStack, nil{pContext}, nil, SymFunctionTableAccess, SymGetModuleBase, nil)) then
  begin
    Exit;
  end;
  Result := TStackFrame.Create();
  Result.CallAddress := Pointer(FStack.AddrPC.Offset);
end;

function TDbgHelpStackTracer.GetFunctionName(pFunc: Pointer): string;
var
  dwDisplacement: DWORD;
  buffer: array[0..$1FF] of BYTE;
  pSymbol: pimagehlp_symbolrec;
begin
  Result := '';
	pSymbol := pimagehlp_symbolrec(@buffer);
	pSymbol.SizeOfStruct := sizeof(imagehlp_symbolrec);
	pSymbol.MaxNameLength := sizeof(buffer) - sizeof(imagehlp_symbolrec) + 1;
	LoadSym(pFunc);
	if (SymGetSymFromAddr(GetCurrentProcess(), DWORD(pFunc), dwDisplacement, pSymbol)) then
  begin
    Result := PChar(@pSymbol.Name);
	end;
end;

function TDbgHelpStackTracer.GetSourceInfo(var nLine: Cardinal; pProc: Pointer): string;
var
  dwDisplacement: DWORD;
  buffer: array[0..$1FF] of BYTE;
  pLine: pimagehlp_linerec;
begin
  Result := '';
	pLine := pimagehlp_linerec(@buffer);
	pLine.SizeOfStruct := sizeof(imagehlp_linerec);
  LoadSym(pProc);
	if (SymGetLineFromAddr(GetCurrentProcess, DWORD(pProc), dwDisplacement, pLine)) then
  begin
		nLine := pLine.LineNumber;
    Result := pLine.FileName;
	end;
end;

function TDbgHelpStackTracer.GetSymbolSearchPath: string;
var
  sPath: array[0..MAX_PATH] of char;
  mbi: MEMORY_BASIC_INFORMATION;
  pProc: Pointer;
label l1;
begin
  asm
    mov eax, offset l1
    mov pProc, eax
  end;
l1:
  Result := '';
  if (GetEnvironmentVariable(symbol_path) <> '') then
    Result := GetEnvironmentVariable(SYMBOL_PATH) + ';';
  if (GetEnvironmentVariable(ALTERNATE_SYMBOL_PATH) <> '') then
    Result := Result + GetEnvironmentVariable(ALTERNATE_SYMBOL_PATH) + ';';
  if (GetEnvironmentVariable('SystemRoot') <> '') then
    Result := Result + GetEnvironmentVariable('SystemRoot') + ';';

	VirtualQuery(pProc, mbi, sizeof(mbi));
	GetModuleFileName(Cardinal(mbi.AllocationBase), sPath, MAX_PATH);
	StrRScan(sPath, '\')^ := #0;
	Result := Result + sPath + ';';

	GetModuleFileName(0, sPath, MAX_PATH);
	StrRScan(sPath, '\')^ := #0;
  Result := Result + sPath;
end;

procedure TDbgHelpStackTracer.Init;
begin
	SymSetOptions(SYMOPT_UNDNAME or SYMOPT_DEFERRED_LOADS or SYMOPT_LOAD_LINES);
	clSymInitialize(GetCurrentProcess, GetSymbolSearchPath(), True);
	SymSetOptions(SYMOPT_UNDNAME or SYMOPT_LOAD_LINES);
end;

procedure TDbgHelpStackTracer.Uninit;
begin
	SymCleanup(GetCurrentProcess);
end;

constructor TDbgHelpStackTracer.Create;
begin
  inherited Create;
  Init;
end;

destructor TDbgHelpStackTracer.Destroy;
begin
  Uninit;
  inherited Destroy;
end;

function SymLoadModule(hProcess, hFile: THandle; ImageName, ModuleName: PChar; BaseOfDll, SizeOfDll :DWORD): DWORD; stdcall; external DbgHelpDll;
function SymGetSymFromAddr(hProcess: THandle; dwAddr: DWORD; var dwDisplacement: DWORD; pSymbol: PIMAGEHLP_SYMBOLrec): Boolean; stdcall; external DbgHelpDll;
function SymSetOptions(SymOptions: DWORD): DWORD; stdcall; external DbgHelpDll;
function SymInitialize(hProcess: THandle; UserSearchPath: PChar; fInvadeProcess: Boolean): Boolean; stdcall; external DbgHelpDll;
function SymCleanup(hProcess: THandle): Boolean; stdcall; external DbgHelpDll;
function StackWalk(MachineType: DWORD; hProcess, hThread: THandle;
  StackFrame: PSTACKFRAMErec; ContextRecord: Pointer;
  ReadMemoryRoutine: PREAD_PROCESS_MEMORY_ROUTINE;
  FunctionTableAccessRoutine: PFUNCTION_TABLE_ACCESS_ROUTINE;
  GetModuleBaseRoutine: PGET_MODULE_BASE_ROUTINE;
  TranslateAddress: PTRANSLATE_ADDRESS_ROUTINE): Integer; stdcall; external DbgHelpDll;
function SymFunctionTableAccess(hProcess: THandle; AddrBase: DWORD): Pointer; stdcall; external DbgHelpDll;
function SymGetModuleBase(hProcess: THandle; Address: DWORD): DWORD; stdcall; external DbgHelpDll;
function SymGetLineFromAddr(hProcess: THandle; dwAddr: DWORD; var dwDisplacement: DWORD; Line: PIMAGEHLP_LINErec): Boolean; stdcall; external DbgHelpDll;

function clSymInitialize(hProcess: THandle; UserSearchPath: string; fInvadeProcess: Boolean): Boolean;
begin
  Result := SymInitialize(hProcess, PChar(UserSearchPath), fInvadeProcess);
end;

function TNovusWin32DebugBase.NotifySafeCallException(Sender: TObject; ExcContext: PContext; ExcRecord: PExceptionRecord): HRESULT;
var
  E: Exception;
begin
  Result := E_FAIL;
  SetLastExceptionInfo(ExcContext, ExcRecord);
  if (ExcRecord^.ExceptionCode <> DelphiException) then
  begin
    if (DoSystemSafeCallException(Sender)) then
    begin
      E := GetExceptionObjectProc(ExceptObjProc)(ExcRecord);
      Result := Sender.SafeCallException(E, ExcRecord^.ExceptionAddress);
      E.Free;
    end;
  end else
  begin
    DoDelphiSafeCallException(Sender, GetLastDelphiException);
  end;
end;

function TNovusWin32DebugBase.DoSystemSafeCallException(Target: TObject): Boolean;
begin
  Result := True;
  if (Assigned(OnSystemSafeCallException)) then
  begin
    OnSystemSafeCallException(Self, Target, LastExceptionInformation, Result, StackTracer);
  end;
end;

procedure TNovusWin32DebugBase.DoDelphiSafeCallException(Target: TObject; E: Exception);
begin
  if (Assigned(OnDelphiSafeCallException)) then
  begin
    OnDelphiSafeCallException(Self, Target, E, LastExceptionInformation, StackTracer);
  end;
end;

procedure TNovusWin32DebugBase.SetActive(const Value: Boolean);
begin
  if (FbActive <> Value) then
  begin
    if FbActive then
    begin
      TNovusWin32Exception.SetRootWin32Debugbase(NIL);
    end;
    FbActive := Value;
    if FbActive then
    begin
      TNovusWin32Exception.SetRootWin32Debugbase(self);
    end;
  end;
end;


constructor TNovusWin32Debugbase.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FbActive := True;

  TNovusWin32Exception.SetRootWin32Debugbase(self);
end;


end.
