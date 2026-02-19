; ============================================================
;  lib/Scan.ahk — 스캔 로직 + 모드 검증 + 선택 다이얼로그
;  의존: Globals.ahk, FileCollect.ahk, Hash.ahk, ListView.ahk, Preview.ahk
; ============================================================

OnScan(*) {
    if ST.Scanning
        return MsgBox("이미 스캔 진행 중입니다.", "알림", "Iconi")

    if ST.Mode = "A" {
        if !ResolveAutoMode()
            return
    } else {
        if !ResolveManualMode()
            return
    }

    OutputDebug("[SCAN] Frame=" ST.FramePath " Album=" ST.AlbumPath "`n")

    ST.AlbumHash  := Map()
    ST.Frames     := []
    ST.Filtered   := []
    ST.RowState   := []
    ST.Cancel     := false
    ST.Scanning   := true
    ST.SelRow     := 0
    ST.Tick0      := A_TickCount
    FILT.Excluded := 0
    UI.LV.Delete()
    ClearPreview()
    UpdateChips(0, 0, 0)
    ScanUI(true)

    Prog("앨범 파일 수집 중…", 0)
    aFiles := GatherAlbum(ST.AlbumPath)
    if ST.Cancel {
        ScanDone("취소됨")
        return
    }
    totA := aFiles.Length
    if totA = 0 {
        ScanDone("")
        return MsgBox("앨범(01~99) 폴더에 이미지 파일이 없습니다.`n" ST.AlbumPath, "알림", "Icon!")
    }

    Loop totA {
        if ST.Cancel {
            ScanDone("취소됨 (앨범 해시 " A_Index "/" totA ")")
            return
        }
        i := A_Index
        h := SHA256(aFiles[i])
        if h {
            if !ST.AlbumHash.Has(h)
                ST.AlbumHash[h] := []
            ST.AlbumHash[h].Push(aFiles[i])
        }
        if Mod(i, 40) = 0 || i = totA
            Prog("앨범 해시 " i "/" totA " | " Elapsed(), Integer(i / totA * 500))
    }

    if ST.Cancel {
        ScanDone("취소됨")
        return
    }
    Prog("액자 파일 수집 중…", 500)
    fFiles := GatherFrame()
    totF := fFiles.Length
    if totF = 0 {
        ScanDone("")
        return MsgBox("액자 폴더에 이미지 파일이 없습니다.`n" ST.FramePath, "알림", "Icon!")
    }

    ST.Frames := []
    ST.RowState := []
    UI.LV.Opt("-Redraw")
    mc := 0, nc := 0
    Loop totF {
        if ST.Cancel {
            UI.LV.Opt("+Redraw")
            ScanDone("취소됨 (매칭 " A_Index "/" totF ")")
            return
        }
        i  := A_Index
        it := fFiles[i]
        h  := SHA256(it.path)
        s  := "NOT FOUND"
        mp := []
        if h && ST.AlbumHash.Has(h) {
            s  := "MATCH"
            mp := ST.AlbumHash[h]
            mc++
        } else {
            nc++
        }
        aNum := ""
        aRel := ""
        if mp.Length > 0 {
            aRel := RelPath(mp[1], ST.AlbumPath)
            aNum := AlbumNum(aRel)
        }
        ST.Frames.Push({
            path: it.path, subdir: it.subdir, name: it.name,
            hash: h, status: s, matchPaths: mp,
            albumNum: aNum, albumRel: aRel
        })
        albumCol := s = "MATCH" ? aNum : ""
        stT := s = "MATCH" ? "MATCH" : "NOT FOUND"
        r := UI.LV.Add(, albumCol, stT, it.subdir, it.name)
        _SetSubItemIcon(r, 0, -2)                    ; 앨범 컬럼: I_IMAGENONE
        _SetSubItemIcon(r, 1, s = "MATCH" ? 0 : 1)  ; 상태 컬럼: 아이콘
        ST.RowState.Push(stT)
        if Mod(i, 15) = 0 || i = totF
            Prog("매칭 " i "/" totF " | MATCH:" mc " NOT:" nc " | " Elapsed()
                , 500 + Integer(i / totF * 500))
    }
    UI.LV.Opt("+Redraw")
    SetIcons()
    EnsureCustomDrawBound()

    filtMsg := FILT.Excluded > 0 ? " | 필터제외: " FILT.Excluded : ""
    Prog("✅ 완료! 총 " totF " | MATCH: " mc " | NOT FOUND: " nc filtMsg " | " Elapsed(), 1000)

    UpdateChips(totF, mc, nc)
    UpdateGrpSum(nc, mc)

    ST.SortCol := 2
    ST.SortAsc := true
    ApplyFilter("ALL")
    ScanDone("")
    if ST.Frames.Length > 0
        UI.LV.Modify(1, "Select Focus Vis")
}

