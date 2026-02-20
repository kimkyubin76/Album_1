; lib/GuiSettings.ahk
; 의존: Globals.ahk (UI, FILT, ST, REN_CFG), Config.ahk, Scan.ahk

OnOpenSettings(*) {
    dg := Gui("+Owner" UI.G.Hwnd " +ToolWindow", "⚙ 설정")
    dg.SetFont("s10", "맑은 고딕")
    dg.BackColor := "F0F2F5"
    dg.Opt("+MinSize500x520")

    tabs := dg.Add("Tab3", "x10 y10 w480 h450", ["필터 및 분류", "파일명 리네임"])
    
    tabs.UseTab(1)
    
    colW := 210
    rX   := 250

    dg.SetFont("s10 bold")
    dg.Add("Text", "x20 y45 w" colW " h22", "🚫 제외 필터")
    dg.SetFont("s9 norm")

    dg.Add("Text", "x20 y70 w" colW " h18 c555555", "📄 파일명 (부분일치, 와일드카드)")
    dg.SetFont("s9", "Consolas")
    edPat := dg.Add("Edit", "x20 y90 w" colW " h100 Multi WantReturn VScroll", FILT.RawText)
    dg.SetFont("s9 norm", "맑은 고딕")

    dg.Add("Text", "x20 y200 w" colW " h18 c555555", "📁 폴더명 (경로 내 폴더와 매칭)")
    dg.SetFont("s9", "Consolas")
    edDir := dg.Add("Edit", "x20 y220 w" colW " h70 Multi WantReturn VScroll", FILT.DirRawText)
    dg.SetFont("s9 norm", "맑은 고딕")

    dg.SetFont("s10 bold")
    dg.Add("Text", "x" rX " y45 w" colW " h22", "🏷️ 폴더 분류 키워드")
    dg.SetFont("s9 norm")

    dg.Add("Text", "x" rX " y70 w" colW " h18 c555555", "🖼️ 액자로 분류할 키워드")
    dg.SetFont("s9", "Consolas")
    edFrameKW := dg.Add("Edit", "x" rX " y90 w" colW " h100 Multi WantReturn VScroll", FILT.FrameKWText)
    dg.SetFont("s9 norm", "맑은 고딕")

    dg.Add("Text", "x" rX " y200 w" colW " h18 c555555", "📕 앨범으로 분류할 키워드")
    dg.SetFont("s9", "Consolas")
    edAlbumKW := dg.Add("Edit", "x" rX " y220 w" colW " h70 Multi WantReturn VScroll", FILT.AlbumKWText)
    dg.SetFont("s9 norm", "맑은 고딕")

    fullW := 450
    dg.Add("Text", "x20 y300 w" fullW " h1 +0x10")
    dg.Add("Text", "x20 y310 w" fullW " h36 c888888 Wrap"
        , "한 줄에 하나씩 입력. 폴더명에 키워드가 포함되면 해당 유형으로 자동 분류됩니다.`n"
        . "예: '표지' 입력 → '표지-가족사진x' 폴더가 앨범으로 분류")

    chkCase := dg.Add("Checkbox", "x20 y350 w150 h22"
        . (FILT.IgnoreCase ? " Checked" : ""), "대소문자 무시")
    chkRx := dg.Add("Checkbox", "x180 y350 w150 h22"
        . (FILT.UseRegex ? " Checked" : ""), "정규식 사용 (고급)")

    dg.Add("Text", "x20 y380 w" fullW " h1 +0x10")
    dg.SetFont("s10 bold")
    dg.Add("Text", "x20 y390 w" fullW " h22", "📂 스캔 옵션")
    dg.SetFont("s9 norm")
    chkAutoFrame := dg.Add("Checkbox", "x20 y415 w400 h22"
        . (ST.AutoSelectAllFrames ? " Checked" : ""), "액자 폴더 전체 자동 선택 (선택창 표시 안함)")
        
    ; --------------------
    ; Rename Settings Tab
    ; --------------------
    tabs.UseTab(2)
    
    dg.SetFont("s10 bold")
    dg.Add("Text", "x20 y45 w450 h22", "✏️ 파일명 변경 템플릿")
    dg.SetFont("s9 norm")
    
    dg.Add("Text", "x20 y70 w450 h18 c555555", "템플릿 (지원 토큰 클릭 시 삽입됨)")
    edRenTpl := dg.Add("Edit", "x20 y90 w450 h50 Multi WantReturn VScroll", REN_CFG["Template"])
    
    ; Token buttons
    btnY := 145
    dg.Add("Button", "x20 y" btnY " w80 h24", "{album_name}").OnEvent("Click", (*) => EditPaste(edRenTpl, "{album_name}"))
    dg.Add("Button", "x105 y" btnY " w80 h24", "{album_ext}").OnEvent("Click", (*) => EditPaste(edRenTpl, "{album_ext}"))
    dg.Add("Button", "x190 y" btnY " w80 h24", "{album_no}").OnEvent("Click", (*) => EditPaste(edRenTpl, "{album_no}"))
    dg.Add("Button", "x275 y" btnY " w90 h24", "{frame_folder}").OnEvent("Click", (*) => EditPaste(edRenTpl, "{frame_folder}"))
    dg.Add("Button", "x370 y" btnY " w90 h24", "{frame_name}").OnEvent("Click", (*) => EditPaste(edRenTpl, "{frame_name}"))
    
    dg.Add("Text", "x20 y180 w450 h1 +0x10")
    
    dg.SetFont("s10 bold")
    dg.Add("Text", "x20 y190 w450 h22", "⚙️ 리네임 동작 옵션")
    dg.SetFont("s9 norm")
    
    chkAutoRen := dg.Add("Checkbox", "x20 y215 w450 h22" . (REN_CFG["AutoRenameOnMatch"] ? " Checked" : ""), "MATCH 시 자동으로 앨범 파일명 변경 (AutoRenameOnMatch)")
    
    dg.Add("Text", "x20 y245 w200 h22", "이미 리네임된 파일 처리:")
    cmbAlready := dg.Add("DropDownList", "x220 y240 w150 AltSubmit", ["skip", "reapply"])
    cmbAlready.Choose(REN_CFG["WhenAlreadyRenamed"] = "skip" ? 1 : 2)
    
    dg.Add("Text", "x20 y275 w200 h22", "동일 이름 충돌 시 처리:")
    cmbConflict := dg.Add("DropDownList", "x220 y270 w150 AltSubmit", ["append_index", "ask"])
    cmbConflict.Choose(REN_CFG["OnNameConflict"] = "append_index" ? 1 : 2)
    
    dg.Add("Text", "x20 y305 w200 h22", "금지문자 치환:")
    edIllChar := dg.Add("Edit", "x220 y300 w150 h22", REN_CFG["IllegalCharReplacement"])
    
    dg.Add("Text", "x20 y340 w450 h1 +0x10")
    dg.SetFont("s10 bold")
    dg.Add("Text", "x20 y350 w450 h22", "👀 미리보기")
    dg.SetFont("s9 norm")
    txtPreview := dg.Add("Text", "x20 y375 w450 h60 c0284C7 Wrap", "현재 선택된 항목이 없습니다.")
    
    UpdatePreview := (*) => _UpdateRenamePreview(txtPreview, edRenTpl.Value, edIllChar.Value)
    edRenTpl.OnEvent("Change", UpdatePreview)
    edIllChar.OnEvent("Change", UpdatePreview)
    
    UpdatePreview()
    
    tabs.UseTab()
    
    dg.Add("Button", "x20 y475 w90 h30 Default", "적용")
       .OnEvent("Click", (*) => _ApplySettings(dg, edPat, edDir, edFrameKW, edAlbumKW, chkCase, chkRx, chkAutoFrame, edRenTpl, chkAutoRen, cmbAlready, cmbConflict, edIllChar))
    dg.Add("Button", "x120 y475 w90 h30", "기본값")
       .OnEvent("Click", (*) => (
           edPat.Value     := "Thumbs.db`ndesktop.ini`n._*`n~$*`n*.tmp",
           edDir.Value     := "설명서",
           edFrameKW.Value := "",
           edAlbumKW.Value := "표지`n가족사진",
           chkCase.Value   := true,
           chkRx.Value     := false,
           chkAutoFrame.Value := false,
           edRenTpl.Value  := "{album_name}_({album_no}-앨범넘버)_({frame_folder}).{album_ext}",
           chkAutoRen.Value := 0,
           cmbAlready.Choose(1),
           cmbConflict.Choose(1),
           edIllChar.Value := "_",
           UpdatePreview()
       ))
    dg.Add("Button", "x380 y475 w90 h30", "닫기")
       .OnEvent("Click", (*) => dg.Destroy())
    dg.OnEvent("Close", (*) => dg.Destroy())

    dg.Show("w500 h520")
}

