; ============================================================
;  lib/Preview.ahk — 미리보기 + 네비게이션
;  의존: Globals.ahk (ST, UI, CFG), GdipUtil.ahk (SetPic), PathUtil.ahk
; ============================================================

OnItemFocus(ctrl, row) {
    if row < 1
        return
    ST.SelRow := row
    if row > ST.Filtered.Length {
        ClearPreview()
        return
    }
    e := ST.Frames[ST.Filtered[row]]

    UI.FileHdrName.Text := e.name
    UI.FileHdrSub.Text  := "  " e.subdir

    if e.status = "MATCH" {
        UI.FileHdrBgM.Visible := true
        UI.FileHdrBgN.Visible := false
        UI.StatusBadge.Text := "  ✓  MATCH  "
        UI.StatusBadge.Opt("BackgroundF0FDF4 c15803D")
        UI.BtnMemo.Visible := false

        if e.albumNum != "" && e.albumNum != "-" && e.albumNum != "?" {
            ; MATCH: 앨범번호 | 파일명 형태로 표시
            if (e.HasProp("albumMatchFile") && e.albumMatchFile != "")
                UI.BadgeTop.Text := e.albumNum " | " e.albumMatchFile
            else
                UI.BadgeTop.Text := e.albumNum " | (파일없음)"
            UI.BadgeTop.Visible := true
            _RepositionBadgeTop()
        } else {
            UI.BadgeTop.Visible := false
        }

        UI.TxtNone.Visible := false
        SetPic(UI.PicA, e.matchPaths[1])

        UI.TxtRel.Text    := "  " (e.albumRel ? e.albumRel : "—")
        UI.TxtRel.ToolTip := e.matchPaths[1]
        UI.FullPath       := e.matchPaths[1]

        items := []
        for mp in e.matchPaths
            items.Push(mp)
        UI.CmbMatch.Delete()
        UI.CmbMatch.Add(items)
        UI.CmbMatch.Choose(1)
        UI.TxtMCnt.Text := e.matchPaths.Length > 1 ? "(" e.matchPaths.Length "개)" : ""

        UI.PicFootA.Text := "  " _ShortPath(e.matchPaths[1])

        UI.BtnCopy.Enabled   := true
        UI.BtnLocate.Enabled := true

    } else {
        UI.FileHdrBgM.Visible := false
        UI.FileHdrBgN.Visible := true
        UI.StatusBadge.Text := "  ✕  NOT FOUND  "
        UI.StatusBadge.Opt("BackgroundFEF2F2 cB91C1C")
        UI.BtnMemo.Visible := true

        UI.BadgeTop.Visible := false
        UI.TxtNone.Visible  := true
        try UI.PicA.Value   := ""

        UI.TxtRel.Text    := "  앨범에서 찾을 수 없음"
        UI.TxtRel.ToolTip := ""
        UI.FullPath       := ""

        UI.CmbMatch.Delete()
        UI.CmbMatch.Add(["(매칭 없음)"])
        UI.CmbMatch.Choose(1)
        UI.TxtMCnt.Text := ""

        UI.PicFootA.Text := ""

        UI.BtnCopy.Enabled   := false
        UI.BtnLocate.Enabled := false
    }

    SetPic(UI.PicF, e.path)
    UI.PicFootF.Text := "  " _ShortPath(e.path)

    ; 탐색기 패널 동기화
    matchPath := (e.status = "MATCH" && e.matchPaths.Length > 0) ? e.matchPaths[1] : ""
    ExpSync(e.path, matchPath)
}

