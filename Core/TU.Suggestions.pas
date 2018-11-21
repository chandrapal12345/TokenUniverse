unit TU.Suggestions;

interface

uses
  System.SysUtils;

procedure ShowErrorSuggestions(E: Exception);

implementation

uses
  Winapi.Windows, System.UITypes, Vcl.Dialogs, TU.NativeApi,
  TU.Common, TU.Tokens.Winapi, TU.Tokens, TU.Tokens.Types;

resourcestring
  TITLE_OS_ERROR = 'System Error';
  TITLE_CONVERT = 'Conversion error';
  TITLE_BUG = 'This is definitely a bug...';
  BUGTRACKER = #$D#$A#$D#$A'If you known how to reproduce this error please ' +
    'help the project by opening an issue on our GitHub page'#$D#$A +
    'https://github.com/diversenok/TokenUniverse';

  SUGGEST_TEMPLATE = #$D#$A#$D#$A'--- Suggestions ---'#$D#$A'%s';

  DUPLICATE_IMP = 'You can''t duplicate a token from a lower impersonation ' +
    'level to a higher one. Although, you can create a primary token from ' +
    'Impersonation and Delegation ones. If you are working with linked ' +
    'tokens you can obtain a primary linked token if you have ' +
    '`SeTcbPrivilege` privilege.';

  WTS_QUERY_TOKEN_PRIV = 'WTSQueryUserToken requires SeTcbPrivilege.';
  WTS_QUERY_TOKEN_NO_TOKEN = 'You can''t query a token of a session that ' +
    'doesn''t belong to any user.';

  RESTCICT_ACCESS = 'The hande need to grant `Duplicate` access to create ' +
    ' resticted tokens.';

  GETTER_QUERY = 'You need `Query` access right to obtain this information ' +
    'from the token';
  GETTER_QUERY_SOURCE = 'You need `Query Source` access right to obtain ' +
    'this information from the token';

  SETTER_DEFAULT = '`Adjust default` access right is required to change this ' +
  'information class for the token';
  SETTER_SESSION = 'To change the session of a token you need to ' +
    'have SeTcbPrivilege and also `Adjust SessionId` and `Adjust default` '+
    'access rights for the token.';
  SETTER_INTEGRITY_RAISE = 'To raise the integrity level of a token you need to ' +
    'have SeTcbPrivilege.';
  SETTER_UIACCESS_TCB = 'You need to have SeTcbPrivilege to enable UIAccess flag.';
  SETTER_POLICY_TCB = 'Changing of mandatory integrity policy requires SeTcbPrivilege.';
  SETTER_PRIVILEGES_ACCESS = 'You need to have `Adjust privileges` access ' +
    'right for the token.';
  SETTER_PRIVILEGES_OTHER = 'You can''t enable some privileges if the ' +
   'integrity level of the token is too low.';
  SETTER_GROUPS_ACCESS = 'This action requires `Adjust groups` access right.';
  SETTER_GROUPS_MODIFY = 'You can''t disable `Mandatory` groups ' +
    'just like you can''t enable `Use for deny only` groups.';

  ACTION_ASSIGN_NOT_SUPPORTED = 'A token can be assigned only on an early ' +
    'stage of a process lifetime. Try this action on a newly created ' +
    'suspended process.';
  ACTION_ASSIGN_PRIVILEGE = '`SeAssignPrimaryTokenPrivilege` is required to ' +
    'assign tokens that are not derived from your current token. ';
  ACTION_ASSIGN_TYPE = 'Only primary token can be assigned to a process';

function SuggestConstructor(E: ELocatedOSError): String;
begin
  if (E.ErrorOrigin = 'NtDuplicateToken') and
    (E.ErrorCode = STATUS_BAD_IMPERSONATION_LEVEL) then
    Exit(DUPLICATE_IMP);

  if E.ErrorOrigin = 'WTSQueryUserToken' then
  begin
    if E.ErrorCode = ERROR_PRIVILEGE_NOT_HELD then
      Exit(WTS_QUERY_TOKEN_PRIV);

    if E.ErrorCode = ERROR_NO_TOKEN then
      Exit(WTS_QUERY_TOKEN_NO_TOKEN);
  end;

  if (E.ErrorOrigin = 'CreateRestricted') and
    (E.ErrorCode = ERROR_ACCESS_DENIED)  then
    Exit(RESTCICT_ACCESS);
