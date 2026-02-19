; ============================================================
;  lib/FileCollect.ahk — 앨범/액자 파일 수집 + 루트 구조 탐색
;  의존: Globals.ahk (CFG, ST, FILT), Filter.ahk
; ============================================================

GatherAlbum(root) {
    f := []
    ; 1) 숫자폴더 (01~99)
    Loop CFG.AlbumMax {
        sub := root "\" Format("{:02}", A_Index)
        if !DirExist(sub)
            continue
        for ext in CFG.Ext
            Loop Files, sub "\*." ext, "FR" {
                if IsExcluded(A_LoopFileName, A_LoopFileDir) {
                    FILT.Excluded++
                    continue
                }
                f.Push(A_LoopFilePath)
            }
    }
    ; 2) 앨범 키워드 매칭 폴더 (비숫자)
    if FILT.AlbumKW.Length > 0 {
        Loop Files, root "\*", "D" {
            dirName := A_LoopFileName
            dirPath := A_LoopFilePath
            if RegExMatch(dirName, "^\d{1,2}$") && Integer(dirName) >= 1 && Integer(dirName) <= CFG.AlbumMax
                continue
            if !_MatchesKeyword(dirName, FILT.AlbumKW)
                continue
            for ext in CFG.Ext
                Loop Files, dirPath "\*." ext, "FR" {
                    if IsExcluded(A_LoopFileName, A_LoopFileDir) {
                        FILT.Excluded++
                        continue
                    }
                    f.Push(A_LoopFilePath)
                }
        }
    }
    ; 3) 루트 직접 이미지
    for ext in CFG.Ext
        Loop Files, root "\*." ext, "F" {
            if IsExcluded(A_LoopFileName, A_LoopFileDir) {
                FILT.Excluded++
                continue
            }
            f.Push(A_LoopFilePath)
        }
    return f
}

GatherFrame(rootUnused := "") {
    items   := []
    folders := ST.HasOwnProp("FrameFolders") && ST.FrameFolders.Length > 0
        ? ST.FrameFolders
        : [ST.FramePath]
    for folderPath in folders {
        SplitPath(folderPath, &folderName)
        for ext in CFG.Ext {
            Loop Files, folderPath "\*." ext, "FR" {
                if IsExcluded(A_LoopFileName, A_LoopFileDir) {
                    FILT.Excluded++
                    continue
                }
                rel   := SubStr(A_LoopFilePath, StrLen(folderPath) + 2)
                parts := StrSplit(rel, "\")
                subdir := parts.Length > 1 ? folderName "\" parts[1] : folderName
                items.Push({
                    path:   A_LoopFilePath,
                    subdir: subdir,
                    name:   A_LoopFileName
                })
            }
        }
    }
    return items
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
