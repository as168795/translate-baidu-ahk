#Requires AutoHotkey v2.0
#SingleInstance Force

#include "%A_LineFile%/../utils/helpertool.ahk"
#include "%A_LineFile%/../utils/steamtool.ahk"
#Include "%A_LineFile%/../lib/WebViewToo/WebViewToo.ahk"

; 获取当前脚本的进程ID
ScriptPID := DllCall("GetCurrentProcessId")
GroupAdd("trbdahk", "ahk_pid" ScriptPID)
; Persistent ; 防止脚本在最后一个线程完成后自动退出, 允许它在空闲状态下运行.
; 任务栏图标
TraySetIcon(TranslatorBaidu.iconFile)
; 创建自定义托盘菜单
A_TrayMenu.Delete() ; 清空托盘菜单
; A_TrayMenu.Add() ; 分割线
; ; MsgBox Type(luncher)
A_TrayMenu.Add("显示", luncher)
A_TrayMenu.Add("退出", (*) => ExitApp())
; A_TrayMenu.Insert("显示1", "显示", luncher)

; 启动器
luncher(*) {
	Default := HelperTool.clipboard()
	TranslatorBaidu.run(Default)
}

OnMessage(0x404, TrayClickHandler)
TrayClickHandler(wParam, lParam, msg, hwnd) {
	if (lParam = 0x202) {  ; 左键单击
		; MsgBox "托盘图标被左键单击！"
	} else if (lParam = 0x203) {  ; 左键双击
		; MsgBox "托盘图标被左键双击！"
		luncher
	} else if (lParam = 0x205) {  ; 右键单击
		; MsgBox "托盘图标被右键单击！"
		; return 1  ; 返回 1 可阻止默认菜单弹出
	}
}

