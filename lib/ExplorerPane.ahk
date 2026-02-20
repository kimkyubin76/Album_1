; ============================================================
;  lib/ExplorerPane.ahk — 탐색기 패널 (TreeView + ListView)
;
;  Windows 탐색기 스타일: 좌측 폴더 트리 + 우측 파일 목록
;  Shell 아이콘(SHGetFileInfo) + 스플리터 드래그
;
;  ■ 공개 API (기존 호환)
;    ExpPaneInit()                 — 컨트롤 생성 (Show 직후)
;    ExpPaneNav(side, path)        — 폴더 탐색
;    ExpPaneSelect(side, filePath) — 파일 선택/하이라이트
;    ExpPaneGetSel(side)           — 선택된 파일 경로 배열 반환
;    ExpPaneResize(side, x,y,w,h)  — 패널 전체 크기 설정
;    ExpPaneClear(side)            — 트리/리스트 비우기
;    ExpPaneGetPath(side)          — 현재 리스트에 표시 중인 폴더 경로
;    ExpPaneDestroyAll()           — 정리
;    IsFolderPanelFocused()        — 폴더 패널(액자/앨범 LV/TV)에 포커스 여부
; ============================================================

; 폴더 패널(액자/앨범 리스트·트리)에 포커스가 있는지 판별 — HotIf/OnMessage에서 사용
IsFolderPanelFocused() {
    try {
        h := DllCall("GetFocus", "Ptr")
        if !h
            return false
        loop {
            if h = UI.ExpLvF.Hwnd || h = UI.ExpLvA.Hwnd || h = UI.ExpTvF.Hwnd || h = UI.ExpTvA.Hwnd
                return true
            h := DllCall("GetParent", "Ptr", h, "Ptr")
            if !h || h = UI.G.Hwnd
                break
        }
    }
    return false
}

; HotIf 콜백 — 폴더 패널에 포커스가 없을 때만 true 반환 (Hotkey가 발동되도록)
_EP_AllowMainHotkeys(*) {
    return !IsFolderPanelFocused()
}

global _EP := {
    F: { path: "", treeW: 180, bounds: {x:0,y:0,w:400,h:200} },
    A: { path: "", treeW: 180, bounds: {x:0,y:0,w:400,h:200}
        , listRows: [], sortCol: 1, sortAsc: true
        , viewMode: "details", iconSize: 48 }
}

global _EPDrag := { Active: false, Side: "", StartX: 0, StartTreeW: 0, LastT: 0 }
global _EP_RenamePending := ""
global _EP_RenameUndo    := ""   ; Ctrl+Z 1단계 undo 저장

; ── Shell 아이콘 시스템 ─────────────────────────────────────────
global _EP_IL_LV := 0          ; ListView용 ImageList
global _EP_IL_TV := 0          ; TreeView용 ImageList
global _EP_IconCache := Map()  ; ".ext" → LV ImageList 인덱스
global _EP_FolderIdx_LV := 1   ; LV의 폴더 아이콘 인덱스
global _EP_FolderIdx_TV := 1   ; TV의 폴더 아이콘 인덱스
global _EP_DefaultIdx := 1     ; 기본 파일 아이콘 인덱스

; ── 초기화 — GUI.Show() 직후 호출 ─────────────────────────────────
ExpPaneInit() {
    global _EP
    g := UI.G
    g.SetFont("s9 norm", "맑은 고딕")

    ; ── ImageList 생성 + Shell 아이콘 등록 ─────────────────────
    _EP_InitIcons()

    ; ── 액자 패널 (F) ──────────────────────────────────────────────
    UI.ExpTvF := g.Add("TreeView", "x0 y0 w10 h10 +HScroll BackgroundWhite vExpTvF")
    UI.ExpLvF := g.Add("ListView"
        , "x0 y0 w10 h10 +LV0x220 NoSortHdr BackgroundWhite vExpLvF"
        , ["이름", "크기", "수정일"])
    UI.ExpSplitF := g.Add("Text", "x0 y0 w4 h10 BackgroundE0E0E0 vExpSplitF", "")

    UI.ExpTvF.SetImageList(_EP_IL_TV)
    UI.ExpLvF.SetImageList(_EP_IL_LV)

    UI.ExpTvF.OnEvent("ItemSelect", (ctrl, item) => _EP_OnTreeSel("F", ctrl, item))
    UI.ExpTvF.OnEvent("ItemExpand", (ctrl, item, expanding) => _EP_OnTreeExpand("F", ctrl, item, expanding))
    UI.ExpTvF.OnEvent("ContextMenu", (ctrl, item, isRight, x, y) => _EP_OnTreeCtxMenu("F", ctrl, item, isRight, x, y))
    UI.ExpLvF.OnEvent("DoubleClick", (ctrl, row) => _EP_OnListDbl("F", ctrl, row))
    UI.ExpLvF.OnEvent("ContextMenu", (ctrl, item, isRight, x, y) => _EP_OnLvCtxMenu("F", ctrl, item, isRight, x, y))

    _EP_SetTransparent(UI.ExpSplitF)

    ; ── 앨범 패널 (A) ──────────────────────────────────────────────
    UI.ExpTvA := g.Add("TreeView", "x0 y0 w10 h10 +HScroll BackgroundWhite vExpTvA")
    UI.ExpLvA := g.Add("ListView"
        , "x0 y0 w10 h10 +LV0x220 BackgroundWhite vExpLvA"
        , ["이름", "크기", "수정일"])
    UI.ExpSplitA := g.Add("Text", "x0 y0 w4 h10 BackgroundE0E0E0 vExpSplitA", "")

    UI.ExpTvA.SetImageList(_EP_IL_TV)
    UI.ExpLvA.SetImageList(_EP_IL_LV)

    UI.ExpTvA.OnEvent("ItemSelect", (ctrl, item) => _EP_OnTreeSel("A", ctrl, item))
    UI.ExpTvA.OnEvent("ItemExpand", (ctrl, item, expanding) => _EP_OnTreeExpand("A", ctrl, item, expanding))
    UI.ExpTvA.OnEvent("ContextMenu", (ctrl, item, isRight, x, y) => _EP_OnTreeCtxMenu("A", ctrl, item, isRight, x, y))
    UI.ExpLvA.OnEvent("DoubleClick", (ctrl, row) => _EP_OnListDbl("A", ctrl, row))
    UI.ExpLvA.OnEvent("ColClick", (ctrl, col) => _EP_OnExpLvAColClick(ctrl, col))
    UI.ExpLvA.OnEvent("ContextMenu", (ctrl, item, isRight, x, y) => _EP_OnLvCtxMenu("A", ctrl, item, isRight, x, y))

    _EP_SetTransparent(UI.ExpSplitA)

    ; LVS_EDITLABELS(0x0200) 기본 창 스타일 적용 — F2/LVM_EDITLABEL 인라인 편집 활성화
    ; (AHK +LV0x220 은 확장 스타일이므로 기본 스타일에 별도 OR 필요)
    _EP_SetEditLabelsStyle(UI.ExpLvF)
    _EP_SetEditLabelsStyle(UI.ExpLvA)

    _EP_LoadSettings()
    OutputDebug("[ExpPane] Init OK (TV+LV + Shell icons)`n")
}

; ── 폴더 탐색 ───────────────────────────────────────────────────
ExpPaneNav(side, path) {
    global _EP
    ep := (side = "F") ? _EP.F : _EP.A
    if !DirExist(path)
        return false
    ep.path := path

    tv := (side = "F") ? UI.ExpTvF : UI.ExpTvA
    tv.Delete()

    SplitPath(path, &dirName)
    rootId := tv.Add(dirName ? dirName : path, 0, "+Expand Icon" _EP_FolderIdx_TV)
    _EP_TreeMap(tv, rootId, path)
    _EP_LoadSubDirs(side, tv, rootId, path, 1)

    _EP_PopulateList(side, path)
    OutputDebug("[EP] Nav side=" side " path=" path "`n")
    return true
}

; ── 파일 선택/하이라이트 ────────────────────────────────────────
ExpPaneSelect(side, filePath) {
    lv := (side = "F") ? UI.ExpLvF : UI.ExpLvA
    SplitPath(filePath, &fname)
    if fname = ""
        return
    Loop lv.GetCount() {
        if lv.GetText(A_Index, 1) = fname {
            lv.Modify(0, "-Select -Focus")
            lv.Modify(A_Index, "Select Focus Vis")
            return
        }
    }
}

