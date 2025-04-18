#include "%A_LineFile%/../../lib/Misc.ahk"
#include "%A_LineFile%/../../lib/Array.ahk" ; 引用数组类
#include "%A_LineFile%/../../lib/Map.ahk" ; 引用字典类
#include "%A_LineFile%/../../lib/JSON.ahk" ; 引用 JSON 类

; 辅助工具类
class HelperTool {

	; static Self := HelperTool
	; 脚本启动提示
	static tips(_content := "", keep_time := 2500) {
		if (!(keep_time >= 100)) keep_time := 2500
			content := _content ? _content : "AutoHotkey V" A_AhkVersion " 映射已生效！"
		; 创建 GUI
		MyGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
		MyGui.BackColor := "Black" ; 设置背景为黑色
		MyGui.SetFont("s12 cWhite", "Consolas") ; 设置字体大小为12，颜色为白色
		MyGui.AddText("xm y20", content) ; 添加文本，并设置位置
		MyGui.Show("w300 h50 x" A_ScreenWidth - 400 " y20") ; 显示窗口

		; 设置窗口透明度（0-255，0为完全透明，255为不透明）
		WinSetTransparent(150, MyGui.Hwnd) ; 设置为半透明效果

		; 保持脚本运行，以便你能看到 GUI
		Sleep(keep_time)
		MyGui.Destroy()
	}

	; 利用粘贴板模拟发送文本
	static SendRaw(str := "") {
		if (!str || Type(str) != "String") {
			ToolTip("异常：粘贴文件为空")
			SetTimer(() => ToolTip(), -2000)  ; 1 秒后清除 ToolTip
			return
		}
		ClipSaved := ClipboardAll() ; 把整个剪贴板保存到您选择的变量中.
		A_Clipboard := str
		Sleep 20
		Send "^v"
		Sleep 100
		A_Clipboard := ClipSaved ; 还原剪贴板. 注意这里使用 A_Clipboard(而不是 ClipboardAll).
		ClipSaved := "" ; 在剪贴板含有大量内容时释放内存.
	}

	; 剪切板临时缓存管理
	static clipboard(copy := False) {
		Default := "", ClipSaved := ""
		if !copy {
			ClipSaved := ClipboardAll() ; 把整个剪贴板保存到您选择的变量中.
			A_Clipboard := ""
		}
		Send "^c"
		flag := ClipWait(0.4, 0)
		if flag
			Default := A_Clipboard
		if copy {
			A_Clipboard := Default
		} else {
			A_Clipboard := ClipSaved ; 还原剪贴板. 注意这里使用 A_Clipboard(而不是 ClipboardAll).
			ClipSaved := "" ; 在剪贴板含有大量内容时释放内存.
		}

		return Default
	}

	static MD5(s) {
		size := StrPut(s, "UTF-8") - 1 ; bin has no null
		bin := Buffer(size)
		StrPut(s, bin, "UTF-8")

		MD5_CTX := Buffer(104)
		DllCall("advapi32\MD5Init", "ptr", MD5_CTX)
		DllCall("advapi32\MD5Update", "ptr", MD5_CTX, "ptr", bin, "uint", size)
		DllCall("advapi32\MD5Final", "ptr", MD5_CTX)

		VarSetStrCapacity(&md5, 32 + 1) ; str has null
		DllCall("crypt32\CryptBinaryToString", "ptr", MD5_CTX.ptr + 88, "uint", 16, "uint", 0x4000000c, "str", md5, "uint*", 33)
		return md5
	}