; 热键
; #HotIf WinExist("ahk_group trbdahk")
; #HotIf GetKeyState("CapsLock", "P")
; Hotkey "CapsLock & t up", luncher
; CapsLock & t up::
#!q up::luncher
; #HotIf
#HotIf WinActive("ahk_group trbdahk")
^Space:: TranslatorBaidu.PostMsg(10, 0, "")
^Tab::TranslatorBaidu.focus
^`:: TranslatorBaidu.PostMsg(20, 0, "")
^o::TranslatorBaidu.opacity
^t::TranslatorBaidu.topwin
#HotIf

; 消息监听
HelperTool.OnMessage((data, hwnd) => MsgCallBack(data, hwnd))
MsgCallBack(data, hwnd) {
	if data = "show" {
		luncher
	}
}

; 百度翻译 WebviewToo 操作类
class TranslatorBaidu {
	; 百度翻译api doc: https://fanyi-api.baidu.com/doc/21
	static MyWindow := ""
	static myFile := A_LineFile "/../html/translate.html"
	static translatebaiduFile := A_LineFile "/../runtime/TranslatorBaidu.json"
	static iconFile := A_LineFile "/../html/bdtran.ico"
	static apiUrl := "https://fanyi-api.baidu.com/api/trans/vip/translate" ;
	static IsOpen := False

	static historyCacheNum := 50
	static historyData := Map()
	static config := Map()
	static account := Map('apiID', '', 'apiKey', '')
	static text := ""

	static __New() {
		dataSave := this.DataManage()
		; HelperTool.print dataSave
		if dataSave.Has('history')
			this.historyData := dataSave['history']
		if dataSave.Has('config')
			this.config := dataSave['config']
		if dataSave.Has('account')
			this.account := dataSave['account']
	}

	static ContextMenuRequestedHandler(handler, args) {
		; 获取上下文菜单目标 target := args.ContextMenuTarget
		; HelperTool.print args.MenuItems
		; 调试：显示上下文信息
		; 如果是文本选中或可编辑区域，允许默认菜单
		; 如果是选中文本 (target.Kind = 2) 或可编辑区域 (IsEditable = 1)，允许默认菜单
		; 0：COREWEBVIEW2_CONTEXT_MENU_TARGET_KIND_PAGE - 普通页面。
		; 1：COREWEBVIEW2_CONTEXT_MENU_TARGET_KIND_IMAGE - 图片。
		; 2：COREWEBVIEW2_CONTEXT_MENU_TARGET_KIND_SELECTED_TEXT - 选中文本。
		; 3：COREWEBVIEW2_CONTEXT_MENU_TARGET_KIND_AUDIO - 音频元素。
		; 4：COREWEBVIEW2_CONTEXT_MENU_TARGET_KIND_VIDEO - 视频元素。

		; if (target.kind != 0 || target.isEditable) {
		; 	return  ; 不设置 Handled，允许默认菜单显示（包含复制、粘贴等）
		; }

		; 其他情况下，阻止默认菜单
		; args.Handled := true

		; 获取默认菜单项
        menuItems := args.MenuItems
		; 例外菜单
		excludeArr := ['emoji', 'forward', 'back', 'print', 'saveAs', 'saveLinkAs', 'inspectElement', 'share', 'webCapture']
		; 遍历菜单项，移除例外项
        i := 0
		; menuName := ""
        while (i < menuItems.Count) {
            item := menuItems.GetValueAtIndex(i)
            name := item.Name
            ; 如果菜单项在例外列表中，移除
            if (excludeArr.IndexOf(name)) {
                menuItems.RemoveValueAtIndex(i)
            } else {
				; menuName .= name "`n"
                i++
            }
        }
		; MsgBox menuName

		; 加载图标文件并创建 IStream
        iconStream := SteamTool.CreateIconStream(this.iconFile)  ; 替换为你的图标文件路径
		customItem := this.MyWindow.CreateContextMenuItem("切换置顶", iconStream, 0)  ; iconStream = 0(无图标) kind = 0 表示 COMMAND
		customItem2 := this.MyWindow.CreateContextMenuItem("切换半透", iconStream, 0)  ; iconStream = 0(无图标) kind = 0 表示 COMMAND
        ; 插入自定义菜单项到菜单末尾
        customCommandId := customItem.CommandId
        customCommandId2 := customItem2.CommandId
        ; 插入自定义菜单项到菜单末尾
        menuItems.InsertValueAtIndex(menuItems.Count, customItem)
        menuItems.InsertValueAtIndex(menuItems.Count, customItem2)
		; 注册 CustomItemSelected 事件处理 ; this.MyWindow.wv
        customItem.Add_CustomItemSelected(WebView2.Handler((handler, sender, kind) => this.topwin()))
        customItem2.Add_CustomItemSelected(WebView2.Handler((handler, sender, kind) => this.opacity()))
	}

	; 启动翻译窗口
	static run(text) {
		if !text {
			if !this.IsOpen {
				Goto WVGUI
			} else {
				this.PostMsg(13, 0, text) ; 输入框焦点
			}
		} else {
			this.text := text
			if !this.IsOpen
				Goto WVGUI
			this.PostMsg(1, 0, text)
		}
		WinActivate(this.MyWindow.Hwnd)
		return
		WVGUI:
		this.IsOpen := True
		this.MyWindow := WebViewToo(, , , False) ;You can omit the final parameter or switch 'True' to 'False' to use a Native Window's Titlebar
		; this.MyWindow.EnableGlobal() ;
		this.MyWindow.OnEvent("Close", (*) => (this.IsOpen := False, this.MyWindow := ''))
		this.MyWindow.OnEvent("Escape", (*) => WinMinimize(this.MyWindow.Hwnd))
		this.MyWindow.Load2(this.myFile)
		; this.MyWindow.AddCallBackToScript("SendMsg", (Webview, Msg) => this.SendMsg(Webview, Msg, this))
		this.MyWindow.AddCallBackToScript("SendMsg", (Webview, Msg) => this.SendMsg(Webview, Msg))
		; this.MyWindow.Debug() ; 调试工具
		; this.MyWindow.Opt("+AlwaysOnTop -Caption -Border")
		this.MyWindow.Gui.Opt("-MaximizeBox -Resize")
		; this.MyWindow.AreDefaultContextMenusEnabled := false	; 禁用默认的右键菜单
		this.MyWindow.ContextMenuRequested((handler, args) => this.ContextMenuRequestedHandler(handler, args))

		wh := [400, 500] ; 窗口大小
		this.MyWindow.Show("w" wh[1] " h" wh[2] " Center", "百度翻译") ; "x" A_ScreenWidth - 860 "xCenter" " y20"
		; WinSetTransparent(180, this.MyWindow.Hwnd) ; 设置为半透明效果
		; Opt的+AlwaysOnTop无效，用WinSetAlwaysOnTop代替 除非WebViewToo第四参数为False
		; WinSetAlwaysOnTop(1, this.MyWindow.Hwnd)

		; 窗口置顶和透明度 初始化
		if this.config.Get('topwin', 0)
			WinSetAlwaysOnTop(1, this.MyWindow.Hwnd)
		if this.config.Get('opacity', 255) != 255
			WinSetTransparent(this.config['opacity'], this.MyWindow.Hwnd)

		; 激活窗口
		WinActivate(this.MyWindow.Hwnd)
	}

	; 翻译框焦点获取
	static focus() {
		HelperTool.PutFocus(Map("x", 10, "y", 100, "Control", "Chrome_RenderWidgetHostHWND1", "Hwnd", this.MyWindow.Hwnd), 1)
		this.PostMsg(13, 0, "")
	}

	; 窗口置顶显示
	static topwin() {
		static val := true
		status := val ? 1 : 0
		WinSetAlwaysOnTop(status, this.MyWindow.Hwnd)
		val := !val
		this.config['topwin'] := status
		this.DataManage('config') ; 保存配置
	}

	;  窗口透明度切换
	static opacity() {
		tmp := WinGetTransparent(this.MyWindow.Hwnd)
		transparency := !tmp || tmp > 200 ? 180 : 255
		WinSetTransparent(transparency, this.MyWindow.Hwnd)
		this.config['opacity'] := transparency
		this.DataManage('config') ; 保存配置
	}

	static PostMsg(type, code, data) {
		json_str := JSON.stringify({ code: code, type: type, data: data })
		this.MyWindow.PostWebMessageAsString(json_str)
	}

	static SendMsg(Webview, Msg) {
		; HelperTool.print Msg
		res := JSON.parse(Msg)
		mtype := res['type'], code := 0
		if mtype = 1 {
			data := this.text
			this.SendMsg Webview, JSON.stringify({ type: 3 })
		} else if mtype = 2 {
			tdata := this.Translate(res['text'], res['from'], res['to'])
			code := tdata[1], data := tdata[2]
			if code != 0
				MsgBox data, '消息提示'
		} else if mtype = 3 {
			data := Map("history", this.historyData, "config", this.config, "account", this.account)
		} else if mtype = 4 {
			typeArr := ['config', 'account']
			for v in typeArr {
				if !res.Has(v)
					continue
				data := res[v]
				tkey := v
				break
			}
			this.DataManage(tkey, data) ; 保存配置
			return
		} else if mtype = 5 {
			this.DataManage('clear_history')
			MsgBox "清除历史记录成功", '消息提示'
			return
		} else if mtype = -1 {	; 错误提示
			data := ""
			MsgBox res['msg'], '消息提示'
		}
		this.PostMsg(mtype, code, data)
	}

	static getSign(text) {
		if !text
			return ""
		if !this.account['apiID'] || !this.account['apiKey']
			return ""
		salt := Random(15236215, 98564125) ; 随机数
		sign := HelperTool.md5(this.account['apiID'] . text . salt . this.account['apiKey']) ; md5签名
		return Map(
			"salt", salt,
			"sign", sign
		)
	}

	; 执行 翻译
	static Translate(text, from := "auto", to := "auto") {
		text := Trim(text)	; 去除首尾空格
		if !text || !to || !this.languages.Has(from) || !this.languages.Has(to)
			return [10, "参数错误"]
		; regex := "^[\x21-\x2F\x3A-\x40\x5B-\x60\x7B-\x7E\x{FF01}-\x{FF0F}\x{FF1A}-\x{FF1F}\x{FF3B}-\x{FF40}\x{FF5B}-\x{FF65}\s]*$"
		regex := "^[\d\s\p{P}\p{S}]+$"
		if RegExMatch(text, regex)
			return [20003, "纯符号不作翻译处理"]
		if to = 'auto'
			if from = 'auto'
				to := RegExMatch(text, "[\p{Han}]") ? 'en' : 'zh' ; 文本是否含中文
			else
				to := from = 'zh' ? 'en' : 'zh' ; 默认自动翻译为英文
		; 判断是否有历史记录
		tkey := text "_" to
		if this.historyData.Has(tkey) {
			this.historyData[tkey]['datetime'] := HelperTool.GetFormatTime()
			this.DataManage('history', [tkey, this.historyData[tkey]])	; 保存历史记录到文件
			return [0, this.historyData[tkey]]
		}
		salt_sign := this.getSign(text)
		if !salt_sign
			return [100, "获取签名失败,请检查api密钥是否正确"]
		; 参数拼装
		paramMap := Map("q", text, "from", from, "to", to, "appid", this.account['apiID'], "salt", salt_sign['salt'], "sign", salt_sign['sign'])
		res := HelperTool.http(this.apiUrl, "POST", paramMap)
		if !res[1]
			return [101, res[2]]
		jsonMap := JSON.parse(res[2])
		if jsonMap.Has('error_code') {
			errorCode := Number(jsonMap['error_code'])
			return [errorCode, '[' jsonMap['error_msg'] '] ' this.errorMap[errorCode]]
		}
		; HelperTool.print(jsonMap) ; Debug
		content := "" ;
		Loop jsonMap['trans_result'].Length {
			val := jsonMap['trans_result'][A_Index]
			content .= val['dst'] "`n"
		}
		item := Map("text", text, "from", jsonMap['from'], "to", jsonMap['to'], "content", content, "datetime", HelperTool.GetFormatTime())
		if (content != text) this.DataManage('history', [tkey, item])	; 保存历史记录到文件

		return [0, item]
	}

	; 历史记录管理
	static DataManage(tkey := "", item := "") {
		if !tkey {
			str := ""
			try
				str := HelperTool.ReadFile(this.translatebaiduFile)
			if !str
				return Map("history", Map(), "config", Map(), 'account', Map('apiID', '', 'apiKey', ''))
			return JSON.parse(str)
		} else {
			if (tkey = "config") {
				; HelperTool.print item
				if (item = '')
					item := this.config
				this.config := item
			} else if (tkey = "account") {
				this.account := item
				MsgBox("保存成功", "消息提示")
			} else if (tkey = "clear_history") {
				this.historyData := Map()
			} else {
				this.historyData[item[1]] := item[2]
				if this.historyData.Count > this.historyCacheNum
					this.historyData := HelperTool.SortAndDelete(this.historyData, 'datetime', this.historyCacheNum)
			}
			data := Map("history", this.historyData, "config", this.config, "account", this.account)
			HelperTool.WriteFile(this.translatebaiduFile, JSON.stringify(data))
		}
	}

	; 语言列表
	static languages := Map(
		"auto", "自动检测",
		"zh", "中文",
		"en", "英语",
		"cht", "繁体中文",
		"wyw", "文言文",
		"yue", "粤语",
		"jp", "日语",
		"kor", "韩语",
		"th", "泰语",
		"pt", "葡萄牙语",
		"el", "希腊语",
		"bul", "保加利亚语",
		"fin", "芬兰语",
		"slo", "斯洛文尼亚语",
		"fra", "法语",
		"ara", "阿拉伯语",
		"de", "德语",
		"nl", "荷兰语",
		"est", "爱沙尼亚语",
		"cs", "捷克语",
		"swe", "瑞典语",
		"vie", "越南语",
		"spa", "西班牙语",
		"ru", "俄语",
		"it", "意大利语",
		"pl", "波兰语",
		"dan", "丹麦语",
		"rom", "罗马尼亚语",
		"hu", "匈牙利语"
	)

	; 错误码及其对应的含义和解决方案
	static errorMap := Map(
		52000, "成功",
		52001, "请求超时 | 检查请求query是否超长，以及原文或译文参数是否在支持的语种列表里",
		52002, "系统错误 | 请重试",
		52003, "未授权用户 | 请检查appid是否正确或者服务是否开通",
		54000, "必填参数为空 | 请检查是否少传参数",
		54001, "签名错误 | 请检查您的签名生成方法",
		54003, "访问频率受限 | 请降低您的调用频率，或在控制台进行身份认证后切换为高级版/尊享版",
		54004, "账户余额不足 | 请前往管理控制台为账户充值",
		54005, "长query请求频繁 | 请降低长query的发送频率，3s后再试",
		58000, "客户端IP非法 | 检查个人资料里填写的IP地址是否正确，可前往开发者信息-基本信息修改",
		58001, "译文语言方向不支持 | 检查译文语言是否在语言列表里",
		58002, "服务当前已关闭 | 请前往管理控制台开启服务",
		58003, "此IP已被封禁 | 同一IP当日使用多个APPID发送翻译请求，则该IP将被封禁当日请求权限，次日解封。请勿将APPID和密钥填写到第三方软件中。",
		90107, "认证未通过或未生效 | 请前往我的认证查看认证进度",
		20003, "请求内容存在安全风险 | 请检查请求内容"
	)

}