; ── 선택 파일 경로 배열 반환 ────────────────────────────────────
ExpPaneGetSel(side) {
    global _EP
    ep := (side = "F") ? _EP.F : _EP.A
    lv := (side = "F") ? UI.ExpLvF : UI.ExpLvA
    paths := []
    row := 0
    Loop {
        row := lv.GetNext(row)
        if row = 0
            break
        name := lv.GetText(row, 1)
        if name != ""
            paths.Push(ep.path "\" name)
    }
    return paths
}

; ── 패널 크기 설정 ──────────────────────────────────────────────
ExpPaneResize(side, x, y, w, h) {
    global _EP
    ep := (side = "F") ? _EP.F : _EP.A
    ep.bounds := {x: Integer(x), y: Integer(y), w: Integer(w), h: Integer(h)}
    _EP_LayoutPane(side)
}

; ── 비우기 ────────────────────────────────────────────────────
ExpPaneClear(side) {
    if !UI.HasProp("ExpTvF")
        return
    tv := (side = "F") ? UI.ExpTvF : UI.ExpTvA
    lv := (side = "F") ? UI.ExpLvF : UI.ExpLvA
    tv.Delete()
    lv.Delete()
}

ExpPaneGetPath(side) {
    global _EP
    return ((side = "F") ? _EP.F : _EP.A).path
}

ExpPaneDestroyAll() {
    _EP_SaveSettings()
}

; ============================================================
;  Shell 아이콘
; ============================================================

_EP_InitIcons() {
    global _EP_IL_LV, _EP_IL_TV, _EP_FolderIdx_LV, _EP_FolderIdx_TV, _EP_DefaultIdx

    _EP_IL_LV := IL_Create(32, 8, false)
    _EP_IL_TV := IL_Create(8, 4, false)

    ; 폴더 아이콘 (FILE_ATTRIBUTE_DIRECTORY = 0x10)
    _EP_FolderIdx_LV := _EP_ShellIconToIL(_EP_IL_LV, "folder", 0x10)
    _EP_FolderIdx_TV := _EP_ShellIconToIL(_EP_IL_TV, "folder", 0x10)

    ; 기본 파일 아이콘 (FILE_ATTRIBUTE_NORMAL = 0x80)
    _EP_DefaultIdx := _EP_ShellIconToIL(_EP_IL_LV, "file", 0x80)

    OutputDebug("[EP] Icons — folder_lv=" _EP_FolderIdx_LV " folder_tv=" _EP_FolderIdx_TV " default=" _EP_DefaultIdx "`n")
}

; SHGetFileInfoW 로 HICON 획득 → ImageList에 추가 → 인덱스 반환
_EP_ShellIconToIL(il, nameOrExt, fileAttr) {
    ; SHFILEINFOW: hIcon(Ptr) + iIcon(Int) + dwAttr(UInt) + szDisplayName(260*2) + szTypeName(80*2)
    sfi := Buffer(A_PtrSize + 8 + 520 + 160, 0)
    ; SHGFI_ICON(0x100) | SHGFI_SMALLICON(0x01) | SHGFI_USEFILEATTRIBUTES(0x10) = 0x111
    DllCall("shell32\SHGetFileInfoW"
        , "WStr", nameOrExt, "UInt", fileAttr
        , "Ptr", sfi, "UInt", sfi.Size, "UInt", 0x111, "Ptr")
    hIcon := NumGet(sfi, 0, "Ptr")
    if hIcon = 0
        return 1
    idx := IL_Add(il, "HICON:" hIcon)
    DllCall("DestroyIcon", "Ptr", hIcon)
    return Max(1, idx)
}

; 확장자 → LV ImageList 아이콘 인덱스 (캐시)
_EP_GetExtIcon(ext) {
    global _EP_IconCache, _EP_IL_LV, _EP_DefaultIdx
    ext := StrLower(ext)
    if ext = ""
        return _EP_DefaultIdx
    if _EP_IconCache.Has(ext)
        return _EP_IconCache[ext]
    idx := _EP_ShellIconToIL(_EP_IL_LV, "*" ext, 0x80)
    if idx < 1
        idx := _EP_DefaultIdx
    _EP_IconCache[ext] := idx
    return idx
}

; ============================================================
;  레이아웃
; ============================================================

_EP_LayoutPane(side) {
    global _EP
    ep := (side = "F") ? _EP.F : _EP.A
    if !UI.HasProp("ExpTvF")
        return

    tv  := (side = "F") ? UI.ExpTvF   : UI.ExpTvA
    lv  := (side = "F") ? UI.ExpLvF   : UI.ExpLvA
    spl := (side = "F") ? UI.ExpSplitF : UI.ExpSplitA

    b := ep.bounds
    SPLIT_W := 4
    treeW := _Clamp(ep.treeW, 80, b.w - 120)
    listX := b.x + treeW + SPLIT_W
    listW := b.w - treeW - SPLIT_W

    tv.Move(b.x, b.y, treeW, b.h)
    spl.Move(b.x + treeW, b.y, SPLIT_W, b.h)
    lv.Move(listX, b.y, listW, b.h)
}

; ============================================================
;  TreeView 폴더 트리
; ============================================================

global _EP_TreePaths := Map()

_EP_TreeMap(tv, nodeId, dirPath) {
    global _EP_TreePaths
    key := tv.Hwnd
    if !_EP_TreePaths.Has(key)
        _EP_TreePaths[key] := Map()
    _EP_TreePaths[key][nodeId] := dirPath
}

_EP_TreeGetPath(tv, nodeId) {
    global _EP_TreePaths
    key := tv.Hwnd
    if _EP_TreePaths.Has(key) && _EP_TreePaths[key].Has(nodeId)
        return _EP_TreePaths[key][nodeId]
    return ""
}

_EP_LoadSubDirs(side, tv, parentId, parentPath, depth) {
    global _EP_FolderIdx_TV
    try {
        Loop Files, parentPath "\*", "D" {
            name := A_LoopFileName
            if SubStr(name, 1, 1) = "."
                continue
            childPath := A_LoopFileFullPath
            childId := tv.Add(name, parentId, "Icon" _EP_FolderIdx_TV)
            _EP_TreeMap(tv, childId, childPath)
            if depth < 2
                _EP_AddDummyIfHasSub(tv, childId, childPath)
        }
    }
}

_EP_AddDummyIfHasSub(tv, parentId, dirPath) {
    try {
        Loop Files, dirPath "\*", "D" {
            tv.Add("...", parentId, "Icon" _EP_FolderIdx_TV)
            return
        }
    }
}

_EP_OnTreeSel(side, ctrl, item) {
    global _EP
    if item = 0
        return
    dirPath := _EP_TreeGetPath(ctrl, item)
    if dirPath = "" || !DirExist(dirPath)
        return
    ep := (side = "F") ? _EP.F : _EP.A
    ep.path := dirPath
    _EP_PopulateList(side, dirPath)

    lbl  := (side = "F") ? UI.ExpPathF : UI.ExpPathA
    stat := (side = "F") ? UI.ExpStatF : UI.ExpStatA
    lbl.Text := "  " _EP_ShortPath(dirPath)
    stat.Text := "  탐색 완료"
}

_EP_OnTreeExpand(side, ctrl, item, expanding) {
    if !expanding || item = 0
        return
    dirPath := _EP_TreeGetPath(ctrl, item)
    if dirPath = ""
        return

    childId := ctrl.GetChild(item)
    if childId = 0
        return
    firstName := ctrl.GetText(childId)
    if firstName != "..."
        return

    Loop {
        nextId := ctrl.GetNext(childId)
        ctrl.Delete(childId)
        childId := nextId
        if childId = 0
            break
    }
    _EP_LoadSubDirs(side, ctrl, item, dirPath, 1)
}

; ============================================================
;  ListView 파일 목록 (Shell 아이콘 적용)
; ============================================================

_EP_PopulateList(side, dirPath) {
    global _EP_FolderIdx_LV, _EP
    lv := (side = "F") ? UI.ExpLvF : UI.ExpLvA
    lv.Delete()
    lv.Opt("-Redraw")

    rows := []
    fileCount := 0
    dirCount  := 0

    ; 1) 폴더 수집
    try {
        Loop Files, dirPath "\*", "D" {
            name := A_LoopFileName
            if SubStr(name, 1, 1) = "."
                continue
            rows.Push({name: name, size: "", date: _EP_FormatDate(A_LoopFileTimeModified), isDir: true, iconIdx: _EP_FolderIdx_LV})
            dirCount++
        }
    }

    ; 2) 파일 수집
    try {
        Loop Files, dirPath "\*", "F" {
            name := A_LoopFileName
            SplitPath(name, , , &ext)
            iconIdx := _EP_GetExtIcon("." ext)
            size := _EP_FormatSize(A_LoopFileSize)
            rows.Push({name: name, size: size, date: _EP_FormatDate(A_LoopFileTimeModified), isDir: false, iconIdx: iconIdx})
            fileCount++
        }
    }

    ; 3) 앨범 패널(A)일 때 정렬 후 저장
    if side = "A" {
        ep := _EP.A
        ep.listRows := rows
        _EP_SortExpListRows(rows, ep.sortCol, ep.sortAsc)
        _EP_UpdateExpLvAHeader(ep.sortCol, ep.sortAsc)
        ; 아이콘/작은아이콘 보기: 전용 ImageList 생성 및 iconIdx 갱신
        if ep.viewMode = "icon" || ep.viewMode = "smallicon" {
            sz := ep.viewMode = "smallicon" ? 16 : ep.iconSize
            hIL := _EP_CreateExpIconList(sz, ep.viewMode = "icon" ? dirPath : "")
            lv.SetImageList(hIL, ep.viewMode = "smallicon" ? 1 : 0)
            SendMessage(0x108E, ep.viewMode = "smallicon" ? 2 : 0, 0, lv)
        } else {
            lv.SetImageList(_EP_IL_LV, 1)
            SendMessage(0x108E, ep.viewMode = "list" ? 3 : 1, 0, lv)
        }
    } else {
        ; 액자 패널(F): 폴더→파일 순 유지 (Loop Files 순서)
    }

    ; 4) LV에 추가
    for r in rows
        lv.Add("Icon" r.iconIdx, r.name, r.size, r.date)

    lv.ModifyCol(1, "AutoHdr")
    lv.ModifyCol(2, 70)
    lv.ModifyCol(3, 120)
    lv.Opt("+Redraw")

    stat := (side = "F") ? UI.ExpStatF : UI.ExpStatA
    stat.Text := "  " (dirCount + fileCount) "개 항목 (폴더 " dirCount ", 파일 " fileCount ")"
}

