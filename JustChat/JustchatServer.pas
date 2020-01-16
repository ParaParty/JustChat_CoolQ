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

type TJustChatTerminal = class
	type TJustChatTerminalStatus = (Start, Confirmed);
	private
		MessageBuffer	: ansistring;
		AMSG			: ansistring;

		procedure OnMessageHeartbeat(S : TJsonData);
		procedure OnMessageRegistration(S : TJsonData);
		procedure OnMessageInfo(S : TJsonData);
		procedure OnMessageChat(S : TJsonData);

		function TextMessageContentUnpack(a:TJSONData):ansistring;

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
	MsgPack : TJustChatStructedMessage;

	Terminal : TJustChatTerminal;
begin
	/// 将本终端从终端列表中移除
	Terminal := ConnectionsMap.GetValue(AContext.Connection);
	ConnectionsMap.Delete(AContext.Connection);

	/// 如果本终端原本存在
	if (Terminal <> nil) then begin

		if Terminal.Status = Confirmed then begin
			MsgPack := TJustChatStructedMessage.Create(TJustChatStructedMessage.Registration_All, TJustChatStructedMessage.Registration_All, TJustChatStructedMessage.Event_offline , '{"version": '+NumToChar(ServerPackVersion)+'}');
			MsgPack.MessageReplacementsAdd('NAME',Terminal.ConnectedTerminal.name);
			Terminal.BroadCast(MsgPack);
			MsgPack.Destroy();
		end;

		Terminal.ConnectedTerminal.name := '';
		Terminal.Destroy();
	end;
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
	MsgPack := TJustChatStructedMessage.Create(TJustChatStructedMessage.Registration_All, TJustChatStructedMessage.Registration_All, TJustChatStructedMessage.Event_online , S.AsJSON);
	MsgPack.MessageReplacementsAdd('NAME',ConnectedTerminal.name);
	BroadCast(MsgPack);
	MsgPack.Destroy();

end;

procedure TJustChatTerminal.OnMessageInfo(S : TJsonData);
var
	eventType : int64;
	MsgPack : TJustChatStructedMessage;

	content, sender : ansistring;