_ShortPath(p) {
    parts := StrSplit(p, "\")
    n     := parts.Length
    if n <= 2
        return p
    return "…\" parts[n-1] "\" parts[n]
}

OnMatchCombo(ctrl, *) {
    if ST.SelRow < 1 || ST.SelRow > ST.Filtered.Length
        return
    e  := ST.Frames[ST.Filtered[ST.SelRow]]
    ci := ctrl.Value
    if ci < 1 || ci > e.matchPaths.Length
        return
    mp := e.matchPaths[ci]
    SetPic(UI.PicA, mp)
    r  := RelPath(mp, ST.AlbumPath)
    n  := AlbumNum(r)
    UI.TxtRel.Text    := "  " r
    UI.TxtRel.ToolTip := mp
    UI.FullPath       := mp
    UI.PicFootA.Text  := "  " _ShortPath(mp)
    if n != "" && n != "-" && n != "?" {
        SplitPath(mp, &fn)
        UI.BadgeTop.Text    := fn != "" ? (n " | " fn) : (n " | (파일없음)")
        UI.BadgeTop.Visible := true
        _RepositionBadgeTop()
    } else {
        UI.BadgeTop.Visible := false
    }
}

ClearPreview() {
    UI._PicFPath := ""
    UI._PicAPath := ""
    try UI.PicF.Value := ""
    try UI.PicA.Value := ""
    UI.TxtNone.Visible  := false
    UI.BadgeTop.Visible := false
    UI.FileHdrBgM.Visible := true
    UI.FileHdrBgN.Visible := false
    UI.FileHdrName.Text := "파일을 선택하세요"
    UI.FileHdrSub.Text  := "—"
    UI.StatusBadge.Text := "—"
    UI.StatusBadge.Opt("BackgroundEFF6FF c1D4ED8")
    UI.BtnMemo.Visible  := false
    UI.TxtRel.Text      := "—"
    UI.TxtRel.ToolTip   := ""
    UI.FullPath          := ""
    UI.PicFootF.Text     := ""
    UI.PicFootA.Text     := ""
    UI.CmbMatch.Delete()
    UI.CmbMatch.Add(["(매칭 결과 없음)"])
    UI.CmbMatch.Choose(1)
    UI.TxtMCnt.Text      := ""
    UI.BtnCopy.Enabled   := false
    UI.BtnLocate.Enabled := false
}

SetPic(ctrl, path) {
    if ctrl.Hwnd = UI.PicF.Hwnd
        UI._PicFPath := path
    else if ctrl.Hwnd = UI.PicA.Hwnd
        UI._PicAPath := path
    try {
        ctrl.GetPos(, , &pw, &ph)
        pw := pw > 10 ? pw : CFG.ThumbW
        ph := ph > 10 ? ph : CFG.ThumbH
        hBmp := _GdipLoadRotated(path, pw, ph)
        if hBmp
            ctrl.Value := "HBITMAP:*" hBmp
        else
            ctrl.Value := "*w" pw " *h" ph " " path
    } catch as err {
        OutputDebug("[SetPic ERR] " err.Message "`n")
        try ctrl.Value := "*w" pw " *h" ph " " path
    }
}

NavNext() {
    if ST.Filtered.Length < 1
        return
    r := Min(ST.Filtered.Length, ST.SelRow + 1)
    UI.LV.Modify(0, "-Select -Focus")
    UI.LV.Modify(r, "Select Focus Vis")
}

NavPrev() {
    if ST.Filtered.Length < 1
        return
    r := Max(1, ST.SelRow - 1)
    UI.LV.Modify(0, "-Select -Focus")
    UI.LV.Modify(r, "Select Focus Vis")
}

NavNextNF() {
    if ST.Filtered.Length < 1
        return
    start := ST.SelRow < 1 ? 1 : ST.SelRow + 1
    Loop ST.Filtered.Length {
        r := start + A_Index - 1
        if r > ST.Filtered.Length
            r := r - ST.Filtered.Length
        e := ST.Frames[ST.Filtered[r]]
        if e.status != "MATCH" {
            UI.LV.Modify(0, "-Select -Focus")
            UI.LV.Modify(r, "Select Focus Vis")
            return
        }
    }
    ToolTip("✓ NOT FOUND 파일이 없습니다")
    SetTimer(() => ToolTip(), -2000)
}

; BadgeTop 텍스트 변경 후 폭/위치를 즉시 재계산 (DoLayout 전체 호출 없이 가볍게)
_RepositionBadgeTop() {
    try {
        UI.PicLblA.GetPos(&ax, &ay, , &ah)
        UI.PicFootA.GetPos(, , &totalW)
        aCardX := ax
        matchW := totalW
        badgeW2 := _MeasureBadgeW(UI.BadgeTop, 20, Integer(matchW * 0.5))
        UI.PicLblA.Move(aCardX, ay, matchW - badgeW2 - 4, ah)
        UI.BadgeTop.Move(aCardX + matchW - badgeW2, ay, badgeW2, ah)
        parentRight := aCardX + matchW
        OutputDebug("[BadgeTop] text=" UI.BadgeTop.Text " matchW=" matchW
            " badgeW=" badgeW2 " badgeX=" (aCardX + matchW - badgeW2)
            " badgeRight=" (aCardX + matchW) " parentRight=" parentRight "`n")
    }
}
