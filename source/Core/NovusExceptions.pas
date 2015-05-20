unit NovusExceptions;

interface

uses
  Classes, Sysutils, Contnrs, Windows, NovusWin32DebugBase;

const
  HackSize = 11;

Type
  PclExcFrame = ^TclExcFrame;
  TclExcFrame = record
    next: PclExcFrame;
    desc: Pointer;
    safe_place: Pointer;
    safe_ebp: DWORD;
  end;

  PExcFrame = ^TExcFrame; //from system.pas
  TExcFrame = record
    next: PExcFrame;
    desc: Pointer;
    hEBP: Pointer;
    case Integer of
    0:  ( );
    1:  ( ConstructedObject: Pointer );
    2:  ( SelfOfMethod: Pointer );
  end;


  TNovusWin32Exception = class
  private
  public
     class procedure AttachMainExceptionHandler;
     class function  GetFirstDelphiExcepionHandler: Pointer;
     class procedure ExtractOldHandler(pProc: Pointer; pProcCode: Pointer);
     class procedure WriteNewHandler(pProc: Pointer; pNewProc: Pointer);
     class function GetExceptionHandler(ExcFrame: TExcFrame): Pointer;
     class procedure AttachHandleAnyExceptionHandler;
     class function GetTopExceptionHandler: Pointer;
     class procedure AttachExceptionHandlers;
     class procedure AttachOnExceptionHandler;
     class procedure AttachSafeCallExceptionHandler; safecall;
     class procedure SetRootWin32Debugbase(ANovusWin32DebugBase: tNovusWin32DebugBase);
  end;

implementation

threadvar
  RootWin32DebugBase: TNovusWin32DebugBase;

var
  pOldExceptionHandlerCode: array[0..20] of Byte;
  pOldHandleAnyExceptionCode: array[0..20] of Byte;
  pOldHandleOnExceptionCode: array[0..20] of Byte;
  pOldHandleAutoExceptionCode: array[0..20] of Byte;

procedure ExWatcherProcImpl(ExcContext: PContext; ExcRecord: PExceptionRecord); stdcall;
begin
  if (ExcRecord^.ExceptionFlags and UnwindInProgress = 0) then
  begin
    if (RootWin32DebugBase <> nil) then
    begin
      RootWin32DebugBase.NotifyException(ExcContext, ExcRecord);
    end;
  end;
end;

procedure DefaultHandler(excPtr: PExceptionRecord; errPtr: Pointer; ctxPtr: PContext; dspPtr: Pointer); stdcall;
asm
  push esi
  push ebx
  mov ebx, excPtr
  test [ebx].TExceptionRecord.ExceptionFlags, 1
  jnz @@l5
  test [ebx].TExceptionRecord.ExceptionFlags, UnwindInProgress
  jz @@l2
  jmp @@l5
@@l2:
//  push 0
//  push ebx
//  push offset @@un23
//  push errPtr
//  call RtlUnwindProc
@@un23:
  mov esi, ctxPtr
  mov ebx, errPtr
  mov [esi + $C4], ebx {[esi].TContext.Esp}
  mov eax, [ebx].TclExcFrame.safe_place
  mov [esi].TContext.Eip, eax
  mov eax, [ebx].TclExcFrame.safe_ebp
  mov [esi + $B4], eax {[esi].TContext.Ebp}
  xor eax, eax
  jmp @@l6
@@l5:
  mov eax, 1
@@l6:
  pop ebx
  pop esi
end;


procedure ExceptHandler;
asm
  {eax - pOldProcCode}
  push ebp
  mov ebp, esp
  push eax

  push ebp
  push offset @@l1 //safe place
  push offset DefaultHandler
  push fs:[0]
  mov fs:[0], esp

  push [ebp + 8]
  push [ebp + 16]
  call ExWatcherProcImpl
@@l1:
  pop fs:[0]
  add esp, 12
  pop eax
  mov esp, ebp
  pop ebp
  jmp eax
end;

procedure ExceptionHandler;
asm
  lea eax, pOldExceptionHandlerCode
  jmp ExceptHandler
end;


procedure HandleAnyException;
asm
  lea eax, pOldHandleAnyExceptionCode
  jmp ExceptHandler
end;

procedure HandleOnException;
asm
  lea eax, pOldHandleOnExceptionCode
  jmp ExceptHandler
end;


class procedure TNovusWin32Exception.AttachMainExceptionHandler;
var
  pOldExceptionHandler: Pointer;
begin
  pOldExceptionHandler := GetFirstDelphiExcepionHandler;
  ExtractOldHandler(pOldExceptionHandler, @pOldExceptionHandlerCode[0]);
  WriteNewHandler(pOldExceptionHandler, @ExceptionHandler);
end;

class procedure TNovusWin32Exception.SetRootWin32Debugbase;
begin
  RootWin32DebugBase := aNovusWin32DebugBase;
end;

class function TNovusWin32Exception.GetFirstDelphiExcepionHandler: Pointer;
asm
  mov eax, fs:[0]
  mov ebx, eax
@@loop:
  cmp [eax].TExcFrame.next, -1
  je @@last_handler
  mov ebx, eax
  mov eax, [eax].TExcFrame.next
  jmp @@loop
