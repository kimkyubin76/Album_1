; ============================================================
;  lib/ListView.ahk — ListView 정렬, 필터, 아이콘, 통계
;  의존: Globals.ahk (ST, UI, FILT)
; ============================================================

SetIcons() {
    static inited := false
    if !inited {
        inited := true
        hIL := IL_Create(2, 0, false)
        IL_Add(hIL, "shell32.dll", 297)  ; index 1 → iImage 0 (MATCH    ✓)
        IL_Add(hIL, "shell32.dll", 132)  ; index 2 → iImage 1 (NOT FOUND ✕)
        UI.LV.SetImageList(hIL, 1)
    }
}

; 특정 서브아이템에 iImage 설정 (LVS_EX_SUBITEMIMAGES 필요)
_SetSubItemIcon(rowIdx, subItem, imageIdx) {
    is64  := A_PtrSize = 8
    buf   := Buffer(is64 ? 64 : 40, 0)
    NumPut("UInt", 0x0002,     buf,  0)          ; mask = LVIF_IMAGE
    NumPut("Int",  rowIdx - 1, buf,  4)          ; iItem (0-based)
    NumPut("Int",  subItem,    buf,  8)          ; iSubItem
    NumPut("Int",  imageIdx,   buf, is64 ? 36 : 28)  ; iImage (0-based)
    SendMessage(0x1006, 0, buf.Ptr, UI.LV)       ; LVM_SETITEM
}

OnLVColClick(ctrl, col) {
    if ST.Filtered.Length = 0
        return
    if col = ST.SortCol
        ST.SortAsc := !ST.SortAsc
    else {
        ST.SortCol := col
        ST.SortAsc := true   ; 새 컬럼 첫 클릭: 항상 오름차순
    }
    SortLV(col, ST.SortAsc)
}

SortLV(col, asc) {
    if ST.Filtered.Length = 0
        return
    EnsureCustomDrawBound()
    arr := ST.Filtered.Clone()
    n   := arr.Length
    Loop n - 1 {
        i   := A_Index + 1
        key := arr[i]
        j   := i - 1
        while j >= 1 && _LVCompare(arr[j], key, col, asc) > 0 {
            arr[j + 1] := arr[j]
            j--
        }
        arr[j + 1] := key
    }
    ST.Filtered := arr

    UI.LV.Opt("-Redraw")
    UI.LV.Delete()
    ST.RowState := []
    for , idx in ST.Filtered {
        e   := ST.Frames[idx]
        stT := e.status = "MATCH" ? "MATCH" : "NOT FOUND"
        aC  := e.status = "MATCH" ? e.albumNum : ""
        r   := UI.LV.Add(, aC, stT, e.subdir, e.name)
        _SetSubItemIcon(r, 0, -2)                           ; 앨범 컬럼: I_IMAGENONE
        _SetSubItemIcon(r, 1, e.status = "MATCH" ? 0 : 1)  ; 상태 컬럼: 아이콘
        ST.RowState.Push(stT)
    }
    UI.LV.Opt("+Redraw")
    _SetLVColWidths()
    _UpdateColHeaders(col, asc)
    if ST.Filtered.Length > 0
        UI.LV.Modify(1, "Select Focus Vis")
    EnsureCustomDrawBound()
}

; SIDE_W 기준 컬럼 폭 반환 — 커스텀 헤더/LV 동기화용
_GetLVColWidths(w) {
    if LV_COL_W.Length = 4 {
        c1 := LV_COL_W[1]
        c2 := LV_COL_W[2]
        c3 := LV_COL_W[3]
        c4 := LV_COL_W[4]
        total := c1 + c2 + c3 + c4 + 6
        if total > w
            c4 := Max(80, w - c1 - c2 - c3 - 6)
        return [c1, c2, c3, c4]
    }
    c1 := 46
    c2 := 76
    rem := Max(80, w - c1 - c2 - 6)
    return [c1, c2, Integer(rem * 0.42), rem - Integer(rem * 0.42)]
}

_SetLVColWidths() {
    UI.LV.GetPos(,, &lvW)
    cols := _GetLVColWidths(lvW)
    c1 := cols[1], c2 := cols[2], c3 := cols[3], c4 := cols[4]

    UI.LV.ModifyCol(1, Max(42, c1) . " Center")
    UI.LV.ModifyCol(2, Max(56, c2) . " Center")
    UI.LV.ModifyCol(3, Max(80, c3))
    UI.LV.ModifyCol(4, Max(100, c4))

    ; CustomDraw용 col0W 캐시 갱신
    global _LV_Col0W
    _LV_Col0W := Max(56, c1)
}

