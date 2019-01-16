unit JustchatConfig;

interface
uses
    Sockets,windows,classes,sysutils,inifiles,
    CoolQSDK;

Var
    Justchat_BindGroup : int64=0;
    ServerConfig : record
                        ip:in_addr;
                        port:int64;
                end;    

procedure Init_Config();

implementation


procedure Init_Config();
Var
	A:TIniFile;
Begin
	A:= TIniFile.Create(CQ_i_getAppDirectory+'config.ini',false);
	ServerConfig.ip:=StrToHostAddr(A.ReadString('server','ip','0.0.0.0'));
	ServerConfig.port:=A.ReadInt64('server','port',54321);
    if ServerConfig.port>65535 then ServerConfig.port:=54321;
    if ServerConfig.port<1 then ServerConfig.port:=54321;
    Justchat_BindGroup:=A.ReadInt64('config','groupid',0);
	A.Destroy;
End;

end.