unit JustChat_QQGroupHandler;
{$MODE OBJFPC}

interface
uses
    windows, classes, sysutils, inifiles,
    fpjson, jsonparser,

    JustChatConfig,

    Tools
    {$IFDEF __FULL_COMPILE_}
    ,CoolQSDK
    {$ENDIF}
    ;
    
function code_eventGroupMsg(subType, MsgID :longint; fromgroup, fromQQ :int64; const fromAnonymous, msg :ansistring; font :longint): longint;

implementation
type
	ImageInfo = record
					url,md5,extension:ansistring;
					width,height,size:int64;
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
	if ID<128 then exit(char(ID));
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

function GetImage(s:ansistring):ImageInfo;
Var
	A:TIniFile;
Begin
	A := TIniFile.Create('data/image/'+s+'.cqimg',false);
	result.url:='https://gchat.qpic.cn/gchatpic_new//--'+copy(s,1,pos('.',s)-1)+'/0';
	result.extension:=copy(s,pos('.',s)+1,length(s));
	result.md5:=A.ReadString('image','md5','');
	result.width:=A.ReadInt64('image','width',0);
	result.height:=A.ReadInt64('image','height',0);
	result.size:=A.ReadInt64('image','size',0);
	//Message_Replace(b,'vuin='+NumToChar(CQ_i_getLoginQQ()),'');
	A.Destroy;
	exit();
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


procedure Params_Free(p:TList);
Var
	i,c	:	longint;
	d	:	PParamPair;
Begin
	c:=p.count;
	for i:=c-1 downto 0 do begin
		d:=p[i];
		p.delete(i);
		dispose(d);
	end;
	p.free;
End;


procedure Params_Print(p:TList);
Var
	i	:	longint;
	d	:	PParamPair;
	s	:	ansistring;
Begin
	s:='';
	for i:=0 downto p.count-1 do begin
		d:=p[i];
		if i<>0 then s:=s+CRLF;
		s:=d^.k+' '+d^.v;
	end;
	CQ_i_addLog(CQLOG_DEBUG,'Params_Print',s);
End;


function getFaceContent(id:longint):ansistring;
var
	out : ansiString;
Begin
	if (JustChat_Config.CQFace.TryGetValue(id,out)) then begin
		out := JustChat_Config.CQFacePrefix + out;
	end
	else out := JustChat_Config.CQFacePrefix + JustChat_Config.CQFaceDefault;
	exit(out);
End;

function StringToOBJ(Terminal:TJustChatService_QQGroupsTerminal; fromGroup,fromQQ:int64; s:ansistring):TJsonObject;
Var
	obj		: TJsonObject;
	func	: ansistring;
	P		: TList;
	aimage	: ImageInfo;
	back, content	: ansistring;
	msgdata,subdata : TJsonData;