end;

function SuggestGetter(E: ELocatedOSError): String;
begin
  if E.ErrorCode = ERROR_ACCESS_DENIED then
  begin
    if E.ErrorOrigin = GetterMessage(TokenSource) then
      Exit(GETTER_QUERY_SOURCE);

    if E.ErrorOrigin.StartsWith('GetTokenInformation:') then
      Exit(GETTER_QUERY);
  end;
end;

function SuggestSetter(E: ELocatedOSError): String;
begin
  if E.ErrorCode = ERROR_ACCESS_DENIED then
  begin
    if E.ErrorOrigin = SetterMessage(TokenSessionId) then
      Exit(SETTER_SESSION);

    if E.ErrorOrigin = SetterMessage(TokenIntegrityLevel) then
      Exit(SETTER_DEFAULT);
  end;

  if E.ErrorCode = ERROR_PRIVILEGE_NOT_HELD then
  begin
    if E.ErrorOrigin = SetterMessage(TokenSessionId) then
      Exit(SETTER_SESSION);

    if E.ErrorOrigin = SetterMessage(TokenIntegrityLevel) then
      Exit(SETTER_INTEGRITY_RAISE);

    if E.ErrorOrigin = SetterMessage(TokenUIAccess) then
      Exit(SETTER_UIACCESS_TCB);

    if E.ErrorOrigin = SetterMessage(TokenMandatoryPolicy) then
      Exit(SETTER_POLICY_TCB);
  end;

  if E.ErrorOrigin = 'AdjustTokenPrivileges' then
  begin
    if E.ErrorCode = ERROR_ACCESS_DENIED then
      Exit(SETTER_PRIVILEGES_ACCESS);

    if E.ErrorCode = ERROR_NOT_ALL_ASSIGNED then
      Exit(SETTER_PRIVILEGES_OTHER);
  end;

  if E.ErrorOrigin = 'AdjustTokenGroups' then
  begin
    if E.ErrorCode = ERROR_ACCESS_DENIED then
      Exit(SETTER_GROUPS_ACCESS);

    if E.ErrorCode = ERROR_CANT_ENABLE_DENY_ONLY then
      Exit(SETTER_GROUPS_MODIFY);

    if E.ErrorCode = ERROR_CANT_DISABLE_MANDATORY then
      Exit(SETTER_GROUPS_MODIFY);
  end;

  if E.ErrorOrigin = 'NtSetInformationProcess#ProcessAccessToken' then
  begin
   if E.ErrorCode = STATUS_NOT_SUPPORTED then
     Exit(ACTION_ASSIGN_NOT_SUPPORTED);

   if E.ErrorCode = STATUS_PRIVILEGE_NOT_HELD then
     Exit(ACTION_ASSIGN_PRIVILEGE);

   if E.ErrorCode = STATUS_BAD_IMPERSONATION_LEVEL then
     Exit(ACTION_ASSIGN_TYPE);
  end;
end;

function SuggestAll(E: ELocatedOSError): String;
begin
  Result := SuggestGetter(ELocatedOSError(E));
  if Result <> '' then
    Exit(Format(SUGGEST_TEMPLATE, [Result]));

  Result := SuggestSetter(ELocatedOSError(E));
  if Result <> '' then
    Exit(Format(SUGGEST_TEMPLATE, [Result]));

  Result := SuggestConstructor(ELocatedOSError(E));
  if Result <> '' then
    Exit(Format(SUGGEST_TEMPLATE, [Result]));

end;

procedure ShowErrorSuggestions(E: Exception);
begin
  if (E is EAccessViolation) or (E is EInvalidPointer) then
    TaskMessageDlg(TITLE_BUG, E.Message + BUGTRACKER, mtError, [mbOk], 0)
  else if E is EConvertError then
    TaskMessageDlg(TITLE_CONVERT, E.Message, mtError, [mbOk], 0)
  else if E is ELocatedOSError then
    TaskMessageDlg(TITLE_OS_ERROR, E.Message + SuggestAll(ELocatedOSError(E)),
      mtError, [mbOk], 0)
  else
    TaskMessageDlg(E.ClassName, E.Message, mtError, [mbOk], 0);
end;

end.
