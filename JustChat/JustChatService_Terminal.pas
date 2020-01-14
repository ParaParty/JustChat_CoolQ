unit JustChatService_Terminal;
{$MODE OBJFPC}

interface
uses
    windows, classes, sysutils,
    fpjson, jsonparser,
    gmap, gutil,
    JustChatConfig_TerminalConfig
    {$IFDEF __FULL_COMPILE_}
    ,CoolQSDK
    {$ENDIF}
    
    ;


type TJustChatService_Terminal = class
    private
        Config : TJustChatConfig_TerminalConfig;
    public
        constructor Create;
        destructor Destroy;override;
end;

implementation
constructor TJustChatService_Terminal.Create;
begin
end;

destructor TJustChatService_Terminal.Destroy;
begin
end;

end.