begin
	if (Status <> Confirmed) or (ConnectedTerminal = nil) then begin
		Connection.Disconnect();
		raise Exception.Create('Invalid message.');
	end;

	if S.FindPath('event')<>nil then begin
		/// 定义事件
		eventType:=S.FindPath('event').asInt64;

		if ( eventType in [TMsgType_INFO_Join, TMsgType_INFO_Disconnect, TMsgType_INFO_PlayerDead] ) then begin
			/// 已知类型
			if S.FindPath('content')<>nil
				then content:=Base64_Decryption(S.FindPath('content').AsString)
				else content:='';

			if content='' then begin
				/// 数据包中不存在预设文本

				if S.FindPath('sender')<>nil then begin

					case eventType of
						TMsgType_INFO_Join : MsgPack := TJustChatStructedMessage.Create(TJustChatStructedMessage.Info_All, TJustChatStructedMessage.Info_Network, TJustChatStructedMessage.Msg_INFO_Join , S.AsJSON);
						TMsgType_INFO_Disconnect :  MsgPack := TJustChatStructedMessage.Create(TJustChatStructedMessage.Info_All, TJustChatStructedMessage.Info_Network, TJustChatStructedMessage.Msg_INFO_Disconnect , S.AsJSON);
						TMsgType_INFO_PlayerDead :  MsgPack := TJustChatStructedMessage.Create(TJustChatStructedMessage.Info_All, TJustChatStructedMessage.Info_PlayerDeath, TJustChatStructedMessage.Msg_INFO_PlayerDead , S.AsJSON);
						else raise Exception.Create('Internal error in Infomation Message Unpacker.');
					end;

					MsgPack.MessageReplacementsAdd('SERVER',ConnectedTerminal.name);
					sender:=Base64_Decryption(S.FindPath('sender').asString);
					MsgPack.MessageReplacementsAdd('SENDER',sender);
					MsgPack.MessageReplacementsAdd('PLAYER',sender);
					BroadCast(MsgPack);
					MsgPack.Destroy();


				end else begin
					/// 数据包中缺少必要信息

					raise Exception.Create('Invalid message.');

				end;

			end
			else
			begin
				/// 数据包中存在预设文本

				if content<>'' then begin

					case eventType of
						TMsgType_INFO_Join : MsgPack := TJustChatStructedMessage.Create(TJustChatStructedMessage.Info_All, TJustChatStructedMessage.Info_Network, TJustChatStructedMessage.Msg_INFO_General , S.AsJSON);
						TMsgType_INFO_Disconnect :  MsgPack := TJustChatStructedMessage.Create(TJustChatStructedMessage.Info_All, TJustChatStructedMessage.Info_Network, TJustChatStructedMessage.Msg_INFO_General , S.AsJSON);
						TMsgType_INFO_PlayerDead :  MsgPack := TJustChatStructedMessage.Create(TJustChatStructedMessage.Info_All, TJustChatStructedMessage.Info_PlayerDeath, TJustChatStructedMessage.Msg_INFO_General , S.AsJSON);
						else raise Exception.Create('Internal error in Infomation Message Unpacker.');
					end;

					MsgPack.MessageReplacementsAdd('SERVER',ConnectedTerminal.name);
					MsgPack.MessageReplacementsAdd('CONTENT',content);
					BroadCast(MsgPack);
					MsgPack.Destroy();

				end;

			end;

		end else begin
			/// 未知类型

			if S.FindPath('content')<>nil
				then content:=Base64_Decryption(S.FindPath('content').AsString)
				else content:='';

			if content<>'' then begin
				MsgPack := TJustChatStructedMessage.Create(TJustChatStructedMessage.Info_All, TJustChatStructedMessage.Info_Other, TJustChatStructedMessage.Msg_INFO_General , S.AsJSON);
				MsgPack.MessageReplacementsAdd('SERVER',ConnectedTerminal.name);
				MsgPack.MessageReplacementsAdd('CONTENT',content);
				BroadCast(MsgPack);
				MsgPack.Destroy();
			end;

		end;

	end
	else
	begin
		/// 一般事件

		if S.FindPath('content')<>nil
			then content:=Base64_Decryption(S.FindPath('content').AsString)
			else content:='';

		if content<>'' then begin
			MsgPack := TJustChatStructedMessage.Create(TJustChatStructedMessage.Info_All, TJustChatStructedMessage.Info_Other, TJustChatStructedMessage.Msg_INFO_General , S.AsJSON);
			MsgPack.MessageReplacementsAdd('SERVER',ConnectedTerminal.name);
			MsgPack.MessageReplacementsAdd('CONTENT',content);
			BroadCast(MsgPack);
			MsgPack.Destroy();
		end;

	end;
end;

function TJustChatTerminal.TextMessageContentUnpack(a:TJSONData):ansistring;
Var
	i:longint;
Begin
	result:='';
	for i:=0 to a.count-1 do begin
		if a.FindPath('['+NumToChar(i)+'].type').asString='text' then begin
			result:=result+Base64_Decryption(a.FindPath('['+NumToChar(i)+'].content').asString);
		end;
	end;
End;

procedure TJustChatTerminal.OnMessageChat(S : TJsonData);
var
	MsgPack : TJustChatStructedMessage;

	sender,world_display,content : ansistring;
begin
	sender := Base64_Decryption(S.FindPath('sender').asString);
	world_display := Base64_Decryption(S.FindPath('world_display').asString);
	content := TextMessageContentUnpack(S.FindPath('content'));
	
	MsgPack := TJustChatStructedMessage.Create(TJustChatStructedMessage.Message_All, TJustChatStructedMessage.Message_All, TJustChatStructedMessage.Msg_Message_Overview , S.AsJSON);
	MsgPack.MessageReplacementsAdd('SERVER', ConnectedTerminal.name);
	MsgPack.MessageReplacementsAdd('WORLD_DISPLAY', CQ_CharEncode(world_display,false));
	MsgPack.MessageReplacementsAdd('SENDER', CQ_CharEncode(sender,false));
	MsgPack.MessageReplacementsAdd('CONTENT', CQ_CharEncode(content,false));
	BroadCast(MsgPack);
	MsgPack.Destroy();
end;

procedure TJustChatTerminal.Broadcast(MSG : TJustChatStructedMessage);
begin
	ConnectedTerminal.Broadcast(MSG);
end;

end.