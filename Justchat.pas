unit Justchat;
{$MODE DELPHI}
interface
uses
    sysutils,classes{,inifiles},
    fpjson,jsonparser,RegExpr,
    sockets,
    CoolQSDK,
    JustchatConfig,JustchatServer;

procedure onMessageReceived(aMSGPack:PMessagePack);
procedure MSG_PackAndSend(
			subType,MsgID			:longint;
			fromgroup,fromQQ		:int64;
			fromAnonymous,msg	:ansistring;
			font					:longint);
function MSG_Register():ansistring;
procedure MSG_Pulse(hwnd, uMsg, eventID, dwTime:longword);stdcall;


implementation


function TextMessageContentUnpack(a:TJSONData):ansistring;
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


function MSG_Pulse_Packer():ansistring;
Var
	S:TJsonObject;
Begin
	S := TJsonObject.Create();
	S.add('version',ServerPackVersion);
	S.add('type',TMsgType_HEARTBEATS);
	result:=S.AsJSON;
	if S<>nil then S.Destroy;
End;

procedure onMessageReceived(aMSGPack:PMessagePack);
Var
    S:TJsonData;
	P:TBaseJSONEnumerator;
    version:int64;
    msgtype:int64;

    world_display,sender,content:AnsiString;
	eventType:longint;

	back:ansistring;
