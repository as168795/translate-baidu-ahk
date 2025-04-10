/*
	名称: Misc.ahk
	版本 1.0.1 (11.11.24)
	创建时间: 26.08.22
	作者: Descolada (https://www.autohotkey.com/boards/viewtopic.php?f=83&t=107759)
	致谢: Coco

	Range(stop)						=> 返回一个从 1 到 stop 的可迭代对象
	Range(start, stop [, step])		=> 返回一个从 start 到 stop，步长为 step 的可迭代对象
	Swap(&a, &b)					=> 交换 a 和 b 的值
	Printer(func?) 					=> 创建一个使用指定函数打印字符串的函数，或返回字符串
	RegExMatchAll(haystack, needleRegEx [, startingPosition := 1])
	    返回 haystack 中所有匹配 needleRegEx 的结果（RegExMatchInfo 对象数组）: [RegExMatchInfo1, RegExMatchInfo2, ...]
	Highlight(x?, y?, w?, h?, showTime:=0, color:="Red", d:=2)
		高亮显示一个带有彩色边框的区域。
	MouseTip(x?, y?, color1:="red", color2:="blue", d:=4)
		在某一点闪烁彩色高亮提示，持续 2 秒。
	WindowFromPoint(X, Y) 			=> 返回屏幕坐标 X 和 Y 处的窗口 ID。
	ConvertCoords(X, Y, &outX, &outY, relativeFrom:=A_CoordModeMouse, relativeTo:="screen", winTitle?, winText?, excludeTitle?, excludeText?)
		在屏幕、窗口和客户区之间转换坐标。
	WinGetInfo(WinTitle:="", Verbose := 1, WinText:="", ExcludeTitle:="", ExcludeText:="", Separator := "`n")
		获取窗口信息（标题、进程名、位置等）。
	WinWaitNew(WinTitle:="", WinText:="", TimeOut:="", ExcludeTitle:="", ExcludeText:="")
		等待符合指定条件的新窗口实例。
	GetCaretPos(&X?, &Y?, &W?, &H?)
		通过 CaretGetPos、Acc、Java Access Bridge 或 UIA 获取光标位置。
	IntersectRect(l1, t1, r1, b1, l2, t2, r2, b2)
		检查两个矩形是否相交，如果相交则返回相交区域的对象: {l:left, t:top, r:right, b:bottom}
	WinGetPosEx(WinTitle:="", &X := "", &Y := "", &Width := "", &Height := "", &LeftBorder := 0, &TopBorder := 0, &RightBorder := 0, &BottomBorder := 0)
		基于窗口的可见属性返回窗口坐标（边界参数设置为不可见 DWM 边框的厚度）。
	WinMoveEx(X?, Y?, Width?, Height?, WinTitle?, WinText?, ExcludeTitle?, ExcludeText?)
		根据窗口的视觉属性移动窗口（调整不可见 DWM 边框）。
*/

/**
 * 返回一个数字序列，从 1 开始（默认），步长为 1（默认），并在指定的结束数字处停止。
 * 可以使用 ToArray 方法将其转换为数组。
 * @param start 起始数字，或者如果省略 end，则表示结束数字
 * @param end 结束数字
 * @param step 可选：指定增量的数字，默认为 1。
 * @returns {Iterable}
 * @example 
 * for v in Range(5)
 *     Print(v) ; 输出 "1 2 3 4 5"
 */
class Range {
	__New(start, end?, step:=1) {
		if !step
			throw TypeError("无效的 'step' 参数")
		if !IsSet(end)
			end := start, start := 1
		if (end < start) && (step > 0)
			step := -step
		this.start := start, this.end := end, this.step := step
	}
	__Enum(varCount) {
		start := this.start - this.step, end := this.end, step := this.step, counter := 0
		EnumElements(&element) {
			start := start + step
			if ((step > 0) && (start > end)) || ((step < 0) && (start < end))
				return false
			element := start
			return true
		}
		EnumIndexAndElements(&index, &element) {
			start := start + step
			if ((step > 0) && (start > end)) || ((step < 0) && (start < end))
				return false
			index := ++counter
			element := start
			return true
		}
		return (varCount = 1) ? EnumElements : EnumIndexAndElements
	}
	/**
	 * 将可迭代对象转换为数组。
	 * @returns {Array}
	 * @example
	 * Range(3).ToArray() ; 返回 [1,2,3]
	 */
	ToArray() {
		r := []
		for v in this
			r.Push(v)
		return r
	}
}

/**
 * 交换两个变量的值
 * @param a 第一个变量
 * @param b 第二个变量
 */
Swap(&a, &b) {
	temp := a
	a := b
	b := temp
}

/**
 * 创建一个使用指定函数打印字符串的函数，或返回字符串。
 * OutputFunc 和 Newline 属性可以在稍后修改。
 * @param OutputFunc 打印字符串的函数，默认无函数（仅返回字符串）。
 * @param NewLine 新行分隔符，默认为 `n
 * @returns {Func}
 * @example 
 * 	MB := Printer(MsgBox)
 * 	MB([1,2,3])
 */