; ── 앨범 ListView "이름" 컬럼 클릭: 오름차순/내림차순 토글 ──
_EP_OnExpLvAColClick(ctrl, col) {
    global _EP
    if col != 1
        return
    ep := _EP.A
    if ep.path = "" || ep.listRows.Length = 0
        return
    ep.sortAsc := !ep.sortAsc
    _EP_SortExpListRows(ep.listRows, 1, ep.sortAsc)
    _EP_UpdateExpLvAHeader(1, ep.sortAsc)
    ; LV 다시 그리기
    lv := UI.ExpLvA
    lv.Opt("-Redraw")
    lv.Delete()
    for r in ep.listRows
        lv.Add("Icon" r.iconIdx, r.name, r.size, r.date)
    lv.ModifyCol(1, "AutoHdr")
    lv.ModifyCol(2, 70)
    lv.ModifyCol(3, 120)
    lv.Opt("+Redraw")
}

; 앨범 ListView 헤더에 ▲/▼ 표시
_EP_UpdateExpLvAHeader(sortCol, sortAsc) {
    arrow := sortAsc ? " ▲" : " ▼"
    baseNames := ["이름", "크기", "수정일"]
    Loop 3 {
        name := baseNames[A_Index]
        if A_Index = sortCol
            name .= arrow
        UI.ExpLvA.ModifyCol(A_Index, , name)
    }
}

; Explorer ListView 행 정렬 (폴더 먼저, 숫자→문자)
_EP_SortExpListRows(rows, sortCol, sortAsc) {
    n := rows.Length
    Loop n - 1 {
        i := A_Index + 1
        temp := rows[i]
        j := i - 1
        while j >= 1 && _EP_CompareExpRow(rows[j], temp, sortCol, sortAsc) > 0 {
            rows[j + 1] := rows[j]
            j--
        }
        rows[j + 1] := temp
    }
}

_EP_CompareExpRow(a, b, col, asc) {
    diff := 0
    if col = 1 {
        ; 폴더 먼저, 그 다음 이름
        if a.isDir != b.isDir
            diff := a.isDir ? -1 : 1
        else
            diff := _EP_CompareExpName(a.name, b.name)
    } else if col = 2 {
        diff := StrCompare(a.size, b.size)
    } else if col = 3 {
        diff := StrCompare(a.date, b.date)
    }
    return asc ? diff : -diff
}

; 이름 비교: 숫자(01~99) → 숫자 크기순, 문자 → 가나다순
_EP_CompareExpName(a, b) {
    aIsNum := RegExMatch(a, "^\d{1,2}$") && Integer(a) >= 1 && Integer(a) <= 99
    bIsNum := RegExMatch(b, "^\d{1,2}$") && Integer(b) >= 1 && Integer(b) <= 99
    if aIsNum && bIsNum
        return Integer(a) - Integer(b)
    if aIsNum
        return -1
    if bIsNum
        return 1
    return DllCall("shlwapi\StrCmpLogicalW", "WStr", a, "WStr", b, "Int")
}

; ListView 더블클릭: 폴더 진입 / 파일 열기
_EP_OnListDbl(side, ctrl, row) {
    global _EP
    if row < 1
        return
    ep := (side = "F") ? _EP.F : _EP.A
    name := ctrl.GetText(row, 1)
    fullPath := ep.path "\" name

    ; 폴더면 진입
    if DirExist(fullPath) {
        ExpPaneNav(side, fullPath)
        lbl := (side = "F") ? UI.ExpPathF : UI.ExpPathA
        lbl.Text := "  " _EP_ShortPath(fullPath)
        return
    }

    ; 파일이면 기본 앱으로 열기
    if FileExist(fullPath)
        try Run('"' fullPath '"')
}

; ── 폴더 패널 키보드 처리 (F2 / Enter / Delete / Ctrl+A / Ctrl+Z) ──────
_EP_OnKeyDown(wParam, lParam, msg, hwnd) {
    side := _EP_GetSideFromHwnd(hwnd)
    if side = "" {
        if wParam = 0x71
            OutputDebug("[RENAME] F2 key hwnd=" hwnd " → side=empty (not folder panel), skip`n")
        return   ; 폴더 패널 아님 → 기본 처리 유지
    }

    ctrlDown := DllCall("GetKeyState", "UInt", 0x11, "UInt") & 0x8000   ; VK_CONTROL

    if wParam = 0x71 {                    ; VK_F2 → 인라인 Rename
        OutputDebug("[RENAME] F2 key hwnd=" hwnd " side=" side " (ExpLvF=" UI.ExpLvF.Hwnd " ExpLvA=" UI.ExpLvA.Hwnd " LV=" UI.LV.Hwnd ")`n")
        _EP_DoRename(side)
        return 0
    }
    if wParam = 0x0D {                    ; VK_RETURN → 폴더 진입 / 파일 열기
        _EP_DoEnter(side)
        return 0
    }
    if wParam = 0x2E {                    ; VK_DELETE → 선택 항목 삭제
        _EP_DoDelete(side)
        return 0
    }
    if ctrlDown && wParam = 0x41 {        ; Ctrl+A → 전체 선택
        _EP_DoSelectAll(side)
        return 0
    }
    if ctrlDown && wParam = 0x5A {        ; Ctrl+Z → 리네임 되돌리기
        _EP_DoUndoRename()
        return 0
    }
}

_EP_GetSideFromHwnd(hwnd) {
    try {
        h := hwnd
        loop {
            if h = UI.ExpLvF.Hwnd || h = UI.ExpTvF.Hwnd
                return "F"
            if h = UI.ExpLvA.Hwnd || h = UI.ExpTvA.Hwnd
                return "A"
            h := DllCall("GetParent", "Ptr", h, "Ptr")
            if !h || h = UI.G.Hwnd
                break
        }
    }
    return ""
}

