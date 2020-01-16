unit JustChatConfig;
{$MODE OBJFPC}

interface
uses
    windows, classes, sysutils,
    fpjson, jsonparser,
    gutil, gmap, gset,

    IdTCPConnection,

    Tools
    {$IFDEF __FULL_COMPILE_}
    ,CoolQSDK
    {$ENDIF}
    ;

type
    {
        JustChat 设置
        服务器模式设置
    }
    JustChat_ServerConfig = record
        enable : boolean;
        port : int64;
    end;

    {
        JustChat 设置
        客户端模式设置
    }
    JustChat_ClientConfig = record
        enable : boolean;
        address : ansistring;
        port : word;
        pulseInterval : longint;
    end;

    {
        JustChat 设置
        连接设置
    }
    JustChat_ConnectionConfig = record
        Server : JustChat_ServerConfig;
        Client : JustChat_ClientConfig;

        ID : ansistring;
        name : ansistring;
    end;

type
    AnsistringLess= specialize TLess<ansistring>;
    Int64Less= specialize TLess<int64>;
    StringBooleanMap = specialize TMap<ansistring,boolean, AnsistringLess>;
    StringStringMap = specialize TMap<ansistring,ansistring, AnsistringLess>;

/// 常量定义
const
	ServerPackVersion = 3;

    TMsgType_HEARTBEATS = 0;
    TMSGTYPE_REGISTRATION = 1;
    TMsgType_INFO = 100;
    TMsgType_MESSAGE = 101;

    TMSGTYPE_PLAYERLIST = 200;
    TMSGTYPE_PLAYERLIST_Request = 0;
    TMSGTYPE_PLAYERLIST_Response = 1;

    REGISTRATION_MINECRAFT = 0;
    REGISTRATION_IDENTITY = 1;

    TMsgType_INFO_Join = 1;
    TMsgType_INFO_Disconnect = 2;
    TMsgType_INFO_PlayerDead = 3;

	MessageHeader = #$11+#$45+#$14;
	//PulseHeader = #$70+#$93+#$94;
	SUBSTRING = #$1A+#$1A+#$1A+#$1A+#$1A+#$1A+#$1A+#$1A;

    Const_ThreadWaitingTime = 5000;

{
    配置对象
}
type TJustChatConfig_TerminalConfig = class
    private
        EventsMap : StringBooleanMap;
        MessagesMap : StringStringMap;
        inheritFrom : TJustChatConfig_TerminalConfig;
        procedure Event_Set(event : ansistring; status : boolean);
        procedure Message_Set(key : ansistring; value : ansistring);

    public
        constructor Create;
        destructor Destroy;override;
        function Event_isEnabled(event : ansistring):boolean;
        function Message_Get(key : ansistring):ansistring;
        procedure InsertConfig(config : TJsonData);


        class function CreateFromConfig(config : TJsonData; inherit:TJustChatConfig_TerminalConfig=nil): TJustChatConfig_TerminalConfig; static;
end;

{
    格式化后数据包
}
type TJustChatStructedMessage = class
    const
        Registration_All = 'Registration_All';
        Info_All = 'Info_All';
        Info_Network = 'Info_Network';
        Info_PlayerDeath = 'Info_PlayerDeath';
        Info_Other = 'Info_Other';
        Message_All = 'Message_All';
        PlayerList_All = 'PlayerList_All';

        Msg_INFO_General = 'Msg_INFO_General';
        Msg_INFO_Join = 'Msg_INFO_Join';
        Msg_INFO_Disconnect = 'Msg_INFO_Disconnect';
        Msg_INFO_PlayerDead = 'Msg_INFO_PlayerDead';
        Msg_Message_Overview = 'Msg_Message_Overview';
        PlayerList_Layout = 'PlayerList_Layout';
        Event_online = 'Event_online';
        Event_offline = 'Event_offline';
    private
        structedMsg : ansistring;
        
        msgType : ansistring;
        eventType,subEventType : ansistring;

        MessageReplacementsLength : longint;
        MessageReplacements : array of record
            k,v : ansistring;
        end;
    public
        constructor Create(aEventType, aSubEventType, aMsgType, aStructedMsg:ansistring);
        procedure MessageReplacementsAdd(k,v:ansistring);
        function QQGroupFormater(sFormat : TJustChatConfig_TerminalConfig) : ansistring;
        function MinecraftFormatter() : ansistring;