class Printer {
	__New(OutputFunc:=0, Newline := "`n") => (this.Newline := Newline, this.OutputFunc := OutputFunc)
	Call(val?) => ((str := !IsSet(val) || IsObject(val) ? ToString(val?) this.Newline : val this.Newline), this.OutputFunc ? this.OutputFunc.Call(str) : str)
}

/**
 * 将值（数字、数组、对象）转换为字符串。
 * @param value 可选：要转换的值。
 * @returns {String}
 */
ToString(val?) {
    if !IsSet(val)
        return "未设置"
    valType := Type(val)
    switch valType, 0 {
        case "String":
            return "'" val "'"
        case "Integer", "Float":
            return val
        default:
            self := "", iter := "", out := ""
            try self := ToString(val.ToString()) ; 如果对象有 ToString 方法，则打印它
            if valType != "Array" { ; 枚举对象的键值对，数组除外
                try {
                    enum := val.__Enum(2) 
                    while (enum.Call(&val1, &val2))
                        iter .= ToString(val1) ":" ToString(val2?) ", "
                }
            }
            if !IsSet(enum) { ; 如果枚举键值对失败，则尝试仅枚举值
                try {
                    enum := val.__Enum(1)
                    while (enum.Call(&enumVal))
                        iter .= ToString(enumVal?) ", "
                }
            }
            if !IsSet(enum) && (valType = "Object") && !self { ; 如果一切失败，则枚举对象属性
                for k, v in val.OwnProps()
                    iter .= SubStr(ToString(k), 2, -1) ":" ToString(v?) ", "
            }
            iter := SubStr(iter, 1, StrLen(iter)-2)
            if !self && !iter && !((valType = "Array" && val.Length = 0) || (valType = "Map" && val.Count = 0) || (valType = "Object" && ObjOwnPropCount(val) = 0))
                return valType ; 如果没有额外信息，则仅打印类型
            else if self && iter
                out .= "值:" self ", 迭代:[" iter "]"
            else
                out .= self iter
            return (valType = "Object") ? "{" out "}" : (valType = "Array") ? "[" out "]" : valType "(" out ")"
    }
}

/**
 * 返回 haystack 中所有匹配 needleRegEx 的结果（RegExMatchInfo 对象数组）: [RegExMatchInfo1, RegExMatchInfo2, ...]
 * @param haystack 要搜索内容的字符串。
 * @param needleRegEx 要搜索的正则表达式模式。
 * @param startingPosition 如果未提供 StartingPos，则默认为 1（haystack 的开头）。
 * @returns {Array}
 */
RegExMatchAll(haystack, needleRegEx, startingPosition := 1) {
	out := [], end := StrLen(haystack)+1
	While startingPosition < end && RegExMatch(haystack, needleRegEx, &outputVar, startingPosition)
		out.Push(outputVar), startingPosition := outputVar.Pos + (outputVar.Len || 1)
	return out
}

/**
 * 高亮显示一个带有彩色边框的区域。如果未提供参数，则移除所有高亮显示。
 * 此函数支持命名参数。
 * @param x 高亮左上角的屏幕 X 坐标
 * @param y 高亮左上角的屏幕 Y 坐标
 * @param w 高亮的宽度
 * @param h 高亮的高度
 * @param showTime 可为以下之一：
 * * 未设置 - 如果存在高亮，则移除高亮，否则高亮 2 秒。这是默认值。
 * * 0 - 持续高亮
 * * 正整数（如 2000）- 高亮并暂停指定毫秒数
 * * 负整数 - 高亮指定毫秒数，但脚本继续执行
 * * "clear" - 无条件移除高亮
 * @param color 高亮的颜色，默认为红色。
 * @param d 高亮边框的厚度（像素）。默认为 2。
 */
