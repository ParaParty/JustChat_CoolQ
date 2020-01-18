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
Begin
	
	case id of
		0:	result:=ansistring('/惊讶');
		1:	result:=ansistring('/撇嘴');
		2:	result:=ansistring('/色');
		3:	result:=ansistring('/发呆');
		4:	result:=ansistring('/得意');
		5:	result:=ansistring('/流泪');
		6:	result:=ansistring('/害羞');
		7:	result:=ansistring('/闭嘴');
		8:	result:=ansistring('/睡');
		9:	result:=ansistring('/大哭');
		10:	result:=ansistring('/尴尬');
		11:	result:=ansistring('/发怒');
		12:	result:=ansistring('/调皮');
		13:	result:=ansistring('/呲牙');
		14:	result:=ansistring('/微笑');
		15:	result:=ansistring('/难过');
		16:	result:=ansistring('/酷');
		17:	result:=ansistring('');
		18:	result:=ansistring('/抓狂');
		19:	result:=ansistring('/吐');
		20:	result:=ansistring('/偷笑');
		21:	result:=ansistring('/可爱');
		22:	result:=ansistring('/白眼');
		23:	result:=ansistring('/傲慢');
		24:	result:=ansistring('/饥饿');
		25:	result:=ansistring('/困');
		26:	result:=ansistring('/惊恐');
		27:	result:=ansistring('/流汗');
		28:	result:=ansistring('/憨笑');
		29:	result:=ansistring('/悠闲');
		30:	result:=ansistring('/奋斗');
		31:	result:=ansistring('/咒骂');
		32:	result:=ansistring('/疑问');
		33:	result:=ansistring('/嘘');
		34:	result:=ansistring('/晕');
		35:	result:=ansistring('/折磨');
		36:	result:=ansistring('/衰');
		37:	result:=ansistring('/骷髅');
		38:	result:=ansistring('/敲打');
		39:	result:=ansistring('/再见');
		40:	result:=ansistring('');
		41:	result:=ansistring('/发抖');
		42:	result:=ansistring('/爱情');
		43:	result:=ansistring('/跳跳');
		44:	result:=ansistring('');
		45:	result:=ansistring('');
		46:	result:=ansistring('/猪头');
		47:	result:=ansistring('');
		48:	result:=ansistring('');
		49:	result:=ansistring('/拥抱');
		50:	result:=ansistring('');
		51:	result:=ansistring('');
		52:	result:=ansistring('');
		53:	result:=ansistring('/蛋糕');
		54:	result:=ansistring('/闪电');
		55:	result:=ansistring('/炸弹');
		56:	result:=ansistring('/刀');
		57:	result:=ansistring('/足球');
		58:	result:=ansistring('');
		59:	result:=ansistring('/便便');
		60:	result:=ansistring('/咖啡');
		61:	result:=ansistring('/饭');
		62:	result:=ansistring('');
		63:	result:=ansistring('/玫瑰');
		64:	result:=ansistring('/凋谢');
		65:	result:=ansistring('');
		66:	result:=ansistring('/爱心');
		67:	result:=ansistring('/心碎');
		68:	result:=ansistring('');
		69:	result:=ansistring('/礼物');
		70:	result:=ansistring('');
		71:	result:=ansistring('');
		72:	result:=ansistring('');
		73:	result:=ansistring('');
		74:	result:=ansistring('/太阳');
		75:	result:=ansistring('/月亮');
		76:	result:=ansistring('/赞');
		77:	result:=ansistring('/踩');
		78:	result:=ansistring('/握手');
		79:	result:=ansistring('/胜利');
		80:	result:=ansistring('');
		81:	result:=ansistring('');
		82:	result:=ansistring('');
		83:	result:=ansistring('');
		84:	result:=ansistring('');
		85:	result:=ansistring('/飞吻');
		86:	result:=ansistring('/怄火');
		87:	result:=ansistring('');
		88:	result:=ansistring('');
		89:	result:=ansistring('/西瓜');
		90:	result:=ansistring('');
		91:	result:=ansistring('');
		92:	result:=ansistring('');
		93:	result:=ansistring('');
		94:	result:=ansistring('');
		95:	result:=ansistring('');
		96:	result:=ansistring('/冷汗');
		97:	result:=ansistring('/擦汗');
		98:	result:=ansistring('/抠鼻');
		99:	result:=ansistring('/鼓掌');
		100:	result:=ansistring('/糗大了');
		101:	result:=ansistring('/坏笑');
		102:	result:=ansistring('/左哼哼');
		103:	result:=ansistring('/右哼哼');
		104:	result:=ansistring('/哈欠');
		105:	result:=ansistring('/鄙视');
		106:	result:=ansistring('/委屈');
		107:	result:=ansistring('/快哭了');
		108:	result:=ansistring('/阴险');
		109:	result:=ansistring('/亲亲');
		110:	result:=ansistring('/吓');
		111:	result:=ansistring('/可怜');
		112:	result:=ansistring('/菜刀');
		113:	result:=ansistring('/啤酒');
		114:	result:=ansistring('/篮球');
		115:	result:=ansistring('/乒乓');
		116:	result:=ansistring('/示爱');
		117:	result:=ansistring('/瓢虫');
		118:	result:=ansistring('/抱拳');
		119:	result:=ansistring('/勾引');
		120:	result:=ansistring('/拳头');
		121:	result:=ansistring('/差劲');
		122:	result:=ansistring('/爱你');
		123:	result:=ansistring('/NO');
		124:	result:=ansistring('/OK');
		125:	result:=ansistring('/转圈');
		126:	result:=ansistring('/磕头');
		127:	result:=ansistring('/回头');
		128:	result:=ansistring('/跳绳');
		129:	result:=ansistring('/挥手');
		130:	result:=ansistring('/激动');
		131:	result:=ansistring('/街舞');
		132:	result:=ansistring('/献吻');
		133:	result:=ansistring('/左太极');
		134:	result:=ansistring('/右太极');
		135:	result:=ansistring('');
		136:	result:=ansistring('/双喜');
		137:	result:=ansistring('/鞭炮');
		138:	result:=ansistring('/灯笼');
		139:	result:=ansistring('/发财');
		140:	result:=ansistring('/K歌');
		141:	result:=ansistring('/购物');
		142:	result:=ansistring('/邮件');
		143:	result:=ansistring('/帅');
		144:	result:=ansistring('/喝彩');
		145:	result:=ansistring('/祈祷');
		146:	result:=ansistring('/爆筋');
		147:	result:=ansistring('/棒棒糖');
		148:	result:=ansistring('/喝奶');
		149:	result:=ansistring('/下面');
		150:	result:=ansistring('/香蕉');
		151:	result:=ansistring('/飞机');
		152:	result:=ansistring('/开车');
		153:	result:=ansistring('/高铁左车头');
		154:	result:=ansistring('/车厢');
		155:	result:=ansistring('/高铁右车头');
		156:	result:=ansistring('/多云');
		157:	result:=ansistring('/下雨');
		158:	result:=ansistring('/钞票');
		159:	result:=ansistring('/熊猫');
		160:	result:=ansistring('/灯泡');
		161:	result:=ansistring('/风车');
		162:	result:=ansistring('/闹钟');
		163:	result:=ansistring('/打伞');
		164:	result:=ansistring('/彩球');
		165:	result:=ansistring('/钻戒');
		166:	result:=ansistring('/沙发');
		167:	result:=ansistring('/纸巾');
		168:	result:=ansistring('/药');
		169:	result:=ansistring('/手枪');
		170:	result:=ansistring('/青蛙');
		171:	result:=ansistring('/茶');
		172:	result:=ansistring('/眨眼睛');
		173:	result:=ansistring('/泪奔');
		174:	result:=ansistring('/无奈');
		175:	result:=ansistring('/卖萌');
		176:	result:=ansistring('/小纠结');
		177:	result:=ansistring('/喷血');
		178:	result:=ansistring('/斜眼笑');
		179:	result:=ansistring('/doge');
		180:	result:=ansistring('/惊喜');
		181:	result:=ansistring('/骚扰');
		182:	result:=ansistring('/笑哭');
		183:	result:=ansistring('/我最美');
		184:	result:=ansistring('/河蟹');
		185:	result:=ansistring('/羊驼');
		186:	result:=ansistring('');
		187:	result:=ansistring('/幽灵');
		188:	result:=ansistring('/蛋');
		189:	result:=ansistring('');
		190:	result:=ansistring('/菊花');
		191:	result:=ansistring('');
		192:	result:=ansistring('/红包');
		193:	result:=ansistring('/大笑');
		194:	result:=ansistring('/不开心');
		195:	result:=ansistring('');
		196:	result:=ansistring('');
		197:	result:=ansistring('/冷漠');
		198:	result:=ansistring('/呃');
		199:	result:=ansistring('/好棒');
		200:	result:=ansistring('/拜托');
		201:	result:=ansistring('/点赞');
		202:	result:=ansistring('/无聊');
		203:	result:=ansistring('/托脸');
		204:	result:=ansistring('/吃');
		205:	result:=ansistring('/送花');
		206:	result:=ansistring('/害怕');
		207:	result:=ansistring('/花痴');
		208:	result:=ansistring('/小样儿');
		209:	result:=ansistring('');
		210:	result:=ansistring('/飙泪');
		211:	result:=ansistring('/我不看');
		212:	result:=ansistring('/托腮');
		213:	result:=ansistring('');
		214:	result:=ansistring('/啵啵');
		215:	result:=ansistring('/糊脸');
		216:	result:=ansistring('/拍头');
		217:	result:=ansistring('/扯一扯');
		218:	result:=ansistring('/舔一舔');
		219:	result:=ansistring('/蹭一蹭');
		220:	result:=ansistring('/拽炸天');
		221:	result:=ansistring('/顶呱呱');
		222:	result:=ansistring('/抱抱');
		223:	result:=ansistring('/暴击');
		224:	result:=ansistring('/开枪');
		225:	result:=ansistring('/撩一撩');
		226:	result:=ansistring('/拍桌');
		227:	result:=ansistring('/拍手');
		228:	result:=ansistring('/恭喜');
		229:	result:=ansistring('/干杯');
		230:	result:=ansistring('/嘲讽');
		231:	result:=ansistring('/哼');
		232:	result:=ansistring('/佛系');
		233:	result:=ansistring('/掐一掐');
		234:	result:=ansistring('/惊呆');
		235:	result:=ansistring('/颤抖');
		236:	result:=ansistring('/啃头');
		237:	result:=ansistring('/偷看');
		238:	result:=ansistring('/扇脸');
		239:	result:=ansistring('/原谅');
		240:	result:=ansistring('/喷脸');
		241:	result:=ansistring('/生日快乐');
		else result:=ansistring('/表情');
	end;
	if result='' then result:='/表情';
