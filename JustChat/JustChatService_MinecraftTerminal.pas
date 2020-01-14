unit JustChatService_MinecraftTerminal;
{$MODE OBJFPC}

interface
uses
    windows, classes, sysutils,
    fpjson, jsonparser,
    gmap, gutil ,
    JustChatService_Terminal
    {$IFDEF __FULL_COMPILE_}
    ,CoolQSDK
    {$ENDIF}
    
    ;


type TJustChatService_MinecraftTerminal = class(TJustChatService_Terminal)
    private

    public
        constructor Create;
        destructor Destroy;override;
end;

implementation
constructor TJustChatService_MinecraftTerminal.Create;
begin
end;

destructor TJustChatService_MinecraftTerminal.Destroy;
begin
end;

end.