Begin
	obj:=TJsonObject.Create;
	if (s[1]='[') and (s[length(s)]=']') then begin
		obj.add('type','cqcode');
		
		func:=copy(s,1+1,pos(',',s)-1-1);
		delete(s,1,pos(',',s));
		delete(s,length(s),1);
		obj.add('function',func);

		if (func='CQ:at') then
		begin
			p:=Params_Split(s);
			if p<>nil then begin
				obj.add('target',Base64_Encryption('@'+GetNick(fromGroup,CharToNum(Params_Get(p,'qq')))));
				Params_Free(p);
				//P.free;
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
				content := Terminal.Message_Get(TJustChatStructedMessage.Msg_Message_ImageAlternative);
				if content = '' then begin
					content := '[IMAGE]';
				end;

				aimage:=GetImage(Params_Get(p,'file'));
				obj.add('url',aimage.url);
				obj.add('extension',aimage.extension);
				obj.add('md5',aimage.md5);
				obj.add('height',aimage.height);
				obj.add('width',aimage.width);
				obj.add('size',aimage.size);
				obj.add('content',Base64_Encryption(content));
				Params_Free(p);
				//P.free;
			end
			else
			begin
				obj.Destroy;
				obj:=nil;
			end;
		end
		else
		if (func='CQ:face') then
		begin
			p:=Params_Split(s);
			if p<>nil then begin
				obj.add('id',CharToNum(Params_Get(p,'id')));
				obj.add('content',Base64_Encryption(getFaceContent(CharToNum(Params_Get(p,'id')))));
				Params_Free(p);
			end
			else
			begin
				obj.Destroy;
				obj:=nil;
			end;
		end
		else
		if (func='CQ:hb') then
		begin
			p:=Params_Split(s);
			if p<>nil then begin
				obj.add('title',Base64_Encryption(Params_Get(p,'title')));
				Params_Free(p);
				//P.free;
			end
			else
			begin
				obj.Destroy;
				obj:=nil;
			end;
		end
		else
		if (func='CQ:share') then
		begin
			p:=Params_Split(s);
			if p<>nil then begin
				obj.add('title',Base64_Encryption(Params_Get(p,'title')));
				obj.add('url',Base64_Encryption(Params_Get(p,'url')));
				obj.add('content',Base64_Encryption(Params_Get(p,'content')));
				obj.add('image',Base64_Encryption(Params_Get(p,'image')));
				Params_Free(p);
				//P.free;
			end
			else
			begin
				obj.Destroy;
				obj:=nil;
			end;
		end
		else
		if (func='CQ:rich') then
		begin
			p:=Params_Split(s);
			if p<>nil then begin

				content := Params_Get(p,'content');

				try
					msgdata:=getjson(content);
					
					if msgdata.FindPath('detail_1') <> nil then begin

						back:=Params_Get(p,'title');
						if (msgdata.FindPath('detail_1.desc') <> nil) and (msgdata.FindPath('detail_1.desc').JSONType = jtString) then
							back:=back+' '+msgdata.FindPath('detail_1.desc').asString;
						obj.add('text',Base64_Encryption(back));

						back:='';
						if (msgdata.FindPath('detail_1.qqdocurl') <> nil) and (msgdata.FindPath('detail_1.qqdocurl').JSONType = jtString) then
							back:=msgdata.FindPath('detail_1.qqdocurl').asString;
						obj.add('url',Base64_Encryption(back));

					end else if (msgdata.FindPath('music') <> nil) or (msgdata.FindPath('news') <> nil) then begin
						subdata:=msgdata.FindPath('music');
						if subdata=nil then subdata:=msgdata.FindPath('news');

						back:='';
						if (subdata.FindPath('tag') <> nil) and (subdata.FindPath('tag').JSONType = jtString) then
							back:=subdata.FindPath('tag').asString;
						if back <> '' then back:='['+back+'] ';

						if (subdata.FindPath('title') <> nil) and (subdata.FindPath('title').JSONType = jtString) then
							back:=back+subdata.FindPath('title').asString;

						if (subdata.FindPath('desc') <> nil) and (subdata.FindPath('desc').JSONType = jtString) then begin
							if back = ''
								then back:=back+subdata.FindPath('desc').asString
								else back:=back+'-'+subdata.FindPath('desc').asString;
						end;
						obj.add('text',Base64_Encryption(back));

						back:='';
						if (subdata.FindPath('jumpUrl') <> nil) and (subdata.FindPath('jumpUrl').JSONType = jtString) then
							back:=subdata.FindPath('jumpUrl').asString;
						obj.add('url',Base64_Encryption(back));
					
					end else if (msgdata.FindPath('albumData') <> nil) then begin
					
						back:=Params_Get(p,'title');
						if (msgdata.FindPath('albumData.desc') <> nil) and (msgdata.FindPath('albumData.desc').JSONType = jtString) then
							back:=back+' '+msgdata.FindPath('albumData.desc').asString;
						obj.add('text',Base64_Encryption(back));

						back:='';
						if (msgdata.FindPath('albumData.h5Url') <> nil) and (msgdata.FindPath('albumData.h5Url').JSONType = jtString) then
							back:=msgdata.FindPath('albumData.h5Url').asString;
						obj.add('url',Base64_Encryption(back));

					end else begin

						FreeAndNil(msgdata);
						raise Exception.Create('');

					end;

					FreeAndNil(msgdata);
				except
					on e: Exception do begin
						back:=Params_Get(p,'url');
						content:=Params_Get(p,'text');
						if content='' then content:=Params_Get(p,'brief');

						if content<>'' then begin
							obj.add('url',Base64_Encryption(back));
							obj.add('text',Base64_Encryption(content));
						end else begin
							obj.Destroy;
							obj:=nil;
						end;
						//P.free;
					end;
				end;

				Params_Free(p);

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
		back:=s;
		Message_Replace(back,CRLF,LF);
		obj.add('content',Base64_Encryption(CQ_CharDecode(back)));
	end;
	exit(obj);
End;
	