Highlight(x?, y?, w?, h?, showTime?, color:="Red", d:=2) {
	static guis := Map(), timers := Map()
	if IsSet(x) { ; 如果设置了 x，则检查该坐标处是否已存在高亮
		if IsObject(x) {
			d := x.HasOwnProp("d") ? x.d : d, color := x.HasOwnProp("color") ? x.color : color, showTime := x.HasOwnProp("showTime") ? x.showTime : showTime
			, h := x.HasOwnProp("h") ? x.h : h, w := x.HasOwnProp("w") ? x.w : h, y := x.HasOwnProp("y") ? x.y : y, x := x.HasOwnProp("x") ? x.x : unset
		}
		if !(IsSet(x) && IsSet(y) && IsSet(w) && IsSet(h))
			throw ValueError("必须提供 x、y、w 和 h 参数", -1)
		for k, v in guis {
			if k.x = x && k.y = y && k.w = w && k.h = h { ; 高亮已存在，因此移除或更新
				if !IsSet(showTime) || (IsSet(showTime) && showTime = "clear")
					TryRemoveTimer(k), TryDeleteGui(k)
				else if showTime = 0
					TryRemoveTimer(k)
				else if IsInteger(showTime) {
					if showTime < 0 {
						if !timers.Has(k)
							timers[k] := Highlight.Bind(x,y,w,h)
						SetTimer(timers[k], showTime)
					} else {
						TryRemoveTimer(k)
						Sleep showTime
						TryDeleteGui(k)
					}
				} else
					throw ValueError('无效的 showTime 值 "' (!IsSet(showTime) ? "未设置" : IsObject(showTime) ? "{对象}" : showTime) '"', -1)
				return
			}
		}
	} else { ; 如果未设置 x（例如 Highlight()），则删除所有高亮
		for k, v in timers
			SetTimer(v, 0)
		for k, v in guis
			v.Destroy()
		guis := Map(), timers := Map()
		return
	}
	
	if (showTime := showTime ?? 2000) = "clear"
		return
	else if !IsInteger(showTime)
		throw ValueError('无效的 showTime 值 "' (!IsSet(showTime) ? "未设置" : IsObject(showTime) ? "{对象}" : showTime) '"', -1)

	; 否则这是一个新的高亮
	loc := {x:x, y:y, w:w, h:h}
	guis[loc] := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08000000")
	GuiObj := guis[loc]
	GuiObj.BackColor := color
	iw:= w+d, ih:= h+d, w:=w+d*2, h:=h+d*2, x:=x-d, y:=y-d
	WinSetRegion("0-0 " w "-0 " w "-" h " 0-" h " 0-0 " d "-" d " " iw "-" d " " iw "-" ih " " d "-" ih " " d "-" d, GuiObj.Hwnd)
	GuiObj.Show("NA x" . x . " y" . y . " w" . w . " h" . h)

	if showTime > 0 {
		Sleep(showTime)
		TryDeleteGui(loc)
	} else if showTime < 0
		SetTimer(timers[loc] := Highlight.Bind(loc.x,loc.y,loc.w,loc.h), showTime)

	TryRemoveTimer(key) {
		if timers.Has(key)
			SetTimer(timers[key], 0), timers.Delete(key)
	}
	TryDeleteGui(key) {
		if guis.Has(key)
			guis[key].Destroy(), guis.Delete(key)
	}
}

/**
 * 在某一点闪烁彩色高亮提示，持续 2 秒。
 * @param x 高亮的屏幕 X 坐标
 *     省略 x 或 y 时，高亮当前光标位置。
 * @param y 高亮的屏幕 Y 坐标
 * @param color1 高亮的第一种颜色，默认为红色。
 * @param color2 高亮的第二种颜色，默认为蓝色。
 * @param d 高亮边框的厚度（像素）。默认为 2。
 */
MouseTip(x?, y?, color1:="red", color2:="blue", d:=4) {
	If !(IsSet(x) && IsSet(y))
		MouseGetPos(&x, &y)
	Loop 2 {
		Highlight(x-10, y-10, 20, 20, 500, color1, d)
		Highlight(x-10, y-10, 20, 20, 500, color2, d)
	}
	Highlight()
}

/**
 * 返回屏幕坐标 X 和 Y 处的窗口 ID。
 * @param X 点的屏幕 X 坐标
 * @param Y 点的屏幕 Y 坐标
 */
WindowFromPoint(X, Y) { ; by SKAN and Linear Spoon
	return DllCall("GetAncestor", "ptr", DllCall("user32.dll\WindowFromPoint", "Int64", Y << 32 | X, "ptr"), "UInt", 2)
}

/**
 * 在屏幕、窗口和客户区之间转换坐标。
 * @param X 要转换的 X 坐标
 * @param Y 要转换的 Y 坐标
 * @param outX 存储转换后的 X 坐标的变量
 * @param outY 存储转换后的 Y 坐标的变量
 * @param relativeFrom 转换来源的 CoordMode，默认为 A_CoordModeMouse。
 * @param relativeTo 转换目标的 CoordMode，默认为 Screen。
 * @param winTitle 标识目标窗口的窗口标题或其他条件。
 * @param winText 如果存在，此参数必须是目标窗口的单个文本元素的子字符串。
 * @param excludeTitle 不考虑包含此值的窗口标题。
 * @param excludeText 不考虑包含此值的窗口文本。
 */