_EP_DoRename(side) {
    global _EP, _EP_RenamePending
    ep := (side = "F") ? _EP.F : _EP.A
    lv := (side = "F") ? UI.ExpLvF : UI.ExpLvA
    row := lv.GetNext(0)
    if row < 1 {
        OutputDebug("[RENAME] _EP_DoRename side=" side " → no selection, skip`n")
        return
    }
    name := lv.GetText(row, 1)
    fullPath := ep.path "\" name
    OutputDebug("[RENAME] _EP_DoRename lvHwnd=" lv.Hwnd " side=" side " row=" row " oldPath=" fullPath "`n")
    if !FileExist(fullPath) && !DirExist(fullPath) {
        OutputDebug("[RENAME] _EP_DoRename → path not exist, skip`n")
        return
    }
    _EP_RenamePending := {side: side, oldPath: fullPath}
    ; LVM_EDITLABEL(0x1017): 항목 위에서 바로 인라인 편집 시작 (윈도우 탐색기처럼)
    ; SendMessage 반환값 = 인라인 에디트 컨트롤 HWND
    hEdit := SendMessage(0x1017, row - 1, 0, lv)
    ; 확장자 제외하고 파일명 부분만 선택 (윈도우 탐색기 동작: "aaa.jpg" → "aaa" 만 선택)
    if hEdit {
        SplitPath(name, , , &_ext, &_nameNoExt)
        ; ext 있고 nameNoExt 있는 경우만 확장자 제외, 그 외(폴더·숨김파일 등)는 전체 선택
        selEnd := (_ext != "" && _nameNoExt != "") ? StrLen(_nameNoExt) : StrLen(name)
        ; EM_SETSEL(0x00B1): wParam=선택 시작(0), lParam=선택 끝(selEnd)
        DllCall("SendMessageW", "Ptr", hEdit, "UInt", 0x00B1, "Ptr", 0, "Ptr", selEnd)
    }
}

; ── ① Ctrl+A — 현재 ListView 전체 선택 ──────────────────────────────
_EP_DoSelectAll(side) {
    lv := (side = "F") ? UI.ExpLvF : UI.ExpLvA
    if lv.GetCount() = 0
        return
    ; LVM_SETITEMSTATE(0x102B), iItem=-1 → 모든 항목에 일괄 적용
    ; LVITEM: mask(0) state(12) stateMask(16) — LVIS_SELECTED = 0x0002
    lvItem := Buffer(20, 0)
    NumPut("UInt", 0x0002, lvItem, 12)   ; state     = LVIS_SELECTED
    NumPut("UInt", 0x0002, lvItem, 16)   ; stateMask = LVIS_SELECTED
    SendMessage(0x102B, -1, lvItem.Ptr, lv)
    OutputDebug("[EP] Ctrl+A 전체 선택 side=" side " count=" lv.GetCount() "`n")
}

; ── ② VK_DELETE — 선택 항목 삭제 (확인 대화상자 포함) ─────────────────
_EP_DoDelete(side) {
    global _EP
    ep := (side = "F") ? _EP.F : _EP.A
    lv := (side = "F") ? UI.ExpLvF : UI.ExpLvA
    paths := []
    row := 0
    Loop {
        row := lv.GetNext(row)
        if row = 0
            break
        name := lv.GetText(row, 1)
        if name != ""
            paths.Push(ep.path "\" name)
    }
    if paths.Length = 0
        return
    confirmMsg := paths.Length = 1
        ? '"' paths[1] '"' "`n`n삭제하시겠습니까?"
        : paths.Length "개 항목을 삭제하시겠습니까?"
    if MsgBox(confirmMsg, "삭제 확인", "YesNo Icon! Default2") != "Yes"
        return
    errList := []
    for p in paths {
        try {
            if DirExist(p)
                DirDelete(p, true)
            else
                FileDelete(p)
        } catch as e {
            errList.Push(p "`n  → " e.Message)
        }
    }
    if errList.Length > 0
        MsgBox("삭제 실패 항목:`n" _EP_JoinArr(errList), "오류", "IconX")
    _EP_PopulateList(side, ep.path)
    OutputDebug("[EP] Delete " paths.Length "개 side=" side "`n")
}

; ── ③ Ctrl+Z — 마지막 리네임 1단계 되돌리기 ──────────────────────────
_EP_DoUndoRename() {
    global _EP, _EP_RenameUndo
    if !IsObject(_EP_RenameUndo) || !_EP_RenameUndo.HasProp("newPath") {
        OutputDebug("[EP] Ctrl+Z: 되돌릴 리네임 없음`n")
        return
    }
    old  := _EP_RenameUndo.oldPath
    new  := _EP_RenameUndo.newPath
    side := _EP_RenameUndo.side
    if !FileExist(new) && !DirExist(new) {
        MsgBox("되돌릴 파일이 이미 없습니다.`n" new, "되돌리기 실패", "Icon!")
        _EP_RenameUndo := ""
        return
    }
    if FileExist(old) || DirExist(old) {
        MsgBox('"' old '"' " 경로가 이미 존재합니다. 덮어쓸 수 없어 되돌리지 못했습니다.", "되돌리기 실패", "Icon!")
        return
    }
    try {
        if DirExist(new)
            DirMove(new, old, "R")
        else
            FileMove(new, old, 0)
        ep := (side = "F") ? _EP.F : _EP.A
        _EP_PopulateList(side, ep.path)
        ExpPaneSelect(side, old)
        _EP_RenameUndo := ""
        OutputDebug("[EP] Ctrl+Z 되돌림: " new " → " old "`n")
    } catch as e {
        MsgBox("되돌리기 실패: " e.Message, "오류", "IconX")
    }
}

; ── ④ VK_RETURN — 선택 항목 폴더 진입 또는 파일 열기 ─────────────────
_EP_DoEnter(side) {
    global _EP
    ep := (side = "F") ? _EP.F : _EP.A
    lv := (side = "F") ? UI.ExpLvF : UI.ExpLvA
    row := lv.GetNext(0)
    if row < 1
        return
    name := lv.GetText(row, 1)
    fullPath := ep.path "\" name
    if DirExist(fullPath) {
        ExpPaneNav(side, fullPath)
        lbl := (side = "F") ? UI.ExpPathF : UI.ExpPathA
        lbl.Text := "  " _EP_ShortPath(fullPath)
        return
    }
    if FileExist(fullPath)
        try Run('"' fullPath '"')
    OutputDebug("[EP] Enter → " fullPath "`n")
}

; ★ 리네임 성공 후 내부 데이터 구조 업데이트
_EP_UpdateAfterRename(oldPath, newPath, side) {
    global _EP, ST, UI
    SplitPath(oldPath, &oldName)
    SplitPath(newPath, &newName)
    ; 1) 앨범 패널(A) listRows 갱신
    if side = "A" {
        ep := _EP.A
        if ep.HasProp("listRows") && IsObject(ep.listRows) {
            for r in ep.listRows {
                if r.name = oldName {
                    r.name := newName
                    break
                }
            }
        }
    }
    ; 2) ST.Frames — albumMatchPath/albumMatchFile 동기화 (상단 리스트·미리보기 반영)
    if IsObject(ST.Frames) {
        for e in ST.Frames {
            if e.HasProp("albumMatchPath") && e.albumMatchPath = oldPath {
                e.albumMatchPath := newPath
                e.albumMatchFile := newName
                ; matchPaths 배열도 갱신
                if e.HasProp("matchPaths") && IsObject(e.matchPaths) {
                    for i, mp in e.matchPaths {
                        if mp = oldPath
                            e.matchPaths[i] := newPath
                    }
                }
            }
        }
        ; 선택 행이 해당 항목이면 UI 갱신
        if ST.SelRow >= 1 && ST.SelRow <= ST.Filtered.Length {
            e := ST.Frames[ST.Filtered[ST.SelRow]]
            if e.HasProp("albumMatchPath") && e.albumMatchPath = newPath {
                newVal := (e.albumNum != "" ? e.albumNum " | " : "") . newName
                try UI.LV.Modify(ST.SelRow, "Col1", newVal)
                try UI.PicFootA.Text := "  " _ShortPath(newPath)
                try UI.FullPath := newPath
                try UI.TxtRel.ToolTip := newPath
                if e.HasProp("matchPaths") && e.matchPaths.Length > 0 {
                    try SetPic(UI.PicA, newPath)
                    try UI.CmbMatch.Delete()
                    try {
                        for mp in e.matchPaths
                            UI.CmbMatch.Add(mp)
                        UI.CmbMatch.Choose(1)
                    }
                }
                EnsureCustomDrawBound()
            }
        }
    }
}

