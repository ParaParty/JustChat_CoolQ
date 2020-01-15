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

type TJustChatTerminalStatus = (Start, Confirmed);

type TJustChatTerminal = class
	private
		MessageBuffer : ansistring;
	public
		Connection : TIdTCPConnection;
		ID : ansistring;
		status : TJustChatTerminalStatus;

		ConnectedService : TJustChatService_MinecraftTerminal;

		constructor Create();
		procedure MessageBufferPush(s:ansichar);inline;
		function MessageBufferCheck(Var MSG : ansistring) : boolean;
		procedure OnMessageReceived(Var MSG : ansistring);

end;

type TJustChatService = class
	type
		TConnectionsMap = specialize TMap<TIdTCPConnection, TJustChatTerminal, TGenerallyLess>;
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

const
	MessageHeader = #$11+#$45+#$14;
	//PulseHeader = #$70+#$93+#$94;
	SUBSTRING = #$1A+#$1A+#$1A+#$1A+#$1A+#$1A+#$1A+#$1A;
	
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
				CQ_i_addLog(CQLOG_FATAL, 'Server', 'Can not start the server.'+CRLF+AnsiToUTF8(e.message));
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
			/// TODO 客户端模式实现
			raise Exception.Create('Client mode is not supported yet.');
		except
			on e: Exception do begin
				Justchat_Config.Connection.Client.Enable := false;
				{$IFDEF CoolQSDK}
				CQ_i_addLog(CQLOG_FATAL, 'Server', 'Can not start the server.'+CRLF+AnsiToUTF8(e.message));
				{$ENDIF}
			end;
		end;
	end;
end;

procedure TJustChatService.ClientStop();
begin
	
end;

procedure TJustChatService.ServerOnConnect(AContext: TIdContext);
var
    peerIP      : string;
    peerPort    : int64;
	t			: TJustChatTerminal;
begin
    peerIP    := AContext.Binding.PeerIP;
    peerPort  := AContext.Binding.PeerPort;
	{$IFDEF CoolQSDK}
	CQ_i_addLog(CQLOG_INFORECV, 'Server', format('A new client %s:%d tries to connect.', [peerIP, peerPort]));
	{$ENDIF}

	t := TJustChatTerminal.Create();
	t.Connection := AContext.Connection;

	ConnectionsMap.Insert(t.Connection, t);

end;

procedure TJustChatService.ServerOnDisconnect(AContext: TIdContext);
var
	Terminal : TJustChatTerminal;
begin
	/// TODO 删除在线状态
	Terminal := ConnectionsMap.GetValue(AContext.Connection);
	if (Terminal <> nil) then Terminal.Destroy();
	ConnectionsMap.Delete(AContext.Connection);
end;

procedure TJustChatService.ServerOnExecute(AContext: TIdContext);
var
	Terminal : TJustChatTerminal;
	MSG		: ansistring;
begin
	Terminal := ConnectionsMap.GetValue(AContext.Connection);
	if Terminal = nil then begin
		{$IFDEF CoolQSDK}
		CQ_i_addLog(CQLOG_ERROR, 'Server', format('An invalid client %s:%d was detected.', [AContext.Binding.PeerIP, AContext.Binding.PeerPort]));
		{$IFEND}
	end;

	try
		repeat 
			Terminal.MessageBufferPush(AContext.Connection.Socket.ReadChar);
		until Terminal.MessageBufferCheck( MSG );		
	except
		on e: Exception do begin
			{$IFDEF CoolQSDK}
			CQ_i_addLog(CQLOG_ERROR, 'Server',
				format('Client : %s:%d', [AContext.Binding.PeerIP, AContext.Binding.PeerPort]) + CRLF + e.message
			);
			{$IFEND}
			AContext.Connection.Disconnect();
		end;
	end;

	Terminal.OnMessageReceived(MSG);

end;




{
procedure TJustChatService.ServerOnStatus(ASender: TObject; const AStatus: TIdStatus; const AStatusText: string);
begin
	
end;
}

constructor TJustChatTerminal.Create;
begin
	Connection := nil;
	ID := '';
	Status := Start;

	ConnectedService := nil;
end;

procedure TJustChatTerminal.MessageBufferPush(s:ansichar);inline;
begin
	MessageBuffer := MessageBuffer + s;
end;

function TJustChatTerminal.MessageBufferCheck(Var MSG : ansistring) : boolean;
Var
	len		: longint;
	position: longint;
begin
	
	
	if (length(MessageBuffer)>=1024*16) then begin
        raise Exception.Create('Buffer too long.');
    end;

	if (pos(SUBSTRING,MessageBuffer)<>0) then begin
        raise Exception.Create('Client require to close.');
	end;

	position:=pos(MessageHeader,MessageBuffer);
	if length(MessageBuffer)>=position-1+length(MessageHeader)+4 then begin
		len:=longint(
				longint(MessageBuffer[position-1+length(MessageHeader)+1]) * 1<<24 +
				longint(MessageBuffer[position-1+length(MessageHeader)+2]) * 1<<16 +
				longint(MessageBuffer[position-1+length(MessageHeader)+3]) * 1<<8+
				longint(MessageBuffer[position-1+length(MessageHeader)+4])
			);

			
		if length(MessageBuffer)>=position-1+length(MessageHeader)+4+len then begin
			delete(MessageBuffer,1,position-1+length(MessageHeader)+4);
			MSG:=copy(MessageBuffer,1,len);
			delete(MessageBuffer,1,len);

			result:=true;
		end;
	end;

	result := false;
end;

procedure TJustChatTerminal.OnMessageReceived(Var MSG : ansistring);
begin
	/// TODO [紧急] 数据包解析
end;

end.