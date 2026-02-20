; ============================================================
;  lib/FileCollect.ahk — 앨범/액자 파일 수집 + 루트 구조 탐색
;  의존: Globals.ahk (CFG, ST, FILT), Filter.ahk
; ============================================================

GatherAlbum(root) {
    f := []
    ; 1) 폴더 수집 (숫자 01~99 + 키워드 매칭)
    folders := []
    Loop CFG.AlbumMax {
        sub := root "\" Format("{:02}", A_Index)
        if DirExist(sub)
            folders.Push({path: sub, name: Format("{:02}", A_Index)})
    }
    if FILT.AlbumKW.Length > 0 {
        Loop Files, root "\*", "D" {
            dirName := A_LoopFileName
            dirPath := A_LoopFilePath
            if RegExMatch(dirName, "^\d{1,2}$") && Integer(dirName) >= 1 && Integer(dirName) <= CFG.AlbumMax
                continue
            if !_MatchesKeyword(dirName, FILT.AlbumKW)
                continue
            folders.Push({path: dirPath, name: dirName})
        }
    }
    ; 폴더명 기준 오름차순 정렬 (숫자→문자)
    folders := _SortAlbumFolders(folders)
    ; 정렬된 순서로 파일 수집
    for fd in folders {
        for ext in CFG.Ext
            Loop Files, fd.path "\*." ext, "FR" {
                if IsExcluded(A_LoopFileName, A_LoopFileDir) {
                    FILT.Excluded++
                    continue
                }
                f.Push({path: A_LoopFilePath, size: A_LoopFileSize})
            }
    }
    ; 2) 루트 직접 이미지
    for ext in CFG.Ext
        Loop Files, root "\*." ext, "F" {
            if IsExcluded(A_LoopFileName, A_LoopFileDir) {
                FILT.Excluded++
                continue
            }
            f.Push({path: A_LoopFilePath, size: A_LoopFileSize})
        }
    return f
}

GatherFrame(rootUnused := "") {
    items   := []
    folders := ST.HasOwnProp("FrameFolders") && ST.FrameFolders.Length > 0
        ? ST.FrameFolders.Clone()
        : [ST.FramePath]
    ; 폴더명 기준 오름차순 정렬 (숫자→문자)
    folders := _SortPathsByFolderName(folders)
    for folderPath in folders {
        SplitPath(folderPath, &folderName)
        ; 하위 폴더 정렬 후 재귀 수집
        _GatherFrameRecurse(items, folderPath, folderName)
    }
    return items
}

; 액자 폴더 내 파일 수집 (하위 폴더 정렬 후 처리)
_GatherFrameRecurse(items, folderPath, baseSubdir) {
    ; 1) 현재 폴더의 이미지 직접 수집
    for ext in CFG.Ext
        Loop Files, folderPath "\*." ext, "F" {
            if IsExcluded(A_LoopFileName, A_LoopFileDir) {
                FILT.Excluded++
                continue
            }
            items.Push({path: A_LoopFilePath, subdir: baseSubdir, name: A_LoopFileName, size: A_LoopFileSize})
        }
    ; 2) 하위 폴더 수집 후 정렬
    subdirs := []
    Loop Files, folderPath "\*", "D" {
        subdirs.Push({path: A_LoopFilePath, name: A_LoopFileName})
    }
    _SortDirs(subdirs)
    ; 3) 정렬된 하위 폴더 순으로 재귀
    for sd in subdirs {
        subSubdir := baseSubdir = "" ? sd.name : baseSubdir "\" sd.name
        _GatherFrameRecurse(items, sd.path, subSubdir)
    }
}

