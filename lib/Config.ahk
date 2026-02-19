; ============================================================
;  lib/Config.ahk — settings.ini 로드/저장 + 패턴 파싱
;  의존: Globals.ahk
; ============================================================

LoadFilterSettings() {
    ini := SETTINGS_INI
    if !FileExist(ini) {
        FILT.RawText     := "Thumbs.db`ndesktop.ini`n._*`n~$*`n*.tmp"
        FILT.DirRawText  := "설명서"
        FILT.FrameKWText := ""
        FILT.AlbumKWText := "표지`n가족사진"
        FILT.IgnoreCase  := true
        FILT.UseRegex    := false
        ST.AutoSelectAllFrames := false
        _ParsePatterns()
        SaveFilterSettings()
        return
    }
    FILT.RawText     := StrReplace(IniRead(ini, "Filter",   "Patterns",      ""), "||", "`n")
    FILT.DirRawText  := StrReplace(IniRead(ini, "Filter",   "DirPatterns",   ""), "||", "`n")
    FILT.FrameKWText := StrReplace(IniRead(ini, "Classify", "FrameKeywords", ""), "||", "`n")
    FILT.AlbumKWText := StrReplace(IniRead(ini, "Classify", "AlbumKeywords", ""), "||", "`n")
    FILT.IgnoreCase  := IniRead(ini, "Filter", "IgnoreCase", 1) + 0
    FILT.UseRegex    := IniRead(ini, "Filter", "UseRegex",   0) + 0
    ST.AutoSelectAllFrames := IniRead(ini, "Scan", "AutoSelectAllFrames", 0) + 0
    _ParsePatterns()
}

; ============================================================
;  UI 레이아웃(스플리터) 설정 로드/저장
;  - LeftPanelWidth : SIDE_W (좌/우 분리선 — 드래그 가능)
;  - RightOrigWidth : 제거됨 (FIXED_50 고정으로 대체 — ini 저장 안 함)
; ============================================================

LoadUiSettings() {
    global SIDE_W
    ini := SETTINGS_INI
    if !FileExist(ini)
        return
    try SIDE_W := Integer(IniRead(ini, "UI", "LeftPanelWidth", SIDE_W) + 0)
}

SaveUiSettings() {
    global SIDE_W
    ini := SETTINGS_INI
    IniWrite(Integer(SIDE_W), ini, "UI", "LeftPanelWidth")
}

; ============================================================
;  ListView 컬럼 폭 로드/저장
;  섹션: [ListView]  키: ColWidths=c1,c2,c3,c4
; ============================================================

LoadLvColWidths() {
    global LV_COL_W
    ini := SETTINGS_INI
    if !FileExist(ini)
        return
    raw := IniRead(ini, "ListView", "ColWidths", "")
    if !raw
        return
    parts := StrSplit(raw, ",")
    if parts.Length != 4
        return
    try {
        arr := [Integer(parts[1]), Integer(parts[2]), Integer(parts[3]), Integer(parts[4])]
        for v in arr
            if v <= 0
                return   ; 값 이상 → 기본값 유지
        LV_COL_W := arr
    }
}

SaveLvColWidths() {
    IniWrite(LV_COL_W[1] "," LV_COL_W[2] "," LV_COL_W[3] "," LV_COL_W[4]
        , SETTINGS_INI, "ListView", "ColWidths")
}

SaveFilterSettings() {
    ini := SETTINGS_INI
    IniWrite(StrReplace(FILT.RawText,     "`n", "||"), ini, "Filter",   "Patterns")
    IniWrite(StrReplace(FILT.DirRawText,  "`n", "||"), ini, "Filter",   "DirPatterns")
    IniWrite(FILT.IgnoreCase ? 1 : 0,                  ini, "Filter",   "IgnoreCase")
    IniWrite(FILT.UseRegex   ? 1 : 0,                  ini, "Filter",   "UseRegex")
    IniWrite(StrReplace(FILT.FrameKWText, "`n", "||"), ini, "Classify", "FrameKeywords")
    IniWrite(StrReplace(FILT.AlbumKWText, "`n", "||"), ini, "Classify", "AlbumKeywords")
    IniWrite(ST.AutoSelectAllFrames ? 1 : 0, ini, "Scan", "AutoSelectAllFrames")
}

_ParsePatterns() {
    FILT.Patterns := []
    for line in StrSplit(FILT.RawText, "`n", "`r ") {
        line := Trim(line)
        if line = "" || SubStr(line, 1, 1) = "#"
            continue
        FILT.Patterns.Push(line)
    }
    FILT.DirPatterns := []
    for line in StrSplit(FILT.DirRawText, "`n", "`r ") {
        line := Trim(line)
        if line = "" || SubStr(line, 1, 1) = "#"
            continue
        FILT.DirPatterns.Push(line)
    }
    FILT.FrameKW := []
    for line in StrSplit(FILT.FrameKWText, "`n", "`r ") {
        line := Trim(line)
        if line = "" || SubStr(line, 1, 1) = "#"
            continue
        FILT.FrameKW.Push(StrLower(line))
    }
    FILT.AlbumKW := []
    for line in StrSplit(FILT.AlbumKWText, "`n", "`r ") {
        line := Trim(line)
        if line = "" || SubStr(line, 1, 1) = "#"
            continue
        FILT.AlbumKW.Push(StrLower(line))
    }
}