; LVN_ENDLABELEDIT(-105) — 인라인 편집 완료 시 실제 파일/폴더 리네임
;
; ★ LVN_ENDLABELEDIT 반환값 규칙 (MSDN 기준)
;   TRUE  (1, 非0) = 수락 — Windows가 ListView 항목 텍스트를 새 이름으로 즉시 갱신
;   FALSE (0)      = 거부 — Windows가 기존 이름을 복원
;
; ★ 동기 lv.Delete() 금지
;   LVN_ENDLABELEDIT 핸들러 내에서 lv.Delete()/lv.Add()를 동기로 호출하면
;   Windows가 TRUE 반환 후 항목 텍스트를 갱신하려 할 때 항목이 이미 없어져
;   화면에 이름이 바뀌지 않는 것처럼 보임.
;   → SetTimer로 다음 메시지 루프에서 안전하게 목록 새로고침
_EP_OnEndLabelEdit(lParam) {
    global _EP, _EP_RenamePending, _EP_RenameUndo
    OutputDebug("[RENAME] handler=_EP_OnEndLabelEdit ENTRY`n")
    if !IsObject(_EP_RenamePending) || !_EP_RenamePending.HasProp("side") {
        OutputDebug("[RENAME] handler=_EP_OnEndLabelEdit → reject: no _EP_RenamePending`n")
        return 0   ; 알 수 없는 편집 → 거부
    }
    hwndFrom := NumGet(lParam, 0, "Ptr")
    side := ""
    if hwndFrom = UI.ExpLvF.Hwnd
        side := "F"
    else if hwndFrom = UI.ExpLvA.Hwnd
        side := "A"
    if side = "" || side != _EP_RenamePending.side {
        OutputDebug("[RENAME] handler=_EP_OnEndLabelEdit → reject: side mismatch side=" side " pending=" _EP_RenamePending.side "`n")
        return 0   ; 패널 불일치 → 거부
    }
    ; NMLVDISPINFO: NMHDR(Ptr+Ptr+Int=20B) + LVITEM.mask(4)+iItem(4)+iSubItem(4)+state(4)+stateMask(4)
    O_PSZTEXT := A_PtrSize = 8 ? 40 : 32
    pszText := NumGet(lParam, O_PSZTEXT, "Ptr")
    if !pszText {
        _EP_RenamePending := ""
        OutputDebug("[RENAME] handler=_EP_OnEndLabelEdit → reject: Esc cancel (pszText=0)`n")
        return 0   ; Esc 취소 → 거부(기존 이름 유지)
    }
    newName := Trim(StrGet(pszText, "UTF-16"), " `t")
    if newName = "" {
        _EP_RenamePending := ""
        OutputDebug("[RENAME] handler=_EP_OnEndLabelEdit → reject: empty name`n")
        return 0   ; 빈 이름 → 거부
    }
    oldPath := _EP_RenamePending.oldPath
    SplitPath(oldPath, , &dir)
    newPath := dir "\" newName
    OutputDebug("[RENAME] handler=_EP_OnEndLabelEdit old=" oldPath " new=" newPath "`n")
    if newPath = oldPath {
        _EP_RenamePending := ""
        OutputDebug("[RENAME] handler=_EP_OnEndLabelEdit → reject: no change`n")
        return 0   ; 변경 없음 → 거부(기존 유지)
    }
    if FileExist(newPath) || DirExist(newPath) {
        MsgBox("같은 이름의 파일/폴더가 이미 존재합니다.", "이름 충돌", "Icon!")
        OutputDebug("[RENAME] handler=_EP_OnEndLabelEdit → reject: conflict`n")
        return 0   ; 충돌 → 거부
    }
    try {
        ; ★ 실제 디스크 파일/폴더명 변경 (필수)
        if DirExist(oldPath) {
            DirMove(oldPath, newPath, "R")
            OutputDebug("[RENAME] handler=_EP_OnEndLabelEdit DirMove done`n")
        } else {
            if !FileMove(oldPath, newPath, 0)
                throw OSError(A_LastError, "FileMove", oldPath " → " newPath)
            OutputDebug("[RENAME] handler=_EP_OnEndLabelEdit FileMove done`n")
        }
        ; ★ 디스크 검증 (필수)
        movedOk := FileExist(newPath) || DirExist(newPath)
        oldStill := FileExist(oldPath) || DirExist(oldPath)
        OutputDebug("[RENAME] handler=_EP_OnEndLabelEdit diskVerify movedOk=" (movedOk ? "1" : "0") " oldStill=" (oldStill ? "1" : "0") "`n")
        if !movedOk || oldStill {
            errMsg := "디스크 검증 실패: 새 경로 존재=" (movedOk ? "Y" : "N") " 구경로 잔존=" (oldStill ? "Y" : "N")
            MsgBox(errMsg "`n`nold=" oldPath "`nnew=" newPath, "리네임 오류", "IconX")
            _EP_RenamePending := ""
            return 0
        }
        ; Ctrl+Z undo 기록 (1단계)
        _EP_RenameUndo := {side: side, oldPath: oldPath, newPath: newPath}
        ; ★ 내부 데이터 구조 업데이트 (앨범 패널 + ST.Frames)
        _EP_UpdateAfterRename(oldPath, newPath, side)
        ; ★ 목록 새로고침은 SetTimer로 비동기 처리
        SetTimer(() => (_EP_CtxRefresh(side), ExpPaneSelect(side, newPath)), -50)
        OutputDebug("[RENAME] handler=_EP_OnEndLabelEdit SUCCESS return 1`n")
    } catch as e {
        MsgBox("이름 변경 실패: " e.Message, "오류", "IconX")
        OutputDebug("[RENAME] handler=_EP_OnEndLabelEdit CATCH " e.Message "`n")
        _EP_RenamePending := ""
        return 0   ; 실패 → 거부(기존 이름 유지)
    }
    _EP_RenamePending := ""
    return 1   ; ★ 수락(TRUE) — Windows가 항목 텍스트를 새 이름으로 즉시 반영
}

; ============================================================
;  스플리터 드래그
; ============================================================

_EP_HitSplitter(cx, cy) {
    if !UI.HasProp("ExpSplitF")
        return ""
    for side in ["F", "A"] {
        spl := (side = "F") ? UI.ExpSplitF : UI.ExpSplitA
        try {
            spl.GetPos(&sx, &sy, &sw, &sh)
            if cx >= sx - 2 && cx <= sx + sw + 2 && cy >= sy && cy <= sy + sh
                return side
        }
    }
    return ""
}

_EP_StartDrag(side, cx) {
    global _EPDrag, _EP
    ep := (side = "F") ? _EP.F : _EP.A
    _EPDrag.Active     := true
    _EPDrag.Side       := side
    _EPDrag.StartX     := cx
    _EPDrag.StartTreeW := ep.treeW
    _EPDrag.LastT      := 0
    spl := (side = "F") ? UI.ExpSplitF : UI.ExpSplitA
    try spl.Opt("Background" . LINE_A)
    try spl.Redraw()
    DllCall("SetCapture", "Ptr", UI.G.Hwnd)
}

_EP_OnDragMove(cx) {
    global _EPDrag, _EP
    if !_EPDrag.Active
        return
    t := A_TickCount
    if (t - _EPDrag.LastT < 16)
        return
    _EPDrag.LastT := t

    side := _EPDrag.Side
    ep := (side = "F") ? _EP.F : _EP.A
    dx := cx - _EPDrag.StartX
    newW := _Clamp(_EPDrag.StartTreeW + dx, 80, ep.bounds.w - 120)
    if newW != ep.treeW {
        ep.treeW := newW
        _EP_LayoutPane(side)
    }
}