	; 窗口/控件 焦点获取
	static PutFocus(Option, Cate := 1) {
		CateArr := [1, 2] ; 1事件触发 2鼠标模拟
		if (Type(Option) != "Map" || !Option.Has('x') || !Option.Has('y')) {
			MsgBox "PutFocus() 参数错误"
			return
		}
		x := Option['x'], y := Option['y']
		if (Cate = 1) {
			if (!Option.Has('Control') || !Option.Has('Hwnd') || !Option.Has('x') || !Option.Has('y')) {
				MsgBox "PutFocus() 参数错误"
				return
			}
			Control := Option['Control'] ; 获取控件句柄 ; WebView2控件是"Chrome_RenderWidgetHostHWND1"
			Hwnd :=  Option['Hwnd']
			hCtrl := ControlGetHwnd(Control, "ahk_id " Hwnd)
			if (!hCtrl) {
				MsgBox("未找到 WebView 控件！")
				return
			}
			; 发送 WM_LBUTTONDOWN 和 WM_LBUTTONUP 消息
			lParam := (y << 16) | x ; 坐标 (100, 100)，相对控件左上角
			DllCall("SendMessage", "Ptr", hCtrl, "UInt", 0x0201, "Ptr", 0, "Ptr", lParam) ; WM_LBUTTONDOWN 鼠标左键按下
			DllCall("SendMessage", "Ptr", hCtrl, "UInt", 0x0202, "Ptr", 0, "Ptr", lParam) ; WM_LBUTTONUP 鼠标左键抬起
			; 发送 WM_SETFOCUS
			DllCall("SendMessage", "Ptr", hCtrl, "UInt", 0x0007, "Ptr", hCtrl, "Ptr", 0) ; WM_SETFOCUS 仅用于通知窗口获得键盘焦点（例如光标出现在输入框）
		} else {
			; 模拟点击激活
			WinGetPos(&X, &Y, &W, &H, "ahk_id " Hwnd)
			MouseGetPos(&origX, &origY) ; 保存鼠标位置
			DllCall("SetCursor", "Ptr", 0) ; 隐藏光标 避免鼠标闪烁
			; DllCall("SetCursorPos", "Int", X + W//2, "Int", Y + H//2) ; 移动鼠标到窗口中心
			DllCall("SetCursorPos", "Int", X + x, "Int", Y + y) ; 移动鼠标到窗口
			DllCall("mouse_event", "UInt", 0x0002, "Int", 0, "Int", 0, "UInt", 0, "Ptr", 0) ; 左键按下
			DllCall("mouse_event", "UInt", 0x0004, "Int", 0, "Int", 0, "UInt", 0, "Ptr", 0) ; 左键释放
			DllCall("SetCursorPos", "Int", origX, "Int", origY) ; 恢复鼠标位置
			DllCall("SystemParametersInfo", "UInt", 0x0057, "UInt", 0, "Ptr", 0, "UInt", 0) ; SPI_SETCURSOR ; 恢复鼠标光标
		}
	}

	; 写入字符串（UTF-8 无 BOM）
	static WriteFile(filePath, content) {
		FileEncoding "UTF-8-RAW"  ; 设置编码为 UTF-8 无 BOM
		if FileExist(filePath)
			FileDelete filePath  ; 删除旧文件，确保新文件编码正确
		FileAppend content, filePath
	}

	; 读取字符串（UTF-8 无 BOM）
	static ReadFile(filePath) {
		return FileRead(filePath, "UTF-8-RAW")  ; 读取并指定编码
	}

	; 判断 URL 是否合法
	static IsValidUrl(url) {
		regex := "^(?:https?|ftp)://(?:[\w-]+\.)*[\w-]+(?:\:[0-9]{1,5})?(?:/[\w-./?%&=]*)?(#:[\w-]*)?$"
		return RegExMatch(url, regex) ? true : false
	}

	; URI 编码（提升为 static 方法）
	static UrlEncode(url, component := true) {
		flag := component ? 0xc2000 : 0xc0000
		DllCall('shlwapi\UrlEscape', 'str', url, 'ptr*', 0, 'uint*', &len := 1, 'uint', flag)
		DllCall('shlwapi\UrlEscape', 'str', url, 'ptr', buf := Buffer(len << 1), 'uint*', &len, 'uint', flag)
		return StrGet(buf)
	}

	static HttpBuildQuery(data, prefix := "", separator := "&", key := "") {
		if (!IsObject(data))
			return ""
		query := []
		for k, v in data {
			if (IsInteger(k) && prefix != "") {
				k := prefix . k
			}
			if (key != "") {
				k := key . "[" . k . "]"
			}
			if (IsObject(v)) {
				query.Push(this.HttpBuildQuery(v, "", separator, k))
			} else {
				; query.Push(UriEncode(k) . "=" . UriEncode(v ?? ""))
				query.Push(this.UrlEncode(k) . "=" . this.UrlEncode(v ?? ""))
			}
		}
		StrJoin(arr, sep) {
			result := ""
			for i, val in arr {
				result .= (i > 1 ? sep : "") . val
			}
			return result
		}
		return StrJoin(query, separator)
	}

	; WinHttp 请求
	static http(url, method := "GET", paramMap := Map(), headerMap := Map(), timeoutArr := [], callback?) {
		; 验证 URL
		if !this.IsValidUrl(url) {
			return [0, "URL is invalid"]
		}

		; 验证和规范化请求方法
		method := StrUpper(method)
		static validMethods := Map("GET", true, "POST", true, "JSON", true)
		if !validMethods.Has(method) {
			return [0, "Invalid request method"]
		}

		; 封装参数
		pData := ""
		if (method = "POST" && paramMap.Count > 0 && Type(paramMap) = "Map") {
			; encoded := ""
			; for key, value in paramMap {
			; 	encoded .= (encoded ? "&" : "") . this.UriEncode(key) . "=" . this.UriEncode(value)
			; }
			; pData := encoded
			pData := this.HttpBuildQuery(paramMap)
		} else if (method = "JSON") {
			if (paramMap.Count > 0 && Type(paramMap) ~= "^(Map|Object)$") {
				pData := JSON.stringify(paramMap)  ; 假设有 JSON 库
			} else {
				pData := "{}"
			}
		}
		; 设置 Content-Type
		contentType := (method = "JSON") ? "application/json" : "application/x-www-form-urlencoded"
		; 发送请求; 默认超时值（单位：毫秒）
		defaultTimeouts := [5000, 5000, 15000, 15000]  ; [Resolve, Connect, Send, Receive]
		; 合并超时参数
		finalTimeouts := defaultTimeouts.Clone()  ; 复制默认值
		if (Type(timeoutArr) = "Array" && timeoutArr.Length > 0) {
			Loop Min(timeoutArr.Length, 4) {  ; 只处理前4个元素
				if (IsInteger(timeoutArr[A_Index]) && timeoutArr[A_Index] >= 0) {
					finalTimeouts[A_Index] := timeoutArr[A_Index]  ; 覆盖默认值
				}
			}
		}
		; this.print finalTimeouts ;test
		; 发送请求
		try {
			http := ComObject("WinHttp.WinHttpRequest.5.1")
			; 设置超时
			http.SetTimeouts(finalTimeouts[1], finalTimeouts[2], finalTimeouts[3], finalTimeouts[4])
			http.Open(method, url, false)  ; 同步模式
			; 设置请求头
			if (headerMap.Count > 0 && Type(headerMap) ~= "^(Map|Object)$") {
				for key, value in headerMap {
					http.SetRequestHeader(key, value)
				}
			}
			http.SetRequestHeader("Content-Type", contentType)
			http.Send(pData)
			; 无需 WaitForResponse，因为是同步模式

			; 处理响应
			status := http.Status
			if (status >= 200 && status <= 299) {
				response := http.ResponseText
				if (IsSet(callback) && Type(callback) = "Func") {
					response := callback(response, status)  ; 调用回调但不直接返回结果
					return [1, response]  ; 保持返回格式一致
				}
				return [1, response]
			} else {
				return [0, "Network error: (" . status . ") " . http.StatusText]
			}
		} catch as e {
			return [0, "异常: " . e.Message]
		}
	}

	; 打印
	static print(object) {
		Print := Printer(MsgBox)
		Print(object)
	}

	; 获取当前时间
	static GetFormatTime(format := "yy-MM-dd HH:mm:ss") {
		return FormatTime(, format)
	}
	; 获取当前时间戳（秒）
	static GetUnixTimestamp() {
		now := A_NowUTC  ; 获取当前 UTC 时间
		base := "19700101000000"  ; Unix 纪元起点
		return DateDiff(now, base, "Seconds")  ; 计算秒差
	}

	; 按 datetime 排序并删除前 N 个元素
	static SortAndDelete(map, sortField, saveCount) {
		; 参数校验
		if Type(sortField) != 'String' || Type(saveCount) != 'Integer' || Type(map) != 'Map' {
			throw ValueError("参数类型错误：`nmap: Map, sortField: String, saveCount: Integer", -1)
		}

		; 1. 提取键值对并校验字段存在性
		entries := []
		for key, subMap in map {
			if !subMap.Has(sortField) {
				throw ValueError("字段 '" sortField "' 在键 '" key "' 中不存在", -1)
			}
			entries.Push({ mkey: key, sortValue: subMap[sortField] })
		}

		; 2. 自然排序（支持数字和字符串混合）
		entries.Sort((a, b) => this.NaturalCompare(a.sortValue, b.sortValue))

		; 3. 删除最早的条目
		deleteCount := entries.Length - saveCount
		if (deleteCount > 0) {
			Loop deleteCount {
				map.Delete(entries[A_Index].mkey)
			}
		}
		return map
	}

	; 自然排序比较函数
	static NaturalCompare(a, b) {
		; 正则分割数字和非数字部分
		regex := "(\d+)|(\D+)"
		aParts := [], bParts := []

		; 分割字符串a
		while (RegExMatch(a, regex, &match)) {
			aParts.Push(match[0])
			a := SubStr(a, match.Pos + match.Len)
		}

		; 分割字符串b
		while (RegExMatch(b, regex, &match)) {
			bParts.Push(match[0])
			b := SubStr(b, match.Pos + match.Len)
		}

		; 逐段比较
		loop min(aParts.Length, bParts.Length) {
			aPart := aParts[A_Index], bPart := bParts[A_Index]

			; 数字部分按数值比较
			if (IsInteger(aPart) && IsInteger(bPart)) {
				if (aPart != bPart)
					return aPart < bPart ? -1 : 1
			}
			; 非数字部分按字符串比较
			else if (aPart != bPart) {
				return aPart < bPart ? -1 : 1
			}
		}
		return aParts.Length < bParts.Length ? -1 : 1
	}

	; 注册消息监听
	static OnMessage(_callback) {
		static callback := _callback
		OnMessage 0x004A, Receive_WM_COPYDATA  ; 0x004A is WM_COPYDATA
		static Receive_WM_COPYDATA(wParam, lParam, msg, hwnd) {
			StringAddress := NumGet(lParam, 2 * A_PtrSize, "Ptr")  ; 检索 CopyDataStruct 的 lpData 成员.
			CopyOfData := StrGet(StringAddress)  ; 从结构中复制字符串.
			; 比起 MsgBox, 应该用 ToolTip 显示, 这样我们可以及时返回:
			; ToolTip A_ScriptName "`nReceived the following string:`n" CopyOfData
			callback(CopyOfData, hwnd)
			return true  ;  返回 1(true) 是回复此消息的传统方式.
		}
	}
	; 发送消息
	static SendMessage(targetScriptTitle, StringToSend) {
		CopyDataStruct := Buffer(3 * A_PtrSize)  ; 分配结构的内存区域.
		; 首先设置结构的 cbData 成员为字符串的大小, 包括它的零终止符:
		SizeInBytes := (StrLen(StringToSend) + 1) * 2
		NumPut("Ptr", SizeInBytes  ; 操作系统要求这个需要完成.
			, "Ptr", StrPtr(StringToSend)  ; 设置 lpData 为到字符串自身的指针.
			, CopyDataStruct, A_PtrSize)
		Prev_TitleMatchMode := A_TitleMatchMode
		SetTitleMatchMode 2
		Prev_DetectHiddenWindows := A_DetectHiddenWindows
		if (!Prev_DetectHiddenWindows)
			DetectHiddenWindows True
		TimeOutTime := 14000  ; 可选的. 等待 receiver.ahk 响应的毫秒数. 默认是 5000
		; 必须使用发送 SendMessage 而不是投递 PostMessage.
		RetValue := SendMessage(0x4a, 0, CopyDataStruct, , TargetScriptTitle, , , , TimeOutTime) ; 0x4a 是 WM_COPYDATA.
		if (!Prev_DetectHiddenWindows)
			DetectHiddenWindows Prev_DetectHiddenWindows  ; 恢复调用者原来的设置.
		SetTitleMatchMode Prev_TitleMatchMode         ; 同样.
		return RetValue  ; 返回 SendMessage 的回复给我们的调用者.
	}
}

; this.tips('测试一下')

; MsgBox A_LineFile "/../../lib/Misc.ahk"
; MsgBox Type([])