ConvertCoords(X, Y, &outX, &outY, relativeFrom:="", relativeTo:="screen", winTitle?, winText?, excludeTitle?, excludeText?) {
	relativeFrom := relativeFrom || A_CoordModeMouse
	if relativeFrom = relativeTo {
		outX := X, outY := Y
		return
	}
	hWnd := WinExist(winTitle?, winText?, excludeTitle?, excludeText?)

	switch relativeFrom, 0 {
		case "screen", "s":
			if relativeTo = "window" || relativeTo = "w" {
				DllCall("user32\GetWindowRect", "Int", hWnd, "Ptr", RECT := Buffer(16))
				outX := X-NumGet(RECT, 0, "Int"), outY := Y-NumGet(RECT, 4, "Int")
			} else { 
				; 屏幕到客户区
				pt := Buffer(8), NumPut("int",X,pt), NumPut("int",Y,pt,4)
				DllCall("ScreenToClient", "Int", hWnd, "Ptr", pt)
				outX := NumGet(pt,0,"int"), outY := NumGet(pt,4,"int")
			}
		case "window", "w":
			; 窗口到屏幕
			WinGetPos(&outX, &outY,,,hWnd)
			outX += X, outY += Y
			if relativeTo = "client" || relativeTo = "c" {
				; 屏幕到客户区
				pt := Buffer(8), NumPut("int",outX,pt), NumPut("int",outY,pt,4)
				DllCall("ScreenToClient", "ptr", hWnd, "Ptr", pt)
				outX := NumGet(pt,0,"int"), outY := NumGet(pt,4,"int")
			}
		case "client", "c":
			; 客户区到屏幕
			pt := Buffer(8), NumPut("int",X,pt), NumPut("int",Y,pt,4)
			DllCall("ClientToScreen", "ptr", hWnd, "Ptr", pt)
			outX := NumGet(pt,0,"int"), outY := NumGet(pt,4,"int")
			if relativeTo = "window" || relativeTo = "w" { ; 屏幕到窗口
				DllCall("user32\GetWindowRect", "ptr", hWnd, "ptr", RECT := Buffer(16))
				outX -= NumGet(RECT, 0, "Int"), outY -= NumGet(RECT, 4, "Int")
			}
	}
}
ConvertWinPos(X, Y, &outX, &outY, relativeFrom:="", relativeTo:="screen", winTitle?, winText?, excludeTitle?, excludeText?) => ConvertCoords(X, Y, &outX, &outY, relativeFrom, relativeTo, winTitle?, winText?, excludeTitle?, excludeText?)

/**
 * 获取窗口信息（标题、进程名、位置等）
 * @param WinTitle 同 AHK 的 WinTitle
 * @param {number} Verbose 输出的详细程度（默认为 1）：
 *  0: 返回窗口标题、句柄、类名、进程名、PID、进程路径、屏幕位置、最小化/最大化信息、样式和扩展样式
 *  1: 另外返回透明色、透明度级别、文本（包括隐藏和非隐藏）、状态栏文本
 *  2: 另外返回所有控件的 ClassNN 名称
 * @param WinText 同 AHK 的 WinText
 * @param ExcludeTitle 同 AHK 的 ExcludeTitle
 * @param ExcludeText 同 AHK 的 ExcludeText
 * @param {string} Separator 换行字符
 * @returns {string} 返回信息字符串。
 * @example MsgBox(WinGetInfo("ahk_exe notepad.exe", 2))
 */
