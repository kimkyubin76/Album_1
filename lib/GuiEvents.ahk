; lib/GuiEvents.ahk
; 의존: Globals.ahk, PathUtil.ahk, GuiLayout.ahk

SwitchMode(m) {
    global _LW, _LH
    ST.Mode := m
    isA := m = "A"
    UI.BtnModeA.Text := isA  ? "▶ 자동(A)" : "자동(A)"
    UI.BtnModeB.Text := !isA ? "▶ 수동(B)" : "수동(B)"
    for n in ["LblRoot","EdtRoot","BtnRoot"]
        UI.G[n].Visible := isA
    for n in ["LblFrame","EdtFrame","BtnFrame","LblAlbum","EdtAlbum","BtnAlbum"]
        UI.G[n].Visible := !isA
    DoLayout(_LW, _LH)
}

OnBrowseRoot(*) {
    UI.G.Opt("+OwnDialogs")
    f := DirSelect(, 3, "[자동 모드] 루트 폴더를 선택하세요")
    if !f
        return
    f := RTrim(f, "\")
    ST.Root := f
    UI.EdtRoot.Value := f
}

OnBrowseFrame(*) {
    UI.G.Opt("+OwnDialogs")
    f := DirSelect(, 3, "[수동 모드] 액자 폴더를 선택하세요")
    if !f
        return
    f := RTrim(f, "\")
    ST.FramePath := f
    UI.EdtFrame.Value := f
}

OnBrowseAlbum(*) {
    UI.G.Opt("+OwnDialogs")
    f := DirSelect(, 3, "[수동 모드] 앨범 루트 폴더를 선택하세요")
    if !f
        return
    f := RTrim(f, "\")
    ST.AlbumPath := f
    UI.EdtAlbum.Value := f
}

OnEditRoot(ctrl, *) {
    val := Trim(ctrl.Value, ' "' . "`t`r`n")
    val := RTrim(val, "\")
    if !val
        return
    if DirExist(val) {
        ST.Root := val
        return
    }
    path := CleanPath(val)
    if path && DirExist(path) {
        ST.Root := path
        ctrl.Value := path
    }
}

OnEditFrame(ctrl, *) {
    val := Trim(ctrl.Value, ' "' . "`t`r`n")
    val := RTrim(val, "\")
    if !val
        return
    if DirExist(val) {
        ST.FramePath := val
        return
    }
    path := CleanPath(val)
    if path && DirExist(path) {
        ST.FramePath := path
        ctrl.Value := path
    }
}

OnEditAlbum(ctrl, *) {
    val := Trim(ctrl.Value, ' "' . "`t`r`n")
    val := RTrim(val, "\")
    if !val
        return
    if DirExist(val) {
        ST.AlbumPath := val
        return
    }
    path := CleanPath(val)
    if path && DirExist(path) {
        ST.AlbumPath := path
        ctrl.Value := path
    }
}

OnWM_DROPFILES(wParam, lParam, msg, hwnd) {
    count := DllCall("Shell32\DragQueryFileW"
        , "Ptr", wParam, "UInt", 0xFFFFFFFF, "Ptr", 0, "UInt", 0, "UInt")
    if count < 1 {
        DllCall("Shell32\DragFinish", "Ptr", wParam)
        return 0
    }
    reqLen := DllCall("Shell32\DragQueryFileW"
        , "Ptr", wParam, "UInt", 0, "Ptr", 0, "UInt", 0, "UInt")
    bufChars := reqLen + 2
    buf := Buffer(bufChars * 2, 0)
    DllCall("Shell32\DragQueryFileW"
        , "Ptr", wParam, "UInt", 0, "Ptr", buf, "UInt", bufChars, "UInt")
    rawPath := StrGet(buf, "UTF-16")
    pt := Buffer(8)
    DllCall("Shell32\DragQueryPoint", "Ptr", wParam, "Ptr", pt)
    dx := NumGet(pt, 0, "Int")
    dy := NumGet(pt, 4, "Int")
    DllCall("Shell32\DragFinish", "Ptr", wParam)
    path := CleanPath(rawPath)
    if !path {
        ToolTip("⚠ 드롭 경로 인식 실패`n" rawPath)
        SetTimer(() => ToolTip(), -3000)
        return 0
    }
    if ST.Mode = "A" {
        if _HitCtrl(UI.EdtRoot, dx, dy) || !_HitAnyRight(dx, dy) {
            ST.Root := path
            UI.EdtRoot.Value := path
        }
    } else {
        if _HitCtrl(UI.EdtFrame, dx, dy) {
            ST.FramePath := path
            UI.EdtFrame.Value := path
        } else if _HitCtrl(UI.EdtAlbum, dx, dy) {
            ST.AlbumPath := path
            UI.EdtAlbum.Value := path
        } else if !ST.FramePath || ST.FramePath = "" {
            ST.FramePath := path
            UI.EdtFrame.Value := path
        } else {
            ST.AlbumPath := path
            UI.EdtAlbum.Value := path
        }
    }
    ToolTip("📂 " path)
    SetTimer(() => ToolTip(), -1500)
    return 0
}

_HitCtrl(ctrl, x, y) {
    try {
        ctrl.GetPos(&cx, &cy, &cw, &ch)
        return x >= cx && x <= cx + cw && y >= cy && y <= cy + ch
    }
    return false
}

_HitAnyRight(x, y) {
    try {
        UI.PicF.GetPos(&px, &py, &pw, &ph)
        if x >= px
            return true
    }
    return false
}

; ============================================================
;  스플리터 드래그 (SepSide: 좌/우)
;
;  ■ hit 판정 방식 변경 — HWND 의존 → 클라이언트 X 좌표 범위
;    이유: ctrlHwnd 비교는 WS_EX_TRANSPARENT/빠른 이동 시 빗나갈 수 있음.
;         X 좌표 기반은 어떤 자식 컨트롤이 포커스를 가져가도 정확히 동작.
;
;  hit area: [SIDE_W - HIT_EXTRA, SIDE_W + SEP_SIDE_W + HIT_EXTRA]
;            SEP_SIDE_W=6, HIT_EXTRA=2 → 총 10px (보이는 라인=2px 유지)
; ============================================================

; 현재 X 좌표가 SepSide hit area 안에 있는지 판정
_InSepSideHit(cx, cy) {
    global SIDE_W
    SEP_SIDE_W := 6
    HIT_EXTRA  := 2
    BodyTopY   := LAYOUT.HDR_H
    return (cy >= BodyTopY)
        && (cx >= SIDE_W - HIT_EXTRA)
        && (cx <= SIDE_W + SEP_SIDE_W + HIT_EXTRA)
}

; 헤더 컬럼 경계 hit 판정 — 경계 ±3px 이내면 컬럼 인덱스(1~3) 반환, 아니면 0
_HitLVColBorder(cx, cy) {
    global _LVHdrTop, _LVHdrH, LV_COL_W
    if (cy < _LVHdrTop || cy > _LVHdrTop + _LVHdrH)
        return 0
    cols := _GetLVColWidths(SIDE_W)
    HIT := 4
    bx := 0
    Loop 3 {
        bx += cols[A_Index]
        if (cx >= bx - HIT && cx <= bx + HIT)
            return A_Index
    }
    return 0
}

OnWM_LButtonDown(wParam, lParam, msg, hwnd) {
    global DRAG, SIDE_W, _EPDrag, COLDRAG
    _GetMouseClientXY(&cx, &cy)

    ; 헤더 컬럼 경계 드래그 시작
    colIdx := _HitLVColBorder(cx, cy)
    if colIdx > 0 {
        cols := _GetLVColWidths(SIDE_W)
        COLDRAG.Active := true
        COLDRAG.ColIdx := colIdx
        COLDRAG.StartX := cx
        COLDRAG.StartWidths := [cols[1], cols[2], cols[3], cols[4]]
        COLDRAG.LastT := 0
        DllCall("SetCapture", "Ptr", UI.G.Hwnd)
        return
    }

    ; 탐색기 패널 스플리터 hit 테스트 (우선순위 높음 — 더 좁은 영역)
    epSide := _EP_HitSplitter(cx, cy)
    if epSide != "" {
        _EP_StartDrag(epSide, cx)
        return
    }

    ; 기존 사이드바 스플리터
    if !_InSepSideHit(cx, cy)
        return

    DRAG.Active     := true
    DRAG.Target     := "SIDE"
    DRAG.StartX     := cx
    DRAG.StartSideW := SIDE_W
    DRAG.LastT      := 0

    _SetSplitterLineColor(UI.SepSideLine, LINE_A)
    DllCall("SetCapture", "Ptr", UI.G.Hwnd)
}

OnWM_LButtonUp(wParam, lParam, msg, hwnd) {
    global DRAG, _EPDrag, COLDRAG

    ; 헤더 컬럼 드래그 종료
    if COLDRAG.Active {
        COLDRAG.Active := false
        DllCall("ReleaseCapture")
        SaveLvColWidths()
        return
    }

    ; 탐색기 패널 스플리터 드래그 종료
    if _EPDrag.Active {
        _EP_EndDrag()
        return
    }

    if !DRAG.Active
        return
    DRAG.Active    := false
    DRAG.Target    := ""
    DRAG.JustEnded := true
    DllCall("ReleaseCapture")
    _SetSplitterLineColor(UI.SepSideLine, LINE_P)
    DoLayout(_LW, _LH)
    try SaveUiSettings()
}

OnWM_MouseMove(wParam, lParam, msg, hwnd) {
    global DRAG, SIDE_W, _LW, _LH, _EPDrag, COLDRAG, LV_COL_W

    ; 헤더 컬럼 드래그 중
    if COLDRAG.Active {
        t := A_TickCount
        if (t - COLDRAG.LastT < 16)
            return
        COLDRAG.LastT := t
        _GetMouseClientXY(&cx, &cy)
        dx := cx - COLDRAG.StartX
        ci := COLDRAG.ColIdx
        sw := COLDRAG.StartWidths
        MIN_COL := 30
        newW := Max(MIN_COL, sw[ci] + dx)
        delta := newW - sw[ci]
        nextW := Max(MIN_COL, sw[ci + 1] - delta)
        LV_COL_W := [sw[1], sw[2], sw[3], sw[4]]
        LV_COL_W[ci]     := newW
        LV_COL_W[ci + 1] := nextW
        DoLayout(_LW, _LH)
        return
    }

    ; 탐색기 패널 스플리터 드래그 중
    if _EPDrag.Active {
        _GetMouseClientXY(&cx, &cy)
        _EP_OnDragMove(cx)
        return
    }

    ; 1) Hover 시각 라인 색 변경 — 커서 제어는 OnWM_SetCursor가 담당
    if !DRAG.Active {
        _GetMouseClientXY(&cx, &cy)
        static _ls := -1
        sidHov := _InSepSideHit(cx, cy) ? 1 : 0
        if DRAG.JustEnded {
            DRAG.JustEnded := false
            _ls := -1
        }
        if sidHov != _ls {
            _ls := sidHov
            _SetSplitterLineColor(UI.SepSideLine, sidHov ? LINE_A : LINE_P)
        }
        return
    }

    ; 2) 사이드바 드래그 중 실시간 리사이즈 — throttle 16ms (~60fps)
    t := A_TickCount
    if (t - DRAG.LastT < 16)
        return
    DRAG.LastT := t

    _GetMouseClientXY(&cx, &cy)
    dx := cx - DRAG.StartX

    SEP_SIDE_W := 6
    LeftMinW  := 260
    RightMinW := 720
    maxLeft := _LW - RightMinW - SEP_SIDE_W
    if (maxLeft < LeftMinW)
        maxLeft := LeftMinW
    newW := _Clamp(DRAG.StartSideW + dx, LeftMinW, maxLeft)
    if (newW != SIDE_W) {
        SIDE_W := newW
        DoLayout(_LW, _LH)
    }
}

; ============================================================
;  WM_SETCURSOR (0x0020) 핸들러
;
;  원리: Windows는 마우스 이동마다 WM_SETCURSOR를 해당 창에 보내고,
;        DefWindowProc가 이를 처리하며 커서를 클래스 기본값(화살표)으로 리셋.
;        WM_MOUSEMOVE에서 SetCursor를 호출해도 곧바로 덮어씌워지는 이유.
;
;  해결: WM_SETCURSOR를 가로채서 return 1 → DefWindowProc 호출 차단.
;        우선순위: 드래그 중 > hit zone hover > 기본 처리
; ============================================================

OnWM_SetCursor(wParam, lParam, msg, hwnd) {
    global DRAG, SIDE_W, _EPDrag, COLDRAG

    ; 헤더 컬럼 드래그 중
    if COLDRAG.Active {
        DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Ptr", 32644, "Ptr"))
        return 1
    }

    ; 탐색기 패널 스플리터 드래그 중 또는 호버
    if _EPDrag.Active {
        DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Ptr", 32644, "Ptr"))
        return 1
    }

    ; 사이드바 드래그 중
    if DRAG.Active {
        DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Ptr", 32644, "Ptr"))
        return 1
    }

    _GetMouseClientXY(&cx, &cy)

    ; 헤더 컬럼 경계 hover
    if _HitLVColBorder(cx, cy) > 0 {
        DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Ptr", 32644, "Ptr"))
        return 1
    }

    ; 탐색기 패널 스플리터 hover
    if _EP_HitSplitter(cx, cy) != "" {
        DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Ptr", 32644, "Ptr"))
        return 1
    }

    ; 사이드바 스플리터 hover
    if _InSepSideHit(cx, cy) {
        DllCall("SetCursor", "Ptr", DllCall("LoadCursor", "Ptr", 0, "Ptr", 32644, "Ptr"))
        return 1
    }
}

_Clamp(v, mn, mx) {
    return Max(mn, Min(mx, v))
}

; ============================================================
;  ListView 컬럼 폭 변경 감지 — WM_NOTIFY / HDN_ENDTRACK(W)
;  HDN_ENDTRACKW(-327): 사용자가 헤더 분리선 드래그를 완료한 시점에 1회 발화
;  → SetTimer로 300ms 디바운스 후 _SaveLVColWidths() 1회 호출
; ============================================================

; LV hwnd 변경 감지용 (되돌아감 추적)
global _LV_LastHwnd := 0
global _NM_CUSTOMDRAW_Count := 0

; 스캔/필터/정렬/리프레시 시 호출 — pill 배지 유지 보장
EnsureCustomDrawBound() {
    try DllCall("InvalidateRect", "Ptr", UI.LV.Hwnd, "Ptr", 0, "Int", 1)
}

OnWM_NOTIFY(wParam, lParam, msg, hwnd) {
    global _LV_LastHwnd
    code := NumGet(lParam, A_PtrSize * 2, "Int")
    hwndFrom := NumGet(lParam, 0, "Ptr")

    ; LVN_ENDLABELEDIT = -105 — 폴더 패널 인라인 리네임 완료
    if code = -105 {
        ; ★ 리네임 엔트리포인트 로그: 어느 ListView가 이벤트를 받았는지
        try {
            lvName := ""
            if hwndFrom = UI.ExpLvF.Hwnd
                lvName := "ExpLvF(액자)"
            else if hwndFrom = UI.ExpLvA.Hwnd
                lvName := "ExpLvA(앨범)"
            else if hwndFrom = UI.LV.Hwnd
                lvName := "LV(상단매칭리스트)"
            else
                lvName := "OTHER(hwnd=" hwndFrom ")"
            OutputDebug("[RENAME] OnNotify code=-105 hwndFrom=" hwndFrom " lv=" lvName " ExpLvF=" UI.ExpLvF.Hwnd " ExpLvA=" UI.ExpLvA.Hwnd " LV=" UI.LV.Hwnd "`n")
        }
        try {
            if hwndFrom = UI.ExpLvF.Hwnd || hwndFrom = UI.ExpLvA.Hwnd {
                ret := _EP_OnEndLabelEdit(lParam)
                OutputDebug("[RENAME] OnNotify → _EP_OnEndLabelEdit returned " ret "`n")
                return ret
            }
            OutputDebug("[RENAME] OnNotify → NOT routed (hwndFrom not ExpLvF/ExpLvA)`n")
        }
    }

    ; HDN_ENDTRACKW = -327, HDN_ENDTRACK(ANSI) = -307
    if code = -327 || code = -307 {
        try {
            hdrHwnd := SendMessage(0x101F, 0, 0, UI.LV)
            if hwndFrom = hdrHwnd
                SetTimer(_SaveLVColWidths, -300)
        }
    }
}

; ── 리사이즈 드래그 구간 최적화 (버튼 깨짐/잔상 방지) ──
; 원인: WM_SIZE 연속 호출로 Move() 과다 + EXITSIZEMOVE 시 LV만 Redraw하여 버튼바 미갱신
OnWM_ENTERSIZEMOVE(wParam, lParam, msg, hwnd) {
    global _Resizing
    _Resizing := true
}

OnWM_EXITSIZEMOVE(wParam, lParam, msg, hwnd) {
    global _Resizing
    _Resizing := false
    SetTimer(_ForceRepaintAfterResize, -50)   ; 50ms: 창 안정화 후 재그리기
}

; 드래그 종료 시 전체 레이아웃 1회 재정렬 + 버튼바 포함 강제 리프레시
_ForceRepaintAfterResize() {
    try {
        hMain := UI.G.Hwnd
        rc := Buffer(16, 0)
        if !DllCall("GetClientRect", "Ptr", hMain, "Ptr", rc)
            return
        w := NumGet(rc, 8, "Int")
        h := NumGet(rc, 12, "Int")
        if w < 100 || h < 100
            return
        DoLayout(w, h)
        ; RDW_ERASE(0x04)|INVALIDATE(0x01)|UPDATENOW(0x100)|ALLCHILDREN(0x80) — 잔상 제거 + 버튼바 재그리기
        DllCall("RedrawWindow", "Ptr", hMain, "Ptr", 0, "Ptr", 0, "UInt", 0x0185)
        ; LV pill 배지 보정
        hLv := UI.LV.Hwnd
        cnt := ST.Filtered.Length
        if cnt > 0
            DllCall("SendMessageW", "Ptr", hLv, "UInt", 0x1015, "Ptr", 0, "Ptr", cnt - 1, "Ptr")
        DllCall("RedrawWindow", "Ptr", hLv, "Ptr", 0, "Ptr", 0, "UInt", 0x0501)
    }
}

; ============================================================
;  NM_CUSTOMDRAW — 상태 컬럼(column 0) pill 배지 렌더링
;  ★ 핵심 규칙: 핸들러 내부에서 UI.LV에 AHK 메시지를 보내면 안 됨 (재진입 방지)
;    → GetText 금지, AHK SendMessage 금지, DllCall("SendMessageW",...) 만 사용
;  MATCH: #49B56A 연녹 / NOT FOUND: #E55353 빨강 / text: white
; ============================================================

_LV_CustomDraw(lParam) {
    static is64 := A_PtrSize = 8
    static O_STAGE := is64 ? 24 : 12
    static O_HDC   := is64 ? 32 : 16
    static O_ITEM  := is64 ? 56 : 36
    static O_SUB   := is64 ? 88 : 56

    ; GDI 리소스 캐싱
    static MatchBr := 0, MatchPn := 0
    static NotFndBr := 0, NotFndPn := 0
    static WhiteBr := 0
    if (!MatchBr) {
        MatchBr := DllCall("CreateSolidBrush", "UInt", 0x006AB549, "Ptr")
        MatchPn := DllCall("CreatePen", "Int", 0, "Int", 0, "UInt", 0x006AB549, "Ptr")
        NotFndBr := DllCall("CreateSolidBrush", "UInt", 0x005353E5, "Ptr")
        NotFndPn := DllCall("CreatePen", "Int", 0, "Int", 0, "UInt", 0x005353E5, "Ptr")
        WhiteBr := DllCall("CreateSolidBrush", "UInt", 0x00FFFFFF, "Ptr")
    }

    stage := NumGet(lParam, O_STAGE, "UInt")

    if stage = 1          ; CDDS_PREPAINT
        return 0x20       ; CDRF_NOTIFYITEMDRAW
    if stage = 0x10001 {  ; CDDS_ITEMPREPAINT
        ; ★ 기본 텍스트 색을 흰색(배경과 동일)으로 — column 0 빈 문자열 미표시 보장
        NumPut("UInt", 0x00FFFFFF, lParam, is64 ? 72 : 44)  ; clrText = white
        return 0x22       ; CDRF_NOTIFYSUBITEMDRAW | CDRF_NEWFONT
    }
    if stage != 0x30001   ; CDDS_SUBITEMPREPAINT only
        return 0

    iSub := NumGet(lParam, O_SUB, "Int")
    if iSub != 0
        return 0          ; column 0 only

    hdc  := NumGet(lParam, O_HDC, "Ptr")
    iRow := NumGet(lParam, O_ITEM, "Ptr")
    row  := Integer(iRow) + 1

    if iRow < 0 || row < 1
        return 0

    try lvH := UI.LV.Hwnd
    catch
        return 0

    ; ── column 0 rect ──
    global _LV_Col0W
    rcBuf := Buffer(16, 0)
    NumPut("Int", 0, rcBuf, 0)
    NumPut("Int", 0, rcBuf, 4)
    DllCall("SendMessageW", "Ptr", lvH, "UInt", 0x1038, "Ptr", iRow, "Ptr", rcBuf, "Ptr")
    rowL  := NumGet(rcBuf, 0, "Int")
    rowT  := NumGet(rcBuf, 4, "Int")
    rowB  := NumGet(rcBuf, 12, "Int")
    ; [Fix] 캐시(_LV_Col0W)가 레이아웃 변경 전 값일 수 있으므로
    ;       LVM_GETCOLUMNWIDTH(0x101D)로 실제 폭을 매 드로우마다 직접 측정.
    ;       DllCall("SendMessageW")을 사용 — CustomDraw 내 AHK SendMessage 재진입 방지.
    col0W := DllCall("SendMessageW", "Ptr", lvH, "UInt", 0x101D, "Ptr", 0, "Ptr", 0, "Ptr")
    if col0W > 10
        _LV_Col0W := col0W   ; 캐시도 최신값으로 갱신
    else
        col0W := _LV_Col0W > 10 ? _LV_Col0W : 76
    rowR  := rowL + col0W
    colW  := col0W
    cellH := rowB - rowT

    if colW < 10 || cellH < 4
        return 4  ; CDRF_SKIPDEFAULT

    ; ── 상태 텍스트 ──
    text := ""
    if HasProp(ST, "RowState") && row <= ST.RowState.Length
        text := ST.RowState[row]
    if !text && HasProp(ST, "Filtered") && row <= ST.Filtered.Length && HasProp(ST, "Frames")
        try text := ST.Frames[ST.Filtered[row]].status = "MATCH" ? "MATCH" : "NOT FOUND"
    if InStr(text, "MATCH")
        text := "✔ MATCH"
    else if InStr(text, "NOT")
        text := "✕ NOT FOUND"
    else
        return 4  ; CDRF_SKIPDEFAULT (빈 셀 유지)

    isMatch := InStr(text, "MATCH")
    
    ; ── 렌더링 ──
    saved := DllCall("SaveDC", "Ptr", hdc, "Int")
    hRgn := DllCall("CreateRectRgn", "Int", rowL, "Int", rowT, "Int", rowR, "Int", rowB, "Ptr")
    DllCall("SelectClipRgn", "Ptr", hdc, "Ptr", hRgn)

    ; 셀 클리어
    bgRc := Buffer(16, 0)
    NumPut("Int", rowL, bgRc, 0),  NumPut("Int", rowT, bgRc, 4)
    NumPut("Int", rowR, bgRc, 8),  NumPut("Int", rowB, bgRc, 12)
    DllCall("FillRect", "Ptr", hdc, "Ptr", bgRc, "Ptr", WhiteBr)

    ; pill
    padX := 10, padY := 4
    sz := Buffer(8, 0)
    DllCall("GetTextExtentPoint32W", "Ptr", hdc, "WStr", text, "Int", StrLen(text), "Ptr", sz)
    tw := NumGet(sz, 0, "Int"), th := NumGet(sz, 4, "Int")
    pillW := Min(tw + padX * 2, Max(24, colW - 8))
    pillH := Min(th + padY * 2, Max(16, cellH - 6))
    pillX := rowL + Integer((colW - pillW) / 2)
    pillY := rowT + Integer((cellH - pillH) / 2)
    rad   := Integer(pillH / 2)

    if pillW >= 4 && pillH >= 4 {
        hBr := isMatch ? MatchBr : NotFndBr
        hPn := isMatch ? MatchPn : NotFndPn
        DllCall("SelectObject", "Ptr", hdc, "Ptr", hBr)
        DllCall("SelectObject", "Ptr", hdc, "Ptr", hPn)
        DllCall("RoundRect", "Ptr", hdc
            , "Int", pillX, "Int", pillY
            , "Int", pillX + pillW, "Int", pillY + pillH
            , "Int", rad, "Int", rad)
        DllCall("SetBkMode", "Ptr", hdc, "Int", 1)
        DllCall("SetTextColor", "Ptr", hdc, "UInt", 0x00FFFFFF)
        trc := Buffer(16, 0)
        NumPut("Int", pillX, trc, 0),          NumPut("Int", pillY, trc, 4)
        NumPut("Int", pillX + pillW, trc, 8),  NumPut("Int", pillY + pillH, trc, 12)
        DllCall("DrawTextW", "Ptr", hdc, "WStr", text, "Int", -1, "Ptr", trc, "UInt", 0x0825)
    }

    DllCall("RestoreDC", "Ptr", hdc, "Int", saved)
    DllCall("DeleteObject", "Ptr", hRgn)
    return 4   ; CDRF_SKIPDEFAULT
}

_GetMouseClientXY(&cx, &cy) {
    CoordMode("Mouse", "Screen")
    MouseGetPos(&sx, &sy)
    pt := Buffer(8, 0)
    NumPut("Int", sx, pt, 0)
    NumPut("Int", sy, pt, 4)
    DllCall("ScreenToClient", "Ptr", UI.G.Hwnd, "Ptr", pt)
    cx := NumGet(pt, 0, "Int")
    cy := NumGet(pt, 4, "Int")
}

; 스플리터 시각 라인 색 동적 변경 (Primary ↔ Accent) + 즉시 리페인트
; ctrl.Opt() → AHK 내부 WM_CTLCOLORSTATIC 브러시 갱신 → Redraw()로 반영
_SetSplitterLineColor(ctrl, hex) {
    try {
        ctrl.Opt("Background" . hex)
        ctrl.Redraw()
    }
}