begin
    try
		if length(aMSGPack^.MSG)<=2 then begin
			CQ_i_addLog(CQLOG_ERROR,'JustChat | onMessageReceived',NetAddrToStr(aMSGPack^.Client^.FromName.sin_addr)+':'+NumToChar(aMSGPack^.Client^.FromName.sin_port)+' : Received an unrecognized message.');
			exit();
		end;
        S:=GetJSON(aMSGPack^.MSG);
        version:=S.FindPath('version').asInt64;
        if version=ServerPackVersion then begin
            msgtype:=S.FindPath('type').asInt64;

            if msgtype=TMsgType_Message then begin
                sender:=Base64_Decryption(S.FindPath('sender').asString);
                world_display:=Base64_Decryption(S.FindPath('world_display').asString);
                content:=TextMessageContentUnpack(S.FindPath('content'));
				
                //if pos('Text{',content)=1 then delete(content,1,5);
                //if content[length(content)]='}' then delete(content,length(content),1);

                //CQ_i_SendGroupMSG(Justchat_BindGroup,'[*]'+CQ_CharEncode(sender,false)+': '+CQ_CharEncode(content,false));
				back:=MessageFormat.Msg_Text_Overview;
				Message_Replace(back,'%WORLD_DISPLAY%',CQ_CharEncode(world_display,false));
				Message_Replace(back,'%SENDER%',CQ_CharEncode(sender,false));
				Message_Replace(back,'%CONTENT%',CQ_CharEncode(content,false));
                CQ_i_SendGroupMSG(Justchat_BindGroup,back);

            end
            else
			if msgtype=TMsgType_Info then begin
				P:=S.GetEnumerator;
				back:='';
				while P.MoveNext do begin
					if upcase(P.Current.Key)='CONTENT' then begin
						back:=Base64_Decryption(S.FindPath(P.Current.Key).AsString);
					end;
				end;
				
				if back='' then begin
					eventType:=S.FindPath('event').asInt64;

					if eventType=TMsgType_INFO_Join then back:=MessageFormat.Msg_INFO_Join else
					if eventType=TMsgType_INFO_Disconnect then back:=MessageFormat.Msg_INFO_Disconnect else
					if eventType=TMsgType_INFO_PlayerDead then back:=MessageFormat.Msg_INFO_PlayerDead;

					sender:=Base64_Decryption(S.FindPath('sender').asString);
					if pos('%SENDER%',back)>0
						then Message_Replace(back,'%SENDER%',sender)
						else Message_Replace(back,'%PLAYER%',sender);
				end;

				//P.Destroy;
				CQ_i_SendGroupMSG(Justchat_BindGroup,back);
			end
			else
			if (msgtype=TMsgType_HEARTBEATS) then begin
				if upcase(ServerConfig.mode)='SERVER' then begin
					Broadcast(MSG_Pulse_Packer,aMSGPack.Client);
					CQ_i_addLog(CQLOG_DEBUG,'JustChat | onMessageReceived',NetAddrToStr(aMSGPack^.Client^.FromName.sin_addr)+':'+NumToChar(aMSGPack^.Client^.FromName.sin_port)+' : Sent a pulse echo.');
				end
				else
				begin
					CQ_i_addLog(CQLOG_DEBUG,'JustChat | onMessageReceived',NetAddrToStr(aMSGPack^.Client^.FromName.sin_addr)+':'+NumToChar(aMSGPack^.Client^.FromName.sin_port)+' : Received a pulse echo.');
				end;
			end
			else
			if (msgtype=TMSGTYPE_REGISTRATION) then begin
				CQ_i_addLog(CQLOG_DEBUG,'JustChat | onMessageReceived',NetAddrToStr(aMSGPack^.Client^.FromName.sin_addr)+':'+NumToChar(aMSGPack^.Client^.FromName.sin_port)+' : Received a registration message.');
			end
			else
			if (msgtype=TMSGTYPE_REGISTRATION) then begin

			end
			else
            begin
                CQ_i_addLog(CQLOG_WARNING,'JustChat | onMessageReceived',NetAddrToStr(aMSGPack^.Client^.FromName.sin_addr)+':'+NumToChar(aMSGPack^.Client^.FromName.sin_port)+' : Received a message with an unrecognized type.');
            end;
        end
        else
        begin
            if version<ServerPackVersion then begin
                CQ_i_addLog(CQLOG_WARNING,'JustChat | onMessageReceived',NetAddrToStr(aMSGPack^.Client^.FromName.sin_addr)+':'+NumToChar(aMSGPack^.Client^.FromName.sin_port)+' : Received a message made by a lower-version client.');
            end
            else
            begin
                CQ_i_addLog(CQLOG_WARNING,'JustChat | onMessageReceived',NetAddrToStr(aMSGPack^.Client^.FromName.sin_addr)+':'+NumToChar(aMSGPack^.Client^.FromName.sin_port)+' : Received a message made by a higher-version client.');
            end;
        end;
        if S<>nil then S.Destroy;
    except
        on e:Exception do begin
            CQ_i_addLog(CQLOG_ERROR,'JustChat | onMessageReceived',NetAddrToStr(aMSGPack^.Client^.FromName.sin_addr)+':'+NumToChar(aMSGPack^.Client^.FromName.sin_port)+' : Received an unrecognized message.');
            if S<>nil then S.Destroy;
        end;
    end;
end;


Function UTF8First_Remain(a:longint):longint;
Begin
	case a of
		0: exit(8);
		1: exit(5);
		2: exit(4);
		3: exit(3);
		4: exit(2);
		5: exit(1);
		6: exit(0);
	end;
End;

Function UTF8First(a:longint):longint;
Begin
	case a of
		0: exit(  0);       //%00000000
		1: exit(192);       //%11000000
		2: exit(224);       //%11100000
		3: exit(240);       //%11110000
		4: exit(248);       //%11111000
		5: exit(252);       //%11111100
		6: exit(254);       //%11111110
	end;
End;

Function OctToUTF8(ID:longint):ansistring;
Var
	d:longint;
	t:longint;
	a:longint;
Begin
	result:='';
	t:=ID;
	while t>0 do begin
		d:=t mod 64;
		t:=t div 64;
		if t>0
			then result:=Char(128+d)+result //%10000000
			else begin
				a:=UTF8First_Remain(length(result));
				if (d < 1<<a)
					then result:=Char(UTF8First(length(result))+d)+result
					else result:=Char(UTF8First(length(result)+1))+Char(128+d)+result; //%10000000
			end;
		{
		for a:=1 to length(result) do write(longint(result[a]),' ');
		writeln;
        }
	end;