_EP_EndDrag() {
    global _EPDrag
    if !_EPDrag.Active
        return
    _EPDrag.Active := false
    DllCall("ReleaseCapture")
    side := _EPDrag.Side
    spl := (side = "F") ? UI.ExpSplitF : UI.ExpSplitA
    try spl.Opt("BackgroundE0E0E0")
    try spl.Redraw()
    _EP_SaveSettings()
}

; ============================================================
;  유틸리티
; ============================================================

_EP_FormatSize(bytes) {
    if !IsNumber(bytes)
        return ""
    b := Integer(bytes)
    if b < 1024
        return b " B"
    if b < 1048576
        return Round(b / 1024, 1) " KB"
    if b < 1073741824
        return Round(b / 1048576, 1) " MB"
    return Round(b / 1073741824, 2) " GB"
}

_EP_FormatDate(ts) {
    if StrLen(ts) < 8
        return ""
    return SubStr(ts,1,4) "-" SubStr(ts,5,2) "-" SubStr(ts,7,2) " " SubStr(ts,9,2) ":" SubStr(ts,11,2)
}

_EP_ShortPath(p) {
    parts := StrSplit(p, "\")
    n := parts.Length
    if n <= 2
        return p
    return "…\" parts[n-1] "\" parts[n]
}

; WS_EX_TRANSPARENT (0x20) — 마우스 이벤트가 아래 컨트롤로 관통
_EP_SetTransparent(ctrl) {
    ex := DllCall("GetWindowLongPtr", "Ptr", ctrl.Hwnd, "Int", -20, "Ptr")
    DllCall("SetWindowLongPtr", "Ptr", ctrl.Hwnd, "Int", -20, "Ptr", ex | 0x20)
}

; LVS_EDITLABELS (0x0200) — ListView 기본 창 스타일에 인라인 편집 플래그 추가
; LVM_EDITLABEL(0x1017)이 동작하려면 기본 스타일(GWL_STYLE, -16)에
; LVS_EDITLABELS 비트가 설정되어 있어야 함.
; AHK의 +LV0x??? 옵션은 확장 스타일(LVM_SETEXTENDEDLISTVIEWSTYLE)이므로
; 이 함수를 통해 별도로 기본 스타일에 OR 처리함.
_EP_SetEditLabelsStyle(lv) {
    style := DllCall("GetWindowLongPtr", "Ptr", lv.Hwnd, "Int", -16, "Ptr")
    DllCall("SetWindowLongPtr", "Ptr", lv.Hwnd, "Int", -16, "Ptr", style | 0x0200)
}

_EP_SaveSettings() {
    global _EP, SETTINGS_INI
    try {
        IniWrite(_EP.F.treeW, SETTINGS_INI, "Explorer", "FrameTreeWidth")
        IniWrite(_EP.A.treeW, SETTINGS_INI, "Explorer", "AlbumTreeWidth")
        IniWrite(_EP.A.viewMode, SETTINGS_INI, "Explorer", "AlbumViewMode")
        IniWrite(_EP.A.iconSize, SETTINGS_INI, "Explorer", "AlbumIconSize")
    }
}

_EP_LoadSettings() {
    global _EP, SETTINGS_INI
    try _EP.F.treeW := Integer(IniRead(SETTINGS_INI, "Explorer", "FrameTreeWidth", "180"))
    try _EP.A.treeW := Integer(IniRead(SETTINGS_INI, "Explorer", "AlbumTreeWidth", "180"))
    try _EP.A.viewMode := IniRead(SETTINGS_INI, "Explorer", "AlbumViewMode", "details")
    try _EP.A.iconSize := Integer(IniRead(SETTINGS_INI, "Explorer", "AlbumIconSize", "48"))
}

; ============================================================
;  컨텍스트 메뉴 — Windows Shell 컨텍스트 메뉴 (탐색기 동일)
;  IShellFolder + IContextMenu COM 으로 OS 기본 메뉴 표시
;  우클릭 + Shift+F10 모두 지원 (AHK ContextMenu 이벤트)
; ============================================================

global _EP_ICM2 := 0   ; IContextMenu2 — owner-draw 서브메뉴 렌더링
global _EP_ICM3 := 0   ; IContextMenu3 — WM_MENUCHAR 처리

; ── ListView 컨텍스트 메뉴 ────────────────────────────────────
_EP_OnLvCtxMenu(side, ctrl, item, isRight, x, y) {
    global _EP
    ep := (side = "F") ? _EP.F : _EP.A
    curDir := ep.path
    if curDir = ""
        return

    names := []
    if item > 0 {
        selRows := []
        row := 0
        Loop {
            row := ctrl.GetNext(row)
            if row = 0
                break
            selRows.Push(row)
        }

        isInSel := false
        for r in selRows {
            if r = item {
                isInSel := true
                break
            }
        }

        if isInSel && selRows.Length > 1 {
            for r in selRows
                names.Push(ctrl.GetText(r, 1))
        } else {
            ctrl.Modify(0, "-Select -Focus")
            ctrl.Modify(item, "Select Focus")
            names.Push(ctrl.GetText(item, 1))
        }
    }

    sx := x, sy := y
    if !isRight {
        if item > 0 {
            rc := Buffer(16, 0)
            NumPut("Int", 0, rc, 0)
            SendMessage(0x100E, item - 1, rc.Ptr, ctrl)
            mx := Integer((NumGet(rc, 0, "Int") + NumGet(rc, 8, "Int")) / 2)
            my := Integer((NumGet(rc, 4, "Int") + NumGet(rc, 12, "Int")) / 2)
        } else {
            mx := 10, my := 10
        }
        pt := Buffer(8, 0)
        NumPut("Int", mx, pt, 0), NumPut("Int", my, pt, 4)
        DllCall("ClientToScreen", "Ptr", ctrl.Hwnd, "Ptr", pt)
        sx := NumGet(pt, 0, "Int"), sy := NumGet(pt, 4, "Int")
    }

    OutputDebug("[EP-LvCtx] side=" side " item=" item " names=" _EP_JoinArr(names) "`n")

    ; 앨범 패널(A): Windows Shell 기본 컨텍스트 메뉴만 표시 (커스텀 메뉴 제거)
    if side = "A" {
        if names.Length > 0
            _EP_ShowShellMenu(ctrl.Hwnd, side, curDir, names, sx, sy)
        else {
            ; 빈 공간 우클릭 → 폴더 배경 메뉴 (부모 기준 현재 폴더 1개로 Shell 메뉴)
            SplitPath(curDir, &folderName, &parentDir)
            if parentDir != "" && folderName != ""
                _EP_ShowShellMenu(ctrl.Hwnd, side, parentDir, [folderName], sx, sy)
            else
                _EP_ShowFallbackMenu(side, curDir, sx, sy)
        }
        return
    }
    if names.Length > 0 {
        if _EP_ShowShellMenu(ctrl.Hwnd, side, curDir, names, sx, sy)
            return
    }
    _EP_ShowFallbackMenu(side, curDir, sx, sy)
}

; ── TreeView 컨텍스트 메뉴 ────────────────────────────────────
_EP_OnTreeCtxMenu(side, ctrl, item, isRight, x, y) {
    global _EP
    ep := (side = "F") ? _EP.F : _EP.A

    ; 트리 노드의 폴더 경로
    folderPath := ""
    if item != 0
        folderPath := _EP_TreeGetPath(ctrl, item)

    if folderPath = "" || !DirExist(folderPath) {
        curDir := ep.path
        if curDir != ""
            _EP_ShowFallbackMenu(side, curDir, x ? x : 0, y ? y : 0)
        return
    }

    ; 부모 디렉토리 + 폴더명 분리
    SplitPath(folderPath, &folderName, &parentDir)
    if parentDir = "" || folderName = "" {
        _EP_ShowFallbackMenu(side, folderPath, x ? x : 0, y ? y : 0)
        return
    }

    ; 스크린 좌표
    sx := x, sy := y
    if !isRight {
        rc := Buffer(16, 0)
        ; TVM_GETITEMRECT = 0x1104, wParam = TRUE (item rect)
        NumPut("Ptr", item, rc, 0)
        SendMessage(0x1104, 1, rc.Ptr, ctrl)
        mx := Integer((NumGet(rc, 0, "Int") + NumGet(rc, 8, "Int")) / 2)
        my := Integer((NumGet(rc, 4, "Int") + NumGet(rc, 12, "Int")) / 2)
        pt := Buffer(8, 0)
        NumPut("Int", mx, pt, 0), NumPut("Int", my, pt, 4)
        DllCall("ClientToScreen", "Ptr", ctrl.Hwnd, "Ptr", pt)
        sx := NumGet(pt, 0, "Int"), sy := NumGet(pt, 4, "Int")
    }

    OutputDebug("[EP-TvCtx] side=" side " folder=" folderPath " parent=" parentDir "`n")

    if _EP_ShowShellMenu(ctrl.Hwnd, side, parentDir, [folderName], sx, sy)
        return
    _EP_ShowFallbackMenu(side, folderPath, sx, sy)
}

; ============================================================
;  Windows Shell 컨텍스트 메뉴 (IShellFolder → IContextMenu)
; ============================================================

_EP_ShowShellMenu(hwnd, side, dirPath, names, sx, sy) {
    global _EP_ICM2, _EP_ICM3

    ; 1) 폴더 PIDL → IShellFolder
    pidlDir := 0
    hr := DllCall("shell32\SHParseDisplayName"
        , "WStr", dirPath, "Ptr", 0, "Ptr*", &pidlDir, "UInt", 0, "UInt*", &dummy := 0, "Int")
    if hr != 0 || pidlDir = 0
        return false

    iid_sf := _EP_GUID("{000214E6-0000-0000-C000-000000000046}")
    pSF := 0
    hr := DllCall("shell32\SHBindToObject"
        , "Ptr", 0, "Ptr", pidlDir, "Ptr", 0, "Ptr", iid_sf, "Ptr*", &pSF, "Int")
    DllCall("ole32\CoTaskMemFree", "Ptr", pidlDir)
    if hr != 0 || pSF = 0
        return false

    ; ── [Fix] vtable 인덱스 근거 (IShellFolder COM 표준 스펙 고정값) ──────────
    ; IShellFolder (IID: 000214E6) 상속 구조:
    ;   IUnknown  vtable[0]=QueryInterface, [1]=AddRef, [2]=Release
    ;   IShellFolder vtable[3]=ParseDisplayName, [4]=EnumObjects,
    ;               [5]=BindToObject, [6]=BindToStorage, [7]=CompareIDs,
    ;               [8]=CreateViewObject, [9]=GetAttributesOf, [10]=GetUIObjectOf
    ; IContextMenu (IID: 000214E4) 상속 구조:
    ;   IUnknown  vtable[0]=QueryInterface, [1]=AddRef, [2]=Release
    ;   IContextMenu vtable[3]=QueryContextMenu, [4]=InvokeCommand, [5]=GetCommandString
    ; 위 인덱스는 Windows SDK 공식 COM 인터페이스 정의에 따른 고정값으로
    ; Windows 버전에 무관하게 동일하게 유지됨 (COM binary stability 보장).
    ; ─────────────────────────────────────────────────────────────────────────

    ; 2) 파일명 → child PIDL 배열 (IShellFolder::ParseDisplayName — vtable[3])
    cidl := names.Length
    childPidls := []
    apidl := Buffer(cidl * A_PtrSize, 0)

    for i, name in names {
        cpidl := 0, eaten := 0
        try ComCall(3, pSF, "Ptr", hwnd, "Ptr", 0, "WStr", name
            , "UInt*", &eaten, "Ptr*", &cpidl, "Ptr", 0)
        if !cpidl {
            OutputDebug("[EP-Ctx] ParseDisplayName 실패: " name "`n")
            for p in childPidls
                DllCall("ole32\CoTaskMemFree", "Ptr", p)
            ComCall(2, pSF)   ; IUnknown::Release
            return false
        }
        childPidls.Push(cpidl)
        NumPut("Ptr", cpidl, apidl, (i - 1) * A_PtrSize)
    }

    ; 3) IContextMenu 획득 (IShellFolder::GetUIObjectOf — vtable[10])
    iid_cm := _EP_GUID("{000214E4-0000-0000-C000-000000000046}")
    pCM := 0
    try ComCall(10, pSF, "Ptr", hwnd, "UInt", cidl, "Ptr", apidl
        , "Ptr", iid_cm, "Ptr", 0, "Ptr*", &pCM)

    for p in childPidls
        DllCall("ole32\CoTaskMemFree", "Ptr", p)
    ComCall(2, pSF)   ; IUnknown::Release

    if !pCM {
        OutputDebug("[EP-Ctx] GetUIObjectOf 실패`n")
        return false
    }

    ; 4) IContextMenu2/3 QI — vtable[0] = IUnknown::QueryInterface
    ;    IContextMenu3 (BCFCE0A0): HandleMenuMsg2(WM_MENUCHAR 처리)
    ;    IContextMenu2 (000214F4): HandleMenuMsg(owner-draw 서브메뉴 렌더링)
    _EP_ICM2 := 0, _EP_ICM3 := 0
    p3 := 0
    try ComCall(0, pCM, "Ptr", _EP_GUID("{BCFCE0A0-EC17-11D0-8D10-00A0C90F2719}"), "Ptr*", &p3)
    if p3 {
        _EP_ICM3 := p3
        _EP_ICM2 := p3
    } else {
        p2 := 0
        try ComCall(0, pCM, "Ptr", _EP_GUID("{000214F4-0000-0000-C000-000000000046}"), "Ptr*", &p2)
        if p2
            _EP_ICM2 := p2
    }

    ; 5) 팝업 메뉴 생성 + "이름 바꾸기" 맨 위 삽입 + QueryContextMenu (vtable[3])
    hMenu := DllCall("CreatePopupMenu", "Ptr")
    if !hMenu {
        OutputDebug("[EP-Ctx] CreatePopupMenu 실패`n")
        ComCall(2, pCM)
        return false
    }
    ; "이름 바꾸기"를 맨 위에 추가 (ID=1). Shell 메뉴는 idCmdFirst=2부터 시작
    DllCall("InsertMenu", "Ptr", hMenu, "UInt", 0, "UInt", 0x400|0x0,   "Ptr", 1, "WStr", "이름 바꾸기")
    DllCall("InsertMenu", "Ptr", hMenu, "UInt", 1, "UInt", 0x400|0x800, "Ptr", 0, "Ptr",  0)
    ; IContextMenu::QueryContextMenu — vtable[3]
    try ComCall(3, pCM, "Ptr", hMenu, "UInt", 2, "UInt", 2, "UInt", 0x7FFF, "UInt", 0x00000000)

    ; 6) OnMessage 훅 — owner-draw 서브메뉴(보내기, 연결 프로그램 등) 렌더링
    OnMessage(0x0117, _EP_HandleMenuMsg)    ; WM_INITMENUPOPUP
    OnMessage(0x002B, _EP_HandleMenuMsg)    ; WM_DRAWITEM
    OnMessage(0x002C, _EP_HandleMenuMsg)    ; WM_MEASUREITEM
    OnMessage(0x0120, _EP_HandleMenuChar)   ; WM_MENUCHAR

    ; 7) 메뉴 표시 (TPM_RETURNCMD | TPM_RIGHTBUTTON)
    cmd := DllCall("TrackPopupMenuEx"
        , "Ptr", hMenu, "UInt", 0x0102
        , "Int", sx, "Int", sy, "Ptr", hwnd, "Ptr", 0, "UInt")

    ; 8) 훅 해제
    OnMessage(0x0117, _EP_HandleMenuMsg, 0)
    OnMessage(0x002B, _EP_HandleMenuMsg, 0)
    OnMessage(0x002C, _EP_HandleMenuMsg, 0)
    OnMessage(0x0120, _EP_HandleMenuChar, 0)

    ; 9) 명령 실행 — cmd=1: "이름 바꾸기"(인라인 편집), cmd>=2: Shell InvokeCommand
    if cmd = 1 {
        _EP_DoRename(side)
    } else if cmd > 1 {
        sz := A_PtrSize = 8 ? 56 : 36
        ici := Buffer(sz, 0)
        NumPut("UInt", sz, ici, 0)
        NumPut("Ptr", hwnd, ici, 8)
        NumPut("Ptr", cmd - 2, ici, A_PtrSize = 8 ? 16 : 12)
        NumPut("Int", 1, ici, A_PtrSize = 8 ? 40 : 24)
        try ComCall(4, pCM, "Ptr", ici)
        SetTimer(() => _EP_CtxRefresh(side), -500)
    }

    ; 10) 정리
    DllCall("DestroyMenu", "Ptr", hMenu)
    if _EP_ICM3 {
        ComCall(2, _EP_ICM3)
    } else if _EP_ICM2 {
        ComCall(2, _EP_ICM2)
    }
    _EP_ICM2 := 0, _EP_ICM3 := 0
    ComCall(2, pCM)
    OutputDebug("[EP-Ctx] Shell menu done, cmd=" cmd "`n")
    return true
}