end;

type TJustChatConfig_Services = class;

{
    终端
}
type TJustChatService_Terminal = class
    protected
        Config : TJustChatConfig_TerminalConfig;
        Service : TJustChatConfig_Services;

        hMutex	: handle;
    public
        constructor Create;
        destructor Destroy; override;
        //function GetID : int64; virtual;
        //function GetID : ansistring; virtual;
        procedure InsertConfig(aConfig :TJsonData);
        function Send(MSG : TJustChatStructedMessage):longint; virtual;
        procedure Broadcast(MSG : TJustChatStructedMessage);
end;

{
    QQ群终端
}
type TJustChatService_QQGroupsTerminal = class(TJustChatService_Terminal)
    private
        ID : int64;
    public
        constructor Create(AID : int64; inherit : TJustChatConfig_TerminalConfig; parent : TJustChatConfig_Services);
        destructor Destroy;override;
        function GetID : int64;
        function Send(MSG : TJustChatStructedMessage):longint; override;
end;

{
    MC终端
}
type TJustChatService_MinecraftTerminal = class(TJustChatService_Terminal)
    private
        ID : ansistring;
        Connection : TIdTCPConnection;
    public
        name : ansistring;

        constructor Create(AID : ansistring; inherit : TJustChatConfig_TerminalConfig; parent : TJustChatConfig_Services);
        destructor Destroy;override;
        function GetID : ansistring;
        function Send(MSG : TJustChatStructedMessage):longint; override;
end;

{
    关于指针的一个 STL 比较器
}
type TGenerallyLess = class
  class function c(a,b:TObject):boolean;inline;
end;

type
    TJustChatService_TerminalSet = specialize TSet<TJustChatService_Terminal, TGenerallyLess>;

    TJustChatService_QQGroupsTerminalMap = specialize TMap<int64, TJustChatService_QQGroupsTerminal, Int64Less>;
    TJustChatService_MinecraftTerminalMap = specialize TMap<ansistring, TJustChatService_MinecraftTerminal, AnsistringLess>;

{
    配置文件，服务组
}
type TJustChatConfig_Services = class
    private
        TerminalSet : TJustChatService_TerminalSet;
        Config : TJustChatConfig_TerminalConfig;
    public
        constructor Create(Aconfig :TJsonData; inherit : TJustChatConfig_TerminalConfig);
        destructor Destroy;override;
end;

type
    TJustChatConfig_ServicesSet = specialize TSet<TJustChatConfig_Services, TGenerallyLess>;

var
    {
        JustChat 设置
        总体设置
    }
    JustChat_Config : record
        Version : longint; // 设置文件版本号
        Connection : JustChat_ConnectionConfig; // 连接设置

        Global_Configuration : TJustChatConfig_TerminalConfig; // 全局设置
        Services : TJustChatConfig_ServicesSet; // 服务组设置

        QQGroupTerminals : TJustChatService_QQGroupsTerminalMap;
        MinecraftTerminals : TJustChatService_MinecraftTerminalMap;
    end;

procedure Init_Config();
procedure Init_ConfigLayout();
procedure Final_ConfigFree();

implementation

{$IFNDEF CoolQSDK}
{
    调试重写
}
function CQ_i_getAppDirectory():ansistring;
begin
    exit('');
end;
{$ENDIF}

{
    生成配置文件
}
function GenerateConfig():longint;
var
    t : text;
    s : ansistring;