End;

function getFaceExtension(id:longint):ansistring;
Begin
	case id of
		47,66,75,203: result:='png';
		else result:='gif'
	end;
End;

function StringToOBJ(fromGroup,fromQQ:int64;s:ansistring):TJsonObject;
Var
	obj		:TJsonObject;
	func	:ansistring;
	P		:TList;
	aimage	:ImageInfo;
	back	:ansistring;
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
				aimage:=GetImage(Params_Get(p,'file'));
				obj.add('url',aimage.url);
				obj.add('extension',aimage.extension);
				obj.add('md5',aimage.md5);
				obj.add('height',aimage.height);
				obj.add('width',aimage.width);
				obj.add('size',aimage.size);
				obj.add('content',Base64_Encryption('[图片]'));
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
			obj.add('id',CharToNum(Params_Get(p,'id')));
			obj.add('content',Base64_Encryption(getFaceContent(CharToNum(Params_Get(p,'id')))));
			obj.add('extension',getFaceExtension(CharToNum(Params_Get(p,'id')))); 
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
				obj.add('url',Base64_Encryption(Params_Get(p,'url')));
				back:=Params_Get(p,'text');
				if back='' then back:=Params_Get(p,'brief');
				obj.add('text',Base64_Encryption(back));
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

	content:=MSG_StringToJSON(fromGroup,fromQQ,MSG_EmojiConverter(fromGroup,fromQQ,MSG));
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