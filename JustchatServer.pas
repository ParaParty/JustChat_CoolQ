unit JustchatServer;
{$mode delphi}

interface
uses
    Sockets,windows,classes,sysutils,crt,
    CoolQSDK,
	JustchatConfig;

Type
	Client = record
				FromName: sockaddr_in;
				Sin,Sout: Text;
				PID		: LongWord;
				
				buff	: ansistring;
				info	: record
							name:ansistring;
						end;

				status	: longint;
			end;
	PClient = ^Client;
	
	MessagePack	=	record
						Client	:	PClient;
						length	:	longint;
						MSG		:	ansistring;
						PID		:	LongWord;
					end;
	PMessagePack= ^MessagePack;
	
	TonMessageReceived = procedure(aMSGPack:PMessagePack);
	TonClientDisconnect = procedure(aClient:PClient);
	TMSG_Register = function():ansistring;


Var
    PonMessageReceived:pointer=nil;
    PonClientDisconnect:pointer=nil;
    PMSG_Register:pointer=nil;
    JustchatServer_PID:LongWord;


procedure closeServer();
procedure StartService();stdcall;
procedure Broadcast(MSG:ansistring);overload;
procedure Broadcast(MSG:ansistring;aClient:PClient);overload;

implementation

	
Const
	MessageHeader = #$11+#$45+#$14;
	//PulseHeader = #$70+#$93+#$94;
	SUBSTRING = #$1A+#$1A+#$1A+#$1A+#$1A+#$1A+#$1A+#$1A;
	
	Const_ThreadWaitingTime = 5000;
	
Var
	S			: Longint;
	SAddr		: TInetSockAddr;
	ClientList: TList;

	hMutex	: handle;

  
  
procedure stertServer();
Begin
	if upcase(ServerConfig.mode)='SERVER' then begin
		S:=fpSocket (AF_INET,SOCK_STREAM,0);
		if (SocketError<>0) and (SocketError<>183) then CQ_i_addLog(CQLOG_FATAL,'JustChatS | StartServer','Socket : ERR:'+NumToChar(SocketError));
		SAddr.sin_family:=AF_INET;
		SAddr.sin_port:=htons(ServerConfig.port);
		SAddr.sin_addr:=ServerConfig.ip;
		if fpBind(S,@SAddr,sizeof(saddr))=-1 then begin
			CQ_i_addLog(CQLOG_FATAL,'JustChatS | StartServer','Bind : ERR:'+NumToChar(SocketError)+CRLF+
									'Fail to bind to '+NetAddrToStr(SAddr.sin_addr)+':'+NumToChar(ntohs(SAddr.sin_port)));
		end;
		if fpListen (S,1)=-1 then begin
			CQ_i_addLog(CQLOG_FATAL,'JustChatS | StartServer','Listen : ERR:'+NumToChar(SocketError)+CRLF+
									'Fail to listen on '+NetAddrToStr(SAddr.sin_addr)+':'+NumToChar(ntohs(SAddr.sin_port)));
		end;
	end	else
	if upcase(ServerConfig.mode)='CLIENT' then begin
		S:=fpSocket (AF_INET,SOCK_STREAM,0);
		if (SocketError<>0) and (SocketError<>183) then CQ_i_addLog(CQLOG_FATAL,'JustChatS | StartServer','Socket : ERR:'+NumToChar(SocketError));
		SAddr.sin_family:=AF_INET;
		SAddr.sin_port:=htons(ServerConfig.port);
		SAddr.sin_addr.s_addr:=ServerConfig.ip.s_addr;
	end else
	begin
		CQ_i_addLog(CQLOG_FATAL,'JustChatS | StartServer','A Unknown mode given.');
	end;
End;

procedure closeServer();
Begin
	CloseSocket(S);
	CQ_i_addLog(CQLOG_INFO,'JustChatS | CloseServer','Server Closed.');
End;

