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
        buf := Buffer(CFG.HashChunk)
        rem := f.Length
        while rem > 0 {
            n := f.RawRead(buf, rem > CFG.HashChunk ? CFG.HashChunk : rem)
            if n <= 0
                break
            DllCall("bcrypt\BCryptHashData", "Ptr", hH, "Ptr", buf, "UInt", n, "UInt", 0, "UInt")
            rem -= n
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