begin
    if (Is_FileStatus(CQ_i_getAppDirectory+'config.ini')=0) then begin
        /// TODO 配置文件迁移
        /// 存在旧版本配置文件
        /// 把文件搬走然后给你重建配置文件
        raise Exception.Create('Configuration generated by previous version was detected. Please backup and clean the configuration before restarting the application.'); 
    end
    else
    begin
        s := 'ewoJInZlcnNpb24iOiB7CgkJImNvbmZpZyI6IDIKCX0sCgkiY29ubmVjdGlvbiI6IHsKCQkic2VydmVyIjogewoJCQkiZW5hYmxlIjogZmFsc2UsCgkJCSJwb3J0IjogMzg0NDAKCQl9LAoJCSJjbGllbnQiOiB7CgkJCSJlbmFibGUiOiBmYWxzZSwKCQkJImFkZHJlc3MiOiAiIiwKCQkJInBvcnQiOiAzODQ0MCwKCQkJInB1bHNlX2ludGVydmFsIjogMjAKCQl9LAoJCSJJRCI6ICIiLAoJCSJuYW1lIjogIiIKCX0sCgkic2VydmljZXMiOiBbCgkJewoJCQkiYmluZCI6IHsKCQkJCSJxcWdyb3VwcyI6IFsKCQkJCQkxMjM0NTY3ODkKCQkJCV0sCgkJCQkibWluZWNyYWZ0IjogWwoJCQkJCSJVVUlEMSIKCQkJCV0KCQkJfQoJCX0KCV0sCgkiZ2xvYmFsX2NvbmZpZ3VyYXRpb24iOiB7CgkJImV2ZW50cyI6IHsKCQkJIlJlZ2lzdHJhdGlvbl9BbGwiOiB0cnVlLAoJCQkiSW5mb19hbGwiOiB0cnVlLAoJCQkiSW5mb19OZXR3b3JrIjogdHJ1ZSwKCQkJIkluZm9fUGxheWVyRGVhdGgiOiB0cnVlLAoJCQkiSW5mb19vdGhlciI6IHRydWUsCgkJCSJNZXNzYWdlX0FsbCI6IHRydWUsCgkJCSJQbGF5ZXJMaXN0X0FsbCI6IHRydWUKCQl9LAoJCSJtZXNzYWdlX2Zvcm1hdCI6IHsKCQkJIk1zZ19JTkZPX0dlbmVyYWwiOiAiWyVTRVJWRVIlXSAlQ09OVEVOVCUiLAoJCQkiTXNnX0lORk9fSm9pbiI6ICJbJVNFUlZFUiVdICVTRU5ERVIlIGpvaW5lZCB0aGUgZ2FtZS4iLAoJCQkiTXNnX0lORk9fRGlzY29ubmVjdCI6ICJbJVNFUlZFUiVdICVTRU5ERVIlIGxlZnQgdGhlIGdhbWUuIiwKCQkJIk1zZ19JTkZPX1BsYXllckRlYWQiOiAiWyVTRVJWRVIlXSAlU0VOREVSJSBkZWFkLiIsCgkJCSJNc2dfVGV4dF9PdmVydmlldyI6ICJbKl1bJVNFUlZFUiVdWyVXT1JMRF9ESVNQTEFZJV0lU0VOREVSJTogJUNPTlRFTlQlIiwKCQkJIk1zZ19TZXJ2ZXJfUGxheWVybGlzdCI6ICJbJVNFUlZFUiVdIFRoZXJlIGFyZSAlTk9XJS8lTUFYJSBwbGF5ZXJzIG9ubGluZS4iLAoJCQkiRXZlbnRfb25saW5lIjogIlNlcnZlciAlTkFNRSUgaXMgbm93IG9ubGluZS4iLAoJCQkiRXZlbnRfb2ZmbGluZSI6ICJTZXJ2ZXIgJU5BTUUlIGlzIG5vdyBvZmZsaW5lLiIKCQl9Cgl9Cn0';
        assign(t, CQ_i_getAppDirectory+'config.json');rewrite(t);
        write(t, Base64_Decryption(s));
        close(t);
    end;
    exit(0);
end;

{
    升级配置文件
}
function UpdateConfig(Config:TJsonData):longint;
begin
    if ((Config.findPath('version.config')=nil) or (Config.findPath('version.config').AsInt64 < 2)) then begin
        /// TODO 配置文件升级
        /// 存在旧版本配置文件
        /// 把文件搬走然后给你重建配置文件
        raise Exception.Create('Configuration generated by previous version was detected. Please backup and clean the configuration before restarting the application.'); 
    end else if (Config.findPath('version.config').AsInt64 = 2) then begin

    end else begin
        raise Exception.Create('Configuration generated by later version was detected. Please backup and clean the configuration before restarting the application.'); 
    end;
    exit(0);
end;

{
    保存配置文件
}
procedure Config_Save(Config:TJsonData);
var
    t : text;