ResolveAutoMode() {
    if !ST.Root {
        MsgBox("먼저 루트 폴더를 선택해 주세요.", "알림", "Iconi")
        return false
    }
    scan := ScanRootStructure(ST.Root)

    if scan.albumFolders.Length = 0 {
        MsgBox("루트 아래에서 앨범 폴더를 찾을 수 없습니다.`n`n"
             . "앨범 폴더 = 내부에 01~99 숫자 하위폴더가 있는 폴더`n"
             . "         또는 앨범 키워드와 일치하는 폴더`n`n"
             . "루트: " ST.Root, "앨범 없음", "Icon!")
        return false
    }
    if scan.albumFolders.Length = 1 {
        ST.AlbumPath := scan.albumFolders[1].path
    } else {
        ST.AlbumPath := ChooseFromList("앨범 폴더 선택"
            , "앨범 폴더 후보가 " scan.albumFolders.Length "개 발견되었습니다."
            , scan.albumFolders, "name", "numCount", "개 하위폴더")
        if !ST.AlbumPath
            return false
    }

    if scan.frameFolders.Length = 0 {
        MsgBox("루트 아래에서 액자 폴더를 찾을 수 없습니다.`n`n"
             . "액자 폴더 = 이미지 파일이 있으면서 01~99 숫자폴더가 없는 폴더`n`n"
             . "루트: " ST.Root, "액자 없음", "Icon!")
        return false
    }
    if scan.frameFolders.Length = 1 {
        ST.FrameFolders := [scan.frameFolders[1].path]
        ST.FramePath    := scan.frameFolders[1].path
    } else {
        if ST.AutoSelectAllFrames {
            ; 전체 자동 선택 (다이얼로그 생략)
            ST.FrameFolders := []
            for f in scan.frameFolders
                ST.FrameFolders.Push(f.path)
            ST.FramePath := ST.FrameFolders[1]
        } else {
            selected := ChooseMultiFrame(scan.frameFolders)
            if !selected || selected.Length = 0
                return false
            ST.FrameFolders := selected
            ST.FramePath    := selected[1]
        }
    }
    return true
}

ResolveManualMode() {
    _TrySetFromEdit("Frame")
    _TrySetFromEdit("Album")

    if !ST.FramePath || !DirExist(ST.FramePath) {
        MsgBox("액자 폴더가 선택되지 않았거나 존재하지 않습니다.`n`n"
             . "• [수동 모드] '액자' 선택 버튼으로 폴더를 지정하세요.`n"
             . "• 현재 값: " (ST.FramePath ? ST.FramePath : "(없음)")
             , "액자 폴더 오류", "Icon!")
        return false
    }
    hasImg := false
    for ext in CFG.Ext {
        Loop Files, ST.FramePath "\*." ext, "FR" {
            hasImg := true
            break
        }
        if hasImg
            break
    }
    if !hasImg {
        MsgBox("액자 폴더에 이미지 파일이 없습니다.`n"
             . "• 지원 확장자: jpg, jpeg, png, heic`n"
             . "• 경로: " ST.FramePath, "액자 비어있음", "Icon!")
        return false
    }
    ST.FrameFolders := [ST.FramePath]

    if !ST.AlbumPath || !DirExist(ST.AlbumPath) {
        MsgBox("앨범 폴더가 선택되지 않았거나 존재하지 않습니다.`n`n"
             . "• [수동 모드] '앨범' 선택 버튼으로 폴더를 지정하세요.`n"
             . "• 현재 값: " (ST.AlbumPath ? ST.AlbumPath : "(없음)")
             , "앨범 폴더 오류", "Icon!")
        return false
    }
    numCount := CountNumberedSubs(ST.AlbumPath)
    if numCount = 0 {
        MsgBox("앨범 폴더 아래에 01~99 숫자 폴더가 없습니다.`n"
             . "• 경로: " ST.AlbumPath, "앨범 구조 오류", "Icon!")
        return false
    }
    return true
}

