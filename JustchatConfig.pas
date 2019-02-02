unit JustchatConfig;
{$I-}{$h+}{$MODE DELPHI}

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

                        mode:ansistring;
                        ID:ansistring;
                        ConsoleName:ansistring;

                        pulseInterval : int64;
                end;
    MessageFormat: record
                        Msg_INFO_Join,Msg_INFO_Disconnect,Msg_INFO_PlayerDead,Msg_Text_Overview :ansistring;
                    end;

procedure Init_Config();

Const
	ServerPackVersion = 3;

    TMsgType_HEARTBEATS = 0;
    TMSGTYPE_REGISTRATION = 1;
    TMsgType_INFO = 100;
    TMsgType_MESSAGE = 101;

    TMsgType_INFO_Join = 1;
    TMsgType_INFO_Disconnect = 2;
    TMsgType_INFO_PlayerDead = 3;

implementation
Function Guid_Gen:ansistring;
Var
	s:string;
	i:longint;
Begin
	s:='0123456789abcdef';
	result:='xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx';
	for i:=1 to length(result) do begin
		if result[i]='x' then result[i]:=s[Random(16)+1];
	end;
End;

Function Is_FileStatus(s:ansistring):integer;
Var
	t:text;
	
Begin
    assign(t,s);reset(t);
	result:=IOresult;
    if result=0 then close(t);
End;

Function Json_OpenFromFile(N:ansistring):TJsonData;
Var
	F:TFileStream;
	P:TJSONParser;
Begin	
	F:=TFileStream.create(N,fmopenRead);
	P:=TJSONParser.Create(F);
	result:=P.Parse;
	FreeAndNil(P);
	F.Destroy;
End;


procedure SaveConfigToJson();
Var
    Full,serverNode,configNode:TJsonObject;
    T:Text;
Begin
    Full:=TJsonObject.Create;
    serverNode:=TJsonObject.Create;
    configNode:=TJsonObject.Create;
	Full.add('server',serverNode);
    Full.add('config',configNode);
    serverNode.add('mode',ServerConfig.mode);
    serverNode.add('ip',NetAddrToStr(ServerConfig.ip));
    serverNode.add('port',ServerConfig.port);
    serverNode.add('ID',ServerConfig.ID);
    serverNode.add('name',ServerConfig.ConsoleName);
    serverNode.add('pulseInterval',ServerConfig.pulseInterval);
    configNode.add('groupid',Justchat_BindGroup);
    assign(T,CQ_i_getAppDirectory+'config.json');rewrite(T);
    writeln(T,full.FormatJson);
	close(T);
    Full.Destroy;
End;

procedure SaveLocaleToJson();
Var
    Full:TJsonObject;
    T:Text;
Begin
    Full:=TJsonObject.Create;
	Full.add('Msg_INFO_Join',MessageFormat.Msg_INFO_Join);
	Full.add('Msg_INFO_Disconnect',MessageFormat.Msg_INFO_Disconnect);
	Full.add('Msg_INFO_PlayerDead',MessageFormat.Msg_INFO_PlayerDead);
	Full.add('Msg_Text_Overview',MessageFormat.Msg_Text_Overview);
    assign(T,CQ_i_getAppDirectory+'message.json');rewrite(T);
    writeln(T,full.FormatJson);
	close(T);
    Full.Destroy;
End;

procedure Init_Config();
Var
	A:TIniFile;
    B,BB:TJsonData;
	E,EE:TBaseJSONEnumerator;
