unit TU.Common;

interface

uses
  System.SysUtils, Ntapi.ntdef, Ntapi.ntstatus;

type
  /// <summary>
  ///  Exception class for an OS error for which exact unsuccessful call
  ///  location is known.
  /// </summary>
  ELocatedOSError = class(EOSError)
  public
   ErrorOrigin: String;
   ErrorContext: TObject;
   constructor CreateLE(Code: Cardinal; Location: String;
     Context: TObject = nil);
   class function FormatErrorMessage(Location: String; Code: Cardinal): String;
   function ErrorIn(Origin: String; Code: Cardinal): Boolean; inline;
  end;

  /// <summary>
  ///   A generic wrapper for the result of a function that can fail but
  ///   is designed not to raise exceptions.
  /// </summary>
  CanFail<ResultType> = record
    Value: ResultType;
    IsValid: Boolean;
    ErrorCode: Cardinal;
    ErrorOrigin: String;
    ErrorContext: TObject;

    /// <summary>
    /// Initializes the wrapper. This is necessary since records are created on
    /// the stack and can contain arbitrary data.
    /// </summary>
    procedure Init(Context: TObject = nil);

    /// <returns> The value if it is valid. </returns>
    /// <exception cref="TU.Common.ELocatedOSError">
    ///  Can raise <see cref="TU.Common.ELocatedOSError"/> with the code stored
    ///  in the wrapper if the value is not valid.
    /// </exception>
    function GetValueOrRaise: ResultType;

    /// <summary> Saves the specified data as a valid value. </summary>
    /// <returns> Self. </returns>
    function Succeed(ResultValue: ResultType): CanFail<ResultType>; overload;
    function Succeed: CanFail<ResultType>; overload;
    class function SucceedWith(ResultValue: ResultType): CanFail<ResultType>; static;

    /// <summary> Checks and saves the last Win32 error. </summary>
    /// <returns>
    ///  The same value as <paramref name="Win32Ret"/> parameter.
    /// </returns>
    function CheckError(Win32Ret: LongBool; Where: String): LongBool;

    /// <summary>
    ///  This function is designed to use with API calls that need a probe
    ///  call to obtain the buffer size. It checks the size and the last
    ///  Win32 error. </summary>
    /// <returns>
    ///  <para><c>True</c> if the buffer size is save to use.</para>
    ///  <para><c>False</c> otherwise.</para>
    /// </returns>
    function CheckBuffer(BufferSize: Cardinal; Where: String): Boolean;

    /// <summary> Checks and saves NativeAPI status. </summary>
    /// <returns>
    ///  <para><c>True</c> if the call succeeded.</para>
    ///  <para><c>False</c> otherwise.</para>
    /// </returns>
    function CheckNativeError(Status: NTSTATUS; Where: String): Boolean;

    /// <summary>
    ///  Test the buffer wrapper for validity and copies it's error information.
    /// </summary>
    /// <returns> The buffer wrapper itself (<paramref name="Src"/>). </returns>
    function CopyResult(Src: CanFail<Pointer>): CanFail<Pointer>;

    function GetErrorMessage: String;
  end;

  TEventListener<T> = procedure(Value: T) of object;
  TEventListenerArray<T> = array of TEventListener<T>;

  /// <summary> Multiple source event handler. </summary>
  TEventHandler<T> = record
  strict private
    Listeners: TEventListenerArray<T>;
  public
    /// <summary>
    ///  Adds an event listener. The event listener can add and remove other
    ///  event listeners, but all these changes will take effect only on the
    ///  next call.
    /// </summary>
    /// <remarks>
    ///  Be careful with exceptions since they break the loop of <c>Invoke</c>
    ///  method.
    /// </remarks>
    procedure Add(EventListener: TEventListener<T>);
    function Delete(EventListener: TEventListener<T>): Boolean;
    function Count: Integer;

    /// <summary> Calls all event listeners. </summary>
    /// <remarks>
    ///  If an exception occurs some of the listeners may not be notified.
    /// </remarks>
    procedure Invoke(Value: T);

    /// <summary> Calls all event listeners if the value is valid. </summary>
    /// <remarks>
    ///  If an exception occurs some of the listeners may not be notified.
    /// </remarks>
    procedure InvokeIfValid(Value: CanFail<T>); inline;
  end;

  /// <summary>
  ///  Multiple source event handler compatible with TNotifyEvent from
  ///  <see cref="System.Classes"/>.
  /// </summary>
  TNotifyEventHandler = TEventHandler<TObject>;

  TEqualityCheckFunc<T> = function(Value1, Value2: T): Boolean;

  /// <summary> Multiple source event handler with cache support. </summary>
  TValuedEventHandler<T> = record
  strict private
    Event: TEventHandler<T>;
  public
    ComparisonFunction: TEqualityCheckFunc<T>;
    LastValuePresent: Boolean;
    LastValue: T;

    /// <summary>
    ///  Adds an event listener and calls it with the last known value.
    /// </summary>
    /// <remarks>
    ///  Be careful with exceptions since they break the loop of
    ///  <see cref="Invoke"/> method.
    /// </remarks>
    procedure Add(EventListener: TEventListener<T>;
      CallWithLastValue: Boolean = True);

    /// <summary> Deletes the specified event listener. </summary>
    /// <returns>
    ///  <para><c>True</c> if the event listener was found and deleted; </para>
    ///  <para><c>False</c> if there was no such event listener.</para>
    /// </returns>
    function Delete(EventListener: TEventListener<T>): Boolean;
    function Count: Integer; inline;

    /// <summary>
    ///  Notifies event listeners if the value differs from the previous one.
    /// </summary>
    /// <returns>
    ///  <para><c>True</c> if the value has actually changed; </para>
    ///  <para><c>False</c> otherwise. </para>
    /// </returns>
    function Invoke(Value: T): Boolean;

    /// <summary>
    ///  Notifies event listeners if the value is valid and differs from the
    ///  previous one.
    /// </summary>
    /// <returns>
    ///  <para><c>True</c> if the value has actually changed; </para>
    ///  <para><c>False</c> otherwise. </para>
    /// </returns>
    function InvokeIfValid(Value: CanFail<T>): Boolean; inline;
  end;

