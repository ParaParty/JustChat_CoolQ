unit JustChatConfig;
{$MODE OBJFPC}

interface
uses
    windows, classes, sysutils,
    fpjson, jsonparser,
    Tools,
    gutil, gmap, gset,

    JustChatService_Terminal, JustChatService_QQGroupsTerminal,JustChatService_MinecraftTerminal

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

    AnsistringLess= specialize TLess<ansistring>;
    StringBooleanMap = specialize TMap<ansistring,boolean, AnsistringLess>;
    StringStringMap = specialize TMap<ansistring,ansistring, AnsistringLess>;

Const
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

        class function CreateFromConfig(config : TJsonData; inherit:TJustChatConfig_TerminalConfig=nil): TJustChatConfig_TerminalConfig; static;
end;

{
    关于指针的一个 STL 比较器
}
type TGenerallyLess = class
  class function c(a,b:TObject):boolean;inline;
end;

{
    配置文件，服务组
}
type TJustChatConfig_Services = class
    type
        TJustChatService_TerminalSet = specialize TSet<TJustChatService_Terminal, TGenerallyLess>;
    private
        TerminalSet : TJustChatService_TerminalSet;
        Config : TJustChatConfig_TerminalConfig;
    public
        constructor Create(Aconfig :TJsonData; inherit : TJustChatConfig_TerminalConfig);
        destructor Destroy;override;
end;

Var
    {
        JustChat 设置
        总体设置
    }
    JustChat_Config : record
        Version : longint; // 设置文件版本号
        Connection : JustChat_ConnectionConfig; // 连接设置

        Global_Configuration : TJustChatConfig_TerminalConfig; // 全局设置

        Services : array of TJustChatConfig_Services; // 服务组设置
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
                    /// 咕咕咕
                    {$IFDEF CoolQSDK}
                    CQ_i_addLog(CQ_LOG_WARNING,'Init_Config','Client mode is under development.');
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
            Justchat_Config.Global_Configuration := TJustChatConfig_TerminalConfig.CreateFromConfig(Config.findPath('global_configuration') ,nil);

            /// 读取服务组配置
            

            //Justchat_Config.Services 

            /// 读取群配置
            //Justchat_Config.Groups  

            /// 保存配置文件
            Config_Save(Config);
            Config.Free;
        end;
    except
        on e: Exception do begin
            Justchat_Config.Connection.Server.Enable := false;
            Justchat_Config.Connection.Client.Enable := false;
            {$IFDEF CoolQSDK}
            CQ_i_setFatal(CQLOG_FATAL, 'Config', 'Can not load configuration.'+CRLF+AnsiToUTF8(e.message));
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
            exit('')
        end;
    end;

    exit(ret);
end;

procedure TJustChatConfig_TerminalConfig.Message_Set(key : ansistring; value : ansistring);
begin
    MessagesMap.Insert(upcase(key),value);
end;

class function TJustChatConfig_TerminalConfig.CreateFromConfig(config : TJsonData; inherit:TJustChatConfig_TerminalConfig=nil): TJustChatConfig_TerminalConfig; static;
var
	enum : TBaseJSONEnumerator;
    current : TJSONEnum;

    ret : TJustChatConfig_TerminalConfig;
begin
    ret := TJustChatConfig_TerminalConfig.Create();

    ret.inheritFrom:=inherit;

    /// 读入事件设置
    if (config<>nil) and (config.findPath('events')<>nil) then begin
        /// 如果事件设置存在
        if config.findPath('events').JSONType = jtObject then begin

            /// 读入事件设置
            enum:=config.findPath('events').GetEnumerator;
            while enum.MoveNext do begin
                current := enum.GetCurrent();

                try
                    ret.Event_Set(current.key,current.value.asboolean)
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
                    ret.Message_Set(current.key,current.value.asstring)
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

    exit(ret);
end;


constructor TJustChatConfig_Services.Create(Aconfig :TJsonData; inherit : TJustChatConfig_TerminalConfig);
var
    tmp,cnt : TJsonData;
    i : longint;
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
            for i:= 0 to tmp.getPath('qqgroups').count-1 do begin
                cnt := tmp.getPath('qqgroups['+NumToChar(i)+']');
                if (cnt.JSONType <> jtNumber) then begin
                    {$IFDEF CoolQSDK}
                    CQ_i_addLog(CQLOG_WARNING,'Configuration','A QQ Group declaration in a service must be a NUMBER.'+CRLF+Aconfig.FormatJson());
                    {$ENDIF}
                end else begin
                    /// 读入QQ群配置

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
            for i:= 0 to tmp.getPath('minecraft').count-1 do begin
                cnt := tmp.getPath('minecraft['+NumToChar(i)+']');
                if (cnt.JSONType <> jtString) or (not IsGuid(cnt.AsString)) then begin
                    {$IFDEF CoolQSDK}
                    CQ_i_addLog(CQLOG_WARNING,'Configuration','A Minecraft terminal declaration in a service must be a UUID Format String.'+CRLF+Aconfig.FormatJson());
                    {$ENDIF}
                end else begin
                    /// 读入MC终端群配置

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
        exit ( longint(pointer(a))<longint(pointer(b)) )
    else if sizeof(pointer)=8 then
        exit ( int64(pointer(a))<int64(pointer(b)) )
    else raise Exception.Create('');
end;


end.