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
; ============================================================

global _EP := {
    F: { path: "", treeW: 180, bounds: {x:0,y:0,w:400,h:200} },
    A: { path: "", treeW: 180, bounds: {x:0,y:0,w:400,h:200}
        , listRows: [], sortCol: 1, sortAsc: true }
}

global _EPDrag := { Active: false, Side: "", StartX: 0, StartTreeW: 0, LastT: 0 }

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
        , "x0 y0 w10 h10 +LV0x20 NoSortHdr BackgroundWhite vExpLvF"
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
        , "x0 y0 w10 h10 +LV0x20 BackgroundWhite vExpLvA"
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

_EP_SaveSettings() {
    global _EP, SETTINGS_INI
    try {
        IniWrite(_EP.F.treeW, SETTINGS_INI, "Explorer", "FrameTreeWidth")
        IniWrite(_EP.A.treeW, SETTINGS_INI, "Explorer", "AlbumTreeWidth")
    }
}

_EP_LoadSettings() {
    global _EP, SETTINGS_INI
    try _EP.F.treeW := Integer(IniRead(SETTINGS_INI, "Explorer", "FrameTreeWidth", "180"))
    try _EP.A.treeW := Integer(IniRead(SETTINGS_INI, "Explorer", "AlbumTreeWidth", "180"))
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

    ; 2) 파일명 → child PIDL 배열 (IShellFolder::ParseDisplayName)
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
            ComCall(2, pSF)
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
    ComCall(2, pSF)

    if !pCM {
        OutputDebug("[EP-Ctx] GetUIObjectOf 실패`n")
        return false
    }

    ; 4) IContextMenu2 / IContextMenu3 (owner-draw 서브메뉴 아이콘)
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

    ; 5) 팝업 메뉴 생성 + QueryContextMenu (vtable[3])
    hMenu := DllCall("CreatePopupMenu", "Ptr")
    try ComCall(3, pCM, "Ptr", hMenu, "UInt", 0, "UInt", 1, "UInt", 0x7FFF, "UInt", 0x00000000)

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

    ; 9) 명령 실행 (IContextMenu::InvokeCommand — vtable[4])
    if cmd > 0 {
        sz := A_PtrSize = 8 ? 56 : 36
        ici := Buffer(sz, 0)
        NumPut("UInt", sz, ici, 0)
        NumPut("Ptr", hwnd, ici, 8)
        NumPut("Ptr", cmd - 1, ici, A_PtrSize = 8 ? 16 : 12)
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

; ── 폴백 메뉴 (Shell 메뉴 실패 시 또는 빈 공간) ──────────────
_EP_ShowFallbackMenu(side, curDir, sx, sy) {
    m := Menu()
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