begin
    assign(t,CQ_i_getAppDirectory+'config.json');rewrite(t);
    write(t,Config.FormatJson());
    close(t);
end;

{
    载入配置文件
}
procedure Init_Config();
var
    Config,T:TJsonData;
    tmpObject:TJsonObject;

    i : longint;
    tmpService : TJustChatConfig_Services;

    groupid : int64;
    tmpGroupTerminal : TJustChatService_QQGroupsTerminal;
begin
    Justchat_Config.Connection.Server.Enable := false;
    Justchat_Config.Connection.Client.Enable := false;

    try
        /// 配置文件是否存在
        if (Is_FileStatus(CQ_i_getAppDirectory+'config.json')=2) then begin
            if GenerateConfig()<>0 then
                raise Exception.Create('Can not generate the default configuration.');
        end;
        
        /// 读取配置文件
        if (Is_FileStatus(CQ_i_getAppDirectory+'config.json')=0) then begin
            Config:= Json_OpenFromFile(CQ_i_getAppDirectory+'config.json');

            /// 配置文件版本更新
            if UpdateConfig(Config)<>0 then begin
                Config.Free;
                raise Exception.Create('Can not update the configuration.');
            end;

            /// 读取连接配置
            if Config.findPath('connection')=nil then
                raise Exception.Create('Connection setting must be set.');

            if Config.findPath('connection').JSONType <> jtObject then
                raise Exception.Create('Connection setting must be a JSONObject.');

            Justchat_Config.Connection.Server.Enable := false;
            if Config.findPath('connection.server')<>nil then begin
                T:=Config.findPath('connection.server');
                if (T.findPath('enable')<>nil) and (T.findPath('enable').AsBoolean) then begin
                    if (T.findPath('port')=nil) then begin
                        Config.Free;
                        raise Exception.Create('Server port must be specified.');
                    end else begin
                        Justchat_Config.Connection.Server.Port := T.findPath('port').asInt64;
                    end;
                end;
            end;

            Justchat_Config.Connection.Client.Enable := false;
            if Config.findPath('connection.client')<>nil then begin
                T:=Config.findPath('connection.client');
                if (T.findPath('enable')<>nil) and (T.findPath('enable').AsBoolean) then begin
                    tmpObject := TJsonObject(Config.findPath('connection.client'));
                    
                    if tmpObject.findPath('address') = nil then begin
                        raise Exception.Create('Server address in client mode configuration must be specified.');
                    end;

                    if tmpObject.findPath('port') = nil then begin
                        raise Exception.Create('Server port in client mode configuration must be specified.');
                    end;

                    if tmpObject.findPath('pulseInterval') = nil then begin
                        tmpObject.add('pulse_interval',20);
                    end;

                    Justchat_Config.Connection.Client.address := tmpObject.findPath('address').asString;
                    Justchat_Config.Connection.Client.port := tmpObject.findPath('port').asInt64;
                    Justchat_Config.Connection.Client.pulseInterval := tmpObject.findPath('pulseInterval').asInt64;

                end;
            end;

            if (Config.findPath('connection.ID')=nil) or (not IsGUID(Config.findPath('connection.ID').asString)) then begin
                tmpObject := TJsonObject(Config.findPath('connection'));
                if (tmpObject.findPath('ID')<>nil) then tmpObject.Delete('ID');
                tmpObject.Add('ID',Guid_Gen());
            end;
            
            if Config.findPath('connection.name')=nil then begin
                tmpObject := TJsonObject(Config.findPath('connection'));
                tmpObject.Add('name','JustChat');
            end;

            JustChat_Config.Connection.ID := Config.findPath('connection.ID').asString;
            JustChat_Config.Connection.name := Config.findPath('connection.name').asString;


            /// 读取全局配置
            Justchat_Config.Global_Configuration := TJustChatConfig_TerminalConfig.CreateFromConfig(Config.findPath('global_configuration'), nil);

            JustChat_Config.QQGroupTerminals := TJustChatService_QQGroupsTerminalMap.Create();
            JustChat_Config.MinecraftTerminals := TJustChatService_MinecraftTerminalMap.Create();

            /// 读取服务组配置
            if (Config.findPath('services')<>nil) and (Config.findPath('services').JSONType = jtArray) and (Config.findPath('services').Count > 0) then begin
                Justchat_Config.Services := TJustChatConfig_ServicesSet.Create();
                for i:= 0 to Config.findPath('services').Count-1 do begin
                    T := Config.findPath('services['+NumToChar(i)+']');
                    if T.JsonType <> jtObject then begin
                        {$IFDEF CoolQSDK}
                        CQ_i_addLog(CQLOG_WARNING,'Configuration','An invalid service configuration was detected.'+CRLF+T.FormatJson());
                        {$ENDIF}
                        continue;
                    end;
                    TmpService := TJustChatConfig_Services.Create(T, Justchat_Config.Global_Configuration);
                    Justchat_Config.Services.Insert(TmpService);
                end;
            end else begin
                Justchat_Config.Global_Configuration.Destroy();
                JustChat_Config.QQGroupTerminals.Destroy();
                JustChat_Config.MinecraftTerminals.Destroy();
                raise Exception.Create('Services configuration must be set.');
            end;

            /// 读取群配置
            if (Config.findPath('qqgroups')<>nil) and (Config.findPath('qqgroups').JSONType = jtArray) and (Config.findPath('qqgroups').Count > 0) then begin
                for i:= 0 to Config.findPath('qqgroups').Count-1 do begin
                    if T.JsonType <> jtObject then begin
                        {$IFDEF CoolQSDK}
                        CQ_i_addLog(CQLOG_WARNING,'Configuration','An invalid qqgroups configuration was detected.'+CRLF+T.FormatJson());
                        {$ENDIF}
                        continue;
                    end;

                    groupid := T.findPath('groupid').asInt64;
                    if JustChat_Config.QQGroupTerminals.TryGetValue(groupid, tmpGroupTerminal) then begin
                        tmpGroupTerminal.InsertConfig(T.findPath('config'));
                    end else begin
                        {$IFDEF CoolQSDK}
                        CQ_i_addLog(CQLOG_WARNING,'Configuration','An unused qqgroups configuration was detected.'+CRLF+T.FormatJson());
                        {$ENDIF}
                    end;
                end;
            end;

            /// 保存配置文件
            Config_Save(Config);
            Config.Free;
        end;
    except
        on e: Exception do begin
            Justchat_Config.Connection.Server.Enable := false;
            Justchat_Config.Connection.Client.Enable := false;
            {$IFDEF CoolQSDK}
            CQ_i_addLog(CQLOG_FATAL, 'Configuration', 'Can not load configuration.'+CRLF+AnsiToUTF8(e.message));
            {$ENDIF}
        end;
    end;

