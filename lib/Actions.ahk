; ============================================================
;  lib/Actions.ahk — 버튼 클릭 액션 핸들러
;  의존: Globals.ahk (ST, UI)
; ============================================================

OnCopyPath(*) {
    if UI.FullPath {
        A_Clipboard := UI.FullPath
        ToolTip("클립보드에 복사됨`n" UI.FullPath)
        SetTimer(() => ToolTip(), -2000)
    }
}

OnLocateAlbumFile(*) {
    OpenExplorerSelect(UI.FullPath)
}

OnOpenAlbumDir(*) {
    OpenFolder(ST.AlbumPath)
}

OnOpenFrameDir(*) {
    if ST.SelRow >= 1 && ST.SelRow <= ST.Filtered.Length {
        e := ST.Frames[ST.Filtered[ST.SelRow]]
        if OpenExplorerSelect(e.path)
            return
    }
    OpenFolder(ST.FramePath)
}

OnOpenFile(*) {
    if ST.SelRow < 1 || ST.SelRow > ST.Filtered.Length
        return
    e := ST.Frames[ST.Filtered[ST.SelRow]]
    if FileExist(e.path)
        Run('"' e.path '"')
}

OnCustomerMemo(*) {
    if ST.SelRow < 1 || ST.SelRow > ST.Filtered.Length
        return
    e    := ST.Frames[ST.Filtered[ST.SelRow]]
    memo := "📞 고객 확인 필요`n파일명: " e.name "`n경로: " e.path "`n앨범에서 찾을 수 없음"
    A_Clipboard := memo
    ToolTip("📋 고객 메모가 클립보드에 복사되었습니다`n" e.name)
    SetTimer(() => ToolTip(), -2500)
}

OnManualRename(*) {
    if ST.SelRow < 1 || ST.SelRow > ST.Filtered.Length
        return
    e := ST.Frames[ST.Filtered[ST.SelRow]]
    if e.status != "MATCH" {
        MsgBox("MATCH 상태인 항목만 리네임할 수 있습니다.", "안내", "Iconi")
        return
    }
    
    res := ExecuteRename(REN_CFG, e.albumMatchPath, e.albumNum, e.subdir, e.path)
    if InStr(res, "err:") {
        MsgBox("리네임 실패: " res, "오류", "IconX")
    } else if InStr(res, "cancel:") {
        ; Canceled by user
    } else if InStr(res, "skip:") {
        MsgBox("건너뜀: " res, "안내", "Iconi")
    } else {
        MsgBox("리네임 성공:`n" res, "성공", "Iconi")
        ; 업데이트된 경로 반영
        e.albumMatchFile := ""
        SplitPath(res, &newFile)
        e.albumMatchFile := newFile
        e.albumMatchPath := res
        
        ; ListView 갱신 (Col2) - Requires AlbumDisplay logic, simpler to just modify row manually
        if (e.albumNum != "")
            newVal := e.albumNum " | " e.albumMatchFile
        else
            newVal := e.albumMatchFile
            
        UI.LV.Modify(ST.SelRow, "Col1", newVal)
        SetPic(UI.PicA, res)
        UI.PicFootA.Text := "  " _ShortPath(res)
        UI.FullPath := res
        UI.TxtRel.ToolTip := res
        
        ; MATCH 경로 목록 갱신
        curSel := UI.CmbMatch.Value
        e.matchPaths[curSel] := res
        
        items := []
        for mp in e.matchPaths
            items.Push(mp)
        UI.CmbMatch.Delete()
        UI.CmbMatch.Add(items)
        UI.CmbMatch.Choose(curSel)
        
        EnsureCustomDrawBound()
    }
}

; ── 탐색기에서 파일 위치 열기 (/select) ────────────────────────────────────
;  성공 시 true, 실패(경로 없음 등) 시 false 반환
OpenExplorerSelect(fullPath) {
    if fullPath = "" {
        ToolTip("⚠ 선택된 파일 경로가 없습니다.")
        SetTimer(() => ToolTip(), -2500)
        return false
    }

    SplitPath(fullPath, &fileName, &folderPath)
    exists := FileExist(fullPath)

    ; ── 진단 로그 ────────────────────────────────────────────────────────
    dbgMsg := "[OpenExplorerSelect]`n"
        . "  folderPath : " folderPath "`n"
        . "  fileName   : " fileName "`n"
        . "  fullPath   : " fullPath "`n"
        . "  FileExist  : " (exists ? exists : "(없음)")
    OutputDebug(dbgMsg)

    ; ── 방법 A: /select 로 파일 직접 선택 ────────────────────────────────
    cmd := 'explorer.exe /select,"' fullPath '"'
    OutputDebug("[OpenExplorerSelect] Run: " cmd)
    try {
        Run(cmd)
        ToolTip("📂 탐색기 열기: " fileName)
        SetTimer(() => ToolTip(), -2000)
        return true
    }

    ; ── 방법 B: 폴더만 열기 (fallback) ───────────────────────────────────
    OutputDebug("[OpenExplorerSelect] /select 실패 → 폴더 열기 시도")
    return OpenFolder(folderPath)
}

; ── 탐색기에서 폴더 열기 ───────────────────────────────────────────────────
OpenFolder(folderPath) {
    if folderPath = "" {
        ToolTip("⚠ 폴더 경로가 없습니다.")
        SetTimer(() => ToolTip(), -2500)
        return false
    }

    OutputDebug("[OpenFolder] folderPath=" folderPath " DirExist=" DirExist(folderPath))

    if !DirExist(folderPath) {
        msg := "폴더를 찾을 수 없습니다:`n" folderPath
        OutputDebug("[OpenFolder] 실패 — " msg)
        MsgBox(msg, "경로 확인", "Icon!")
        return false
    }

    try {
        Run('explorer.exe "' folderPath '"')
        ToolTip("📁 폴더 열기: " folderPath)
        SetTimer(() => ToolTip(), -2000)
        return true
    } catch as e {
        MsgBox("탐색기 실행 실패:`n" e.Message "`n`n경로: " folderPath, "오류", "IconX")
        return false
    }
}
