unit JustchatServer;
{$mode delphi}

interface
uses
    Sockets,windows,classes,sysutils,
    CoolQSDK,
	JustchatConfig;

Type
	Client = record
				FromName: sockaddr_in;
				Sin,Sout: Text;
				PID		: LongWord;
				
				buff	: ansistring;
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

Const
	ServerPackVersion = 1;

Var
    PonMessageReceived:pointer=nil;
    JustchatServer_PID:LongWord;


procedure StertServer();
procedure listening();stdcall;
procedure Broadcast(MSG:ansistring);

implementation

	
Const
	MessageHeader = #$11+#$45+#$14;
	//PulseHeader = #$70+#$93+#$94;
	
	Const_ThreadWaitingTime = 5000;
	
Var
	S			: Longint;
	SAddr		: TInetSockAddr;
	ClientList: TList;

	hMutex	: handle;

  
  
procedure StertServer();
Begin
	S:=fpSocket (AF_INET,SOCK_STREAM,0);
	if SocketError<>0 then CQ_i_addLog(CQLOG_INFO,'JustChatS | StartServer','Socket : ');
	SAddr.sin_family:=AF_INET;
	SAddr.sin_port:=htons(ServerConfig.port);
	SAddr.sin_addr.s_addr:=ServerConfig.ip.s_addr;
	if fpBind(S,@SAddr,sizeof(saddr))=-1 then begin
        CQ_i_addLog(CQLOG_FATAL,'JustChatS | StartServer','Socket : ');
    end;
	if fpListen (S,1)=-1 then begin
        CQ_i_addLog(CQLOG_FATAL,'JustChatS | StartServer','Listen : ');
    end;
End;

procedure onMessageReceived(aMSGPack:PMessagePack);stdcall;
Begin
	CQ_i_addLog(CQLOG_INFORECV,'JustChatS | Broadcast | '+NetAddrToStr(aMSGPack^.Client^.FromName.sin_addr)+':'+NumToChar(aMSGPack^.Client^.FromName.sin_port),Base64_Encryption(aMSGPack^.MSG));
	if PonMessageReceived<>nil then begin
		TonMessageReceived(PonMessageReceived)(aMSGPack);
	end
	else
	begin
        CQ_i_addLog(CQLOG_WARNING,'JustChatS | onMessageReceived',NetAddrToStr(aMSGPack^.Client^.FromName.sin_addr)+':'+NumToChar(aMSGPack^.Client^.FromName.sin_port)+' : onMessageReceived is not assigned.');
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
	if length(a^.buff)>=1024*16 then begin
        CQ_i_addLog(CQLOG_ERROR,'JustChatS | MessageCheck',NetAddrToStr(a^.FromName.sin_addr)+':'+NumToChar(a^.FromName.sin_port)+' : buff too long');
        raise Exception.Create('buff too long');
    end;
End;

procedure aSession(a:PClient);stdcall;
Var
	c	:	char;
Begin
	
	//if NetAddrToStr(a^.FromName.sin_addr)='132.232.30.14' then begin
		CQ_i_addLog(CQLOG_INFOSUCCESS,'JustChatS | Accept',NetAddrToStr(a^.FromName.sin_addr)+':'+NumToChar(a^.FromName.sin_port));
		try
			repeat
				read(a^.sIn,c);
				a^.buff:=a^.buff+c;
				//CQ_i_addLog(CQLOG_INFOSUCCESS,'JustChatS | Readin '+NetAddrToStr(a^.FromName.sin_addr)+':'+NumToChar(a^.FromName.sin_port),Base64_Encryption(a^.buff));
				checkMessage(a);
				
			until false;
		except
			on e:Exception do begin
			CQ_i_addLog(CQLOG_INFOSUCCESS,'JustChatS | Close',NetAddrToStr(a^.FromName.sin_addr)+':'+NumToChar(a^.FromName.sin_port));
			ClientList.Remove(a);
			FreeMem(a);
			end;
		end;
	//end
	//else
	//begin
	//	CQ_i_addLog(CQLOG_INFOSUCCESS,'JustChatS | Close | Invalid Connection',NetAddrToStr(a^.FromName.sin_addr)+':'+NumToChar(a^.FromName.sin_port));
	//	ClientList.Remove(a);
	//	FreeMem(a);
	//end;


End;

procedure listening();stdcall;
Var
	a : PClient;
Begin
	CQ_i_addLog(CQLOG_INFOSUCCESS,'JustChatS | Server','Server started on '+NetAddrToStr(SAddr.sin_addr)+':'+NumToChar(ntohs(SAddr.sin_port)));

	while true do begin
		new(a);
        CQ_i_addLog(CQLOG_INFOSUCCESS,'JustChatS | Server','Waiting for Connect from Client, run now sock_cli in an other tty');
		Accept(S,a^.FromName,a^.Sin,a^.Sout);
		Reset(a^.Sin);
		ReWrite(a^.Sout);
		a^.buff:='';
		createthread(nil,0,@aSession,a,0,a^.PID);		
		ClientList.add(a);
	end;
end;

procedure Broadcast(MSG:ansistring);
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

initialization
    ClientList := TList.Create();


end.