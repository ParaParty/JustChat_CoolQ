unit JustchatConfig;
{$I-}{$h+}

interface
uses
    Sockets,windows,classes,sysutils,
    inifiles,fpjson,jsonparser,
    CoolQSDK;

Var
    Justchat_BindGroup : int64=0;
    ServerConfig : record
                        ip:in_addr;
                        port:int64;
                end;
    MessageFormat: record
                        Msg_INFO_Join,Msg_INFO_Disconnect,Msg_INFO_PlayerDead :ansistring;
                    end;

procedure Init_Config();

Const
	ServerPackVersion = 2;

    TMsgType_HEARTBEATS = 0;
    TMsgType_INFO = 1;
    TMsgType_MESSAGE = 2;

    TMsgType_INFO_Join = 1;
    TMsgType_INFO_Disconnect = 2;
    TMsgType_INFO_PlayerDead = 3;

implementation

Function Is_FileStatus(s:ansistring):integer;
Var
	t:text;
	
Begin
    assign(t,s);reset(t);
	Is_FileStatus:=IOresult;
    if Is_FileStatus=0 then close(t);
End;

Function Json_OpenFromFile(N:ansistring):TJsonData;
Var
	F:TFileStream;
	P:TJSONParser;
Begin	
	F:=TFileStream.create(N,fmopenRead);
	P:=TJSONParser.Create(F);
	Json_OpenFromFile:=P.Parse;
	FreeAndNil(P);
	F.Destroy;
End;

procedure Init_Config();
Var
	A:TIniFile;
    B:TJsonData;
	E:TBaseJSONEnumerator;
Begin

            
    if Is_FileStatus(CQ_i_getAppDirectory+'config.json')=0 then begin
        B:= Json_OpenFromFile(CQ_i_getAppDirectory+'config.json');
        ServerConfig.ip:=StrToHostAddr(B.findPath('server.ip').asString);
        ServerConfig.port:=B.findPath('server.port').asInt64;
        Justchat_BindGroup:=B.findPath('config.groupid').asInt64;
        B.Destroy;
    end
    else
    begin
        
        A:= TIniFile.Create(CQ_i_getAppDirectory+'config.ini',false);
        ServerConfig.ip:=StrToHostAddr(A.ReadString('server','ip','0.0.0.0'));
        ServerConfig.port:=A.ReadInt64('server','port',54321);
        Justchat_BindGroup:=A.ReadInt64('config','groupid',0);
        A.Destroy;

    end;

    if ServerConfig.port>65535 then ServerConfig.port:=54321;
    if ServerConfig.port<1 then ServerConfig.port:=54321;

    MessageFormat.Msg_INFO_Join:='%SENDER% joined the game.';
    MessageFormat.Msg_INFO_Disconnect:='%SENDER% left the game.';
    MessageFormat.Msg_INFO_PlayerDead:='%SENDER% dead.';


    if Is_FileStatus(CQ_i_getAppDirectory+'message.json')=0 then begin
        B:= Json_OpenFromFile(CQ_i_getAppDirectory+'message.json');
        E:=B.GetEnumerator;
        while E.MoveNext do begin
            if upcase(E.Current.Key)='MSG_INFO_JOIN' then begin
                MessageFormat.Msg_INFO_Join:=B.FindPath(E.Current.Key).AsString;
            end else
            if upcase(E.Current.Key)='MSG_INFO_DISCONNECT' then begin
                MessageFormat.Msg_INFO_Disconnect:=B.FindPath(E.Current.Key).AsString;
            end else
            if upcase(E.Current.Key)='MSG_INFO_PLAYERDEAD' then begin
                MessageFormat.Msg_INFO_PlayerDead:=B.FindPath(E.Current.Key).AsString;
            end;
        end;
        //E.Destroy;
        B.Destroy;
    end
    else
    begin
        A:= TIniFile.Create(CQ_i_getAppDirectory+'message.ini',true);
        MessageFormat.Msg_INFO_Join:=A.ReadString('message','Msg_INFO_Join',MessageFormat.Msg_INFO_Join);
        MessageFormat.Msg_INFO_Disconnect:=A.ReadString('message','Msg_INFO_Disconnect',MessageFormat.Msg_INFO_Disconnect);
        MessageFormat.Msg_INFO_PlayerDead:=A.ReadString('message','Msg_INFO_PlayerDead',MessageFormat.Msg_INFO_PlayerDead);
        A.Destroy;
    end;
End;

end.