end;

procedure Init_ConfigLayout();
begin
    /// TODO [DEBUG] 配置文件列举
end;

procedure Final_ConfigFree();
begin
    /// TODO [DEBUG] 内存回收
end;

constructor TJustChatConfig_TerminalConfig.Create;
begin
    EventsMap := StringBooleanMap.Create();
    MessagesMap := StringStringMap.Create();
end;

destructor TJustChatConfig_TerminalConfig.Destroy;
begin
    EventsMap.Destroy();
    MessagesMap.Destroy();
end;

function TJustChatConfig_TerminalConfig.Event_isEnabled(event : ansistring):boolean;
var
    ret : boolean;
begin
    if not EventsMap.TryGetValue(upcase(event), ret) then begin
        if inheritFrom <> nil then ret:=inheritFrom.Event_isEnabled(event) else begin
            /// 没有指派
            exit(false);
        end;
    end;

    exit(ret);
end;

procedure TJustChatConfig_TerminalConfig.Event_Set(event : ansistring; status : boolean);
begin
    EventsMap.Insert(upcase(event),status);
end;

function TJustChatConfig_TerminalConfig.Message_Get(key : ansistring):ansistring;
var
    ret : ansistring;
begin
    if not MessagesMap.TryGetValue(upcase(key), ret) then begin
        if inheritFrom <> nil then ret:=inheritFrom.Message_Get(key) else begin
            /// 没有指派
            exit('');
        end;
    end;

    exit(ret);
end;

procedure TJustChatConfig_TerminalConfig.Message_Set(key : ansistring; value : ansistring);
begin
    MessagesMap.Insert(upcase(key),value);
end;

procedure TJustChatConfig_TerminalConfig.InsertConfig(config : TJsonData);
var
	enum : TBaseJSONEnumerator;
    current : TJSONEnum;
