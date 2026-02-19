; lib/GuiSettings.ahk
; 의존: Globals.ahk (UI, FILT, ST), Config.ahk, Scan.ahk

OnOpenSettings(*) {
    dg := Gui("+Owner" UI.G.Hwnd " +ToolWindow", "⚙ 필터 및 분류 설정")
    dg.SetFont("s10", "맑은 고딕")
    dg.BackColor := "F0F2F5"
    dg.Opt("+MinSize450x420")

    colW := 256
    rX   := 286

    dg.SetFont("s10 bold")
    dg.Add("Text", "x15 y10 w" colW " h22", "🚫 제외 필터")
    dg.SetFont("s9 norm")

    dg.Add("Text", "x15 y34 w" colW " h18 c555555", "📄 파일명 (부분일치, 와일드카드)")
    dg.SetFont("s9", "Consolas")
    edPat := dg.Add("Edit", "x15 y54 w" colW " h100 Multi WantReturn VScroll", FILT.RawText)
    dg.SetFont("s9 norm", "맑은 고딕")

    dg.Add("Text", "x15 y160 w" colW " h18 c555555", "📁 폴더명 (경로 내 폴더와 매칭)")
    dg.SetFont("s9", "Consolas")
    edDir := dg.Add("Edit", "x15 y180 w" colW " h70 Multi WantReturn VScroll", FILT.DirRawText)
    dg.SetFont("s9 norm", "맑은 고딕")

    dg.SetFont("s10 bold")
    dg.Add("Text", "x" rX " y10 w" colW " h22", "🏷️ 폴더 분류 키워드")
    dg.SetFont("s9 norm")

    dg.Add("Text", "x" rX " y34 w" colW " h18 c555555", "🖼️ 액자로 분류할 키워드")
    dg.SetFont("s9", "Consolas")
    edFrameKW := dg.Add("Edit", "x" rX " y54 w" colW " h100 Multi WantReturn VScroll", FILT.FrameKWText)
    dg.SetFont("s9 norm", "맑은 고딕")

    dg.Add("Text", "x" rX " y160 w" colW " h18 c555555", "📕 앨범으로 분류할 키워드")
    dg.SetFont("s9", "Consolas")
    edAlbumKW := dg.Add("Edit", "x" rX " y180 w" colW " h70 Multi WantReturn VScroll", FILT.AlbumKWText)
    dg.SetFont("s9 norm", "맑은 고딕")

    fullW := rX + colW
    dg.Add("Text", "x15 y260 w" fullW " h1 +0x10")
    dg.Add("Text", "x15 y268 w" fullW " h36 c888888 Wrap"
        , "한 줄에 하나씩 입력. 폴더명에 키워드가 포함되면 해당 유형으로 자동 분류됩니다.`n"
        . "예: '표지' 입력 → '표지-가족사진x' 폴더가 앨범으로 분류")

    chkCase := dg.Add("Checkbox", "x15 y310 w200 h22"
        . (FILT.IgnoreCase ? " Checked" : ""), "대소문자 무시")
    chkRx := dg.Add("Checkbox", "x220 y310 w200 h22"
        . (FILT.UseRegex ? " Checked" : ""), "정규식 사용 (고급)")

    ; ── 액자 폴더 자동선택 옵션 ──
    dg.Add("Text", "x15 y338 w" fullW " h1 +0x10")
    dg.SetFont("s10 bold")
    dg.Add("Text", "x15 y346 w" fullW " h22", "📂 스캔 옵션")
    dg.SetFont("s9 norm")
    chkAutoFrame := dg.Add("Checkbox", "x15 y370 w400 h22"
        . (ST.AutoSelectAllFrames ? " Checked" : ""), "액자 폴더 전체 자동 선택 (선택창 표시 안함)")

    dg.Add("Text", "x15 y398 w" fullW " h20 c888888"
        , "제외: 파일 " FILT.Patterns.Length "개 + 폴더 " FILT.DirPatterns.Length "개"
        . "  |  분류: 액자 " FILT.FrameKW.Length "개 + 앨범 " FILT.AlbumKW.Length "개"
        . (FILT.Excluded > 0 ? "  |  제외 " FILT.Excluded "개" : ""))

    dg.Add("Button", "x15 y428 w90 h30 Default", "적용")
       .OnEvent("Click", (*) => _ApplySettings(dg, edPat, edDir, edFrameKW, edAlbumKW, chkCase, chkRx, chkAutoFrame))
    dg.Add("Button", "x115 y428 w90 h30", "기본값")
       .OnEvent("Click", (*) => (
           edPat.Value     := "Thumbs.db`ndesktop.ini`n._*`n~$*`n*.tmp",
           edDir.Value     := "설명서",
           edFrameKW.Value := "",
           edAlbumKW.Value := "표지`n가족사진",
           chkCase.Value   := true,
           chkRx.Value     := false,
           chkAutoFrame.Value := false
       ))
    dg.Add("Button", "x" (fullW - 75) " y428 w90 h30", "닫기")
       .OnEvent("Click", (*) => dg.Destroy())
    dg.OnEvent("Close", (*) => dg.Destroy())

    dg.Show("w" (fullW + 15) " h470")
}

_ApplySettings(dg, edPat, edDir, edFrameKW, edAlbumKW, chkCase, chkRx, chkAutoFrame) {
    FILT.RawText     := edPat.Value
    FILT.DirRawText  := edDir.Value
    FILT.FrameKWText := edFrameKW.Value
    FILT.AlbumKWText := edAlbumKW.Value
    FILT.IgnoreCase  := chkCase.Value
    FILT.UseRegex    := chkRx.Value
    ST.AutoSelectAllFrames := chkAutoFrame.Value
    _ParsePatterns()
    SaveFilterSettings()
    dg.Destroy()

    if ST.Frames.Length > 0 {
        UI.G.Opt("+OwnDialogs")
        r := MsgBox("설정이 저장되었습니다.`n"
            . "제외: 파일 " FILT.Patterns.Length "개 + 폴더 " FILT.DirPatterns.Length "개`n"
            . "분류: 액자 " FILT.FrameKW.Length "개 + 앨범 " FILT.AlbumKW.Length "개`n`n"
            . "정확한 적용을 위해 재스캔을 권장합니다.`n지금 재스캔 하시겠습니까?"
            , "설정 적용", "YesNo Iconi")
        if r = "Yes"
            OnScan()
    } else {
        ToolTip("✅ 설정 저장됨")
        SetTimer(() => ToolTip(), -2000)
    }
}