function MSG_StringToJSON(Terminal:TJustChatService_QQGroupsTerminal;fromGroup,fromQQ:int64;s:ansistring):TJsonArray;
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
				if data<>'' then obj:=StringToOBJ(Terminal,fromGroup,fromQQ,data);
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
				if data<>'' then obj:=StringToOBJ(Terminal,fromGroup,fromQQ,data);
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
		obj:=StringToOBJ(Terminal,fromGroup,fromQQ,data);
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

function getGroupName(groupID:int64):ansistring;
Var
	i				:	longint;
	GroupList		:	CQ_Type_GroupList;
Begin
	result:=NumToChar(groupID);
	if CQ_i_getGroupList(GroupList)=0 then begin
		for i:=0 to GroupList.l-1 do
			if GroupList.s[i].groupID=groupID then
				exit(GroupList.s[i].name);
	end
	else
	begin
		exit();
	end;
End;

procedure MSG_PlayerList(Terminal : TJustChatService_QQGroupsTerminal; fromGroup, fromQQ : int64);
Var
	S : TJsonObject;
	world_display,sender : ansistring;
Begin
    world_display := getGroupName(fromGroup);
    sender := GetNick(fromGroup,fromQQ);

	S := TJsonObject.Create();
	S.add('version',ServerPackVersion);
	S.add('type',TMSGTYPE_PLAYERLIST);
	S.add('subtype',TMSGTYPE_PLAYERLIST_Request);
	S.add('sender',Base64_Encryption(sender));
	S.add('world',Base64_Encryption(NumToChar(fromGroup)));
	S.add('world_display',Base64_Encryption(world_display));
	
	Terminal.BroadCastToMCTerminal(S.AsJSON);
	if S<>nil then S.Destroy;
End;

function code_eventGroupMsg(subType, MsgID :longint; fromgroup, fromQQ :int64; const fromAnonymous, msg :ansistring; font :longint): longint;
Var
	S : TJsonObject;

    world_display : ansistring;
    sender : ansistring;
    content : TJsonArray;

    Terminal : TJustChatService_QQGroupsTerminal;
    MsgPack : TJustChatStructedMessage;


	flag : boolean;
	TS	:	TStringlist;
	command : ansistring;

Begin
	Terminal := nil;
    JustChat_Config.QQGroupTerminals.TryGetValue(fromGroup, Terminal);
    if Terminal = nil then exit(EVENT_IGNORE);

	/// 命令识别

	flag := false;

	TS					:= TStringlist.Create;
	TS.DelimitedText		:= msg;

	if (TS.count>=1) then begin
		command := upcase(TS[0]);
		if (length(command)>=3) and (command[1]+command[2]+command[3]=ansistring('！')) then command:='!'+copy(command,4,length(command));
		if (length(command)>0) and ((command[1]='/') or (command[1]='!')) then begin
			delete(command,1,1);
			if ((command='LS') or (command='LIST')) and Terminal.Event_isEnabled(TJustChatStructedMessage.PlayerList_All) then begin
				MSG_PlayerList(Terminal, fromGroup, fromQQ);
				flag := true;
			end;
		end;
	end;

	TS.Clear;
	TS.Free;

	if flag then exit(EVENT_IGNORE);

	/// 消息广播

	content:=MSG_StringToJSON(Terminal,fromGroup,fromQQ,MSG_EmojiConverter(fromGroup,fromQQ,MSG));
	if (content=nil) or (content.count=0) then begin
		if content<>nil then content.Destroy;
		exit();
	end;

    world_display := getGroupName(fromGroup);
    sender := GetNick(fromGroup,fromQQ);

	S := TJsonObject.Create();
	S.add('version',ServerPackVersion);
	S.add('type',TMsgType_Message);
	S.add('sender',Base64_Encryption(sender));
	S.add('world',Base64_Encryption(NumToChar(fromGroup)));
	S.add('world_display',Base64_Encryption(world_display));
	S.add('content',content);

	// Broadcast(S.AsJSON);
    MsgPack := TJustChatStructedMessage.Create(TJustChatStructedMessage.Message_All, TJustChatStructedMessage.Message_All, TJustChatStructedMessage.Msg_Message_Overview , S.AsJSON);
	MsgPack.MessageReplacementsAdd('SERVER', 'QQ');
	MsgPack.MessageReplacementsAdd('WORLD_DISPLAY', CQ_CharEncode(world_display,false));
	MsgPack.MessageReplacementsAdd('SENDER', CQ_CharEncode(sender,false));
	MsgPack.MessageReplacementsAdd('CONTENT', msg);
	Terminal.BroadCast(MsgPack);
	MsgPack.Destroy();

	S.Destroy;
End;

end.