const
  BUFFER_LIMIT = 1024 * 1024 * 256; // 256 MB

// TODO: What about ERROR_BUFFER_OVERFLOW and ERROR_INVALID_USER_BUFFER?

function WinCheck(RetVal: LongBool; Where: String; Context: TObject = nil):
  LongBool; inline;
procedure WinCheckBuffer(BufferSize: Cardinal; Where: String;
  Context: TObject = nil); inline;
function WinTryCheckBuffer(BufferSize: Cardinal): Boolean; inline;
function NativeCheck(Status: NTSTATUS; Where: String;
  Context: TObject = nil): Boolean; inline;
procedure ReportStatus(Status: NTSTATUS; Where: String);

/// <symmary>
///  Converts a string that contains a decimal or a hexadecimal number to an
///  integer.
/// </summary>
/// <exception cref="EConvertError"> Can raise EConvertError. </exception>
function TryStrToUInt64Ex(S: String; out Value: UInt64): Boolean;
function StrToUIntEx(S: String; Comment: String): Cardinal; inline;
function StrToUInt64Ex(S: String; Comment: String): UInt64; inline;

/// <symmary>
///  Converts a number of 100ns intervals from 01.01.1601 to Delphi's
///  <c>TDateTime</c> type.
/// </summary>
function NativeTimeToLocalDateTime(NativeTime: Int64): TDateTime;

/// <symmary>
///  Converts Delphi's <c>TDateTime</c> to a number of 100ns intervals from
///  01.01.1601.
/// </summary>
function DateTimeToNative(LocalTime: TDateTime): Int64;

implementation

uses
  Winapi.Windows, System.DateUtils;

resourcestring
  OSError = '%s failed.' + #$D#$A#$D#$A +
    'Code 0x%x' + #$D#$A#$D#$A + '%s';

function WinCheck(RetVal: LongBool; Where: String; Context: TObject = nil):
  LongBool;
begin
  if not RetVal then
    raise ELocatedOSError.CreateLE(GetLastError, Where, Context);
  Result := True;
end;

function WinTryCheckBuffer(BufferSize: Cardinal): Boolean;
begin
  Result := (GetLastError = ERROR_INSUFFICIENT_BUFFER) and (BufferSize > 0) and
    (BufferSize <= BUFFER_LIMIT);

  if not Result and (BufferSize > BUFFER_LIMIT) then
    SetLastError(STATUS_IMPLEMENTATION_LIMIT);
end;

procedure WinCheckBuffer(BufferSize: Cardinal; Where: String;
  Context: TObject = nil);
begin
  if (GetLastError <> ERROR_INSUFFICIENT_BUFFER) or (BufferSize = 0) then
    raise ELocatedOSError.CreateLE(GetLastError, Where, Context);

  if BufferSize > BUFFER_LIMIT then
    raise ELocatedOSError.CreateLE(STATUS_IMPLEMENTATION_LIMIT, Where, Context);
