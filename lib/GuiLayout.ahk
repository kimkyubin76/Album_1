; ============================================================
;  lib/GuiLayout.ahk — 창 크기 변경 + 레이아웃 계산
;  의존: Globals.ahk (UI, ST, _LW, _LH), Preview.ahk (SetPic)
; ============================================================

OnResize(thisGui, minMax, w, h) {
    if minMax = -1
        return
    try UI.PicF.Value := ""
    try UI.PicA.Value := ""
    DoLayout(w, h)
    SetTimer(_RefreshPreviews, -120)
}

_RefreshPreviews() {
    try {
        if UI._PicFPath
            SetPic(UI.PicF, UI._PicFPath)
        if UI._PicAPath
            SetPic(UI.PicA, UI._PicAPath)
    }
}

DoLayout(w, h) {
    global _LW, _LH, SIDE_W
    w := Integer(Max(920, w))
    h := Integer(Max(620, h))
    _LW := w
    _LH := h

    ; ── 중간 프레임 렌더 방지: Move() 전 WM_PAINT 차단 ──────────────
    hwnd := UI.G.Hwnd
    DllCall("SendMessage", "Ptr", hwnd, "UInt", 0x000B, "Ptr", 0, "Ptr", 0) ; WM_SETREDRAW false

    M  := 10
    GAP := 6
    HDR := LAYOUT.HDR_H - 1   ; 헤더 배경 높이 (SepHdr 직전까지)
    BOT_H := LAYOUT.BOT_H

    ; ■ 공용 기준선 (바닥선 단일화 — 좌/우/중앙 모두 동일 Y)
    BodyTopY    := LAYOUT.HDR_H
    BaseY       := h - BOT_H
    BodyBottomY := BaseY - 1
    bodyH       := BodyBottomY - BodyTopY + 1

    ; ── 헤더 ────────────────────────────────────────────────────────
    UI.HdrBg.Move(0, 0, w, HDR)
    UI.SepHdr.Move(0, BodyTopY - 1, w, 1)   ; HDR 직하 1px

    settX := w - M - 30
    cancX := settX - GAP - 66
    scanX := cancX - GAP - 84
    cMX   := scanX - GAP - 80
    cNFX  := cMX   - 4   - 80
    cTX   := cNFX  - 4   - 70

    UI.ChipTotal.Move(cTX,   13, 70, 24)
    UI.ChipNF.Move(cNFX,     13, 80, 24)
    UI.ChipMatch.Move(cMX,   13, 80, 24)
    UI.BtnScan.Move(scanX,   12, 84, 28)
    UI.BtnCancel.Move(cancX, 12, 66, 28)
    UI.BtnSettings.Move(settX, 12, 30, 28)

    browseBtnW := 74
    browseBtnX := cTX - GAP - browseBtnW
    edtW       := Max(80, browseBtnX - GAP - 350)

    UI.G["LblRoot"].Move(312, 14, 36, 22)
    UI.EdtRoot.Move(350, 13, edtW, 24)
    UI.BtnRoot.Move(browseBtnX, 12, browseBtnW, 26)

    bBtnW  := 62
    bBtnX  := cTX - GAP - bBtnW
    bEdtW  := Max(60, bBtnX - GAP - 350)
    UI.G["LblFrame"].Move(312, 9, 36, 20)
    UI.EdtFrame.Move(350, 8, bEdtW, 20)
    try UI.G["BtnFrame"].Move(bBtnX, 7, bBtnW, 22)
    UI.G["LblAlbum"].Move(312, 29, 36, 20)
    UI.EdtAlbum.Move(350, 28, bEdtW, 20)
    try UI.G["BtnAlbum"].Move(bBtnX, 27, bBtnW, 22)

    ; ── 사이드바 (BodyTopY ~ BodyBottomY, BaseY 기준) ─────────────────
    TAB_H  := LAYOUT.TAB_H
    GRP_H  := LAYOUT.GRP_H
    HINT_H := LAYOUT.HINT_H

    tabW := Integer(SIDE_W / 3)
    UI.FTabAll.Move(0,        BodyTopY, tabW,              TAB_H)
    UI.FTabNF.Move(tabW,      BodyTopY, tabW,              TAB_H)
    UI.FTabM.Move(tabW * 2,   BodyTopY, SIDE_W - tabW * 2, TAB_H)

    UI.GrpSum.Move(0, BodyTopY + TAB_H, SIDE_W, GRP_H)

    lvHdrTop     := BodyTopY + TAB_H + GRP_H
    lvBot        := BodyBottomY - HINT_H
    lvH          := Max(80, lvBot - lvHdrTop)

    ; ListView (네이티브 헤더 포함, lvHdrTop부터 시작)
    UI.LV.Move(0, lvHdrTop, SIDE_W, lvH)

    UI.LVHint.Move(0, lvBot, SIDE_W, HINT_H)
    SEP_SIDE_W := 6
    ; 세로 스플리터 — BaseY까지 정확히 닿게 (바닥선 단차 제거)
    UI.SepSide.Move(SIDE_W, BodyTopY, SEP_SIDE_W, BaseY - BodyTopY)
    UI.SepSideLine.Move(SIDE_W + 2, BodyTopY, 2, BaseY - BodyTopY)

    ; LV 컬럼 너비 (저장값 우선, 없으면 자동 계산 — ListView.ahk/_SetLVColWidths)
    _SetLVColWidths()

    ; ── 상세 패널 (BodyTopY ~ BodyBottomY, BaseY 기준) ─────────────────
    detX := SIDE_W + SEP_SIDE_W
    detW := Max(300, w - detX)

    FILE_HDR_H := LAYOUT.FILE_HDR_H
    curY := BodyTopY
    UI.FileHdrBgM.Move(detX, curY, detW, FILE_HDR_H)
    UI.FileHdrBgN.Move(detX, curY, detW, FILE_HDR_H)

    ; StatusBadge 고정 폭 — "  ✕  NOT FOUND  " 가 가장 긴 텍스트 (9pt bold 맑은 고딕)
    badgeW  := 130
    memoW   := 96
    showMemo := (detW >= 300 + badgeW + memoW)
    nameW    := Max(80, detW - badgeW - (showMemo ? memoW + 4 : 0) - M * 3)
    UI.FileHdrName.Move(detX + M, curY + 5, nameW, 26)
    UI.FileHdrSub.Move(detX + M, curY + 33, detW - M * 2, 16)
    UI.StatusBadge.Move(detX + M + nameW + M, curY + 12, badgeW, 28)
    UI.BtnMemo.Move(showMemo ? (detX + M + nameW + M + badgeW + 4) : -999
        , curY + 14, memoW, 24)

    curY += FILE_HDR_H

    PIC_LBL_H  := LAYOUT.PIC_LBL_H
    PIC_FOOT_H := LAYOUT.PIC_FOOT_H
    ACTION_H   := LAYOUT.ACTION_H

    ; ── 미리보기 높이 적응형 계산 ───────────────────────────────────────
    ; 탐색기 패널이 항상 최소 공간(EXP_MIN_H)을 확보하도록 picH를 상한 제한
    ;  ▸ EXP_MIN_H = 구분선+툴바+패널헤더+풋+LV최소(100px)
    EXP_MIN_H   := LAYOUT.EXP_DIVIDER_H + LAYOUT.EXP_TOOLBAR_H
                 + LAYOUT.EXP_PANE_HDR_H + LAYOUT.EXP_FOOT_H + 100
    fixedAboveH := FILE_HDR_H + PIC_LBL_H + PIC_FOOT_H + ACTION_H
    availForPic := Max(60, BodyBottomY - BodyTopY - fixedAboveH - EXP_MIN_H)
    picMaxH     := LAYOUT.PIC_H_FIXED - PIC_LBL_H - PIC_FOOT_H   ; 최대 236px
    picH        := Max(60, Min(picMaxH, availForPic))

    ; 우측 내부 분할 — 50:50 고정 비율 (DETAIL_SPLIT_MODE = "FIXED_50", 드래그 불가)
    ; origW + SEP_DET_W + matchW = detW 항등식 보장 → 1px 단차/빈틈 없음
    SEP_DET_W := 6
    OrigMinW  := 300
    origW     := Max(OrigMinW, Integer((detW - SEP_DET_W) / 2))
    matchW    := detW - SEP_DET_W - origW   ; 나머지 전부 (홀수 detW 시 matchW가 1px 더 가짐)
    cardW     := origW

    sepX   := detX + origW
    aCardX := sepX + SEP_DET_W

    UI.PicLblF.Move(detX, curY, cardW, PIC_LBL_H)
    UI.SepPicF.Move(detX, curY + PIC_LBL_H - 1, cardW, 1)      ; Secondary: 타이틀 하단
    UI.PicF.Move(detX, curY + PIC_LBL_H, cardW, picH)
    UI.PicFootF.Move(detX, curY + PIC_LBL_H + picH, cardW, PIC_FOOT_H)

    ; 스플리터(우측 내부) — 프리뷰 섹션 높이에만 한정
    ; (기존 BaseY - curY 는 액션바/탐색기 영역까지 침범하는 버그)
    previewSectionH := PIC_LBL_H + picH + PIC_FOOT_H
    UI.SepDetail.Move(sepX, curY, SEP_DET_W, previewSectionH)
    UI.SepDetailLine.Move(sepX + 2, curY, 2, previewSectionH)

    ; BadgeTop 폭을 텍스트 측정("표지-가족사진" 등)으로 동적 산정
    badgeW2 := UI.BadgeTop.Visible ? _MeasureBadgeW(UI.BadgeTop, 20, Integer(matchW * 0.5)) : 52
    UI.PicLblA.Move(aCardX, curY, matchW - badgeW2 - 4, PIC_LBL_H)
    UI.BadgeTop.Move(aCardX + matchW - badgeW2, curY, badgeW2, PIC_LBL_H)
    UI.SepPicA.Move(aCardX, curY + PIC_LBL_H - 1, matchW, 1)   ; Secondary: 타이틀 하단
    UI.PicA.Move(aCardX, curY + PIC_LBL_H, matchW, picH)
    UI.TxtNone.Move(aCardX, curY + PIC_LBL_H + Integer(picH / 2) - 30, matchW, 60)
    UI.PicFootA.Move(aCardX, curY + PIC_LBL_H + picH, matchW, PIC_FOOT_H)

    curY += PIC_LBL_H + picH + PIC_FOOT_H

    ; ── 액션 바 ──────────────────────────────────────────────────────
    _LayoutActionBar(detX, detW, curY, M)
    curY += ACTION_H

    ; ── 탐색기 섹션 ──────────────────────────────────────────────────
    _LayoutExplorer(detX, detW, curY, BaseY, M)

    ; ── 하단 진행바 (BaseY = 바닥선, 단일 Y로 좌/우 일직선) ─────────────
    UI.SepBot.Move(0, BaseY, w, 1)
    prgY := BaseY + 2
    prgW := Max(160, Integer(w * 0.38))
    UI.TxtProg.Move(M, prgY, Max(100, w - prgW - M * 3), 20)
    UI.Prg.Move(w - M - prgW, prgY + 7, prgW, 10)

    ; ── Redraw 재활성화 + 전체 재그리기 (IExplorerBrowser 하위창 포함) ───
    DllCall("SendMessage", "Ptr", hwnd, "UInt", 0x000B, "Ptr", 1, "Ptr", 0) ; WM_SETREDRAW true
    ; RedrawWindow: RDW_INVALIDATE(0x01)|RDW_ALLCHILDREN(0x80)|RDW_UPDATENOW(0x100)
    ; IExplorerBrowser 의 SysListView32 등 손자 창까지 강제 재그리기
    DllCall("RedrawWindow", "Ptr", hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x181)
    EnsureCustomDrawBound()
}