_TrySetFromEdit(which) {
    edt := which = "Frame" ? UI.EdtFrame : UI.EdtAlbum
    cur := which = "Frame" ? ST.FramePath : ST.AlbumPath
    if cur && DirExist(cur)
        return
    val := Trim(edt.Value, ' "' "`t`r`n")
    val := RTrim(val, "\")
    if !val
        return
    if DirExist(val) {
        if which = "Frame"
            ST.FramePath := val
        else
            ST.AlbumPath := val
        return
    }
    cleaned := CleanPath(val)
    if cleaned && DirExist(cleaned) {
        if which = "Frame"
            ST.FramePath := cleaned
        else
            ST.AlbumPath := cleaned
        edt.Value := cleaned
        return
    }
    if RegExMatch(val, "^[A-Za-z]:\\") {
        if which = "Frame"
            ST.FramePath := val
        else
            ST.AlbumPath := val
    }
}

ChooseFromList(title, msg, items, nameKey, countKey, countSuffix) {
    sel := ""
    dg := Gui("+Owner" UI.G.Hwnd " +ToolWindow", title)
    dg.SetFont("s10", "맑은 고딕")
    dg.Add("Text", "x15 y10 w470 Wrap", msg)
    dispItems := []
    for it in items {
        cnt   := it.%countKey%
        extra := it.HasOwnProp("isExtra") && it.isExtra ? " [키워드]" : ""
        dispItems.Push(it.%nameKey% "  (" cnt countSuffix ")" extra)
    }
    rows := Min(8, items.Length)
    lb := dg.Add("ListBox", "x15 y55 w470 r" rows " Choose1", dispItems)
    bY := 65 + rows * 22
    dg.Add("Button", "x160 y" bY " w80 h30 Default", "선택")
       .OnEvent("Click", (*) => (sel := items[lb.Value].path, dg.Destroy()))
    dg.Add("Button", "x260 y" bY " w80 h30", "취소")
       .OnEvent("Click", (*) => dg.Destroy())
    dg.OnEvent("Close", (*) => dg.Destroy())
    dg.Show("AutoSize")
    WinWaitClose(dg)
    return sel
}

ChooseMultiFrame(frameFolders) {
    selected := []
    dg := Gui("+Owner" UI.G.Hwnd " +ToolWindow", "액자 폴더 선택")
    dg.SetFont("s10", "맑은 고딕")
    dg.Add("Text", "x15 y10 w520 Wrap"
        , "액자 폴더 후보가 " frameFolders.Length "개 발견되었습니다.`n검수할 폴더를 선택하세요.")
    checks := []
    yPos := 60
    for i, f in frameFolders {
        cb := dg.Add("Checkbox", "x20 y" yPos " w500 h22 Checked"
            , f.name " (" f.imgCount "개 이미지)")
        checks.Push({ctrl: cb, path: f.path})
        yPos += 26
    }
    btnY := yPos + 5
    dg.Add("Button", "x20 y" btnY " w80 h28", "전체 선택")
       .OnEvent("Click", (*) => LoopChecks(checks, true))
    dg.Add("Button", "x110 y" btnY " w80 h28", "전체 해제")
       .OnEvent("Click", (*) => LoopChecks(checks, false))
    okY := btnY + 38
    dg.Add("Button", "x180 y" okY " w80 h30 Default", "확인")
       .OnEvent("Click", (*) => (selected := CollectChecked(checks), dg.Destroy()))
    dg.Add("Button", "x270 y" okY " w80 h30", "취소")
       .OnEvent("Click", (*) => (selected := [], dg.Destroy()))
    dg.OnEvent("Close", (*) => (selected := [], dg.Destroy()))
    dg.Show("AutoSize")
    WinWaitClose(dg)
    return selected
}

LoopChecks(checks, val) {
    for c in checks
        c.ctrl.Value := val
}

CollectChecked(checks) {
    out := []
    for c in checks {
        if c.ctrl.Value
            out.Push(c.path)
    }
    return out
}

ScanUI(on) {
    UI.BtnScan.Enabled     := !on
    UI.BtnCancel.Enabled   := on
    UI.BtnRoot.Enabled     := !on
    UI.EdtRoot.Enabled     := !on
    try UI.G["BtnFrame"].Enabled := !on
    try UI.G["BtnAlbum"].Enabled := !on
    try UI.EdtFrame.Enabled      := !on
    try UI.EdtAlbum.Enabled      := !on
    UI.BtnModeA.Enabled := !on
    UI.BtnModeB.Enabled := !on
}

ScanDone(msg) {
    ST.Scanning := false
    ST.Cancel   := false
    ScanUI(false)
    if msg
        UI.TxtProg.Text := msg
}

Prog(txt, pm) {
    UI.TxtProg.Text := txt
    UI.Prg.Value    := pm
    Sleep(-1)
}

Elapsed() => FormatTime_ms(A_TickCount - ST.Tick0)