WinGetInfo(WinTitle:="", Verbose := 1, WinText:="", ExcludeTitle:="", ExcludeText:="", Separator := "`n") {
    if !(hWnd := WinExist(WinTitle, WinText, ExcludeTitle, ExcludeText))
        throw TargetError("未找到目标窗口！", -1)
    out := '标题: '
    try out .= '"' WinGetTitle(hWnd) '"' Separator
    catch
        out .= "#错误" Separator
    out .=  'ahk_id ' hWnd Separator
    out .= 'ahk_class '
    try out .= WinGetClass(hWnd) Separator
    catch
        out .= "#错误" Separator
    out .= 'ahk_exe '
    try out .= WinGetProcessName(hWnd) Separator
    catch
        out .= "#错误" Separator
    out .= 'ahk_pid '
    try out .= WinGetPID(hWnd) Separator
    catch
        out .= "#错误" Separator
    out .= '进程路径: '
    try out .= '"' WinGetProcessPath(hWnd) '"' Separator
    catch
        out .= "#错误" Separator
    out .= '屏幕位置: '
    try { 
        WinGetPos(&X, &Y, &W, &H, hWnd)
        out .= "x: " X " y: " Y " w: " W " h: " H Separator
    } catch
        out .= "#错误" Separator
    out .= '最小化/最大化: '
    try out .= ((minmax := WinGetMinMax(hWnd)) = 1 ? "最大化" : minmax = -1 ? "最小化" : "正常") Separator
    catch
        out .= "#错误" Separator

    static Styles := Map("WS_OVERLAPPED", 0x00000000, "WS_POPUP", 0x80000000, "WS_CHILD", 0x40000000, "WS_MINIMIZE", 0x20000000, "WS_VISIBLE", 0x10000000, "WS_DISABLED", 0x08000000, "WS_CLIPSIBLINGS", 0x04000000, "WS_CLIPCHILDREN", 0x02000000, "WS_MAXIMIZE", 0x01000000, "WS_CAPTION", 0x00C00000, "WS_BORDER", 0x00800000, "WS_DLGFRAME", 0x00400000, "WS_VSCROLL", 0x00200000, "WS_HSCROLL", 0x00100000, "WS_SYSMENU", 0x00080000, "WS_THICKFRAME", 0x00040000, "WS_GROUP", 0x00020000, "WS_TABSTOP", 0x00010000, "WS_MINIMIZEBOX", 0x00020000, "WS_MAXIMIZEBOX", 0x00010000, "WS_TILED", 0x00000000, "WS_ICONIC", 0x20000000, "WS_SIZEBOX", 0x00040000, "WS_OVERLAPPEDWINDOW", 0x00CF0000, "WS_POPUPWINDOW", 0x80880000, "WS_CHILDWINDOW", 0x40000000, "WS_TILEDWINDOW", 0x00CF0000, "WS_ACTIVECAPTION", 0x00000001, "WS_GT", 0x00030000)
    , ExStyles := Map("WS_EX_DLGMODALFRAME", 0x00000001, "WS_EX_NOPARENTNOTIFY", 0x00000004, "WS_EX_TOPMOST", 0x00000008, "WS_EX_ACCEPTFILES", 0x00000010, "WS_EX_TRANSPARENT", 0x00000020, "WS_EX_MDICHILD", 0x00000040, "WS_EX_TOOLWINDOW", 0x00000080, "WS_EX_WINDOWEDGE", 0x00000100, "WS_EX_CLIENTEDGE", 0x00000200, "WS_EX_CONTEXTHELP", 0x00000400, "WS_EX_RIGHT", 0x00001000, "WS_EX_LEFT", 0x00000000, "WS_EX_RTLREADING", 0x00002000, "WS_EX_LTRREADING", 0x00000000, "WS_EX_LEFTSCROLLBAR", 0x00004000, "WS_EX_CONTROLPARENT", 0x00010000, "WS_EX_STATICEDGE", 0x00020000, "WS_EX_APPWINDOW", 0x00040000, "WS_EX_OVERLAPPEDWINDOW", 0x00000300, "WS_EX_PALETTEWINDOW", 0x00000188, "WS_EX_LAYERED", 0x00080000, "WS_EX_NOINHERITLAYOUT", 0x00100000, "WS_EX_NOREDIRECTIONBITMAP", 0x00200000, "WS_EX_LAYOUTRTL", 0x00400000, "WS_EX_COMPOSITED", 0x02000000, "WS_EX_NOACTIVATE", 0x08000000)
    out .= '样式: '
    try {
        out .= (style := WinGetStyle(hWnd)) " ("
        for k, v in Styles {
            if v && style & v {
                out .= k " | "
                style &= ~v
            }
        }
        out := RTrim(out, " |")
        if style
            out .= (SubStr(out, -1, 1) = "(" ? "" : ", ") "未知枚举: " style
        out .= ")" Separator
    } catch
        out .= "#错误" Separator

        out .= '扩展样式: '
        try {
            out .= (style := WinGetExStyle(hWnd)) " ("
            for k, v in ExStyles {
                if v && style & v {
                    out .= k " | "
                    style &= ~v
                }
            }
            out := RTrim(out, " |")
            if style
                out .= (SubStr(out, -1, 1) = "(" ? "" : ", ") "未知枚举: " style
            out .= ")" Separator
        } catch
            out .= "#错误" Separator

    
    if Verbose {
        out .= '透明色: '
        try out .= WinGetTransColor(hWnd) Separator
        catch
            out .= "#错误" Separator
        out .= '透明度: '
        try out .= WinGetTransparent(hWnd) Separator
        catch
            out .= "#错误" Separator

        PrevDHW := DetectHiddenText(0)
        out .= '文本 (DetectHiddenText 关闭): '
        try out .= '"' WinGetText(hWnd) '"' Separator
        catch
            out .= "#错误" Separator
        DetectHiddenText(1)
        out .= '文本 (DetectHiddenText 开启): '
        try out .= '"' WinGetText(hWnd) '"' Separator
        catch
            out .= "#错误" Separator
        DetectHiddenText(PrevDHW)

        out .= '状态栏文本: '
        try out .= '"' StatusBarGetText(1, hWnd) '"' Separator
        catch
            out .= "#错误" Separator
    }
    if Verbose > 1 {
        out .= '控件 (ClassNN): ' Separator
        try {
            for ctrl in WinGetControls(hWnd)
                out .= '`t' ctrl Separator
        } catch
            out .= "#错误" Separator
    }
    return SubStr(out, 1, -StrLen(Separator))
}

/**
 * 等待符合指定条件的新窗口实例。
 * 参数格式与 WinWait 相同。
 * @example
 * w := WinWaitNew("ahk_exe chrome.exe")
 * Run "chrome.exe"
 * w()
 * MsgBox "找到 Chrome"
 * @returns {Integer} 
 */