ScanRootStructure(root) {
    result := { albumFolders: [], frameFolders: [], unknown: [] }

    Loop Files, root "\*", "D" {
        dirPath := A_LoopFilePath
        dirName := A_LoopFileName

        if IsExcludedDir(dirName) {
            FILT.Excluded++
            continue
        }

        ; "액자" 폴더는 여기서 건너뛰고 하단에서 처리
        if dirName = CFG.FrameName
            continue

        if _MatchesKeyword(dirName, FILT.FrameKW) {
            ic := CountImages(dirPath)
            if ic > 0 {
                result.frameFolders.Push({path: dirPath, name: dirName, imgCount: ic})
                continue
            }
        }
        if _MatchesKeyword(dirName, FILT.AlbumKW) {
            ic := CountImages(dirPath)
            if ic > 0 {
                result.albumFolders.Push({path: dirPath, name: dirName, numCount: 0, isExtra: true})
                continue
            }
        }
        numCount := CountNumberedSubs(dirPath)
        if numCount > 0 {
            result.albumFolders.Push({path: dirPath, name: dirName, numCount: numCount})
            continue
        }
        imgCount := CountImages(dirPath)
        if imgCount > 0 {
            result.frameFolders.Push({path: dirPath, name: dirName, imgCount: imgCount})
            continue
        }
        result.unknown.Push({path: dirPath, name: dirName})
    }

    ; "액자"라는 이름의 폴더가 있으면 하위폴더들을 개별 액자로 추가 (기존 구조 호환)
    Loop Files, root "\*", "D" {
        if A_LoopFileName = CFG.FrameName {
            Loop Files, A_LoopFilePath "\*", "D" {
                ic := CountImages(A_LoopFilePath)
                if ic > 0 {
                    result.frameFolders.Push({
                        path: A_LoopFilePath, name: A_LoopFileName, imgCount: ic
                    })
                }
            }
            ic := CountImagesFlat(A_LoopFilePath)
            if ic > 0 {
                result.frameFolders.Push({
                    path: A_LoopFilePath, name: "(액자루트)", imgCount: ic
                })
            }
            break
        }
    }
    return result
}

CountNumberedSubs(dir) {
    c := 0
    Loop CFG.AlbumMax {
        if DirExist(dir "\" Format("{:02}", A_Index))
            c++
    }
    return c
}

CountImages(dir) {
    for ext in CFG.Ext {
        Loop Files, dir "\*." ext, "FR" {
            return 1
        }
    }
    return 0
}

CountImagesFlat(dir) {
    for ext in CFG.Ext {
        Loop Files, dir "\*." ext, "F" {
            return 1
        }
    }
    return 0
}

; 폴더명 비교: 숫자(01~99) → 숫자 크기순, 문자 → 숫자 뒤 가나다순
_CompareDirName(a, b) {
    aIsNum := RegExMatch(a, "^\d{1,2}$") && Integer(a) >= 1 && Integer(a) <= CFG.AlbumMax
    bIsNum := RegExMatch(b, "^\d{1,2}$") && Integer(b) >= 1 && Integer(b) <= CFG.AlbumMax
    if aIsNum && bIsNum
        return Integer(a) - Integer(b)
    if aIsNum
        return -1
    if bIsNum
        return 1
    return StrCompare(StrLower(a), StrLower(b))
}

; 폴더 배열 삽입 정렬 (폴더명 기준)
_SortDirs(arr) {
    Loop arr.Length - 1 {
        i := A_Index + 1
        temp := arr[i]
        j := i - 1
        while j >= 1 && _CompareDirName(arr[j].name, temp.name) > 0 {
            arr[j + 1] := arr[j]
            j--
        }
        arr[j + 1] := temp
    }
}

; 폴더명 정렬 키: 숫자(01~99) → 숫자 크기순, 그 외 → 가나다순
_FolderSortKey(name) {
    if RegExMatch(name, "^\d{1,2}$") {
        v := Integer(name)
        if v >= 1 && v <= CFG.AlbumMax
            return "A_" Format("{:04}", v)
    }
    return "B_" StrLower(name)
}

; 앨범 폴더 배열 정렬 (폴더명 기준)
_SortAlbumFolders(folders) {
    _SortDirs(folders)
    return folders
}

; 경로 배열을 폴더명 기준 정렬
_SortPathsByFolderName(paths) {
    pairs := []
    for p in paths {
        SplitPath(p, &name)
        pairs.Push({path: p, name: name})
    }
    _SortDirs(pairs)
    out := []
    for p in pairs
        out.Push(p.path)
    return out
}