procedure onMessageReceived(aMSGPack:PMessagePack);stdcall;
Begin
	if PonMessageReceived<>nil then begin
		if upcase(ServerConfig.mode)='SERVER' then CQ_i_addLog(CQLOG_INFORECV,'JustChatS | onMessageReceived | '+NetAddrToStr(aMSGPack^.Client^.FromName.sin_addr)+':'+NumToChar(aMSGPack^.Client^.FromName.sin_port),Base64_Encryption(aMSGPack^.MSG))
		else if upcase(ServerConfig.mode)='CLIENT' then CQ_i_addLog(CQLOG_INFORECV,'JustChatS | onMessageReceived | '+NetAddrToStr(aMSGPack^.Client^.FromName.sin_addr)+':'+NumToChar(aMSGPack^.Client^.FromName.sin_port),Base64_Encryption(aMSGPack^.MSG))
		else CQ_i_addLog(CQLOG_FATAL,'JustChatS | aSession','A Unknown mod given');
		TonMessageReceived(PonMessageReceived)(aMSGPack);
	end
	else
	begin
		if upcase(ServerConfig.mode)='SERVER' then CQ_i_addLog(CQLOG_WARNING,'JustChatS | onMessageReceived',NetAddrToStr(aMSGPack^.Client^.FromName.sin_addr)+':'+NumToChar(aMSGPack^.Client^.FromName.sin_port)+' : onMessageReceived is not assigned.')
		else if upcase(ServerConfig.mode)='CLIENT' then  CQ_i_addLog(CQLOG_WARNING,'JustChatS | onMessageReceived',NetAddrToStr(aMSGPack^.Client^.FromName.sin_addr)+':'+NumToChar(aMSGPack^.Client^.FromName.sin_port)+' : onMessageReceived is not assigned.')
		else CQ_i_addLog(CQLOG_FATAL,'JustChatS | aSession','A Unknown mod given');        
	end;
	dispose(aMSGPack);
End;

procedure checkMessage(a:PCLient);
Var
	len		: longint;
	position: longint;
	MSG		: ansistring;
	
	MSGPack	: PMessagePack;
Begin

	//CQ_i_addLog(CQLOG_INFOSEND,'JustChatS | checkMessage | Client '+NetAddrToStr(a^.FromName.sin_addr)+':'+NumToChar(a^.FromName.sin_port),Base64_Encryption(a^.buff));

	position:=pos(MessageHeader,a^.buff);
	if length(a^.buff)>=position-1+length(MessageHeader)+4 then begin
		len:=longint(
				longint(a^.buff[position-1+length(MessageHeader)+1]) * 2<<23+
				longint(a^.buff[position-1+length(MessageHeader)+2]) * 2<<15+
				longint(a^.buff[position-1+length(MessageHeader)+3]) * 2<<7+
				longint(a^.buff[position-1+length(MessageHeader)+4])
			);
		if length(a^.buff)>=position-1+length(MessageHeader)+4+len then begin
			delete(a^.buff,1,position-1+length(MessageHeader)+4);
			MSG:=copy(a^.buff,1,len);
			delete(a^.buff,1,len);
			
			new(MSGPack);
			MSGPack^.Client:=a;
			MSGPack^.length:=len;
			MSGPack^.MSG:=MSG;
			
			createthread(nil,0,@onMessageReceived,MSGPack,0,MSGPack^.PID);
		end;
	end;

