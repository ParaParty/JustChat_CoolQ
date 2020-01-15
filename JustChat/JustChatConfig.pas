unit JustChatConfig;
{$MODE OBJFPC}

interface
/// 引入
uses
    windows, classes, sysutils,
    fpjson, jsonparser,
    Tools,
    gutil, gmap, gset

    {$IFDEF __FULL_COMPILE_}
    ,CoolQSDK
    {$ENDIF}
    ;

/// 类型定义
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

    TMsgType_INFO_Join = 1;
    TMsgType_INFO_Disconnect = 2;
    TMsgType_INFO_PlayerDead = 3;

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
    终端
}
type TJustChatService_Terminal = class
    protected
        Config : TJustChatConfig_TerminalConfig;
    public
        constructor Create;
        destructor Destroy; override;
        function GetID : int64; virtual;
        function GetID : ansistring; virtual;
        procedure InsertConfig(aConfig :TJsonData);
end;

{
    QQ群终端
}
type TJustChatService_QQGroupsTerminal = class(TJustChatService_Terminal)
    private
        ID : int64;
    public
        constructor Create(AID : int64; inherit : TJustChatConfig_TerminalConfig);
        destructor Destroy;override;
        function GetID : int64;
end;

{
    MC终端
}
type TJustChatService_MinecraftTerminal = class(TJustChatService_Terminal)
    private
        ID : ansistring;
    public
        constructor Create(AID : ansistring; inherit : TJustChatConfig_TerminalConfig);
        destructor Destroy;override;
        function GetID : ansistring;
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
begin
    if (Is_FileStatus(CQ_i_getAppDirectory+'config.ini')=0) then begin
        /// TODO
        /// 存在旧版本配置文件
        /// 把文件搬走然后给你重建配置文件
    end;
    /// 咕咕咕
    exit(0);
end;

{
    升级配置文件
}
function UpdateConfig(Config:TJsonData):longint;
begin
    if ((Config.findPath('version.config')=nil) or (Config.findPath('version.config').AsInt64 < 2)) then begin
        /// TODO
        /// 存在旧版本配置文件
        /// 把文件搬走然后给你重建配置文件
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
                    /// TODO
                    /// 咕咕咕
                    {$IFDEF CoolQSDK}
                    CQ_i_addLog(CQ_LOG_WARNING,'Configuration','Client mode is under development.');
                    {$ENDIF}
                end;
            end;

            if (Config.findPath('connection.ID')=nil) or (not IsGUID(Config.findPath('connection.ID').asString)) then begin
                tmpObject := TJsonObject(Config.findPath('connection'));
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
                        CQ_i_addLog(CQ_LOG_WARNING,'Configuration','An invalid service configuration was detected.'+CRLF+T.FormatJson());
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
                        CQ_i_addLog(CQ_LOG_WARNING,'Configuration','An invalid qqgroups configuration was detected.'+CRLF+T.FormatJson());
                        {$ENDIF}
                        continue;
                    end;

                    groupid := T.findPath('groupid').asInt64;
                    if JustChat_Config.QQGroupTerminals.TryGetValue(groupid, tmpGroupTerminal) then begin
                        tmpGroupTerminal.InsertConfig(T.findPath('config'));
                    end else begin
                        {$IFDEF CoolQSDK}
                        CQ_i_addLog(CQ_LOG_WARNING,'Configuration','An unused qqgroups configuration was detected.'+CRLF+T.FormatJson());
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
            CQ_i_setFatal(CQLOG_FATAL, 'Configuration', 'Can not load configuration.'+CRLF+AnsiToUTF8(e.message));
            {$ENDIF}
        end;
    end;

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
                        CQ_i_addlog(CQLOG_ERROR, 'Configuration', e.message());
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
                        CQ_i_addlog(CQLOG_ERROR, 'Configuration', e.message());
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

    t : TJustChatService_Terminal;
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

                    /// TODO 判断是否已经出现过

                    t := TJustChatService_QQGroupsTerminal.Create(cnt.AsInt64, config);
                    TerminalSet.Insert(t);
                    JustChat_Config.QQGroupTerminals.Insert(cnt.AsInt64, TJustChatService_QQGroupsTerminal(t));
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

                    /// TODO 判断是否已经出现过

                    t := TJustChatService_MinecraftTerminal.Create(cnt.AsString, config);
                    TerminalSet.Insert(t);
                    JustChat_Config.MinecraftTerminals.Insert(cnt.AsString, TJustChatService_MinecraftTerminal(t));
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

procedure TJustChatService_Terminal.InsertConfig(aConfig : TJsonData);
begin
    Config.InsertConfig(aConfig)
end;

constructor TJustChatService_QQGroupsTerminal.Create(AID : int64; inherit : TJustChatConfig_TerminalConfig);
begin
    ID := AID;
    Config := TJustChatConfig_TerminalConfig.CreateFromConfig(nil, inherit);
end;

destructor TJustChatService_QQGroupsTerminal.Destroy;
begin
    Config.Destroy();
end;

function TJustChatService_QQGroupsTerminal.GetID():int64;
begin
    exit(ID);
end;

constructor TJustChatService_MinecraftTerminal.Create(AID : ansistring; inherit : TJustChatConfig_TerminalConfig);
begin
    ID := AID;
    Config := TJustChatConfig_TerminalConfig.CreateFromConfig(nil, inherit);
end;

destructor TJustChatService_MinecraftTerminal.Destroy;
begin
    Config.Destroy();
end;

function TJustChatService_MinecraftTerminal.GetID : ansistring;
begin
    exit(ID);
end;

end.