; ── IContextMenu2::HandleMenuMsg (owner-draw 렌더링) ──────────
_EP_HandleMenuMsg(wParam, lParam, msg, hwnd) {
    global _EP_ICM2
    if !_EP_ICM2
        return
    try {
        ComCall(6, _EP_ICM2, "UInt", msg, "Ptr", wParam, "Ptr", lParam)
        return 0
    }
}

; ── IContextMenu3::HandleMenuMsg2 (WM_MENUCHAR) ──────────────
_EP_HandleMenuChar(wParam, lParam, msg, hwnd) {
    global _EP_ICM3
    if !_EP_ICM3
        return
    try {
        result := 0
        ComCall(7, _EP_ICM3, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Ptr*", &result)
        return result
    }
}

; ── 앨범 ListView 전용 메뉴 (보기 + Shell) ─────────────────────
_EP_ShowAlbumLvMenu(curDir, names, sx, sy) {
    global _EP
    m := Menu()
    m.Add("보기", _EP_CreateViewMenu())
    m.Add()
    if names.Length > 0
        m.Add("Shell 메뉴 열기", (*) => _EP_ShowShellMenu(UI.ExpLvA.Hwnd, "A", curDir, names, sx, sy))
    m.Add("🔄 새로고침", (*) => _EP_CtxRefresh("A"))
    if curDir != ""
        m.Add("📁 탐색기에서 폴더 열기", (*) => OpenFolder(curDir))
    m.Show(sx, sy)
}

; 앨범 ListView 보기 모드 변경 (LVM_SETVIEW + ImageList)
_EP_SetExpLvAView(mode, iconSize) {
    global _EP
    ep := _EP.A
    if ep.path = "" || !DirExist(ep.path)
        return
    ep.viewMode := mode
    ep.iconSize := iconSize
    _EP_PopulateList("A", ep.path)
    _EP_SaveSettings()
}

; 지정 크기 ImageList 생성 (썸네일/Shell 아이콘)
_EP_CreateExpIconList(size, basePath := "") {
    global _EP
    hIL := IL_Create(size, 32, false)
    folderIdx := _EP_ShellIconToILSize(hIL, "folder", 0x10, size)
    defaultIdx := _EP_ShellIconToILSize(hIL, "file", 0x80, size)
    ; basePath가 있으면 listRows 기반으로 아이콘 추가
    ep := _EP.A
    extCache := Map()
    for r in ep.listRows {
        fullPath := basePath != "" ? basePath "\" r.name : ""
        if r.isDir
            r.iconIdx := folderIdx
        else if fullPath != "" && _EP_IsImageFile(r.name) {
            r.iconIdx := _EP_ThumbToIL(hIL, fullPath, size, defaultIdx)
        } else {
            pos := InStr(r.name, ".", 0, -1)
            ext := pos ? StrLower(SubStr(r.name, pos)) : "."
            if !extCache.Has(ext)
                extCache[ext] := _EP_ShellIconToILSize(hIL, "*" ext, 0x80, size)
            r.iconIdx := extCache[ext] > 0 ? extCache[ext] : defaultIdx
        }
    }
    return hIL
}

_EP_IsImageFile(name) {
    ext := StrLower(SubStr(name, InStr(name, ".", 0, -1)))
    return ext = ".jpg" || ext = ".jpeg" || ext = ".png" || ext = ".heic"
}

; SHGetFileInfo + 지정 크기 → ImageList
_EP_ShellIconToILSize(il, nameOrExt, fileAttr, size) {
    sfi := Buffer(A_PtrSize + 8 + 520 + 160, 0)
    flags := 0x100 | 0x10   ; SHGFI_ICON | USEFILEATTRIBUTES
    if size <= 16
        flags |= 0x01       ; SHGFI_SMALLICON
    else
        flags |= 0x00       ; SHGFI_LARGEICON
    DllCall("shell32\SHGetFileInfoW", "WStr", nameOrExt, "UInt", fileAttr
        , "Ptr", sfi, "UInt", sfi.Size, "UInt", flags, "Ptr")
    hIcon := NumGet(sfi, 0, "Ptr")
    if hIcon = 0
        return 1
    ; 아이콘 리사이즈: ImageList에 추가 시 크기 맞춤
    idx := IL_Add(il, "HICON:" hIcon)
    DllCall("DestroyIcon", "Ptr", hIcon)
    return Max(1, idx)
}

; GDI+ 썸네일 → ImageList
_EP_ThumbToIL(hIL, path, size, defaultIdx) {
    hBmp := _GdipLoadRotated(path, size, size)
    if !hBmp
        return defaultIdx
    idx := IL_Add(hIL, "HBITMAP:" hBmp)
    DllCall("DeleteObject", "Ptr", hBmp)
    return (idx > 0) ? idx : defaultIdx
}

; 보기 서브메뉴 생성 (체크 표시 포함)
_EP_CreateViewMenu() {
    global _EP
    ep := _EP.A
    viewMenu := Menu()
    viewMenu.Add("아주 큰 아이콘 (256x256)", (*) => _EP_SetExpLvAView("icon", 256))
    if (ep.viewMode = "icon" && ep.iconSize = 256)
        viewMenu.Check("아주 큰 아이콘 (256x256)")
    viewMenu.Add("큰 아이콘 (96x96)", (*) => _EP_SetExpLvAView("icon", 96))
    if (ep.viewMode = "icon" && ep.iconSize = 96)
        viewMenu.Check("큰 아이콘 (96x96)")
    viewMenu.Add("중간 아이콘 (48x48)", (*) => _EP_SetExpLvAView("icon", 48))
    if (ep.viewMode = "icon" && ep.iconSize = 48)
        viewMenu.Check("중간 아이콘 (48x48)")
    viewMenu.Add("작은 아이콘 (16x16)", (*) => _EP_SetExpLvAView("smallicon", 16))
    if (ep.viewMode = "smallicon")
        viewMenu.Check("작은 아이콘 (16x16)")
    viewMenu.Add("자세히", (*) => _EP_SetExpLvAView("details", 0))
    if (ep.viewMode = "details")
        viewMenu.Check("자세히")
    viewMenu.Add("목록", (*) => _EP_SetExpLvAView("list", 0))
    if (ep.viewMode = "list")
        viewMenu.Check("목록")
    return viewMenu
}

; ── 폴백 메뉴 (Shell 메뉴 실패 시 또는 빈 공간) ──────────────
_EP_ShowFallbackMenu(side, curDir, sx, sy) {
    m := Menu()
    if side = "A" {
        m.Add("보기", _EP_CreateViewMenu())
        m.Add()
    }
    m.Add("🔄 새로고침", (*) => _EP_CtxRefresh(side))
    if curDir != ""
        m.Add("📁 탐색기에서 폴더 열기", (*) => OpenFolder(curDir))
    m.Show(sx, sy)
}

; ── GUID 문자열 → 16바이트 버퍼 ──────────────────────────────
_EP_GUID(str) {
    buf := Buffer(16, 0)
    DllCall("ole32\CLSIDFromString", "WStr", str, "Ptr", buf, "Int")
    return buf
}

_EP_JoinArr(arr) {
    s := ""
    for v in arr
        s .= (s ? "," : "") . v
    return s
}

_EP_CtxRefresh(side) {
    global _EP
    ep := (side = "F") ? _EP.F : _EP.A
    if ep.path != "" && DirExist(ep.path)
        _EP_PopulateList(side, ep.path)
}