; ============================================================
;  _LayoutActionBar — 우측 패널 하단 액션 바 배치
;
;  설계 규칙:
;   ▸ 우측 3버튼(Prev/NextNF/Next): 오른쪽 앵커, 항상 표시
;   ▸ 좌측 5버튼: 우선순위(Copy>Locate>OpenF>AlbumDir>FrameDir) 순으로
;     공간 충분하면 표시, 부족하면 화면 밖(-999)으로 이동(겹침 방지)
;
;  좌측 가용 폭 = detW - (우측그룹 296px) - M(좌여백)
;   ├ detW ≥ 762 → 5개 모두 표시
;   ├ detW ≥ 660 → 4개 (BtnFrameDir 숨김)
;   ├ detW ≥ 562 → 3개
;   ├ detW ≥ 486 → 2개
;   └ detW ≥ 392 → 1개 (BtnCopy만)
; ============================================================

_LayoutActionBar(detX, detW, startY, M) {
    ; ── 구분선 ──────────────────────────────────────────────────────
    UI.SepAction.Move(detX, startY, detW, 1)
    startY += 4

    ; ── 드롭다운 행 ─────────────────────────────────────────────────
    relW := Max(80, detW - 200 - M * 2)
    UI.TxtRel.Move(detX + M, startY, relW, 22)
    cmbW := Min(180, Max(60, detW - relW - 60 - M * 3))
    UI.CmbMatch.Move(detX + M + relW + 4, startY, cmbW, 22)
    UI.TxtMCnt.Move(detX + M + relW + 4 + cmbW + 4, startY, 44, 22)

    ; ── 버튼 행 ─────────────────────────────────────────────────────
    bY   := startY + 26
    bH   := 28
    LGAP := 4    ; 좌측 버튼 간격
    RGAP := 6    ; 우측 버튼 간격
    OFF  := -999 ; 화면 밖 X (겹침 방지용 숨김 대체)

    ; 우측 그룹: 오른쪽 앵커 (항상 표시)
    ; 총 점유폭 = 64 + RGAP + 142 + RGAP + 68 + M = 296px
    UI.BtnNext.Move(  detX + detW - M - 68,                               bY, 68,  bH)
    UI.BtnNextNF.Move(detX + detW - M - 68  - RGAP - 142,                 bY, 142, bH)
    UI.BtnPrev.Move(  detX + detW - M - 68  - RGAP - 142 - RGAP - 64,    bY, 64,  bH)

    ; 좌측 그룹: 우선순위 순 배치, 공간 부족 시 낮은 우선순위부터 OFF
    avail := detW - 296 - M   ; 좌측에 쓸 수 있는 최대 폭
    cx    := detX + M
    _PlaceOrHide(UI.BtnCopy,     bY, 82, bH, &avail, &cx, OFF, LGAP)
    _PlaceOrHide(UI.BtnLocate,   bY, 90, bH, &avail, &cx, OFF, LGAP)
    _PlaceOrHide(UI.BtnOpenF,    bY, 72, bH, &avail, &cx, OFF, LGAP)
    _PlaceOrHide(UI.BtnAlbumDir, bY, 98, bH, &avail, &cx, OFF, LGAP)
    _PlaceOrHide(UI.BtnFrameDir, bY, 98, bH, &avail, &cx, OFF, LGAP)
}