class WinWaitNew {
    Tick := 1
    __New(WinTitle:="", WinText:="", TimeOut:="", ExcludeTitle:="", ExcludeText:="") {
        local hWnd, hWnds
		this.hWnds := hWnds := Map(), this.TimeOut := TimeOut="" ? 0x7FFFFFFFFFFFFFFF : A_TickCount+1000*TimeOut
        this.WinTitle := WinTitle, this.WinText := WinText, this.ExcludeTitle := ExcludeTitle, this.ExcludeText := ExcludeText
		for hWnd in WinGetList(WinTitle, WinText, ExcludeTitle, ExcludeText)
			hWnds[hWnd] := 1
    }
    Call() {
        local hWnd
        while this.TimeOut > A_TickCount {
            for hWnd in WinGetList(this.WinTitle, this.WinText, this.ExcludeTitle, this.ExcludeText)
                if !this.hWnds.Has(hWnd)
                    return hWnd
            Sleep this.Tick
        }
        throw TimeoutError("超时", -1)
    }
}

/**
 * 使用 UIA、Acc、Java Access Bridge 或 CaretGetPos 获取光标位置。
 * 致谢: plankoe (https://www.reddit.com/r/AutoHotkey/comments/ysuawq/get_the_caret_location_in_any_program/)
 * @param X 设置为光标的屏幕 X 坐标
 * @param Y 设置为光标的屏幕 Y 坐标
 * @param W 设置为光标的宽度
 * @param H 设置为光标的高度
 */
GetCaretPos(&X?, &Y?, &W?, &H?) {
	/*
		此实现优先使用 CaretGetPos > Acc > JAB > UIA。这主要是由于方法之间的速度差异，
		并且统计上似乎最不可能需要 UIA 方法（Chromium 应用程序也支持 Acc）。
	*/
    ; 默认光标
    savedCaret := A_CoordModeCaret
    CoordMode "Caret", "Screen"
    CaretGetPos(&X, &Y)
    CoordMode "Caret", savedCaret
	if IsInteger(X) && (X | Y) != 0 {
		W := 4, H := 20
		return
	}

    ; Acc 光标
    static _ := DllCall("LoadLibrary", "Str","oleacc", "Ptr")
    try {
        idObject := 0xFFFFFFF8 ; OBJID_CARET
        if DllCall("oleacc\AccessibleObjectFromWindow", "ptr", WinExist("A"), "uint",idObject &= 0xFFFFFFFF
            , "ptr",-16 + NumPut("int64", idObject == 0xFFFFFFF0 ? 0x46000000000000C0 : 0x719B3800AA000C81, NumPut("int64", idObject == 0xFFFFFFF0 ? 0x0000000000020400 : 0x11CF3C3D618736E0, IID := Buffer(16)))
            , "ptr*", oAcc := ComValue(9,0)) = 0 {
            x:=Buffer(4), y:=Buffer(4), w:=Buffer(4), h:=Buffer(4)
            oAcc.accLocation(ComValue(0x4003, x.ptr, 1), ComValue(0x4003, y.ptr, 1), ComValue(0x4003, w.ptr, 1), ComValue(0x4003, h.ptr, 1), 0)
            X:=NumGet(x,0,"int"), Y:=NumGet(y,0,"int"), W:=NumGet(w,0,"int"), H:=NumGet(h,0,"int")
            if (X | Y) != 0
                return
        }
    }


	static JAB := InitJAB() ; Source: https://github.com/Elgin1/Java-Access-Bridge-for-AHK
	if JAB && (hWnd := WinExist("A")) && DllCall(JAB.module "\isJavaWindow", "ptr", hWnd, "CDecl Int") {
		if JAB.firstRun
			Sleep(200), JAB.firstRun := 0
		prevThreadDpiAwarenessContext := DllCall("SetThreadDpiAwarenessContext", "ptr", -2, "ptr")
		DllCall(JAB.module "\getAccessibleContextWithFocus", "ptr", hWnd, "Int*", &vmID:=0, JAB.acType "*", &ac:=0, "Cdecl Int") "`n"
		DllCall(JAB.module "\getCaretLocation", "Int", vmID, JAB.acType, ac, "Ptr", Info := Buffer(16,0), "Int", 0, "Cdecl Int")
		DllCall(JAB.module "\releaseJavaObject", "Int", vmId, JAB.acType, ac, "CDecl")
		DllCall("SetThreadDpiAwarenessContext", "ptr", prevThreadDpiAwarenessContext, "ptr")
		X := NumGet(Info, 0, "Int"), Y := NumGet(Info, 4, "Int"), W := NumGet(Info, 8, "Int"), H := NumGet(Info, 12, "Int")
		hMonitor := DllCall("MonitorFromWindow", "ptr", hWnd, "int", 2, "ptr") ; MONITOR_DEFAULTTONEAREST
    	DllCall("Shcore.dll\GetDpiForMonitor", "ptr", hMonitor, "int", 0, "uint*", &dpiX:=0, "uint*", &dpiY:=0)
		if dpiX
			X := DllCall("MulDiv", "int", X, "int", dpiX, "int", 96, "int"), Y := DllCall("MulDiv", "int", Y, "int", dpiX, "int", 96, "int")
		if X || Y || W || H
			return
	}

    ; UIA caret
    static IUIA := ComObject("{e22ad333-b25f-460c-83d0-0581107395c9}", "{34723aff-0c9d-49d0-9896-7ab52df8cd8a}")
    try {
        ComCall(8, IUIA, "ptr*", &FocusedEl:=0) ; GetFocusedElement
		/*
			The current implementation uses only TextPattern GetSelections and not TextPattern2 GetCaretRange.
			This is because TextPattern2 is less often supported, or sometimes reports being implemented
			but in reality is not. The only downside to using GetSelections is that when text
			is selected then caret position is ambiguous. Nevertheless, in those cases it most
			likely doesn't matter much whether the caret is in the beginning or end of the selection.

			If GetCaretRange is needed then the following code implements that:
			ComCall(16, FocusedEl, "int", 10024, "ptr*", &patternObject:=0), ObjRelease(FocusedEl) ; GetCurrentPattern. TextPattern2 = 10024
			if patternObject {
				ComCall(10, patternObject, "int*", &IsActive:=1, "ptr*", &caretRange:=0), ObjRelease(patternObject) ; GetCaretRange
				ComCall(10, caretRange, "ptr*", &boundingRects:=0), ObjRelease(caretRange) ; GetBoundingRectangles
				if (Rect := ComValue(0x2005, boundingRects)).MaxIndex() = 3 { ; VT_ARRAY | VT_R8
					X:=Round(Rect[0]), Y:=Round(Rect[1]), W:=Round(Rect[2]), H:=Round(Rect[3])
					return
				}
			}
		*/
        ComCall(16, FocusedEl, "int", 10014, "ptr*", &patternObject:=0), ObjRelease(FocusedEl) ; GetCurrentPattern. TextPattern = 10014
        if patternObject {
            ComCall(5, patternObject, "ptr*", &selectionRanges:=0), ObjRelease(patternObject) ; GetSelections
			ComCall(4, selectionRanges, "int", 0, "ptr*", &selectionRange:=0) ; GetElement
			ComCall(6, selectionRange, "int", 0) ; ExpandToEnclosingUnit = Character
            ComCall(10, selectionRange, "ptr*", &boundingRects:=0), ObjRelease(selectionRange), ObjRelease(selectionRanges) ; GetBoundingRectangles
            if (Rect := ComValue(0x2005, boundingRects)).MaxIndex() = 3 { ; VT_ARRAY | VT_R8
                X:=Round(Rect[0]), Y:=Round(Rect[1]), W:=Round(Rect[2]), H:=Round(Rect[3])
                return
            }
        }
    }

	InitJAB() {
		ret := {}, ret.firstRun := 1, ret.module := A_PtrSize = 8 ? "WindowsAccessBridge-64.dll" : "WindowsAccessBridge-32.dll", ret.acType := "Int64"
		ret.DefineProp("__Delete", {call: (this) => DllCall("FreeLibrary", "ptr", this)})
		if !(ret.ptr := DllCall("LoadLibrary", "Str", ret.module, "ptr")) && A_PtrSize = 4 {
			 ; try legacy, available only for 32-bit
			 ret.acType := "Int", ret.module := "WindowsAccessBridge.dll", ret.ptr := DllCall("LoadLibrary", "Str", ret.module, "ptr")
		}
		if !ret.ptr
			return ; Failed to load library. Make sure you are running the script in the correct bitness and/or Java for the architecture is installed.
		DllCall(ret.module "\Windows_run", "Cdecl Int")
		return ret
	}
}