begin

    /// 读入事件设置
    if (config<>nil) and (config.findPath('events')<>nil) then begin
        /// 如果事件设置存在
        if config.findPath('events').JSONType = jtObject then begin

            /// 读入事件设置
            enum:=config.findPath('events').GetEnumerator;
            while enum.MoveNext do begin
                current := enum.GetCurrent();

                try
                    self.Event_Set(current.key,current.value.asboolean)
                except
                    on e: Exception do begin
                        {$IFDEF CoolQSDK}
                        CQ_i_addlog(CQLOG_ERROR, 'Configuration', e.message);
                        {$ENDIF}
                    end;
                end;

            end;
            enum.Destroy;

        end else Begin
            {$IFDEF CoolQSDK}
            CQ_i_addLog(CQLOG_WARNING, 'Configuration', 'Events setting must be a JSONObject.');
            {$ENDIF}
        end;
    end;

    /// 读入消息设置
    if (config<>nil) and (config.findPath('message_format')<>nil) then begin
        /// 如果消息设置存在
        if config.findPath('message_format').JSONType = jtObject then begin

            /// 读入消息设置
            enum:=config.findPath('message_format').GetEnumerator;
            while enum.MoveNext do begin
                current := enum.GetCurrent();

                try
                    self.Message_Set(current.key,current.value.asstring)
                except
                    on e: Exception do begin
                        {$IFDEF CoolQSDK}
                        CQ_i_addlog(CQLOG_ERROR, 'Configuration', e.message);
                        {$ENDIF}
                    end;
                end;

            end;
            enum.Destroy;

        end else Begin
            {$IFDEF CoolQSDK}
            CQ_i_addLog(CQLOG_WARNING, 'Configuration', 'Message_format setting must be a JSONObject.');
            {$ENDIF}
        end;
    end;

end;


class function TJustChatConfig_TerminalConfig.CreateFromConfig(config : TJsonData; inherit:TJustChatConfig_TerminalConfig=nil): TJustChatConfig_TerminalConfig; static;
var
    ret : TJustChatConfig_TerminalConfig;
begin
    ret := TJustChatConfig_TerminalConfig.Create();
    ret.inheritFrom:=inherit;
    ret.InsertConfig(config);
    exit(ret);
end;


constructor TJustChatConfig_Services.Create(Aconfig :TJsonData; inherit : TJustChatConfig_TerminalConfig);
var
    tmp,cnt : TJsonData;
    i : longint;

    QQt : TJustChatService_QQGroupsTerminal;
    MCt : TJustChatService_MinecraftTerminal;