; 버튼 1개를 배치하거나 화면 밖으로 이동 (ByRef avail, cx 갱신)
_PlaceOrHide(ctrl, bY, bW, bH, &avail, &cx, off, gap) {
    if avail >= bW {
        ctrl.Move(cx, bY, bW, bH)
        cx    += bW + gap
        avail -= bW + gap
    } else
        ctrl.Move(off, bY, bW, bH)
}

; ============================================================
;  _LayoutExplorer — 탐색기 섹션 배치
;  startY: 액션 바 직후 Y, baseY: 바닥선 Y
; ============================================================

_LayoutExplorer(detX, detW, startY, baseY, M) {
    DIV_H      := LAYOUT.EXP_DIVIDER_H
    TOOL_H     := LAYOUT.EXP_TOOLBAR_H
    PANE_HDR_H := LAYOUT.EXP_PANE_HDR_H
    FOOT_H     := LAYOUT.EXP_FOOT_H
    MID_W      := 1   ; 중앙 구분선 1px

    ; ── 섹션 구분선 ──────────────────────────────────────────────────
    UI.ExpDivider.Move(detX, startY, detW, DIV_H)
    curY := startY + DIV_H

    ; ── 공통 툴바 ─────────────────────────────────────────────────────
    UI.ExpToolbar.Move(detX, curY, detW, TOOL_H)
    ; 버튼 좌측 정렬
    bx := detX + M
    bY := curY + Integer((TOOL_H - 22) / 2)
    for btn in [UI.ExpBtnCopyPath, UI.ExpBtnLocate] {
        btn.Move(bx, bY, 82, 22)
        bx += 82 + 4
    }
    bx += 4   ; 구분 간격
    for btn in [UI.ExpBtnCopy, UI.ExpBtnMove] {
        btn.Move(bx, bY, 92, 22)
        bx += 92 + 4
    }
    bx += 4
    UI.ExpBtnDel.Move(bx, bY, 60, 22)
    ; 오른쪽 앵커
    UI.ExpBtnRefresh.Move(detX + detW - M - 70, bY, 70, 22)
    curY += TOOL_H

    ; ── 두 패널 폭 계산 (픽셀 완전 일치 — 1px 오차 없음) ───────────────
    ;  leftW = Floor((containerW - splitterW) / 2)
    ;  rightW = containerW - splitterW - leftW
    ;  → leftW + MID_W + rightW == detW 항등식 보장
    paneH  := Max(60, baseY - curY)
    leftW  := Floor((detW - MID_W) / 2)       ; 액자 패널 폭
    rightW := detW - MID_W - leftW             ; 앨범 패널 폭 (나머지 전부)
    splitX := detX + leftW                     ; 구분선 X
    aCardX := splitX + MID_W                   ; 앨범 패널 시작 X

    ; ── 디버그 로그 (좌표 합 검증) ──────────────────────────────────────
    ; OutputDebug("[ExpLay] detX=" detX " detW=" detW " leftW=" leftW " MID_W=" MID_W " rightW=" rightW " sum=" (leftW+MID_W+rightW) "`n")

    ; ── 액자 패널 ────────────────────────────────────────────────────
    upW  := 30
    lblW := 90
    UI.ExpPaneHdrF.Move(detX, curY, lblW, PANE_HDR_H)
    UI.ExpPathF.Move(detX + lblW, curY, leftW - lblW - upW, PANE_HDR_H)
    UI.ExpUpF.Move(detX + leftW - upW, curY + Integer((PANE_HDR_H - 22) / 2), upW - 2, 22)

    lvY := curY + PANE_HDR_H
    lvH := Max(60, paneH - PANE_HDR_H - FOOT_H)

    ExpPaneResize("F", detX, lvY, leftW, lvH)
    UI.ExpStatF.Move(detX, lvY + lvH, leftW, FOOT_H)

    ; ── 중앙 구분선 (1px 단일 라인) ─────────────────────────────────
    UI.ExpSepMid.Move(splitX, curY, MID_W, paneH)

    ; ── 앨범 패널 ────────────────────────────────────────────────────
    UI.ExpPaneHdrA.Move(aCardX, curY, lblW, PANE_HDR_H)
    UI.ExpPathA.Move(aCardX + lblW, curY, rightW - lblW - upW, PANE_HDR_H)
    UI.ExpUpA.Move(aCardX + rightW - upW, curY + Integer((PANE_HDR_H - 22) / 2), upW - 2, 22)

    ExpPaneResize("A", aCardX, lvY, rightW, lvH)
    UI.ExpStatA.Move(aCardX, lvY + lvH, rightW, FOOT_H)
    EnsureCustomDrawBound()
}

