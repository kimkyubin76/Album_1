; ============================================================
;  lib/Explorer.ahk — 파일 탐색기 패널 (TreeView + ListView 기반)
;
;  ExplorerPane.ahk 의 TreeView + ListView를 사용하여
;  Windows 탐색기 스타일 파일 탐색 UI를 제공합니다.
;
;  ■ 공개 API
;    ExpLoad(side, path)          — 특정 폴더 탐색
;    ExpSync(framePath, matchPath) — 리스트 선택 시 양쪽 동기화
;    ExpGoUp(side)                — ⬆ 버튼: 상위 폴더 이동
;    ExpRefresh()                 — 양쪽 새로고침
;    ExpCopyToAlbum()             — 액자 파일 → 앨범 폴더 복사
;    ExpMoveToAlbum()             — 액자 파일 → 앨범 폴더 이동
;    ExpDeleteSel()               — 선택 파일 삭제
;    ExpOpenLocation(side)        — Windows 탐색기로 선택 파일 위치 열기
;    ExpCopyPath()                — 선택 파일 경로 클립보드 복사
; ============================================================

; ── 폴더 탐색 ─────────────────────────────────────────────────────────
ExpLoad(side, path) {
    global ExpSt
    lbl  := (side = "F") ? UI.ExpPathF : UI.ExpPathA
    stat := (side = "F") ? UI.ExpStatF : UI.ExpStatA

    if !DirExist(path) {
        ExpPaneClear(side)
        lbl.Text  := "  (폴더 없음)"
        stat.Text := "  —"
        return
    }

    if side = "F"
        ExpSt.FramePath := path
    else
        ExpSt.AlbumPath := path

    lbl.Text  := "  " _ExpShortPath(path)
    stat.Text := "  탐색 중…"
    ExpPaneNav(side, path)
}

; ── 리스트 선택 시 양쪽 동기화 ────────────────────────────────────────
ExpSync(framePath, matchPath) {
    global ExpSt

    OutputDebug("[ExpSync] framePath=" framePath " matchPath=" matchPath "`n")

    ; 액자 탐색기
    if framePath != "" {
        SplitPath(framePath, &fName, &fDir)
        OutputDebug("[ExpSync] 액자: fDir=" fDir " DirExist=" DirExist(fDir) " FileExist=" FileExist(framePath) "`n")
        if ExpSt.FramePath != fDir
            ExpLoad("F", fDir)
        ExpPaneSelect("F", framePath)
        ExpSt.FrameSel := framePath
    }

    ; 앨범 탐색기
    if matchPath != "" {
        SplitPath(matchPath, &aName, &aDir)
        OutputDebug("[ExpSync] 앨범: aDir=" aDir " DirExist=" DirExist(aDir) " FileExist=" FileExist(matchPath) "`n")
        if ExpSt.AlbumPath != aDir
            ExpLoad("A", aDir)
        ExpPaneSelect("A", matchPath)
        ExpSt.AlbumSel   := matchPath
        UI.ExpStatA.Text := "  " aName " — 매칭됨 ✓"
    } else {
        ExpPaneClear("A")
        UI.ExpPathA.Text := "  (매칭 없음)"
        UI.ExpStatA.Text := "  —"
        ExpSt.AlbumPath  := ""
        ExpSt.AlbumSel   := ""
    }
}

; ── ⬆ 상위 폴더로 이동 ────────────────────────────────────────────────
ExpGoUp(side) {
    global ExpSt
    cur := (side = "F") ? ExpSt.FramePath : ExpSt.AlbumPath
    if cur = ""
        return
    SplitPath(cur, , &parent)
    if parent != "" && DirExist(parent)
        ExpLoad(side, parent)
}

; ── 양쪽 새로고침 ──────────────────────────────────────────────────────
ExpRefresh(*) {
    global ExpSt
    if ExpSt.FramePath != ""
        ExpLoad("F", ExpSt.FramePath)
    if ExpSt.AlbumPath != ""
        ExpLoad("A", ExpSt.AlbumPath)
}

