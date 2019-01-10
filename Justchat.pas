unit Justchat;
{$MODE DELPHI}
interface
uses
    sysutils,classes,
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

                CQ_i_SendGroupMSG(Justchat_BindGroup,'[*]'+sender+': '+content);

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


function MSG_Filter(fromGroup,fromQQ:int64;s:AnsiString):AnsiString;
Var
	RegExp : TRegExpr;
	i:longint;
	
	emojiID			:longint;
	emojiData		:ansistring;
	isScaningEmoji	:boolean;

    AtID            :int64;
    AtData          :ansistring;
    isScaningAt     :boolean;
	
	imageData		:ansistring;
	isScaningImage	:boolean;

Begin
    emojiID:=0;
    AtID:=0;
	isScaningImage:=false;
	isScaningEmoji:=false;
	isScaningAt:=false;
		
	imageData:=ansistring('[图片]');

	i:=1;
	while i<=length(s) do begin
		if isScaningImage then begin
			if s[i]=']' then begin
				delete(s,i,1);
				s:=copy(s,1,i-1)+imageData+Copy(s,i,length(s));
				i:=i+length(imageData)-1;
				isScaningImage:=false
			end
			else
			begin
				delete(s,i,1);
			end;
		end
		else
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
		if isScaningAt then begin
			if s[i]=']' then begin
				delete(s,i,1);
				AtData:='@'+GetNick(fromGroup,AtID);
				s:=copy(s,1,i-1)+AtData+Copy(s,i,length(s));
				i:=i+length(AtData)-1;
				isScaningAt:=false
			end
			else
			begin
				AtID:=AtID*10+CharToNum(s[i]);
				delete(s,i,1);
			end;
		end
		else
		if copy(s,i,length('[CQ:image,file='))='[CQ:image,file=' then begin
			delete(s,i,length('[CQ:image,file='));
			isScaningImage:=true;
		end
		else		
		if copy(s,i,length('[CQ:emoji,id='))='[CQ:emoji,id=' then begin
			emojiid:=0;
			delete(s,i,length('[CQ:emoji,id='));
			isScaningEmoji:=true;
		end
        else
		if copy(s,i,length('[CQ:at,qq='))='[CQ:at,qq=' then begin
			AtID:=0;
			delete(s,i,length('[CQ:at,qq='));
			isScaningAt:=true;
		end
		else
		inc(i);
		//writeln(s,' ',i,' ',s[i],' ',emojiID);
	end;

	
	RegExp := TRegExpr.Create;
	RegExp.Expression := '\[CQ:.*\]';
	s:=RegExp.Replace(s, '', True);
	RegExp.Free;

    s:=CQ_CharDecode(s);

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
    content:ansistring;
Begin

	if fromGroup=Justchat_BindGroup then begin
        content:=Base64_Encryption(MSG_Filter(fromGroup,fromQQ,MSG));
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