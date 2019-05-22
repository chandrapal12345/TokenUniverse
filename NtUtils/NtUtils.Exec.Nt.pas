unit NtUtils.Exec.Nt;

interface

uses
  NtUtils.Exec;

type
  TExecRtlCreateUserProcess = class(TInterfacedObject, IExecMethod)
    function Supports(Parameter: TExecParam): Boolean;
    procedure Execute(ParamSet: IExecProvider);
  end;

implementation

uses
  Ntapi.ntdef, Ntapi.ntrtl, Ntapi.ntpsapi, Ntapi.ntobapi, NtUtils.Exceptions;

function RefStr(const Str: UNICODE_STRING; Present: Boolean): PUNICODE_STRING;
  inline;
begin
  if Present then
    Result := @Str
  else
    Result := nil;
end;

{ TExecRtlCreateUserProcess }

procedure TExecRtlCreateUserProcess.Execute(ParamSet: IExecProvider);
var
  ProcessParams: PRtlUserProcessParameters;
  ProcessInfo: TRtlUserProcessInformation;
  NtImageName, CurrDir, CmdLine, Desktop: UNICODE_STRING;
  Status: NTSTATUS;
begin
  // Convert the filename to native format
  Status := RtlDosPathNameToNtPathName_U_WithStatus(
    PWideChar(ParamSet.Application), NtImageName, nil, nil);

  if not NT_SUCCESS(Status) then
    raise ENtError.Create(Status, 'RtlDosPathNameToNtPathName_U_WithStatus');

  CmdLine.FromString(PrepareCommandLine(ParamSet));

  if ParamSet.Provides(ppCurrentDirectory) then
    CurrDir.FromString(ParamSet.CurrentDircetory);

  if ParamSet.Provides(ppDesktop) then
    Desktop.FromString(ParamSet.Desktop);

  // Construct parameters
  Status := RtlCreateProcessParametersEx(
    ProcessParams,
    NtImageName,
    nil,
    RefStr(CurrDir, ParamSet.Provides(ppCurrentDirectory)),
    @CmdLine,
    nil,
    nil,
    RefStr(Desktop, ParamSet.Provides(ppDesktop)),
    nil,
    nil,
    0
  );

  if not NT_SUCCESS(Status) then
  begin
    RtlFreeUnicodeString(NtImageName);
    raise ENtError.Create(Status, 'RtlCreateProcessParametersEx');
  end;

  // Create the process
  Status := RtlCreateUserProcess(
    NtImageName,
    OBJ_CASE_INSENSITIVE,
    ProcessParams,
    nil,
    nil,
    0,
    ParamSet.Provides(ppInheritHandles) and ParamSet.InheritHandles,
    0,
    ParamSet.Token,
    ProcessInfo
  );

  RtlDestroyProcessParameters(ProcessParams);
  RtlFreeUnicodeString(NtImageName);

  if not NT_SUCCESS(Status) then
    raise ENtError.Create(Status, 'RtlCreateUserProcess');

  // The process was created in a suspended state.
  // Resume it unless the caller explicitly states it should stay suspended.
  if not ParamSet.Provides(ppCreateSuspended) or
    not ParamSet.CreateSuspended then
    NtResumeThread(ProcessInfo.Thread, 0);

  NtClose(ProcessInfo.Thread);
  NtClose(ProcessInfo.Process);
end;

function TExecRtlCreateUserProcess.Supports(Parameter: TExecParam): Boolean;
begin
  case Parameter of
    ppParameters, ppCurrentDirectory, ppDesktop, ppToken, ppInheritHandles,
    ppCreateSuspended:
      Result := True;
  else
    Result := False;
  end;
end;

end.