; ── 복사 →앨범 ────────────────────────────────────────────────────────
ExpCopyToAlbum(*) {
    src := _ExpGetFrameSel()
    dst := _ExpGetAlbumDir()
    if !src || !dst
        return _ExpAlert("액자 파일과 앨범 폴더가 모두 선택되어야 합니다.")
    SplitPath(src, &fname)
    target := dst "\" fname
    if FileExist(target) {
        if MsgBox(fname " 이(가) 이미 대상에 존재합니다.`n덮어쓰시겠습니까?", "복사 확인", "YesNo Icon?") != "Yes"
            return
    }
    try {
        FileCopy(src, target, true)
        _ExpAlert("복사 완료:`n" target, "success")
        ExpRefresh()
    } catch as e {
        _ExpAlert("복사 실패: " e.Message)
    }
}

; ── 이동 →앨범 ────────────────────────────────────────────────────────
ExpMoveToAlbum(*) {
    src := _ExpGetFrameSel()
    dst := _ExpGetAlbumDir()
    if !src || !dst
        return _ExpAlert("액자 파일과 앨범 폴더가 모두 선택되어야 합니다.")
    SplitPath(src, &fname)
    target := dst "\" fname
    if MsgBox("이동 후 원본이 삭제됩니다.`n`n" src "`n→  " target
            , "이동 확인", "YesNo Icon?") != "Yes"
        return
    try {
        FileMove(src, target, true)
        _ExpAlert("이동 완료:`n" target, "success")
        ExpRefresh()
    } catch as e {
        _ExpAlert("이동 실패: " e.Message)
    }
}

; ── 선택 파일 삭제 ─────────────────────────────────────────────────────
ExpDeleteSel(*) {
    src := _ExpGetFrameSel()
    if !src
        src := _ExpGetAlbumSel()
    if !src
        return _ExpAlert("삭제할 파일을 선택하세요.")
    if MsgBox("파일을 삭제합니다.`n`n" src, "삭제 확인", "YesNo Icon?") != "Yes"
        return
    try {
        FileDelete(src)
        ExpRefresh()
    } catch as e {
        _ExpAlert("삭제 실패: " e.Message)
    }
}

; ── Windows 탐색기에서 위치 열기 ────────────────────────────────────────
ExpOpenLocation(side, *) {
    global ExpSt
    path := (side = "F") ? _ExpGetFrameSel() : _ExpGetAlbumSel()
    if path != "" {
        if OpenExplorerSelect(path)
            return
    }
    dir := (side = "F") ? ExpSt.FramePath : ExpSt.AlbumPath
    OpenFolder(dir)
}

; ── 경로 클립보드 복사 ────────────────────────────────────────────────
ExpCopyPath(*) {
    global ExpSt
    path := _ExpGetFrameSel()
    if !path
        path := _ExpGetAlbumSel()
    if !path
        path := ExpSt.FramePath
    if path {
        A_Clipboard := path
        ToolTip("클립보드에 복사됨`n" path)
        SetTimer(() => ToolTip(), -2000)
    }
}

; ============================================================
;  내부 헬퍼
; ============================================================

; ListView 선택 → 첫 번째 파일 경로 반환
_ExpGetFrameSel() {
    global ExpSt
    paths := ExpPaneGetSel("F")
    if paths.Length > 0
        return paths[1]
    return ExpSt.FrameSel   ; 폴링 전 마지막 선택
}

_ExpGetAlbumSel() {
    global ExpSt
    paths := ExpPaneGetSel("A")
    if paths.Length > 0
        return paths[1]
    return ExpSt.AlbumSel
}

_ExpGetAlbumDir() {
    global ExpSt
    return DirExist(ExpSt.AlbumPath) ? ExpSt.AlbumPath : ""
}

_ExpShortPath(p) {
    parts := StrSplit(p, "\")
    n := parts.Length
    if n <= 2
        return p
    return "…\" parts[n-1] "\" parts[n]
}

_ExpAlert(msg, type := "warn") {
    if type = "success" {
        ToolTip("✅ " msg)
        SetTimer(() => ToolTip(), -2500)
    } else {
        ToolTip("⚠ " msg)
        SetTimer(() => ToolTip(), -3000)
    }
}
