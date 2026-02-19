; ============================================================
;  lib/PathUtil.ahk — 경로 유틸리티
;  독립적 헬퍼 함수들 (외부 전역변수 참조 없음)
; ============================================================

CleanPath(raw) {
    p := Trim(raw, ' "' "`t`r`n")
    p := RTrim(p, "\")
    p := RTrim(p, " ")
    if !p
        return ""
    if DirExist(p)
        return p
    Loop Files, p, "D" {
        return A_LoopFilePath
    }
    if FileExist(p) {
        SplitPath(p, , &dir)
        if dir && DirExist(dir)
            return RTrim(dir, "\")
    }
    parts := StrSplit(p, "\")
    while parts.Length > 1 {
        test := ""
        for i, seg in parts {
            cleaned := RTrim(seg, " ")
            test .= (i > 1 ? "\" : "") cleaned
        }
        if DirExist(test)
            return test
        parts.Pop()
    }
    return ""
}

JoinStr(arr, sep) {
    s := ""
    for i, v in arr
        s .= (i > 1 ? sep : "") v
    return s
}

RelPath(full, root) {
    n := StrLen(root)
    return SubStr(full, 1, n) = root ? SubStr(full, n + 2) : full
}

AlbumNum(rel) {
    p := StrSplit(rel, "\")
    if p.Length < 1
        return "?"
    seg := p[1]
    if RegExMatch(seg, "^\d{1,2}$")
        return Format("{:02}", Integer(seg))
    if seg != ""
        return seg
    return "?"
}

FormatTime_ms(ms) {
    s := Integer(ms / 1000)
    return Format("{:02d}:{:02d}", Integer(s // 60), Integer(Mod(s, 60)))
}

Max(a, b) => a > b ? a : b
Min(a, b) => a < b ? a : b