; ListView 헤더 높이를 API로 측정 — 최초 1회만 측정 후 캐시
; LVM_GETHEADER(0x101F)로 헤더 HWND를 얻고, GetWindowRect로 실제 픽셀 높이 계산
_GetLvHdrH() {
    static _h := 0
    if _h > 0
        return _h
    try {
        hdrHwnd := SendMessage(0x101F, 0, 0, UI.LV)   ; LVM_GETHEADER
        rc := Buffer(16, 0)
        DllCall("GetWindowRect", "Ptr", hdrHwnd, "Ptr", rc)
        _h := NumGet(rc, 12, "Int") - NumGet(rc, 4, "Int")   ; bottom - top
    }
    return _h > 0 ? _h : 22   ; API 실패 시 기본값 22px
}

; 배지 컨트롤의 현재 텍스트를 GDI 측정하여 필요 폭 반환 (padX 양쪽 포함)
; minW: 최소 폭, maxW: 최대 폭 (초과 시 SS_ENDELLIPSIS가 "…" 처리)
_MeasureBadgeW(ctrl, minW, maxW) {
    try {
        txt := ctrl.Text
        if txt = "" || txt = "—"
            return minW
        hdc := DllCall("GetDC", "Ptr", ctrl.Hwnd, "Ptr")
        hFont := SendMessage(0x0031, 0, 0, ctrl)   ; WM_GETFONT
        oldFont := DllCall("SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr")
        sz := Buffer(8, 0)
        DllCall("GetTextExtentPoint32W", "Ptr", hdc, "WStr", txt, "Int", StrLen(txt), "Ptr", sz)
        textW := NumGet(sz, 0, "Int")
        DllCall("SelectObject", "Ptr", hdc, "Ptr", oldFont)
        DllCall("ReleaseDC", "Ptr", ctrl.Hwnd, "Ptr", hdc)
        padX := 16
        return _Clamp(textW + padX * 2, minW, maxW)
    }
    return minW
}