End;

function GetNick(fromGroup,fromQQ:int64):ansistring;
Var
    fromInfo:CQ_Type_GroupMember;
Begin
    if CQ_i_getGroupMemberInfo(fromGroup,fromQQ,fromInfo,false)=0 then begin
        if fromInfo.card<>''  then exit(fromInfo.card)
        else if fromInfo.nick<>'' then exit(fromInfo.nick)
        else exit(NumToChar(fromQQ));
    end;
    exit(NumToChar(FromQQ));
End;

function GetImage(s:ansistring):ansistring;
{
	Var
	A:TCustomIniFile;
	b:ansistring;
}
Begin
{
	A := TCustomIniFile('data/image/'+s+'.cqimg',false);
	b:=A.ReadString('image','url','');
	//Message_Replace(b,'vuin='+NumToChar(CQ_i_getLoginQQ()),'');
	A.Destroy;
	exit(b);
}
	exit('https://gchat.qpic.cn/gchatpic_new//--'+copy(s,1,pos('.',s)-1)+'/0');
End;

Type
		ParamPair = record
						k,v:ansistring;
					end;
		PParamPair = ^ParamPair;

function Params_Split(s:ansistring):TList;
Var
	b	:	TList;
	a	:	TStringlist;
	i	:	longint;
	d	:	PParamPair;
Begin
	a					:= TStringlist.Create;
	a.StrictDelimiter	:= True;
	a.Delimiter			:= ',';
	a.DelimitedText		:= s;
	
	if a.count<=0 then Begin
		a.Clear;
		a.Free;
		exit(nil);
	End;

	b := TList.Create();
	for i:=0 to a.count-1 do begin
		new(d);
		d^.v:=a[i];
		d^.k:=copy(d^.v,1,pos('=',d^.v)-1);
		delete(d^.v,1,pos('=',d^.v));

		d^.k:=CQ_CharDecode(d^.k);
		d^.v:=CQ_CharDecode(d^.v);

		b.add(d);
	end;
	
	exit(b);
End;

function Params_Get(a:TList;k:ansistring):ansistring;
Var
	i	:	longint;
Begin
	result:='';
	for i:=0 to a.count-1 do begin
		if k=PParamPair(a[i])^.k then exit(PParamPair(a[i])^.v);
	end;
End;

function StringToOBJ(fromGroup,fromQQ:int64;s:ansistring):TJsonObject;
Var
	obj:TJsonObject;
	func:ansistring;
	P:TList;
Begin
	obj:=TJsonObject.Create;
	if (s[1]='[') and (s[length(s)]=']') then begin
		obj.add('type','cqcode');
		
		func:=copy(s,1+1,pos(',',s)-1-1);
		delete(s,1,pos(',',s));
		delete(s,length(s),1);
		
		if (func='CQ:at') then
		begin
			p:=Params_Split(s);
			if p<>nil then begin
				obj.add('function',func);
				obj.add('target',Base64_Encryption('@'+GetNick(fromGroup,CharToNum(Params_Get(p,'qq')))));
				P.free;
			end
			else
			begin
				obj.Destroy;
				obj:=nil;
			end;
		end
		else
		if (func='CQ:image') then
		begin
			p:=Params_Split(s);
			if p<>nil then begin
				obj.add('function',func);
				obj.add('url',GetImage(Params_Get(p,'file')));
				obj.add('content',Base64_Encryption('[图片]'));
				P.free;
			end
			else
			begin
				obj.Destroy;
				obj:=nil;
			end;
		end
		else
		begin
			obj.Destroy;
			obj:=nil;
		end;
	end
	else
	begin
		obj.add('type','text');
		obj.add('content',Base64_Encryption(CQ_CharDecode(s)));
	end;
	exit(obj);
End;
	
function MSG_StringToJSON(fromGroup,fromQQ:int64;s:ansistring):TJsonArray;
Var
	isScaning : boolean;
	data	:	ansistring;
	
	i	:	longint;
	
	obj		:	TJsonObject;
	back	:	TJsonArray;
