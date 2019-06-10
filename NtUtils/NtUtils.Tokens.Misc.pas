unit NtUtils.Tokens.Misc;

interface

uses
  Winapi.WinNt, Ntapi.ntseapi, NtUtils.Exceptions, NtUtils.Security.Sid;

{ Error formatting }

// Format error locations for querying/setting token information
function NtxFormatTokenQuery(InfoClass: TTokenInformationClass): String;
function NtxFormatTokenSet(InfoClass: TTokenInformationClass): String;

{ Allocations }

// Prepare PTokenPrivileges
function NtxpAllocPrivileges(Privileges: TLuidDynArray;
  Attribute: Cardinal): PTokenPrivileges;
function NtxpAllocPrivileges2(Privileges: TPrivilegeArray): PTokenPrivileges;

// Prepare PTokenGroups
function NtxpAllocGroups(Sids: ISidArray; Attribute: Cardinal): PTokenGroups;
function NtxpAllocGroups2(Groups: TGroupArray): PTokenGroups;

implementation

uses
  System.TypInfo;

{ Error formatting }

function NtxFormatTokenQuery(InfoClass: TTokenInformationClass): String;
begin
  // Use the name of the info class from the enumeration definition
  Result := 'NtQueryInformationToken [' +
    GetEnumName(TypeInfo(TTokenInformationClass), Integer(InfoClass)) + ']';
end;

function NtxFormatTokenSet(InfoClass: TTokenInformationClass): String;
begin
  // Use the name of the info class from the enumeration definition
  Result := 'NtSetInformationToken [' +
    GetEnumName(TypeInfo(TTokenInformationClass), Integer(InfoClass)) + ']';
end;

{ Allocations }

function NtxpAllocPrivileges(Privileges: TLuidDynArray;
  Attribute: Cardinal): PTokenPrivileges;
var
  i: Integer;
begin
  Result := AllocMem(SizeOf(Integer) +
    Length(Privileges) * SizeOf(TLUIDAndAttributes));

  Result.PrivilegeCount := Length(Privileges);
  for i := 0 to High(Privileges) do
  begin
    Result.Privileges[i].Luid := Privileges[i];
    Result.Privileges[i].Attributes := Attribute;
  end;
end;

function NtxpAllocPrivileges2(Privileges: TPrivilegeArray): PTokenPrivileges;
var
  i: Integer;
begin
  Result := AllocMem(SizeOf(Integer) +
    Length(Privileges) * SizeOf(TLUIDAndAttributes));

  Result.PrivilegeCount := Length(Privileges);
  for i := 0 to High(Privileges) do
    Result.Privileges[i] := Privileges[i];
end;

function NtxpAllocGroups(Sids: ISidArray; Attribute: Cardinal): PTokenGroups;
var
  i: Integer;
begin
  Result := AllocMem(SizeOf(Integer) + Length(Sids) * SizeOf(TSIDAndAttributes));

  Result.GroupCount := Length(Sids);
  for i := 0 to High(Sids) do
  begin
    Result.Groups[i].Sid := Sids[i].Sid;
    Result.Groups[i].Attributes := Attribute;
  end;
end;

function NtxpAllocGroups2(Groups: TGroupArray): PTokenGroups;
var
  i: Integer;
begin
  Result := AllocMem(SizeOf(Integer) +
    Length(Groups) * SizeOf(TSIDAndAttributes));

  Result.GroupCount := Length(Groups);
  for i := 0 to High(Groups) do
  begin
    Result.Groups[i].Sid := Groups[i].SecurityIdentifier.Sid;
    Result.Groups[i].Attributes := Groups[i].Attributes;
  end;
end;

end.
