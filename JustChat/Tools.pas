unit Tools;
{$I-}{$h+}{$MODE DELPHI}

interface

uses
    windows, classes, sysutils,
    fpjson, jsonparser;

function Guid_Gen:ansistring;
function IsGuid(a:ansistring):boolean;
function Is_FileStatus(s:ansistring):integer;
function Json_OpenFromFile(N:ansistring):TJsonData;
{$IFNDEF CoolQSDK}
Function NumToChar(a:int64):string;
{$ENDIF}

implementation
{
    GUID 生成器
}
function Guid_Gen:ansistring;
var
	s:string;
	i:longint;
begin
	s:='0123456789abcdef';
	result:='xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx';
	for i:=1 to length(result) do begin
		if result[i]='x' then result[i]:=s[Random(16)+1];
	end;
end;

{
    GUID  格式验证
}
function IsGuid(a:ansistring):boolean;
var
    s,f:string;
    i:longint;
begin
	a:=lowercase(a);
    s:='0123456789abcdef';
	f:='xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx';
    
    if length(a) <> length(f) then exit(false);

	for i:=1 to length(f) do begin
		if f[i]='x' then begin
            if pos(s,a[i])<=0 then exit(false);
        end else begin
            if a[i] <> '-' then exit(false);
        end;
	end;

    exit(true);
end;

{
    文件存在状态
}
function Is_FileStatus(s:ansistring):integer;
var
	t:text;
	
begin
    assign(t,s);reset(t);
	result:=IOresult;
    if result=0 then close(t);
end;

{
    打开 JSON 文件
}
function Json_OpenFromFile(N:ansistring):TJsonData;
var
	F:TFileStream;
	P:TJSONParser;
begin	
	F:=TFileStream.create(N,fmopenRead);
	P:=TJSONParser.Create(F);
	result:=P.Parse;
	FreeAndNil(P);
	F.Destroy;
end;

{$IFNDEF CoolQSDK}
{
    调试重写
}
Function NumToChar(a:int64):string;
Begin
	str(a,result);
End;
{$ENDIF}

end.