Begin

            
    if Is_FileStatus(CQ_i_getAppDirectory+'config.json')=0 then begin
		ServerConfig.mode:='server';
		ServerConfig.IP:=StrToNetAddr('0.0.0.0');
		ServerConfig.port:=54321;
		ServerConfig.ID:=Guid_Gen;
		ServerConfig.ConsoleName:='';
		ServerConfig.pulseInterval:=20;
		
        B:= Json_OpenFromFile(CQ_i_getAppDirectory+'config.json');
		E:=B.GetEnumerator;
		while E.MoveNext do begin
            if upcase(E.Current.Key)='SERVER' then begin
			
				BB:=B.FindPath(E.Current.Key);
				EE:=BB.GetEnumerator;
				while EE.MoveNext do begin
					if upcase(EE.Current.Key)='MODE' then begin
						ServerConfig.mode:=BB.FindPath(EE.Current.Key).AsString;
					end else
					if upcase(EE.Current.Key)='IP' then begin
						ServerConfig.IP:=StrToNetAddr(BB.FindPath(EE.Current.Key).AsString);
					end else
					if upcase(EE.Current.Key)='PORT' then begin
						ServerConfig.Port:=BB.FindPath(EE.Current.Key).AsInt64;
					end else
					if upcase(EE.Current.Key)='ID' then begin
						ServerConfig.ID:=BB.FindPath(EE.Current.Key).AsString;
					end else
					if upcase(EE.Current.Key)='NAME' then begin
						ServerConfig.ConsoleName:=BB.FindPath(EE.Current.Key).AsString;
					end else
					if upcase(EE.Current.Key)='PULSEINTERVAL' then begin
						ServerConfig.pulseInterval:=BB.FindPath(EE.Current.Key).AsInt64;
					end;
				end;
				
            end else
            if upcase(E.Current.Key)='CONFIG' then begin
				BB:=B.FindPath(E.Current.Key);
				EE:=BB.GetEnumerator;
				while EE.MoveNext do begin
					if upcase(EE.Current.Key)='GROUPID' then begin
						Justchat_BindGroup:=BB.FindPath(EE.Current.Key).AsInt64;
					end;
				end;
				//EE.Destroy;
				//BB.Destroy;
            end;
			
		end;

        B.Destroy;
		//E.Destroy;
		
		if (ServerConfig.port<1) or (ServerConfig.port>65535) then begin
			ServerConfig.port:=54321;
		end;
		if ServerConfig.ID='' then begin
            ServerConfig.ID:=Guid_Gen;
        end;
		if (upcase(ServerConfig.mode)<>'SERVER') and (upcase(ServerConfig.mode)<>'CLIENT') then begin
            ServerConfig.mode:='server';
        end;
        if ServerConfig.pulseInterval<0 then begin
            ServerConfig.pulseInterval:=20;
        end;

        SaveConfigToJson();
    end
    else
    begin
        
        A:= TIniFile.Create(CQ_i_getAppDirectory+'config.ini',false);
		A.CacheUpdates:= true;
        ServerConfig.ip:=StrToHostAddr(A.ReadString('server','ip','0.0.0.0'));
        if HostAddrToStr(ServerConfig.ip)='0.0.0.0' then begin
            A.WriteString('server','ip','0.0.0.0');
        end;
        ServerConfig.port:=A.ReadInt64('server','port',54321);
		if (ServerConfig.port=54321) or (ServerConfig.port<1) or (ServerConfig.port>65535) then begin
			A.WriteInt64('server','port',54321);
			ServerConfig.port:=54321;
		end;
        ServerConfig.mode:=A.ReadString('server','mode','');
        if (upcase(ServerConfig.mode)<>'SERVER') and (upcase(ServerConfig.mode)<>'CLIENT') then begin
            ServerConfig.mode:='server';
            A.WriteString('server','mode',ServerConfig.mode);
        end;
        if upcase(ServerConfig.mode)='CLIENT' then begin
            ServerConfig.ID:=A.ReadString('server','ID','');
            if ServerConfig.ID='' then begin
                ServerConfig.ID:=Guid_Gen;
                A.WriteString('server','ID',ServerConfig.ID);
            end;
            ServerConfig.ConsoleName:=A.ReadString('server','name','');
			if ServerConfig.ConsoleName='' then begin
				A.WriteString('server','name',ServerConfig.ConsoleName);
			end;
        end;
        ServerConfig.pulseInterval:=A.ReadInt64('server','pulseInterval',20);
		if ServerConfig.pulseInterval<0 then begin
			A.WriteInt64('server','pulseInterval',20);
			ServerConfig.pulseInterval:=20;
		end;
        Justchat_BindGroup:=A.ReadInt64('config','groupid',0);
        if Justchat_BindGroup=0 then begin
            A.WriteInt64('config','groupid',0);
        end;
		A.UpdateFile;
        A.Destroy;
    end;

    if ServerConfig.port>65535 then ServerConfig.port:=54321;
    if ServerConfig.port<1 then ServerConfig.port:=54321;

    MessageFormat.Msg_INFO_Join:='%SENDER% joined the game.';
    MessageFormat.Msg_INFO_Disconnect:='%SENDER% left the game.';
    MessageFormat.Msg_INFO_PlayerDead:='%SENDER% dead.';
    MessageFormat.Msg_Text_Overview:='[*][%WORLD_DISPLAY%]%SENDER%: %CONTENT%';


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
            end else
            if upcase(E.Current.Key)='MSG_TEXT_OVERVIEW' then begin
                MessageFormat.Msg_Text_Overview:=B.FindPath(E.Current.Key).AsString;
            end;
        end;
        E.Destroy;
        B.Destroy;
        
        SaveLocaleToJson();
    end
    else
    begin
        A:= TIniFile.Create(CQ_i_getAppDirectory+'message.ini',true);
		A.CacheUpdates:= true;
		
        MessageFormat.Msg_INFO_Join:=A.ReadString('message','Msg_INFO_Join',MessageFormat.Msg_INFO_Join);
        A.WriteString('message','Msg_INFO_Join',MessageFormat.Msg_INFO_Join);

        MessageFormat.Msg_INFO_Disconnect:=A.ReadString('message','Msg_INFO_Disconnect',MessageFormat.Msg_INFO_Disconnect);
        A.WriteString('message','Msg_INFO_Disconnect',MessageFormat.Msg_INFO_Disconnect);

        MessageFormat.Msg_INFO_PlayerDead:=A.ReadString('message','Msg_INFO_PlayerDead',MessageFormat.Msg_INFO_PlayerDead);
        A.WriteString('message','Msg_INFO_PlayerDead',MessageFormat.Msg_INFO_PlayerDead);

        MessageFormat.Msg_Text_Overview:=A.ReadString('message','Msg_Text_Overview',MessageFormat.Msg_Text_Overview);
        A.WriteString('message','Msg_Text_Overview',MessageFormat.Msg_Text_Overview);


        A.Destroy;
    end;


End;

end.