begin
    TerminalSet := TJustChatService_TerminalSet.Create();

    Config := TJustChatConfig_TerminalConfig.CreateFromConfig(Aconfig, inherit);

    if Aconfig.getPath('bind')=nil then begin
        {$IFDEF CoolQSDK}
        CQ_i_addLog(CQLOG_WARNING,'Configuration','A empty service was detected.'+CRLF+Aconfig.FormatJson());
        {$ENDIF}
    end else if Aconfig.getPath('bind').JSONType <> jtObject then begin
        {$IFDEF CoolQSDK}
        CQ_i_addLog(CQLOG_WARNING,'Configuration','A service declaration must be a JSONObject.'+CRLF+Aconfig.FormatJson());
        {$ENDIF}
    end else begin

        tmp:=Aconfig.getPath('bind');
        if tmp.getPath('qqgroups')=nil then begin
            {$IFDEF CoolQSDK}
            CQ_i_addLog(CQLOG_WARNING,'Configuration','A service with no QQ Groups was detected.'+CRLF+Aconfig.FormatJson());
            {$ENDIF}
        end else if tmp.getPath('qqgroups').JSONType <> jtArray then begin
            {$IFDEF CoolQSDK}
            CQ_i_addLog(CQLOG_WARNING,'Configuration','QQ Groups declaration in a service must be a JSONArray.'+CRLF+Aconfig.FormatJson());
            {$ENDIF}
        end else begin
            if tmp.getPath('qqgroups').count = 0 then begin
                {$IFDEF CoolQSDK}
                CQ_i_addLog(CQLOG_WARNING,'Configuration','A service with no QQ Groups was detected.'+CRLF+Aconfig.FormatJson());
                {$ENDIF}
            end;
            for i:= 0 to tmp.getPath('qqgroups').count-1 do begin
                cnt := tmp.getPath('qqgroups['+NumToChar(i)+']');
                if (cnt.JSONType <> jtNumber) then begin
                    {$IFDEF CoolQSDK}
                    CQ_i_addLog(CQLOG_WARNING,'Configuration','A QQ Group declaration in a service must be a NUMBER.'+CRLF+Aconfig.FormatJson());
                    {$ENDIF}
                end else begin
                    /// 读入QQ群配置

                    if JustChat_Config.QQGroupTerminals.TryGetValue(cnt.AsInt64, QQt) then begin
                        /// 出现过
                        {$IFDEF CoolQSDK}
                        CQ_i_addLog(CQLOG_WARNING,'Configuration',format('A QQ Group [%d] was declared more than once.',[cnt.AsInt64]));
                        {$ENDIF}
                    end else begin
                        /// 未出现过
                        QQt := TJustChatService_QQGroupsTerminal.Create(cnt.AsInt64, config, self);
                        TerminalSet.Insert(QQt);
                        JustChat_Config.QQGroupTerminals.Insert(cnt.AsInt64, QQt);
                    end;

                end;

            end;
        end;
        
        if tmp.getPath('minecraft')=nil then begin
            {$IFDEF CoolQSDK}
            CQ_i_addLog(CQLOG_WARNING,'Configuration','A service with no Minecraft terminal was detected.'+CRLF+Aconfig.FormatJson());
            {$ENDIF}
        end else if tmp.getPath('minecraft').JSONType <> jtArray then begin
            {$IFDEF CoolQSDK}
            CQ_i_addLog(CQLOG_WARNING,'Configuration','Minecraft terminals declaration in a service must be a JSONArray.'+CRLF+Aconfig.FormatJson());
            {$ENDIF}
        end else begin
            if tmp.getPath('minecraft').count = 0 then begin
                {$IFDEF CoolQSDK}
                CQ_i_addLog(CQLOG_WARNING,'Configuration','A service with no Minecraft terminal was detected.'+CRLF+Aconfig.FormatJson());
                {$ENDIF}
            end;
            for i:= 0 to tmp.getPath('minecraft').count-1 do begin
                cnt := tmp.getPath('minecraft['+NumToChar(i)+']');
                if (cnt.JSONType <> jtString) or (not IsGuid(cnt.AsString)) then begin
                    {$IFDEF CoolQSDK}
                    CQ_i_addLog(CQLOG_WARNING,'Configuration','A Minecraft terminal declaration in a service must be a UUID Format String.'+CRLF+Aconfig.FormatJson());
                    {$ENDIF}
                end else begin
                    /// 读入MC终端群配置

                    if JustChat_Config.MinecraftTerminals.TryGetValue(cnt.AsString, MCt) then begin
                        /// 出现过
                        {$IFDEF CoolQSDK}
                        CQ_i_addLog(CQLOG_WARNING,'Configuration',format('A Minecraft [%s] was declared more than once.',[cnt.AsString]));
                        {$ENDIF}
                    end else begin
                        /// 未出现过
                        MCt := TJustChatService_MinecraftTerminal.Create(cnt.AsString, config, self);
                        TerminalSet.Insert(MCt);
                        JustChat_Config.MinecraftTerminals.Insert(cnt.AsString, MCt);
                    end;

                end;

            end;
        end;


    end;

end;

destructor TJustChatConfig_Services.Destroy;
begin
    TerminalSet.Destroy();
end;

class function TGenerallyLess.c(a,b:TObject):boolean;inline;
begin
    if sizeof(pointer)=4 then
        exit ( dword(pointer(a)) < dword(pointer(b)) )
    else if sizeof(pointer)=8 then
        exit ( qword(pointer(a)) < qword(pointer(b)) )
    else raise Exception.Create('');
end;

constructor TJustChatService_Terminal.Create;
begin
end;

destructor TJustChatService_Terminal.Destroy;
begin
end;

{
function TJustChatService_Terminal.GetID() : int64;
begin
    raise Exception.Create('No Number ID specified.');
    exit(-1);
end;

function TJustChatService_Terminal.GetID() : ansistring;
begin
    raise Exception.Create('No Number UUID specified.');
    exit('');
end;
}

