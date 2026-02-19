; lib/GuiBuild.ahk
; 역할: GUI 컨트롤 생성 + 이벤트 바인딩 (모든 핸들러 참조 → 맨 마지막 로드)
; 의존: 모든 모듈

BuildGui() {
    g := Gui("+Resize +MinSize920x620", "액자-앨범 매칭 검수기 v4.0")
    g.SetFont("s10", "맑은 고딕")
    g.BackColor := "F5F4F0"
    g.OnEvent("Size",  OnResize)
    g.OnEvent("Close", (*) => (ExpPaneDestroyAll(), ExitApp()))
    UI.G := g

    UI.HdrBg := g.Add("Text", "x0 y0 w10 h48 BackgroundWhite", "")

    g.SetFont("s11 bold", "맑은 고딕")
    UI.Logo := g.Add("Text", "x14 y13 w114 h26 +0x200 BackgroundWhite c0284C7", "photo·match")
    g.SetFont("s8 norm", "맑은 고딕")
    UI.VerLbl := g.Add("Text", "x130 y32 w30 h14 BackgroundWhite c9CA3AF", "v4.0")
    g.SetFont("s9 norm", "맑은 고딕")

    UI.BtnModeA := g.Add("Button", "x166 y12 w66 h26", "자동(A)")
    UI.BtnModeB := g.Add("Button", "x236 y12 w66 h26", "수동(B)")
    UI.BtnModeA.OnEvent("Click", (*) => SwitchMode("A"))
    UI.BtnModeB.OnEvent("Click", (*) => SwitchMode("B"))

    g.Add("Text", "x312 y16 w36 h22 +0x200 BackgroundWhite vLblRoot", "루트:")
    UI.EdtRoot := g.Add("Edit", "x350 y14 w10 h22 vEdtRoot BackgroundWhite")
    UI.EdtRoot.OnEvent("Change", OnEditRoot)
    UI.BtnRoot := g.Add("Button", "x10 y12 w74 h26 vBtnRoot", "폴더 선택…")
    UI.BtnRoot.OnEvent("Click", OnBrowseRoot)

    g.Add("Text", "x312 y10 w36 h20 +0x200 Hidden BackgroundWhite vLblFrame", "액자:")
    UI.EdtFrame := g.Add("Edit", "x350 y8 w10 h20 Hidden vEdtFrame BackgroundWhite")
    UI.EdtFrame.OnEvent("Change", OnEditFrame)
    UI.BtnFrame := g.Add("Button", "x10 y6 w62 h22 Hidden vBtnFrame", "선택…")
    UI.BtnFrame.OnEvent("Click", OnBrowseFrame)

    g.Add("Text", "x312 y30 w36 h20 +0x200 Hidden BackgroundWhite vLblAlbum", "앨범:")
    UI.EdtAlbum := g.Add("Edit", "x350 y28 w10 h20 Hidden vEdtAlbum BackgroundWhite")
    UI.EdtAlbum.OnEvent("Change", OnEditAlbum)
    UI.BtnAlbum := g.Add("Button", "x10 y26 w62 h22 Hidden vBtnAlbum", "선택…")
    UI.BtnAlbum.OnEvent("Click", OnBrowseAlbum)

    g.SetFont("s9 bold", "맑은 고딕")
    UI.ChipTotal := g.Add("Text", "x10 y13 w70 h24 +0x200 +Center BackgroundEFF6FF c1D4ED8", "전체 0")
    UI.ChipNF    := g.Add("Text", "x10 y13 w80 h24 +0x200 +Center BackgroundFEF2F2 cB91C1C", "✕ NF 0")
    UI.ChipMatch := g.Add("Text", "x10 y13 w80 h24 +0x200 +Center BackgroundF0FDF4 c15803D", "✓ MATCH 0")
    g.SetFont("s9 norm", "맑은 고딕")

    UI.BtnScan     := g.Add("Button", "x10 y12 w84 h28", "▶ 스캔")
    UI.BtnCancel   := g.Add("Button", "x10 y12 w66 h28 Disabled", "✕ 취소")
    UI.BtnSettings := g.Add("Button", "x10 y12 w30 h28", "⚙")
    UI.BtnScan.OnEvent("Click",     OnScan)
    UI.BtnCancel.OnEvent("Click",   (*) => (ST.Cancel := true))
    UI.BtnSettings.OnEvent("Click", OnOpenSettings)

    UI.SepHdr := g.Add("Text", "x0 y48 w10 h1 Background" . LINE_P)   ; Primary

    g.SetFont("s9 bold", "맑은 고딕")
    UI.FTabAll := g.Add("Button", "x0 y50 w10 h28", "전체")
    UI.FTabNF  := g.Add("Button", "x0 y50 w10 h28", "✕ NOT FOUND")
    UI.FTabM   := g.Add("Button", "x0 y50 w10 h28", "✓ MATCH")
    g.SetFont("s9 norm", "맑은 고딕")
    UI.FTabAll.OnEvent("Click", (*) => ApplyFilter("ALL"))
    UI.FTabNF.OnEvent("Click",  (*) => ApplyFilter("NOT"))
    UI.FTabM.OnEvent("Click",   (*) => ApplyFilter("MATCH"))

    UI.GrpSum := g.Add("Text", "x0 y80 w10 h20 +0x200 c555555 BackgroundF5F4F0", "  스캔 전")

    ; ── 커스텀 헤더 배경 (연한 파랑) ──
    UI.LVHdrBg := g.Add("Text", "x0 y100 w10 h24 BackgroundEFF6FF")

    ; ── 커스텀 헤더 컬럼명 ──
    g.SetFont("s9 bold", "맑은 고딕")
    UI.LVHdr1 := g.Add("Text", "x0 y100 w58 h24 +0x200 +Center BackgroundEFF6FF c1D4ED8", "앨범")
    UI.LVHdr2 := g.Add("Text", "x58 y100 w58 h24 +0x200 +Center BackgroundEFF6FF c1D4ED8", "상태")
    UI.LVHdr3 := g.Add("Text", "x116 y100 w60 h24 +0x200 BackgroundEFF6FF c1D4ED8", " 사이즈폴더")
    UI.LVHdr4 := g.Add("Text", "x176 y100 w60 h24 +0x200 BackgroundEFF6FF c1D4ED8", " 파일명")
    g.SetFont("s9 norm", "맑은 고딕")

    ; ── 헤더 하단 구분선 ──
    UI.LVHdrSep := g.Add("Text", "x0 y124 w10 h1 Background9DC3E6")

    ; ── 커스텀 헤더 클릭 이벤트 ──
    UI.LVHdr1.OnEvent("Click", (*) => OnLVColClick(UI.LV, 1))
    UI.LVHdr2.OnEvent("Click", (*) => OnLVColClick(UI.LV, 2))
    UI.LVHdr3.OnEvent("Click", (*) => OnLVColClick(UI.LV, 3))
    UI.LVHdr4.OnEvent("Click", (*) => OnLVColClick(UI.LV, 4))

    ; ── ListView (네이티브 헤더 숨김) ──
    UI.LV := g.Add("ListView"
        , "x0 y125 w10 h10 +LV0x10020 +Grid NoSortHdr -Hdr -Multi BackgroundWhite"
        , ["앨범", "상태", "사이즈폴더", "파일명"])
    UI.LV.OnEvent("ItemFocus", OnItemFocus)
    UI.LV.OnEvent("ColClick",  OnLVColClick)

    ; Explorer 테마 명시적 제거 — NM_CUSTOMDRAW pill 배지와 충돌(hot tracking 오버레이가 덮어씀)
    ; DOUBLEBUFFER(0x10000) + FULLROWSELECT(0x20)으로 깜박임/선택 표시 충분히 처리
    DllCall("uxtheme\SetWindowTheme", "Ptr", UI.LV.Hwnd, "Str", "", "Str", "")

    ; 포커스 점선 숨김
    DllCall("SendMessage", "Ptr", UI.LV.Hwnd, "UInt", 0x0127, "Ptr", 0x10001, "Ptr", 0)

    ; DOUBLEBUFFER(0x10000) | FULLROWSELECT(0x20) | SUBITEMIMAGES(0x0002)
    SendMessage(0x1036, 0x10022, 0x10022, UI.LV)   ; LVM_SETEXTENDEDLISTVIEWSTYLE

    global _LV_LastHwnd
    _LV_LastHwnd := UI.LV.Hwnd
    OutputDebug("[LV] created hwnd=" UI.LV.Hwnd " (BuildGui)`n")

    ; WM_NOTIFY — LV pill 배지: Show 이전에 등록 (첫 페인트부터 pill 적용)
    static _notifyBound := false
    if !_notifyBound {
        OnMessage(0x004E, OnWM_NOTIFY)
        _notifyBound := true
        OutputDebug("[BuildGui] OnMessage(0x004E) 등록 (LV 생성 직후)`n")
    }

    ; ★ 리사이즈 완료 후 pill 강제 리페인트
    static _sizeBound := false
    if !_sizeBound {
        OnMessage(0x0232, OnWM_EXITSIZEMOVE)  ; WM_EXITSIZEMOVE
        _sizeBound := true
    }

    g.SetFont("s8 norm", "맑은 고딕")
    UI.LVHint := g.Add("Text", "x0 y0 w10 h16 +0x200 c9CA3AF BackgroundF5F4F0"
        , "  F1전체  F2 MATCH  F3 NF  F4 다음NF!")
    g.SetFont("s9 norm", "맑은 고딕")

    ; SepSide: 6px 히트영역 — 드래그 클릭용, body 색으로 시각적 투명화
    UI.SepSide := g.Add("Text", "x230 y50 w6 h10 BackgroundF5F4F0")
    ; SepSideLine: 히트영역 중앙 2px 시각 라인(Primary) — WS_EX_TRANSPARENT(0x20)으로 마우스 통과
    UI.SepSideLine := g.Add("Text", "x232 y50 w2 h10 Background" . LINE_P)
    DllCall("SetWindowLongPtr", "Ptr", UI.SepSideLine.Hwnd, "Int", -20
        , "Ptr", DllCall("GetWindowLongPtr", "Ptr", UI.SepSideLine.Hwnd, "Int", -20, "Ptr") | 0x20)

    UI.FileHdrBgM := g.Add("Text", "x0 y0 w10 h52 BackgroundWhite", "")
    UI.FileHdrBgN := g.Add("Text", "x0 y0 w10 h52 BackgroundFFF5F5 Hidden", "")

    g.SetFont("s11 bold", "맑은 고딕")
    UI.FileHdrName := g.Add("Text", "x0 y0 w10 h26 +0x4200 BackgroundWhite", "파일을 선택하세요")  ; +0x4000=SS_ENDELLIPSIS
    g.SetFont("s9 norm", "맑은 고딕")
    UI.FileHdrSub  := g.Add("Text", "x0 y0 w10 h18 +0x4200 BackgroundWhite c78716C", "—")

    g.SetFont("s9 bold", "맑은 고딕")
    ; +0x4200 = SS_ENDELLIPSIS | SS_CENTERIMAGE — 폭 초과 시 "…" 말줄임 + 세로 중앙
    UI.StatusBadge := g.Add("Text", "x0 y0 w120 h26 +0x4200 +Center BackgroundEFF6FF c1D4ED8", "—")
    g.SetFont("s9 norm", "맑은 고딕")

    UI.BtnMemo := g.Add("Button", "x0 y0 w94 h24 Hidden", "📞 고객 메모")
    UI.BtnMemo.OnEvent("Click", OnCustomerMemo)

    g.SetFont("s9 bold", "맑은 고딕")
    UI.PicLblF := g.Add("Text", "x0 y0 w10 h24 +0x200 c0284C7 BackgroundEFF6FF", "  🖼  액자 원본")
    UI.PicLblA := g.Add("Text", "x0 y0 w10 h24 +0x200 c15803D BackgroundF0FDF4", "  📒  앨범 매칭")
    g.SetFont("s9 norm", "맑은 고딕")
    ; 섹션 타이틀(원본/매칭) 하단 Secondary 구분선
    UI.SepPicF := g.Add("Text", "x0 y0 w10 h1 Background" . LINE_S)
    UI.SepPicA := g.Add("Text", "x0 y0 w10 h1 Background" . LINE_S)

    g.SetFont("s9 bold", "맑은 고딕")
    ; +0x4200 = SS_ENDELLIPSIS | SS_CENTERIMAGE — 긴 앨범번호("표지-가족사진") 대응
    UI.BadgeTop := g.Add("Text"
        , "x0 y0 w120 h24 +0x4200 +Center cWhite Background1D4ED8 Hidden", "")
    g.SetFont("s9 norm", "맑은 고딕")

    UI.PicF := g.Add("Picture", "x0 y0 w10 h10 BackgroundWhite", "")

    ; SepDetail: 6px 히트영역 — 드래그용
    UI.SepDetail := g.Add("Text", "x0 y0 w6 h10 BackgroundF5F4F0")
    ; SepDetailLine: 2px 시각 라인(Primary) — WS_EX_TRANSPARENT(0x20)으로 마우스 통과
    UI.SepDetailLine := g.Add("Text", "x0 y0 w2 h10 Background" . LINE_P)
    DllCall("SetWindowLongPtr", "Ptr", UI.SepDetailLine.Hwnd, "Int", -20
        , "Ptr", DllCall("GetWindowLongPtr", "Ptr", UI.SepDetailLine.Hwnd, "Int", -20, "Ptr") | 0x20)

    UI.PicA := g.Add("Picture", "x0 y0 w10 h10 BackgroundWhite", "")

    g.SetFont("s12 bold", "맑은 고딕")
    UI.TxtNone := g.Add("Text"
        , "x0 y0 w10 h60 +0x200 +Center cB91C1C BackgroundFFF5F5 Hidden"
        , "앨범에서 찾을 수 없음")
    g.SetFont("s9 norm", "맑은 고딕")

    g.SetFont("s8 norm", "맑은 고딕")
    UI.PicFootF := g.Add("Text", "x0 y0 w10 h18 +0x200 c78716C BackgroundF8F7F5", "")
    UI.PicFootA := g.Add("Text", "x0 y0 w10 h18 +0x200 c78716C BackgroundF8F7F5", "")
    g.SetFont("s9 norm", "맑은 고딕")

    UI.SepAction := g.Add("Text", "x0 y0 w10 h1 Background" . LINE_S)   ; Secondary

    g.SetFont("s8 norm", "맑은 고딕")
    UI.TxtRel := g.Add("Text", "x0 y0 w10 h22 +0x200 c57534E", "—")
    g.SetFont("s9 norm", "맑은 고딕")
    UI.CmbMatch := g.Add("DropDownList", "x0 y0 w10", ["(없음)"])
    UI.CmbMatch.OnEvent("Change", OnMatchCombo)
    UI.TxtMCnt := g.Add("Text", "x0 y0 w44 h22 +0x200 c0284C7", "")

    UI.BtnCopy     := g.Add("Button", "x0 y0 w82 h28", "📋 경로 복사")
    UI.BtnLocate   := g.Add("Button", "x0 y0 w90 h28", "📂 위치 열기")
    UI.BtnOpenF    := g.Add("Button", "x0 y0 w72 h28", "파일 열기")
    UI.BtnAlbumDir := g.Add("Button", "x0 y0 w98 h28", "앨범 폴더 열기")
    UI.BtnFrameDir := g.Add("Button", "x0 y0 w98 h28", "액자 폴더 열기")

    UI.BtnCopy.OnEvent("Click",     OnCopyPath)
    UI.BtnLocate.OnEvent("Click",   OnLocateAlbumFile)
    UI.BtnOpenF.OnEvent("Click",    OnOpenFile)
    UI.BtnAlbumDir.OnEvent("Click", OnOpenAlbumDir)
    UI.BtnFrameDir.OnEvent("Click", OnOpenFrameDir)
    UI.BtnCopy.Enabled   := false
    UI.BtnLocate.Enabled := false

    UI.BtnPrev   := g.Add("Button", "x0 y0 w64 h28", "← 이전")
    UI.BtnNextNF := g.Add("Button", "x0 y0 w142 h28", "⚠ 다음 NOT FOUND")
    UI.BtnNext   := g.Add("Button", "x0 y0 w68 h28",  "다음 →")
    UI.BtnPrev.OnEvent("Click",   (*) => NavPrev())
    UI.BtnNextNF.OnEvent("Click", (*) => NavNextNF())
    UI.BtnNext.OnEvent("Click",   (*) => NavNext())

    ; ══ 탐색기 섹션 구분선 ══════════════════════════════════════════════
    g.SetFont("s9 bold", "맑은 고딕")
    UI.ExpDivider := g.Add("Text", "x0 y0 w10 h28 +0x200 c374151 BackgroundECEEF2"
        , "  📁 파일 탐색기")
    g.SetFont("s9 norm", "맑은 고딕")

    ; ── 탐색기 공통 툴바 ──────────────────────────────────────────────
    UI.ExpToolbar := g.Add("Text", "x0 y0 w10 h32 BackgroundECEEF2", "")
    ; 툴바 버튼 (초기 위치 0,0 — DoLayout에서 재배치)
    UI.ExpBtnCopyPath := g.Add("Button", "x0 y0 w82 h22",  "📋 경로 복사")
    UI.ExpBtnLocate   := g.Add("Button", "x0 y0 w82 h22",  "📂 위치 열기")
    UI.ExpBtnCopy     := g.Add("Button", "x0 y0 w92 h22",  "⇄ 복사 →앨범")
    UI.ExpBtnMove     := g.Add("Button", "x0 y0 w92 h22",  "⇢ 이동 →앨범")
    UI.ExpBtnDel      := g.Add("Button", "x0 y0 w60 h22",  "✕ 삭제")
    UI.ExpBtnRefresh  := g.Add("Button", "x0 y0 w70 h22",  "↺ 새로고침")
    UI.ExpBtnCopyPath.OnEvent("Click", ExpCopyPath)
    UI.ExpBtnLocate.OnEvent("Click",   (*) => ExpOpenLocation("F"))
    UI.ExpBtnCopy.OnEvent("Click",     ExpCopyToAlbum)
    UI.ExpBtnMove.OnEvent("Click",     ExpMoveToAlbum)
    UI.ExpBtnDel.OnEvent("Click",      ExpDeleteSel)
    UI.ExpBtnRefresh.OnEvent("Click",  ExpRefresh)

    ; ── 액자 탐색기 패널 ─────────────────────────────────────────────
    g.SetFont("s9 bold", "맑은 고딕")
    UI.ExpPaneHdrF := g.Add("Text", "x0 y0 w10 h26 +0x200 c0284C7 BackgroundF8F9FB"
        , "  🖼 액자 폴더")
    g.SetFont("s9 norm", "맑은 고딕")
    UI.ExpPathF := g.Add("Text", "x0 y0 w10 h26 +0x4200 c9CA3AF BackgroundF8F9FB", "  —")
    UI.ExpUpF   := g.Add("Button", "x0 y0 w26 h22", "⬆")
    UI.ExpUpF.OnEvent("Click", (*) => ExpGoUp("F"))

    ; TreeView + ListView 는 g.Show() 이후 ExpPaneInit() 에서 생성됨
    g.SetFont("s8 norm", "맑은 고딕")
    UI.ExpStatF := g.Add("Text", "x0 y0 w10 h20 +0x200 c6B7280 BackgroundF3F4F6"
        , "  —")
    g.SetFont("s9 norm", "맑은 고딕")

    ; ── 탐색기 패널 사이 구분선 ──────────────────────────────────────
    UI.ExpSepMid := g.Add("Text", "x0 y0 w2 h10 Background" . LINE_P)

    ; ── 앨범 탐색기 패널 ─────────────────────────────────────────────
    g.SetFont("s9 bold", "맑은 고딕")
    UI.ExpPaneHdrA := g.Add("Text", "x0 y0 w10 h26 +0x200 c15803D BackgroundF8F9FB"
        , "  📒 앨범 폴더")
    g.SetFont("s9 norm", "맑은 고딕")
    UI.ExpPathA := g.Add("Text", "x0 y0 w10 h26 +0x4200 c9CA3AF BackgroundF8F9FB", "  —")
    UI.ExpUpA   := g.Add("Button", "x0 y0 w26 h22", "⬆")
    UI.ExpUpA.OnEvent("Click", (*) => ExpGoUp("A"))

    g.SetFont("s8 norm", "맑은 고딕")
    UI.ExpStatA := g.Add("Text", "x0 y0 w10 h20 +0x200 c6B7280 BackgroundF3F4F6"
        , "  —")
    g.SetFont("s9 norm", "맑은 고딕")

    UI.SepBot  := g.Add("Text", "x0 y0 w10 h1 Background" . LINE_P)   ; Primary
    UI.TxtProg := g.Add("Text", "x14 y0 w10 h20 +0x200 c555555", "대기 중")
    UI.Prg     := g.Add("Progress", "x0 y0 w10 h8 Range0-1000 c0EA5E9 BackgroundE8E8E8", 0)

    UI.FullPath  := ""
    UI._PicFPath := ""
    UI._PicAPath := ""

    HotIfWinActive("ahk_id " g.Hwnd)
    Hotkey("Right",  (*) => NavNext())
    Hotkey("Left",   (*) => NavPrev())
    Hotkey("Enter",  (*) => NavNext())
    Hotkey("F1",     (*) => ApplyFilter("ALL"))
    Hotkey("F2",     (*) => ApplyFilter("MATCH"))
    Hotkey("F3",     (*) => ApplyFilter("NOT"))
    Hotkey("F4",     (*) => NavNextNF())

    g.Show("w1100 h720")
    ExpPaneInit()   ; TreeView + ListView 컨트롤 생성 (Show 이후)
    DllCall("Shell32\DragAcceptFiles", "Ptr", g.Hwnd, "Int", true)
    OnMessage(0x0233, OnWM_DROPFILES)
    DoLayout(1100, 720)
    EnsureCustomDrawBound()
    OnMessage(0x0200, OnWM_MouseMove)    ; WM_MOUSEMOVE
    OnMessage(0x0201, OnWM_LButtonDown)  ; WM_LBUTTONDOWN
    OnMessage(0x0202, OnWM_LButtonUp)    ; WM_LBUTTONUP
    OnMessage(0x0020, OnWM_SetCursor)    ; WM_SETCURSOR  — 드래그/hover 중 커서 강제 유지
    SwitchMode("A")
}
