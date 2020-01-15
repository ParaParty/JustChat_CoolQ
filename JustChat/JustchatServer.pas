unit JustchatServer;
{$MODE OBJFPC}

interface
uses
    windows, classes, sysutils,
	gmap,
	
	IdTcpServer, IdContext, IdTCPConnection, 
	//IdComponent,
	

	JustChatConfig

	{$IFDEF __FULL_COMPILE_}
    ,CoolQSDK
    {$ENDIF}
    ;

procedure CloseService();
procedure StartService();

type TJustChatService = class
	type
		TConnectionsMap = specialize TMap<TIdTCPConnection, TIdTCPConnection, TGenerallyLess>;
	private
		JustChatServer : TIdTcpServer;
		ConnectionsMap : TConnectionsMap;

        procedure ServerOnConnect(AContext: TIdContext);
        procedure ServerOnDisconnect(AContext: TIdContext);
        procedure ServerOnExecute(AContext: TIdContext);
        ///procedure ServerOnStatus(ASender: TObject; const AStatus: TIdStatus; const AStatusText: string);
 

		procedure ServerStart();
		procedure ServerStop();

		procedure ClientStart();
		procedure ClientStop();


	public
		constructor Create();
		destructor Destroy(); override;
end;

var
	JustChatService : TJustChatService;

implementation

Const
	MessageHeader = #$11+#$45+#$14;
	
procedure CloseService();
begin
	
end;

procedure StartService();
begin
	JustChatService := TJustChatService.Create();
end;

constructor TJustChatService.Create();
begin
	ConnectionsMap := TConnectionsMap.Create();
	ServerStart();
	ClientStart();
end;

destructor TJustChatService.Destroy();
begin
	ConnectionsMap.Destroy();
	ServerStop();
	ClientStop();
end;

procedure TJustChatService.ServerStart();
begin
	if JustChat_Config.Connection.Server.enable then begin
		try
			JustChatServer := TIdTCPServer.Create(nil);
			JustChatServer.DefaultPort := JustChat_Config.Connection.Server.port;
			JustChatServer.OnConnect := @ServerOnConnect;
			JustChatServer.OnDisconnect := @ServerOnDisconnect;
			JustChatServer.OnExecute := @ServerOnExecute;
			//JustChatServer.OnStatus := ServerOnStatus;
			JustChatServer.Active := true;
		except
			on e: Exception do begin
				Justchat_Config.Connection.Server.Enable := false;
				{$IFDEF CoolQSDK}
				CQ_i_setFatal(CQLOG_FATAL, 'Server', 'Can not start the server.'+CRLF+AnsiToUTF8(e.message));
				{$ENDIF}
			end;
		end;
	end;
end;

procedure TJustChatService.ServerStop();
begin
	JustChatServer.Active := false;
end;

procedure TJustChatService.ClientStart();
begin
	if JustChat_Config.Connection.Client.enable then begin
		try
			/// TODO
			raise Exception.Create('Client mode is not supported yet.');
		except
			on e: Exception do begin
				Justchat_Config.Connection.Client.Enable := false;
				{$IFDEF CoolQSDK}
				CQ_i_setFatal(CQLOG_FATAL, 'Server', 'Can not start the server.'+CRLF+AnsiToUTF8(e.message));
				{$ENDIF}
			end;
		end;
	end;
end;

procedure TJustChatService.ClientStop();
begin
	
end;

procedure TJustChatService.ServerOnConnect(AContext: TIdContext);
begin
	
end;

procedure TJustChatService.ServerOnDisconnect(AContext: TIdContext);
begin
	
end;

procedure TJustChatService.ServerOnExecute(AContext: TIdContext);
begin
	
end;

{
procedure TJustChatService.ServerOnStatus(ASender: TObject; const AStatus: TIdStatus; const AStatusText: string);
begin
	
end;
}

end.