{
	if pos(PulseHeader,a^.buff)<>0 then begin
		writeln('Server, Are you online? Go out and have fun!');
		delete(a^.buff,1,pos(PulseHeader,a^.buff)-1+length(PulseHeader));
		write(a^.Sout,PulseHeader+#$00+#$00+#$00+#$00);
	end;
}
	if (length(a^.buff)>=1024*16) then begin
        CQ_i_addLog(CQLOG_ERROR,'JustChatS | MessageCheck',NetAddrToStr(a^.FromName.sin_addr)+':'+NumToChar(a^.FromName.sin_port)+' : buff too long');
        raise Exception.Create('buff too long');
    end;

	if (pos(SUBSTRING,a^.buff)<>0) then begin
        CQ_i_addLog(CQLOG_INFO,'JustChatS | MessageCheck',NetAddrToStr(a^.FromName.sin_addr)+':'+NumToChar(a^.FromName.sin_port)+' : Client close the connection');
        raise Exception.Create('closed by client');
	end;
End;

procedure aSession(a:PClient);stdcall;
Var
	c	:	char;
Begin
	
	//if NetAddrToStr(a^.FromName.sin_addr)='132.232.30.14' then begin
		if upcase(ServerConfig.mode)='SERVER' then CQ_i_addLog(CQLOG_INFOSUCCESS,'JustChatS | aSession Accept',NetAddrToStr(a^.FromName.sin_addr)+':'+NumToChar(a^.FromName.sin_port))
		else if upcase(ServerConfig.mode)='CLIENT'  then CQ_i_addLog(CQLOG_INFOSUCCESS,'JustChatS | aSession Connected',NetAddrToStr(a^.FromName.sin_addr)+':'+NumToChar(a^.FromName.sin_port))
		else CQ_i_addLog(CQLOG_FATAL,'JustChatS | aSession','A Unknown mod given');
		try
			repeat
				read(a^.sIn,c);
				a^.buff:=a^.buff+c;
				//CQ_i_addLog(CQLOG_INFOSUCCESS,'JustChatS | Readin '+NetAddrToStr(a^.FromName.sin_addr)+':'+NumToChar(a^.FromName.sin_port),Base64_Encryption(a^.buff));
				checkMessage(a);
			//until false;
			until eof(a^.sIn) or (a^.status=-1);
			
			ClientList.Remove(a);
			if PonClientDisconnect<>nil then TonClientDisconnect(PonClientDisconnect)(a);
			Dispose(a);
		except
			on e:Exception do begin
				if upcase(ServerConfig.mode)='SERVER' then CQ_i_addLog(CQLOG_INFOSUCCESS,'JustChatS | aSession Close',NetAddrToStr(a^.FromName.sin_addr)+':'+NumToChar(a^.FromName.sin_port))
				else if upcase(ServerConfig.mode)='CLIENT'  then CQ_i_addLog(CQLOG_INFOSUCCESS,'JustChatS | aSession Disconnected',NetAddrToStr(a^.FromName.sin_addr)+':'+NumToChar(a^.FromName.sin_port))
				else CQ_i_addLog(CQLOG_FATAL,'JustChatS | aSession Close','A Unknown mod given');
				
				ClientList.Remove(a);
				if PonClientDisconnect<>nil then TonClientDisconnect(PonClientDisconnect)(a);
				Dispose(a);
			end;
		end;
	//end
	//else
	//begin
	//	CQ_i_addLog(CQLOG_INFOSUCCESS,'JustChatS | Close | Invalid Connection',NetAddrToStr(a^.FromName.sin_addr)+':'+NumToChar(a^.FromName.sin_port));
	//	ClientList.Remove(a);
	//	Dispose(a);
	//end;


End;

procedure listening();stdcall;
Var
	a : PClient;
	i : longint;
Begin
	if upcase(ServerConfig.mode)='SERVER' then begin
		CQ_i_addLog(CQLOG_INFOSUCCESS,'JustChatS | Server','Server started on '+NetAddrToStr(SAddr.sin_addr)+':'+NumToChar(ntohs(SAddr.sin_port)));
		while true do begin
			new(a);
			CQ_i_addLog(CQLOG_INFOSUCCESS,'JustChatS | Server','Waiting for Connect from Client, run new sock_cli in another tty.');
			if Accept(S,a^.FromName,a^.Sin,a^.Sout) then begin
				Reset(a^.Sin);
				ReWrite(a^.Sout);
				a^.buff:='';
				a^.status:=0;
				createthread(nil,0,@aSession,a,0,a^.PID);		
				ClientList.add(a);
			end
			else
			begin
				CQ_i_addLog(CQLOG_INFOSUCCESS,'JustChatS | Server','Fail to accept a new sock_cli.');
				for i:=0 to ClientList.Count-1 do begin
					a^.status:=-1;
				end;
				exit();
			end;
		end;
	end	else
	if upcase(ServerConfig.mode)='CLIENT' then begin
		while true do begin
			while ClientList.Count>0 do delay(5000);

			CQ_i_addLog(CQLOG_INFOSUCCESS,'JustChatS | Server (Client Mode)','Connecting to '+NetAddrToStr(SAddr.sin_addr)+':'+NumToChar(ntohs(SAddr.sin_port)));
			new(a);
			a^.FromName:=SAddr;
			if Connect(S,SAddr,a^.Sin,a^.Sout) then begin
				//CQ_i_addLog(CQLOG_INFOSUCCESS,'JustChatS | Server (Client Mode)','Connected to '+NetAddrToStr(SAddr.sin_addr)+':'+NumToChar(ntohs(SAddr.sin_port)));
				Reset(a^.Sin);
				ReWrite(a^.Sout);
				a^.buff:='';
				a^.status:=0;
				if PMSG_Register<>nil then Broadcast(TMSG_Register(PMSG_Register)(),a);
				createthread(nil,0,@aSession,a,0,a^.PID);		
				ClientList.add(a);
			end
			else
			begin
				Dispose(a);
				CQ_i_addLog(CQLOG_ERROR,'JustChatS | Server (Client Mode) | ERR:'+NumToChar(SocketError),'Fail to connect to '+NetAddrToStr(SAddr.sin_addr)+':'+NumToChar(ntohs(SAddr.sin_port)));
				delay(5000);
				exit();
			end;

		end;
	end else
	begin
		CQ_i_addLog(CQLOG_FATAL,'JustChatS | Server','A Unknown mod given');
	end;




end;


procedure StartService();stdcall;
Begin
	while true do begin
		StertServer();
		listening();
		CloseServer();
	end;
End;


procedure Broadcast(MSG:ansistring);overload;
Var
	i:longint;
	P:ansistring;
	len:longint;
	a:PClient;
begin
	if ClientList.Count=0 then exit();

	WaitForSingleObject(hMutex,Const_ThreadWaitingTime);
	CQ_i_addLog(CQLOG_INFOSEND,'JustChatS | Broadcast | Clients:'+NumToChar(ClientList.Count),Base64_Encryption(MSG));
	len:=length(MSG);
	{CQ_i_addLog(CQLOG_INFOSEND,'JustChatS | Broadcast | Clients:'+NumToChar(ClientList.Count),
	NumtoChar(len div (2<<23))+' '+
	NumtoChar(len mod (2<<23) div (2<<15))+' '+
	NumtoChar(len mod (2<<15) div (2<<7))+' '+
	NumtoChar(len mod (2<<7)) );}
	p:=MessageHeader+ char(len div (2<<23)) + char(len mod (2<<23) div (2<<15)) + char(len mod (2<<15) div (2<<7)) + char(len mod (2<<7));
	for i:=0 to ClientList.Count-1 do begin
		a:=ClientList[i];
		write(a^.Sout,p+MSG);
	end;
end;


procedure Broadcast(MSG:ansistring;aClient:PClient);overload;
Var
	P:ansistring;
	len:longint;
begin
	if aClient=nil then exit();
	WaitForSingleObject(hMutex,Const_ThreadWaitingTime);
	CQ_i_addLog(CQLOG_INFOSEND,'JustChatS | Broadcast | Client '+NetAddrToStr(aClient^.FromName.sin_addr)+':'+NumToChar(aClient^.FromName.sin_port),Base64_Encryption(MSG));
	len:=length(MSG);
	{CQ_i_addLog(CQLOG_INFOSEND,'JustChatS | Broadcast | Clients:'+NumToChar(ClientList.Count),
	NumtoChar(len div (2<<23))+' '+
	NumtoChar(len mod (2<<23) div (2<<15))+' '+
	NumtoChar(len mod (2<<15) div (2<<7))+' '+
	NumtoChar(len mod (2<<7)) );}
	p:=MessageHeader+ char(len div (2<<23)) + char(len mod (2<<23) div (2<<15)) + char(len mod (2<<15) div (2<<7)) + char(len mod (2<<7));
	write(aClient^.Sout,p+MSG);
end;

initialization
    ClientList := TList.Create();


end.