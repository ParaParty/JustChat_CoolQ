unit JustchatServer;
{$MODE OBJFPC}

interface
uses
    windows, classes, sysutils,
	fpjson, jsonparser,
	gmap,
	
	IdTcpServer, IdContext, IdTCPConnection, 
	//IdComponent,
	
	Tools,
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
		MessageBuffer	: ansistring;
		AMSG			: ansistring;

		procedure OnMessageHeartbeat(S : TJsonData);
		procedure OnMessageRegistration(S : TJsonData);
		procedure OnMessageInfo(S : TJsonData);
		procedure OnMessageChat(S : TJsonData);

	public
		Connection : TIdTCPConnection;
		ID : ansistring;
		status : TJustChatTerminalStatus;

		ConnectedTerminal : TJustChatService_MinecraftTerminal;

		constructor Create();
		procedure MessageBufferPush(s:ansichar);inline;
		function MessageBufferCheck() : boolean;
		procedure OnMessageReceived();

		procedure Broadcast(MSG : TJustChatStructedMessage);

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
begin
	Terminal := ConnectionsMap.GetValue(AContext.Connection);
	if Terminal = nil then begin
		{$IFDEF CoolQSDK}
		CQ_i_addLog(CQLOG_ERROR, 'Server', format('An invalid client %s:%d was detected.', [AContext.Binding.PeerIP, AContext.Binding.PeerPort]));
		{$ENDIF}
	end;

	try
		repeat 
			Terminal.MessageBufferPush(AContext.Connection.Socket.ReadChar);
		until Terminal.MessageBufferCheck();		
	except
		on e: Exception do begin
			{$IFDEF CoolQSDK}
			CQ_i_addLog(CQLOG_ERROR, 'Server',
				format('Client : %s:%d', [AContext.Binding.PeerIP, AContext.Binding.PeerPort]) + CRLF + e.message
			);
			{$ENDIF}
			AContext.Connection.Disconnect();
		end;
	end;

	Terminal.OnMessageReceived();

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

	ConnectedTerminal := nil;
end;

procedure TJustChatTerminal.MessageBufferPush(s:ansichar);inline;
begin
	MessageBuffer := MessageBuffer + s;
end;

function TJustChatTerminal.MessageBufferCheck() : boolean;
Var
	len		: longint;
	position: longint;
begin
	AMSG := '';
	
	if (length(MessageBuffer)>=1024*16) then begin
        raise Exception.Create('Buffer too long.');
    end;

	if (pos(SUBSTRING,MessageBuffer)<>0) then begin
        raise Exception.Create('Client require to close.');
	end;

	position:=pos(MessageHeader,MessageBuffer);	// 数据包起始点

	if length(MessageBuffer) >= position - 1 + (length(MessageHeader) + 4) then begin // 数据包足够包头长度
		len:=longint(
				longint( MessageBuffer[ position - 1 + length(MessageHeader) + 1 ] ) * 1<<24 +
				longint( MessageBuffer[ position - 1 + length(MessageHeader) + 2 ] ) * 1<<16 +
				longint( MessageBuffer[ position - 1 + length(MessageHeader) + 3 ] ) * 1<<8+
				longint( MessageBuffer[ position - 1 + length(MessageHeader) + 4 ] )
			);	// 数据包包体长度

			
		if length(MessageBuffer) >= position - 1 + (length(MessageHeader) + 4) + len then begin	// 如果数据包完整

			delete(MessageBuffer, 1, position - 1 + length(MessageHeader) + 4 ); // 删除数据包头部分
			AMSG:=copy(MessageBuffer, 1, len); // 截取出数据包体
			delete(MessageBuffer,1,len); // 删除数据包体部分

			exit(true);
		end;
	end;

	exit(false)
end;

procedure TJustChatTerminal.OnMessageReceived();
var
	MSG : ansistring;
	S : TJsonData;

	version,msgtype : int64;
begin
	MSG := AMSG;
	AMSG := '';

	try

		S := GetJSON(MSG);	

		/// 判断数据包版本
		version:=S.FindPath('version').asInt64;
		if version < ServerPackVersion then begin
			raise Exception.Create('Received a message made by a lower-version client.');
		end
		else if version > ServerPackVersion then begin
			raise Exception.Create('Received a message made by a higher-version client.');
		end;

		/// 判断数据包类型
		msgtype:=S.FindPath('type').asInt64;
		case msgtype of
			TMsgType_HEARTBEATS : begin
				OnMessageHeartbeat(S);
			end;
			TMSGTYPE_REGISTRATION : begin
				OnMessageRegistration(S);
			end;
			TMsgType_INFO : begin
				OnMessageInfo(S);
			end;
			TMsgType_MESSAGE : begin
				OnMessageChat(S);
			end;
			else begin
				raise Exception.Create('Received a message with an unrecognized type.');
			end;
		end;


		S.Free
		
	except
		on e: Exception do begin
			{$IFDEF CoolQSDK}
			CQ_i_addLog(CQLOG_ERROR, 'Message Handler',
				'Received an unrecognized message.' + CRLF +
				e.message + CRLF +
				Base64_Encryption(AMSG));
			{$ELSE}
			CQ_i_addLog(CQLOG_ERROR, 'Message Handler',
				'Received an unrecognized message.' + CRLF +
				e.message );
			{$ENDIF}
		end;
	end;

end;

procedure TJustChatTerminal.OnMessageHeartbeat(S : TJsonData);
begin
	{$IFDEF CoolQSDK}
	CQ_i_addLog(CQLOG_DEBUG,'Message Handler',format('[%s:%d] : Received a pulse echo.', [Connection.Socket.binding.peerIP, Connection.Socket.binding.PeerPort] ));
	{$ENDIF}
end;

procedure TJustChatTerminal.OnMessageRegistration(S : TJsonData);
var
	MsgPack : TJustChatStructedMessage;
begin
	if Status <> Start then begin
		Connection.Disconnect();
		raise Exception.Create('Invalid message.');
	end;

	if S.FindPath('identity').asInt64 <> REGISTRATION_MINECRAFT then begin
		Connection.Disconnect();
		raise Exception.Create('Invalid identity.');
	end;

	ID := Base64_Decryption(S.FindPath('name').asString);
	if (not IsGuid(ID)) then begin
		Connection.Disconnect();
		raise Exception.Create('Invalid ID.');
	end;


	ConnectedTerminal := JustChat_Config.MinecraftTerminals.GetValue(ID);
	if ConnectedTerminal = nil then begin
		Connection.Disconnect();
		raise Exception.Create('Invalid message. ID not found in configuration.'); 
	end;

	ConnectedTerminal.name := Base64_Decryption(S.FindPath('name').asString);

	MsgPack := TJustChatStructedMessage.Create(TJustChatStructedMessage.Registration_All, TJustChatStructedMessage.Event_online, S.AsJSON);
	MsgPack.MessageReplacementsAdd('NAME',ConnectedTerminal.name);
	BroadCast(MsgPack);
	MsgPack.Destroy();

end;

procedure TJustChatTerminal.OnMessageInfo(S : TJsonData);
begin
	/// TODO
end;

procedure TJustChatTerminal.OnMessageChat(S : TJsonData);
begin
	/// TODO
end;

procedure TJustChatTerminal.Broadcast(MSG : TJustChatStructedMessage);
begin
	ConnectedTerminal.Broadcast(MSG);
end;

end.