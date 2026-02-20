; ============================================================
;  lib/RenameEngine.ahk — 파일명 템플릿 기반 리네임 엔진
; ============================================================

LoadRenameSettings(settingsPath) {
    cfg := Map()
    cfg["Template"] := IniRead(settingsPath, "Rename", "Template", "{album_name}_({album_no}-앨범넘버)_({frame_folder}).{album_ext}")
    cfg["AutoRenameOnMatch"] := IniRead(settingsPath, "Rename", "AutoRenameOnMatch", 0) + 0
    cfg["WhenAlreadyRenamed"] := IniRead(settingsPath, "Rename", "WhenAlreadyRenamed", "skip")
    cfg["OnNameConflict"] := IniRead(settingsPath, "Rename", "OnNameConflict", "append_index")
    cfg["IllegalCharReplacement"] := IniRead(settingsPath, "Rename", "IllegalCharReplacement", "_")
    return cfg
}

SaveRenameSettings(settingsPath, cfg) {
    IniWrite(cfg["Template"], settingsPath, "Rename", "Template")
    IniWrite(cfg["AutoRenameOnMatch"], settingsPath, "Rename", "AutoRenameOnMatch")
    IniWrite(cfg["WhenAlreadyRenamed"], settingsPath, "Rename", "WhenAlreadyRenamed")
    IniWrite(cfg["OnNameConflict"], settingsPath, "Rename", "OnNameConflict")
    IniWrite(cfg["IllegalCharReplacement"], settingsPath, "Rename", "IllegalCharReplacement")
}

SanitizeFileName(name, replacement) {
    ; Windows 파일명 금지문자 처리: <>:"/\|?*
    cleanName := RegExReplace(name, '[<>:"/\\|?*]', replacement)
    ; 끝에 점/공백 제거
    cleanName := RTrim(cleanName, " .")
    return cleanName
}

BuildNewAlbumName(cfg, albumFullPath, albumNo, frameFolderName, frameFilePath:="") {
    SplitPath(albumFullPath, &albumFile, &albumDir, &albumExt, &albumName)
    frameFile := ""
    frameName := ""
    if (frameFilePath != "") {
        SplitPath(frameFilePath, &frameFile, , , &frameName)
    }
    
    newName := cfg["Template"]
    newName := StrReplace(newName, "{album_name}", albumName)
    newName := StrReplace(newName, "{album_ext}", albumExt)
    newName := StrReplace(newName, "{album_no}", albumNo)
    newName := StrReplace(newName, "{frame_folder}", SanitizeFileName(frameFolderName, cfg["IllegalCharReplacement"]))
    newName := StrReplace(newName, "{frame_file}", SanitizeFileName(frameFile, cfg["IllegalCharReplacement"]))
    newName := StrReplace(newName, "{frame_name}", SanitizeFileName(frameName, cfg["IllegalCharReplacement"]))
    
    newFullPath := albumDir "\" newName
    return {newName: newName, newFullPath: newFullPath}
}

ResolveNameConflict(path, onConflict) {
    if !FileExist(path)
        return path
    
    if (onConflict = "ask") {
        r := MsgBox("파일명이 충돌합니다. 덮어쓰시겠습니까?`n`n" path, "이름 충돌", "YesNo")
        if (r = "Yes") {
            return path
        } else {
            return "" ; Canceled
        }
    }
    
    ; append_index
    SplitPath(path, , &dir, &ext, &name)
    idx := 1
    Loop {
        newPath := dir "\" name " (" idx ")." ext
        if !FileExist(newPath)
            return newPath
        idx++
    }
}

IsAlreadyRenamed(cfg, albumName) {
    ; 템플릿의 변수를 제외한 고정 문자열이 포함되어 있으면 이미 리네임되었다고 판단.
    staticText := RegExReplace(cfg["Template"], "\{[^\}]+\}", "")
    ; [Fix] 구분자를 배열로 지정 — "_", "(", ")" 각각을 개별 구분자로 처리
    ; 이전 코드: StrSplit(staticText, "_()")는 세 글자 전체를 하나의 구분자로 인식하여
    ;            실제로 분리가 거의 일어나지 않는 버그가 있었음.
    staticParts := StrSplit(staticText, ["_", "(", ")"])
    for p in staticParts {
        p := Trim(p, " .")
        if (StrLen(p) > 2 && InStr(albumName, p))
            return true
    }
    return false
}

ApplyRename(albumFullPath, newFullPath) {
    if !FileExist(albumFullPath)
        return "err"
        
    try {
        ; overwrite=0 기반 처리 (덮어쓰지 않음)
        FileMove(albumFullPath, newFullPath, 0)
        return "ok"
    } catch as e {
        return "err"
    }
}

; 헬퍼 함수
ExecuteRename(cfg, albumFullPath, albumNo, frameFolderName, frameFilePath:="") {
    if !FileExist(albumFullPath)
        return "err: file not found"
        
    SplitPath(albumFullPath, , , , &albumNameNoExt)
    if (cfg["WhenAlreadyRenamed"] = "skip" && IsAlreadyRenamed(cfg, albumNameNoExt)) {
        return "skip: already renamed"
    }
    
    res := BuildNewAlbumName(cfg, albumFullPath, albumNo, frameFolderName, frameFilePath)
    if (res.newFullPath = albumFullPath)
        return "skip: same name"
        
    finalPath := ResolveNameConflict(res.newFullPath, cfg["OnNameConflict"])
    if (finalPath = "")
        return "cancel: conflict"
        
    result := ApplyRename(albumFullPath, finalPath)
    if (result = "ok")
        return finalPath
    return "err: apply failed"
}