function TJustChatService_Terminal.Send(MSG : TJustChatStructedMessage):longint;
begin
    raise Exception.Create('Send() method is not implemented.');
    exit(-1);
end;

procedure TJustChatService_Terminal.Broadcast(MSG : TJustChatStructedMessage);
var
    it:TJustChatService_TerminalSet.TIterator;
begin
    it:=Service.TerminalSet.min;
    repeat
        if it.Data <> self then Begin
            it.Data.Send(MSG);
        end;
    until not it.next;
end;

procedure TJustChatService_Terminal.InsertConfig(aConfig : TJsonData);
begin
    Config.InsertConfig(aConfig)
end;

constructor TJustChatService_QQGroupsTerminal.Create(AID : int64; inherit : TJustChatConfig_TerminalConfig; parent : TJustChatConfig_Services);
begin
    ID := AID;
    Config := TJustChatConfig_TerminalConfig.CreateFromConfig(nil, inherit);
    Service := parent;
end;

destructor TJustChatService_QQGroupsTerminal.Destroy;
begin
    Config.Destroy();
end;

function TJustChatService_QQGroupsTerminal.GetID():int64;
begin
    exit(ID);
end;

function TJustChatService_QQGroupsTerminal.Send(MSG : TJustChatStructedMessage):longint;
begin
    {$IFDEF CoolQSDK}
    exit(CQ_i_SendGroupMSG( GetID(), msg.QQGroupFormater(config) ));
    {$ELSE}
    exit(0);
    {$IFEND}
end;

constructor TJustChatService_MinecraftTerminal.Create(AID : ansistring; inherit : TJustChatConfig_TerminalConfig; parent : TJustChatConfig_Services);
begin
    ID := AID;
    Config := TJustChatConfig_TerminalConfig.CreateFromConfig(nil, inherit);
    Service := parent;
    
    Connection := nil;
end;

destructor TJustChatService_MinecraftTerminal.Destroy;
begin
    Config.Destroy();
end;

function TJustChatService_MinecraftTerminal.GetID : ansistring;
begin
    exit(ID);
end;

function TJustChatService_MinecraftTerminal.Send(MSG : TJustChatStructedMessage):longint;
Var
	P : ansistring;
	len : longint;

    AMsg : ansistring;
begin
	WaitForSingleObject(hMutex,Const_ThreadWaitingTime);

    AMsg := Msg.MinecraftFormatter;
	len:=length(AMsg);
	p:=MessageHeader+ char(len div (2<<23)) + char(len mod (2<<23) div (2<<15)) + char(len mod (2<<15) div (2<<7)) + char(len mod (2<<7)) + AMsg;
	
    Connection.Socket.Write(p);
    exit(0);
end;

function TJustChatStructedMessage.MinecraftFormatter():ansistring;
begin
    exit(structedMsg);
end;

function TJustChatStructedMessage.QQGroupFormater(sFormat : TJustChatConfig_TerminalConfig) : ansistring;
var
    msg : ansistring;
    i : longint;
begin
    if (sFormat.Event_isEnabled(eventType)) and (sFormat.Event_isEnabled(subEventType)) then begin
        msg := sFormat.Message_Get(msgType);
        for i:=0 to messageReplacementsLength-1 do begin
            {$IFDEF CoolQSDK}
            Message_Replace(msg,'%'+upcase(messageReplacements[i].k)+'%',messageReplacements[i].v);
            {$IFEND}
        end;
        exit(msg);
    end else begin
        exit('');
    end;
end;

constructor TJustChatStructedMessage.Create(aEventType, aSubEventType, aMsgType, aStructedMsg:ansistring);
begin
    messageReplacementsLength := 0;

    eventType := aEventType;
    subEventType := aSubEventType;
    msgType := aMsgType;
    structedMsg := aStructedMsg;
end;

procedure TJustChatStructedMessage.MessageReplacementsAdd(k,v:ansistring);
begin
    inc(messageReplacementsLength);
    setlength(messageReplacements, messageReplacementsLength);
    messageReplacements[messageReplacementsLength-1].k := k;
    messageReplacements[messageReplacementsLength-1].v := v;
end;

end.