/**
 * 检查两个矩形是否相交，如果相交，则返回一个包含相交矩形信息的对象：{l:left, t:top, r:right, b:bottom}
 * 注意 1：重叠区域必须至少为 1 个单位。
 * 注意 2：第二个矩形从第一个矩形的边缘开始不算作相交：
 *     {l:100, t:100, r:200, b:200} 不与 {l:200, t:100, 400, 400} 相交
 * @param l1 第一个矩形左上角的 x 坐标
 * @param t1 第一个矩形左上角的 y 坐标
 * @param r1 第一个矩形右下角的 x 坐标
 * @param b1 第一个矩形右下角的 y 坐标
 * @param l2 第二个矩形左上角的 x 坐标
 * @param t2 第二个矩形左上角的 y 坐标
 * @param r2 第二个矩形右下角的 x 坐标
 * @param b2 第二个矩形右下角的 y 坐标
 * @returns {Object}
 */
IntersectRect(l1, t1, r1, b1, l2, t2, r2, b2) {
	rect1 := Buffer(16), rect2 := Buffer(16), rectOut := Buffer(16)
	NumPut("int", l1, "int", t1, "int", r1, "int", b1, rect1)
	NumPut("int", l2, "int", t2, "int", r2, "int", b2, rect2)
	if DllCall("user32\IntersectRect", "Ptr", rectOut, "Ptr", rect1, "Ptr", rect2)
		return {l:NumGet(rectOut, 0, "Int"), t:NumGet(rectOut, 4, "Int"), r:NumGet(rectOut, 8, "Int"), b:NumGet(rectOut, 12, "Int")}
}