EditPaste(ctrl, text) {
    SendMessage(0x00C2, 1, StrPtr(text), ctrl) ; EM_REPLACESEL
    ctrl.Focus()
}

_UpdateRenamePreview(txtCtrl, tpl, illChar) {
    if ST.SelRow < 1 || ST.SelRow > ST.Filtered.Length {
        txtCtrl.Text := "현재 선택된 항목이 없습니다. (리스트에서 항목을 선택하세요)"
        return
    }
    e := ST.Frames[ST.Filtered[ST.SelRow]]
    
    cfgMock := Map("Template", tpl, "IllegalCharReplacement", illChar)
    albumPath := e.status = "MATCH" ? e.albumMatchPath : "C:\Dummy\Album\KW_08903.jpg"
    albumNo := e.albumNum != "" ? e.albumNum : "06"
    frameFolder := e.subdir != "" ? e.subdir : "11x14_마르_1점"
    
    res := BuildNewAlbumName(cfgMock, albumPath, albumNo, frameFolder, e.path)
    
    SplitPath(albumPath, &oldName)
    txtCtrl.Text := "변경 전: " oldName "`n변경 후: " res.newName
}

_ApplySettings(dg, edPat, edDir, edFrameKW, edAlbumKW, chkCase, chkRx, chkAutoFrame, edRenTpl, chkAutoRen, cmbAlready, cmbConflict, edIllChar) {
    FILT.RawText     := edPat.Value
    FILT.DirRawText  := edDir.Value
    FILT.FrameKWText := edFrameKW.Value
    FILT.AlbumKWText := edAlbumKW.Value
    FILT.IgnoreCase  := chkCase.Value
    FILT.UseRegex    := chkRx.Value
    ST.AutoSelectAllFrames := chkAutoFrame.Value
    _ParsePatterns()
    SaveFilterSettings()
    
    REN_CFG["Template"] := edRenTpl.Value
    REN_CFG["AutoRenameOnMatch"] := chkAutoRen.Value
    REN_CFG["WhenAlreadyRenamed"] := cmbAlready.Text
    REN_CFG["OnNameConflict"] := cmbConflict.Text
    REN_CFG["IllegalCharReplacement"] := edIllChar.Value
    SaveRenameSettings(SETTINGS_INI, REN_CFG)
    
    dg.Destroy()

    if ST.Frames.Length > 0 {
        UI.G.Opt("+OwnDialogs")
        r := MsgBox("설정이 저장되었습니다.`n재스캔 하시겠습니까?", "설정 적용", "YesNo Iconi")
        if r = "Yes"
            OnScan()
    } else {
        ToolTip("✅ 설정 저장됨")
        SetTimer(() => ToolTip(), -2000)
    }
}