end;

function NativeCheck(Status: NTSTATUS; Where: String; Context: TObject = nil):
  Boolean;
begin
  if not NT_SUCCESS(Status) then
    raise ELocatedOSError.CreateLE(Status, Where, Context);
  Result := True;
end;

procedure ReportStatus(Status: NTSTATUS; Where: String);
begin
  if not NT_SUCCESS(Status) then
    OutputDebugStringW(PWideChar(ELocatedOSError.FormatErrorMessage(Where,
      Status)));
end;

{ CanFail<ResultType> }

function CanFail<ResultType>.CheckBuffer(BufferSize: Cardinal;
  Where: String): Boolean;
begin
  IsValid := (GetLastError = ERROR_INSUFFICIENT_BUFFER) and (BufferSize > 0) and
    (BufferSize <= BUFFER_LIMIT);
  if not IsValid then
  begin
    ErrorOrigin := Where;
    if BufferSize > BUFFER_LIMIT then
      ErrorCode := STATUS_IMPLEMENTATION_LIMIT
    else
      ErrorCode := GetLastError;
  end;
  Result := IsValid;
end;

function CanFail<ResultType>.CheckError(Win32Ret: LongBool;
  Where: String): LongBool;
begin
  IsValid := Win32Ret;
  if not Win32Ret then
  begin
    ErrorCode := GetLastError;
    ErrorOrigin := Where;
  end;
  Result := IsValid;
end;

function CanFail<ResultType>.CheckNativeError(Status: NTSTATUS;
  Where: String): Boolean;
begin
  IsValid := NT_SUCCESS(Status);
  if not Result then
  begin
    ErrorCode := Status;
    ErrorOrigin := Where;
  end;
  Result := IsValid;
end;

function CanFail<ResultType>.CopyResult(
  Src: CanFail<Pointer>): CanFail<Pointer>;
begin
  Self.IsValid := Src.IsValid;
  Self.ErrorCode := Src.ErrorCode;
  Self.ErrorOrigin := Src.ErrorOrigin;
  Result := Src;
end;

function CanFail<ResultType>.GetErrorMessage: String;
begin
  Result := ELocatedOSError.FormatErrorMessage(ErrorOrigin, ErrorCode);
end;

function CanFail<ResultType>.GetValueOrRaise: ResultType;
begin
  if not IsValid then
    raise ELocatedOSError.CreateLE(ErrorCode, ErrorOrigin, ErrorContext);

  Result := Value;
end;

procedure CanFail<ResultType>.Init(Context: TObject = nil);
begin
  // We can't use FillChar(Self, SizeOf(Self), 0) since we may accidentally
  // overwrite a string reference (for example inside Self.Value record)
  // and compiler wouldn't know about it. That leads to memory leaks since
  // strings have reference counting mechanism.
  Self.IsValid := False;
  Self.ErrorCode := 0;
  Self.ErrorOrigin := '';
  Self.ErrorContext := Context;
end;

function CanFail<ResultType>.Succeed: CanFail<ResultType>;
begin
  IsValid := True;
  Result := Self;
end;

class function CanFail<ResultType>.SucceedWith(
  ResultValue: ResultType): CanFail<ResultType>;
begin
  Result.IsValid := True;
  Result.Value := ResultValue;
end;

function CanFail<ResultType>.Succeed(
  ResultValue: ResultType): CanFail<ResultType>;
begin
  IsValid := True;
  Value := ResultValue;
  Result := Self;
end;

{ ELocatedOSError }

constructor ELocatedOSError.CreateLE(Code: Cardinal;
  Location: String; Context: TObject = nil);
begin
  inherited Create(FormatErrorMessage(Location, Code));
  ErrorCode := Code;
  ErrorOrigin := Location;
  ErrorContext := Context;
end;

function ELocatedOSError.ErrorIn(Origin: String; Code: Cardinal): Boolean;
begin
  Result := (ErrorOrigin = Origin) and (ErrorCode = Code);
end;

class function ELocatedOSError.FormatErrorMessage(Location: String;
  Code: Cardinal): String;
begin
  // Lucky guess: small errors are most likely Win32Api errors, big ones are
  // most likely NativeApi errors. If we have an arror that is considered by
  // NT_SUCCESS as a success then it is a Win32Api error.

  if NT_SUCCESS(Code) then
    Result := Format(OSError, [Location, Code, SysErrorMessage(Code)])
  else
    Result := Format(OSError, [Location, Code, SysErrorMessage(Code,
      GetModuleHandle('ntdll.dll'))]);