/**
 * 获取窗口的位置、大小和偏移量。更多信息请参见 *备注* 部分。
 * 来源：https://www.autohotkey.com/boards/viewtopic.php?f=6&t=3392
 * 额外致谢：原始创意和部分代码来自 *KaFu* (AutoIt 论坛)
 * @param WinTitle 目标窗口标题或句柄
 * @param X 可选：包含窗口的屏幕 x 坐标
 * @param Y 可选：包含窗口的屏幕 y 坐标
 * @param Width 可选：包含窗口的宽度
 * @param Height 可选：包含窗口的高度
 * @param LeftBorder 可选：左侧不可见边框的厚度
 * @param TopBorder 可选：顶部不可见边框的厚度
 * @param RightBorder 可选：右侧不可见边框的厚度
 * @param BottomBorder 可选：底部不可见边框的厚度
 * @returns {Integer} 如果失败返回 0，否则返回窗口句柄
 * 
 * 备注：
 * 
 * 从 Windows Vista 开始，微软引入了桌面窗口管理器（DWM）
 * 以及使用 DWM 的 Aero 主题。Aero 主题提供了新的功能，例如半透明的玻璃设计和微妙的窗口动画。
 * 不幸的是，DWM 并不总是遵循操作系统关于窗口大小和定位的规则。如果使用 Aero 主题，许多窗口的实际大小
 * 比通过标准命令（例如：WinGetPos, GetWindowRect 等）报告的要大，因此在使用标准命令（例如：Gui.Show, WinMove 等）
 * 时无法正确定位窗口。此函数的创建目的是 1) 无论窗口属性、桌面主题或 Windows 版本如何，都能识别所有窗口的真实位置和大小，
 * 以及 2) 确定如果窗口大小与报告的大小不同时所需的适当偏移量。
 * 
 * 在窗口渲染之前，无法确定窗口的真实大小、位置和偏移量。请参阅示例脚本，了解如何使用此函数定位新窗口。
 */
WinGetPosEx(WinTitle:="", &X := "", &Y := "", &Width := "", &Height := "", &LeftBorder := 0, &TopBorder := 0, &RightBorder := 0, &BottomBorder := 0) {
	static S_OK := 0x0, DWMWA_EXTENDED_FRAME_BOUNDS := 9
	local RECT := Buffer(16, 0), RECTPlus := Buffer(24,0), R, B
	if !(WinTitle is Integer)
		WinTitle := WinGetID(WinTitle)
	DllCall("GetWindowRect", "Ptr", WinTitle, "Ptr", RECT)
	try DWMRC := DllCall("dwmapi\DwmGetWindowAttribute", "Ptr",  WinTitle, "UInt", DWMWA_EXTENDED_FRAME_BOUNDS, "Ptr", RECTPlus, "UInt", 16, "UInt")
	catch
	   return 0
	X := NumGet(RECTPlus, 0, "Int"), LeftBorder := X - NumGet(RECT, 0, "Int")
	Y := NumGet(RECTPlus, 4, "Int"), TopBorder := Y - NumGet(RECT, 4, "Int")
	R := NumGet(RECTPlus, 8, "Int"), RightBorder := NumGet(RECT,  8, "Int") - R
	B := NumGet(RECTPlus, 12, "Int"), BottomBorder := NumGet(RECT,  12, "Int") - B
	Width := R - X
	Height := B - Y
	return WinTitle
}

/**
 * 根据窗口的视觉属性移动窗口（调整不可见边框）。
 * @param X 如果省略，则不更改 X 维度的位置。否则，指定目标窗口新位置左上角的 X 坐标（以像素为单位）。
 * 屏幕的左上角像素位于 0, 0。
 * @param Y 如果省略，则不更改 Y 维度的位置。否则，指定目标窗口新位置左上角的 Y 坐标（以像素为单位）。
 * 屏幕的左上角像素位于 0, 0。
 * @param Width 如果省略，则不更改宽度。否则，指定窗口的新宽度（以像素为单位）。
 * @param Height 如果省略，则不更改高度。否则，指定窗口的新高度（以像素为单位）。
 * @param WinTitle WinTitle，与普通的 WinMove 相同
 * @param WinText 与普通的 WinMove 相同
 * @param ExcludeTitle 与普通的 WinMove 相同
 * @param ExcludeText 与普通的 WinMove 相同
 */
WinMoveEx(X?, Y?, Width?, Height?, WinTitle?, WinText?, ExcludeTitle?, ExcludeText?) {
	WinGetPosEx(hWnd := WinGetID(WinTitle?, WinText?, ExcludeTitle?, ExcludeText?),,,,, &LeftBorder := 0, &TopBorder := 0, &RightBorder := 0, &BottomBorder := 0)
	if IsSet(X)
		X -= LeftBorder
	if IsSet(Y)
		Y -= TopBorder
	if IsSet(Width)
		Width += LeftBorder + RightBorder
	if IsSet(Height)
		Height += TopBorder + BottomBorder
	return WinMove(X?, Y?, Width?, Height?, hWnd)
}