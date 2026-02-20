; ============================================================
;  lib/Hash.ahk — SHA-256 해시 (BCrypt DLL)
;  의존: Globals.ahk (CFG.HashChunk)
;  외부: bcrypt.dll
; ============================================================

SHA256(filePath) {
    static OK := 0
    try {
        f := FileOpen(filePath, "r")
        if !f
        return ""
        if DllCall("bcrypt\BCryptOpenAlgorithmProvider"
            , "Ptr*", &hA := 0, "Str", "SHA256", "Ptr", 0, "UInt", 0, "UInt") != OK {
            f.Close()
            return ""
        }
        if DllCall("bcrypt\BCryptCreateHash"
            , "Ptr", hA, "Ptr*", &hH := 0
            , "Ptr", 0, "UInt", 0, "Ptr", 0, "UInt", 0, "UInt", 0, "UInt") != OK {
            DllCall("bcrypt\BCryptCloseAlgorithmProvider", "Ptr", hA, "UInt", 0)
            f.Close()
            return ""
        }
        buf       := Buffer(CFG.HashChunk)
        fLen      := f.Length
        halfChunk := CFG.HashChunk // 2   ; 512KB

        if fLen <= CFG.HashChunk {
            ; ── 소형 파일 (≤1MB): 전체 해시 ───────────────────────────
            rem := fLen
            while rem > 0 {
                n := f.RawRead(buf, rem)
                if n <= 0
                    break
                DllCall("bcrypt\BCryptHashData", "Ptr", hH, "Ptr", buf, "UInt", n, "UInt", 0, "UInt")
                rem -= n
            }
        } else {
            ; ── 대형 파일 (>1MB): 앞 512KB + 뒤 512KB 해시 ──────────
            ; 파일 앞부분만 해싱할 경우 앞부분이 동일한 파일이 오매칭될 수 있으므로
            ; 파일 끝부분도 함께 해시에 포함하여 구분력을 높임.
            ; 앞 512KB
            rem := halfChunk
            while rem > 0 {
                n := f.RawRead(buf, rem)
                if n <= 0
                    break
                DllCall("bcrypt\BCryptHashData", "Ptr", hH, "Ptr", buf, "UInt", n, "UInt", 0, "UInt")
                rem -= n
            }
            ; 뒤 512KB (파일 끝에서 halfChunk 이전 지점으로 이동)
            f.Pos := fLen - halfChunk
            rem   := halfChunk
            while rem > 0 {
                n := f.RawRead(buf, rem)
                if n <= 0
                    break
                DllCall("bcrypt\BCryptHashData", "Ptr", hH, "Ptr", buf, "UInt", n, "UInt", 0, "UInt")
                rem -= n
            }
        }
        f.Close()
        hb := Buffer(32, 0)
        DllCall("bcrypt\BCryptFinishHash",  "Ptr", hH, "Ptr", hb, "UInt", 32, "UInt", 0, "UInt")
        DllCall("bcrypt\BCryptDestroyHash", "Ptr", hH)
        DllCall("bcrypt\BCryptCloseAlgorithmProvider", "Ptr", hA, "UInt", 0)
        hex := ""
        Loop 32
            hex .= Format("{:02x}", NumGet(hb, A_Index - 1, "UChar"))
        return hex
    } catch as e {
        OutputDebug("[ERR] SHA256 " filePath " " e.Message "`n")
        return ""
    }
}