; SetTimer 콜백 — HDN_ENDTRACK 후 300ms 디바운스 저장
_SaveLVColWidths() {
    global LV_COL_W
    ; LVM_GETCOLUMNWIDTH = 0x101D (0-based col index)
    w1 := SendMessage(0x101D, 0, 0, UI.LV)
    w2 := SendMessage(0x101D, 1, 0, UI.LV)
    w3 := SendMessage(0x101D, 2, 0, UI.LV)
    w4 := SendMessage(0x101D, 3, 0, UI.LV)
    if w1 > 0 && w2 > 0 && w3 > 0 && w4 > 0 {
        LV_COL_W := [w1, w2, w3, w4]
        SaveLvColWidths()
    }
}

_LVCompare(idxA, idxB, col, asc) {
    a := ST.Frames[idxA]
    b := ST.Frames[idxB]
    switch col {
        case 1:  ; 앨범 — 자연 정렬 (06 < 08 < 표지...)
            diff := _NatCmp(_AlbumSortKey(a), _AlbumSortKey(b))
        case 2:  ; 상태 — MATCH(0) < NOT FOUND(1)
            diff := (a.status = "MATCH" ? 0 : 1) - (b.status = "MATCH" ? 0 : 1)
        case 3:  ; 사이즈폴더 — 자연 정렬 (11x14 < 30x20)
            diff := _NatCmp(StrLower(a.subdir), StrLower(b.subdir))
        case 4:  ; 파일명 — 자연 정렬
            diff := _NatCmp(StrLower(a.name), StrLower(b.name))
        default:
            diff := 0
    }
    return asc ? diff : -diff
}

; Windows StrCmpLogicalW — 숫자 포함 문자열 자연 정렬
_NatCmp(a, b) {
    return DllCall("shlwapi\StrCmpLogicalW", "WStr", a, "WStr", b, "Int")
}

; 커스텀 헤더 텍스트에 ▲/▼ 정렬 방향 표시
_UpdateColHeaders(sortCol, sortAsc) {
    arrow := sortAsc ? " ▲" : " ▼"
    UI.LVHdr1.Text := (sortCol = 1) ? "앨범" arrow : "앨범"
    UI.LVHdr2.Text := (sortCol = 2) ? "상태" arrow : "상태"
    UI.LVHdr3.Text := (sortCol = 3) ? " 사이즈폴더" arrow : " 사이즈폴더"
    UI.LVHdr4.Text := (sortCol = 4) ? " 파일명" arrow : " 파일명"
}

_AlbumSortKey(e) {
    if e.status != "MATCH" || e.albumNum = "" || e.albumNum = "-"
        return "Z"
    try {
        v := Integer(e.albumNum)
        return "A_" Format("{:04}", v)
    }
    return "B_" StrLower(e.albumNum)
}

ApplyFilter(m) {
    EnsureCustomDrawBound()
    ST.Filter := m
    UI.FTabAll.Text := m = "ALL"   ? "▶ 전체"         : "전체"
    UI.FTabNF.Text  := m = "NOT"   ? "▶ ✕ NOT FOUND"  : "✕ NOT FOUND"
    UI.FTabM.Text   := m = "MATCH" ? "▶ ✓ MATCH"      : "✓ MATCH"

    if m = "ALL" && ST.SortCol = 2 {
        ST.SortAsc := true
    }

    UI.LV.Opt("-Redraw")
    UI.LV.Delete()
    ST.Filtered := []
    ST.RowState := []
    for idx, e in ST.Frames {
        ok := m = "ALL"
           || (m = "MATCH" && e.status = "MATCH")
           || (m = "NOT"   && e.status != "MATCH")
        if !ok
            continue
        ST.Filtered.Push(idx)
        stT := e.status = "MATCH" ? "MATCH" : "NOT FOUND"
        aC  := e.status = "MATCH" ? e.albumNum : ""
        r   := UI.LV.Add(, aC, stT, e.subdir, e.name)
        _SetSubItemIcon(r, 0, -2)                           ; 앨범 컬럼: I_IMAGENONE
        _SetSubItemIcon(r, 1, e.status = "MATCH" ? 0 : 1)  ; 상태 컬럼: 아이콘
        ST.RowState.Push(stT)
    }
    UI.LV.Opt("+Redraw")
    _SetLVColWidths()

    if ST.Filtered.Length > 0
        SortLV(ST.SortCol, ST.SortAsc)
    else
        ClearPreview()
    EnsureCustomDrawBound()
}

UpdateChips(tot, mc, nc) {
    UI.ChipTotal.Text := "전체 " tot
    UI.ChipMatch.Text := "✓ " mc
    UI.ChipNF.Text    := "✕ " nc
}

UpdateGrpSum(nc, mc) {
    if nc > 0
        UI.GrpSum.Text := "  ⚠ NOT FOUND: " nc "개  |  ✓ MATCH: " mc "개"
    else
        UI.GrpSum.Text := "  ✓ 전체 MATCH: " mc "개"
}
