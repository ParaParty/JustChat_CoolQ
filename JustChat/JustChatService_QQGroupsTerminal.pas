unit JustChatService_QQGroupsTerminal;
{$MODE OBJFPC}

interface
uses
    windows, classes, sysutils,
    fpjson, jsonparser,
    gmap, gutil,
    JustChatService_Terminal
    {$IFDEF __FULL_COMPILE_}
    ,CoolQSDK
    {$ENDIF}
    
    ;


type TJustChatService_QQGroupsTerminal = class(TJustChatService_Terminal)
    private

    public
        constructor Create;
        destructor Destroy;override;
end;

implementation
constructor TJustChatService_QQGroupsTerminal.Create;
begin
end;

destructor TJustChatService_QQGroupsTerminal.Destroy;
begin
end;

end.