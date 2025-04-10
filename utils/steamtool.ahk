#SingleInstance Force

class SteamTool {
	; 辅助函数：从文件创建 IStream 对象
	static CreateIconStream(filePath) {
		; 确保文件存在
		if (!FileExist(filePath)) {
			MsgBox "Icon file does not exist: " filePath
			return 0
		}

		; 读取图标文件到内存
		file := FileOpen(filePath, "r")
		if (!file) {
			MsgBox "Failed to open icon file: " filePath
			return 0
		}

		; 获取文件大小
		fileSize := file.Length
		if (fileSize = 0) {
			MsgBox "Icon file is empty: " filePath
			file.Close()
			return 0
		}

		; 初始化 iconBuffer 为 0
		iconBuffer := 0

		; 创建缓冲区
		try {
			iconBuffer := Buffer(fileSize, 0)  ; 使用 Buffer 类构造函数
		} catch as e {
			MsgBox "Failed to create buffer: " e.Message
			file.Close()
			return 0
		}

		; 读取文件内容
		try {
			bytesRead := file.RawRead(iconBuffer, fileSize)
			if (bytesRead != fileSize) {
				MsgBox "Failed to read entire icon file. Expected " fileSize " bytes, but read " bytesRead " bytes."
				file.Close()
				return 0
			}
		} catch as e {
			MsgBox "Failed to read icon file: " e.Message
			file.Close()
			return 0
		}
		file.Close()

		; 确保 iconBuffer 已赋值
		if (!iconBuffer) {
			MsgBox "Buffer is not assigned after reading file."
			return 0
		}

		; 创建全局内存句柄
		hGlobal := DllCall("GlobalAlloc", "uint", 0x0002, "uint", fileSize, "ptr")  ; GMEM_MOVEABLE
		if (!hGlobal) {
			MsgBox "Failed to allocate global memory"
			return 0
		}

		; 锁定内存并复制数据
		pGlobal := DllCall("GlobalLock", "ptr", hGlobal, "ptr")
		DllCall("RtlMoveMemory", "ptr", pGlobal, "ptr", iconBuffer.Ptr, "uint", fileSize)
		DllCall("GlobalUnlock", "ptr", hGlobal)

		; 创建 IStream 对象
		stream := 0
		hr := DllCall("Ole32\CreateStreamOnHGlobal", "ptr", hGlobal, "int", 1, "ptr*", &stream, "uint")
		if (hr != 0) {
			MsgBox "Failed to create IStream: " hr
			DllCall("GlobalFree", "ptr", hGlobal)
			return 0
		}

		return stream
	}
}