Begin
	data:='';
	isScaning:=false;
	back := TJsonArray.create();
	
	for i:=1 to length(s) do begin
		if isScaning then begin
			data:=data+s[i];
			if s[i]=']' then begin
				obj:=nil;
				if data<>'' then obj:=StringToOBJ(fromGroup,fromQQ,data);
				if obj<>nil then back.add(obj);
				isScaning:=false;
				data:='';
			end
			else
			begin
			end;
		end
		else
		begin
			if s[i]='[' then begin
				obj:=nil;
				if data<>'' then obj:=StringToOBJ(fromGroup,fromQQ,data);
				if obj<>nil then back.add(obj);
				isScaning:=true;
				data:='[';
			end
			else
			begin
				data:=data+s[i];
			end;			
		end;	
	end;
	obj:=nil;
	if data<>'' then begin
		obj:=StringToOBJ(fromGroup,fromQQ,data);
		if obj<>nil then back.add(obj);
	end;

	exit(back);
End;


function MSG_EmojiConverter(fromGroup,fromQQ:int64;s:AnsiString):AnsiString;
Var
	i:longint;
	emojiID			:longint;
	emojiData		:ansistring;
	isScaningEmoji	:boolean;
Begin
    emojiID:=0;
	isScaningEmoji:=false;


	i:=1;
	while i<=length(s) do begin
		if isScaningEmoji then begin
			if s[i]=']' then begin
				delete(s,i,1);
				emojiData:=OctToUTF8(emojiID);
				s:=copy(s,1,i-1)+emojiData+Copy(s,i,length(s));
				i:=i+length(emojiData)-1;
				isScaningEmoji:=false
			end
			else
			begin
				emojiID:=emojiID*10+CharToNum(s[i]);
				delete(s,i,1);
			end;
		end
		else
		if copy(s,i,length('[CQ:emoji,id='))='[CQ:emoji,id=' then begin
			emojiid:=0;
			delete(s,i,length('[CQ:emoji,id='));
			isScaningEmoji:=true;
		end
		else
		inc(i);
		//writeln(s,' ',i,' ',s[i],' ',emojiID);
	end;

    exit(s);
End;

procedure MSG_PackAndSend(
			subType,MsgID			:longint;
			fromgroup,fromQQ		:int64;
			fromAnonymous,msg	:ansistring;
			font					:longint);
Var
	S:TJsonObject;
    sender:ansistring;
    content:TJsonArray;
Begin

	if fromGroup=Justchat_BindGroup then begin
		content:=MSG_StringToJSON(fromGroup,fromQQ,MSG_EmojiConverter(fromGroup,fromQQ,MSG));
		//CQ_i_addLog(CQLOG_DEBUG,'',content.AsJson);
		if (content=nil) or (content.count=0) then begin
			if content<>nil then content.Destroy;
			exit();
		end;

        S := TJsonObject.Create();
        S.add('version',ServerPackVersion);
        S.add('type',TMsgType_Message);
        sender:=Base64_Encryption(GetNick(fromGroup,fromQQ));
        S.add('sender',sender);
        S.add('world',NumToChar(fromGroup));
        S.add('world_display',Base64_Encryption(NumToChar(fromGroup)));
        S.add('content',content);
        Broadcast(S.AsJSON);
        if S<>nil then S.Destroy;
	end;
End;

function MSG_Register():ansistring;
Var
	S:TJsonObject;
Begin
	S := TJsonObject.Create();
	S.add('version',ServerPackVersion);
	S.add('type',TMSGTYPE_REGISTRATION);
	S.add('identity',1);
	S.add('id',ServerConfig.ID);
	S.add('name',Base64_Encryption(ServerConfig.ConsoleName));
	result:=S.AsJSON;
	if S<>nil then S.Destroy;
End;

procedure MSG_Pulse(hwnd, uMsg, eventID, dwTime:longword);stdcall;
Begin
	Broadcast(MSG_Pulse_Packer);
End;

end.