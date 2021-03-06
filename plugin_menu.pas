unit plugin_menu;

interface
uses
	CoolQSDK, iconv, windows, sysutils, dateutils,
	JustchatConfig, JustchatServer;

Function _menuA():longint;stdcall;
Function _menuB():longint;stdcall;

implementation

{
* 菜单，可在 .json 文件中设置菜单数目、函数名
* 如果不使用菜单，请在 .json 及此处删除无用菜单
}
Function _menuA():longint;
stdcall;
Begin
	//MessageBox(0,StoP('本插件的AuthCode为 : '+NumToChar(AuthCode)),'样例 _ AuthCode查询',36);

	if JustChatService.getConnectionsAmount() > 0 then begin
		CQ_i_addLog(CQLOG_WARNING, 'Reload', 'Failed to reload configuration.' + CRLF +
			'Reloading operation requires no connection connected to this terminal so far.');
		exit(0);
	end;

	CloseService();	
	Final_ConfigFree();
	
	Init_Config();
	StartService();
{$IFDEF FPC}
	exit(0);
{$ELSE}
	result:=0;
{$ENDIF}
End;

Function _menuB():longint;
stdcall;
Begin
	//MessageBox(0,StoP('当前时间 : '+DateTimeToStr(now)),'样例 _ 当前时间',36);
{$IFDEF FPC}
	exit(0);
{$ELSE}
	result:=0;
{$ENDIF}
End;

end.