@@last_handler:
  mov eax, ebx
  call GetExceptionHandler
end;

class procedure TNovusWin32Exception.ExtractOldHandler(pProc: Pointer; pProcCode: Pointer);
asm
  mov eax, ecx
  xchg eax, edx
  {eax - pProc, edx - pProcCode}
  push esi
  push edi
  mov ecx, HackSize
  mov esi, eax
  mov edi, edx
  rep movsb
  mov byte ptr [edi], $E9 //jmp
  add eax, HackSize
  sub eax, edi
  sub eax, 5 //sizeof(jmp xxx)
  mov dword ptr [edi + 1], eax
  pop edi
  pop esi
end;

class procedure TNovusWin32Exception.WriteNewHandler(pProc: Pointer; pNewProc: Pointer);
var
  mbi: TMemoryBasicInformation;
  OldProtect: Cardinal;
begin
  VirtualQuery(pProc, mbi, sizeof(mbi));
  VirtualProtect(mbi.BaseAddress, mbi.RegionSize, PAGE_EXECUTE_READWRITE, OldProtect);
  asm
    mov eax, pProc
    mov ebx, pNewProc
    mov byte ptr [eax], $E9 //jmp
    sub ebx, eax
    sub ebx, 5 //sizeof(jmp xxx)
    mov dword ptr [eax + 1], ebx
  end;
  VirtualProtect(mbi.BaseAddress, mbi.RegionSize, OldProtect, OldProtect);
end;

class function TNovusWin32Exception.GetExceptionHandler(ExcFrame: TExcFrame): Pointer;
asm
  {eax - ExcFrame}
  mov eax, [eax].TExcFrame.desc
  cmp byte ptr [eax], $E9 //jmp
  jne @@exit
  mov ebx, [eax + 1]
  add eax, ebx
  add eax, 5 //sizeof(jmp xxx)
@@exit:
end;

function HandleAutoProcImpl(Sender: TObject; ExcContext: PContext; ExcRecord: PExceptionRecord): HRESULT; stdcall;
begin
  Result := E_FAIL;
  if (ExcRecord^.ExceptionFlags and UnwindInProgress = 0) then
  begin
    if (RootWin32DebugBase <> nil) then
    begin
      Result := RootWin32DebugBase.NotifySafeCallException(Sender, ExcContext, ExcRecord);
    end;
  end;
end;

procedure HandleAutoException;
asm
  push ebp
  mov ebp, esp

  push ebp //safe stack frame
  push offset @@l1 //safe place
  push offset DefaultHandler
  push fs:[0]
  mov fs:[0], esp

  mov eax, [ebp + 12]
  mov eax, [eax].TExcFrame.SelfOfMethod

  push [ebp + 8]
  push [ebp + 16]
  push eax
  call HandleAutoProcImpl
  mov ebx, eax //Don't work now
@@l1:
  pop fs:[0]
  add esp, 12
  mov esp, ebp
  pop ebp
  lea eax, pOldHandleAutoExceptionCode
  jmp eax
end;

class procedure TNovusWin32Exception.AttachHandleAnyExceptionHandler;
var
  pOldHandleAnyException: Pointer;
begin
  try
    pOldHandleAnyException := GetTopExceptionHandler;
    ExtractOldHandler(pOldHandleAnyException, @pOldHandleAnyExceptionCode[0]);
    WriteNewHandler(pOldHandleAnyException, @HandleAnyException);
  except
  end;
end;

class function TNovusWin32Exception.GetTopExceptionHandler: Pointer;
asm
  mov eax, fs:[0]
  call GetExceptionHandler
end;

class procedure TNovusWin32Exception.AttachOnExceptionHandler;
var
  pOldHandleOnException: Pointer;
begin
  try
    pOldHandleOnException := GetTopExceptionHandler();
    ExtractOldHandler(pOldHandleOnException, @pOldHandleOnExceptionCode[0]);
    WriteNewHandler(pOldHandleOnException, @HandleOnException);
  except
    on E: Exception do ;
  end;
end;


class procedure TNovusWin32Exception.AttachSafeCallExceptionHandler; safecall;
var
  pOldHandleAutoException: Pointer;
begin
  pOldHandleAutoException := GetTopExceptionHandler;
  ExtractOldHandler(pOldHandleAutoException, @pOldHandleAutoExceptionCode[0]);
  WriteNewHandler(pOldHandleAutoException, @HandleAutoException);
end;


class procedure TNovusWin32Exception.AttachExceptionHandlers;
begin
  ZeroMemory(@pOldExceptionHandlerCode[0], 21);
  ZeroMemory(@pOldHandleAnyExceptionCode[0], 21);
  ZeroMemory(@pOldHandleOnExceptionCode[0], 21);
  ZeroMemory(@pOldHandleAutoExceptionCode[0], 21);

  TNovusWin32Exception.AttachMainExceptionHandler;
  TNovusWin32Exception.AttachHandleAnyExceptionHandler;
  TNovusWin32Exception.AttachOnExceptionHandler;
  TNovusWin32Exception.AttachSafeCallExceptionHandler;
end;


end.