end;

{ TEventHandler<T> }

procedure TEventHandler<T>.Add(EventListener: TEventListener<T>);
begin
  SetLength(Listeners, Length(Listeners) + 1);
  Listeners[High(Listeners)] := EventListener;
end;

function TEventHandler<T>.Count: Integer;
begin
  Result := Length(Listeners);
end;

function TEventHandler<T>.Delete(EventListener: TEventListener<T>): Boolean;
var
  i, position: integer;
begin
  position := -1;

  // Note: we can't simply use @A = @B for `procedure of object` since we should
  // distinguish methods linked to different object instances.
  // Luckily, System.TMethod overrides equality operator just as we need.
  for i := 0 to High(Listeners) do
    if System.PMethod(@@Listeners[i])^ = System.PMethod(@@EventListener)^ then
    begin
      position := i;
      Break;
    end;

  Result := position <> -1;

  if Result then
  begin
    for i := position + 1 to High(Listeners) do
      Listeners[i - 1] := Listeners[i];

    SetLength(Listeners, Length(Listeners) - 1);
  end;

  if not Result then
    OutputDebugString('Cannot delete event listener');
end;

procedure TEventHandler<T>.Invoke(Value: T);
var
  i: integer;
  ListenersCopy: TEventListenerArray<T>;
begin
  // Event listeners can modify the list while we process it, so we should make
  // a copy. All these modifications would take effect only on the next call.
  ListenersCopy := Copy(Listeners, 0, Length(Listeners));

  for i := 0 to High(ListenersCopy) do
    ListenersCopy[i](Value);
end;

procedure TEventHandler<T>.InvokeIfValid(Value: CanFail<T>);
begin
  if Value.IsValid then
    Invoke(Value.Value);
end;

{ TValuedEventHandler<T> }

procedure TValuedEventHandler<T>.Add(EventListener: TEventListener<T>;
  CallWithLastValue: Boolean);
begin
  Event.Add(EventListener);

  if CallWithLastValue and LastValuePresent then
    EventListener(LastValue);
end;

function TValuedEventHandler<T>.Count: Integer;
begin
  Result := Event.Count;
end;

function TValuedEventHandler<T>.Delete(
  EventListener: TEventListener<T>): Boolean;
begin
  Result := Event.Delete(EventListener);
end;

function TValuedEventHandler<T>.Invoke(Value: T): Boolean;
begin
  // Do not invoke on the same value twice
  if LastValuePresent and Assigned(ComparisonFunction) and
    ComparisonFunction(LastValue, Value) then
    Exit(False);

  Result := LastValuePresent;
  LastValuePresent := True;
  LastValue := Value;

  Event.Invoke(Value);
end;

function TValuedEventHandler<T>.InvokeIfValid(Value: CanFail<T>): Boolean;
begin
  if Value.IsValid then
    Result := Invoke(Value.Value)
  else
    Result := False;
end;

{ Conversion functions }

function TryStrToUInt64Ex(S: String; out Value: UInt64): Boolean;
var
  E: Integer;
begin
  if S.StartsWith('0x') then
    S := S.Replace('0x', '$', []);

  Val(S, Value, E);
  Result := (E = 0);
end;

function StrToUInt64Ex(S: String; Comment: String): UInt64;
const
  E_DECHEX = 'Invalid %s. Please specify a decimal or a hexadecimal value.';
begin
  if not TryStrToUInt64Ex(S, Result) then
    raise EConvertError.Create(Format(E_DECHEX, [Comment]));
end;

function StrToUIntEx(S: String; Comment: String): Cardinal;
begin
  {$R-}
  Result := StrToUInt64Ex(S, Comment);
  {$R+}
end;

const
  DAYS_FROM_1601 = 109205;
  NATIVE_TIME_SCALE = 864000000000; // 100ns in 1 day

function NativeTimeToLocalDateTime(NativeTime: Int64): TDateTime;
begin
  Result := NativeTime / NATIVE_TIME_SCALE - DAYS_FROM_1601;
  Result := TTimeZone.Local.ToLocalTime(Result);
end;

function DateTimeToNative(LocalTime: TDateTime): Int64;
begin
  Result := Trunc(NATIVE_TIME_SCALE * (DAYS_FROM_1601 +
    TTimeZone.Local.ToUniversalTime(LocalTime)));
end;

end.
