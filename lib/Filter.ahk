; ============================================================
;  lib/Filter.ahk — 파일/폴더 제외 판정 + 키워드 매칭
;  의존: Globals.ahk (FILT 참조)
; ============================================================

_MatchesKeyword(folderName, kwArray) {
    if kwArray.Length = 0
        return false
    fn := StrLower(folderName)
    for kw in kwArray {
        if InStr(fn, kw)
            return true
    }
    return false
}

IsExcludedDir(folderName) {
    if FILT.DirPatterns.Length = 0
        return false
    s := FILT.IgnoreCase ? StrLower(folderName) : folderName
    for pat in FILT.DirPatterns {
        p := FILT.IgnoreCase ? StrLower(pat) : pat
        if FILT.UseRegex {
            try {
                if RegExMatch(s, p)
                    return true
            }
        } else {
            if _WildMatch(s, p)
                return true
        }
    }
    return false
}

IsExcludedPath(fullPath) {
    if FILT.DirPatterns.Length = 0
        return false
    for seg in StrSplit(fullPath, "\") {
        if seg = ""
            continue
        if IsExcludedDir(seg)
            return true
    }
    return false
}

IsExcluded(name, dirPath := "") {
    if FILT.Patterns.Length > 0 {
        n := FILT.IgnoreCase ? StrLower(name) : name
        for pat in FILT.Patterns {
            p := FILT.IgnoreCase ? StrLower(pat) : pat
            if FILT.UseRegex {
                try {
                    if RegExMatch(n, p)
                        return true
                }
            } else {
                if _WildMatch(n, p)
                    return true
            }
        }
    }
    if dirPath != ""
        return IsExcludedPath(dirPath)
    return false
}

_WildMatch(str, pat) {
    if !InStr(pat, "*") && !InStr(pat, "?")
        return InStr(str, pat) > 0
    rx := "^"
    Loop Parse, pat {
        if A_LoopField = "*"
            rx .= ".*"
        else if A_LoopField = "?"
            rx .= "."
        else
            rx .= "\Q" A_LoopField "\E"
    }
    rx .= "$"
    return RegExMatch(str, FILT.IgnoreCase ? "i)" rx : rx)
}
