unit Justchat;
{$MODE DELPHI}
interface
uses
    sysutils,classes,inifiles,
    fpjson,jsonparser,RegExpr,
    sockets,
    CoolQSDK,
    JustchatConfig,JustchatServer;

const
    TMsgType_Message = 0;

procedure onMessageReceived(aMSGPack:PMessagePack);
procedure MSG_PackAndSend(
			subType,MsgID			:longint;
			fromgroup,fromQQ		:int64;
			fromAnonymous,msg	:ansistring;
			font					:longint);


implementation
procedure onMessageReceived(aMSGPack:PMessagePack);
Var
    S:TJsonData;

    version:int64;
    msgtype:int64;

    sender,content:AnsiString;
begin
    try
        S:=GetJSON(aMSGPack^.MSG);
        version:=S.FindPath('version').asInt64;
        if version=ServerPackVersion then begin
            msgtype:=S.FindPath('type').asInt64;

            if msgtype=TMsgType_Message then begin
                sender:=Base64_Decryption(S.FindPath('sender').asString);
                content:=Base64_Decryption(S.FindPath('content').asString);
                // Text{   }

                if pos('Text{',content)=1 then delete(content,1,5);
                if content[length(content)]='}' then delete(content,length(content),1);

                CQ_i_SendGroupMSG(Justchat_BindGroup,'[*]'+CQ_CharEncode(sender,false)+': '+CQ_CharEncode(content,false));

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
				obj.add('target',Base64_Encryption(GetNick(fromGroup,CharToNum(Params_Get(p,'qq')))));
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
	A:TJsonArray;
	S:TJsonObject;
    sender:ansistring;
    content:ansistring;
Begin

	if fromGroup=Justchat_BindGroup then begin
		A:=MSG_StringToJSON(fromGroup,fromQQ,MSG_EmojiConverter(fromGroup,fromQQ,MSG));
		CQ_i_addLog(CQLOG_DEBUG,'',A.AsJson);
		if (A=nil) or (A.count=0) then begin
			if A<>nil then A.Destroy;
			exit();
		end;
        content:=Base64_Encryption(A.AsJSON);
        if content='' then exit();

        S := TJsonObject.Create();
        S.add('version',ServerPackVersion);
        S.add('type',TMsgType_Message);
        sender:=Base64_Encryption(GetNick(fromGroup,fromQQ));
        S.add('sender',sender);
        S.add('content',content);
        Broadcast(S.AsJSON);
        if S<>nil then S.Destroy;
	end;
End;

end.