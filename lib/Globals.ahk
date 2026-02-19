; ============================================================
;  lib/Globals.ahk — 전역 변수 정의
;  모든 모듈이 공유하는 전역 객체 선언 (선언만, 로직 없음)
; ============================================================

global GDIP_TOKEN := 0   ; GdipInit() 에서 채워짐

global CFG := {
    Ext:         ["jpg","jpeg","png","heic"],
    FrameName:   "액자",
    AlbumMin:    1,
    AlbumMax:    99,
    ThumbW:      300,
    ThumbH:      230,
    HashChunk:   1048576
}

global ST := {
    Mode:         "A",
    Root:         "",
    FramePath:    "",
    FrameFolders: [],
    AlbumPath:    "",
    AlbumHash:    Map(),
    Frames:       [],
    Filtered:     [],
    RowState:     [],   ; [row] = "MATCH"|"NOT FOUND" — CustomDraw용 캐시 (GetText 대체)
    Filter:       "ALL",
    Scanning:     false,
    Cancel:       false,
    SelRow:       0,
    Tick0:        0,
    SortCol:      1,      ; 기본: 상태 컬럼
    SortAsc:      false,  ; false = NOT FOUND 먼저
    AutoSelectAllFrames: false   ; true=전체 자동선택, false=선택창 표시
}

global UI   := {}
global _LW  := 1100
global _LH  := 720
global SIDE_W    := 232   ; 사이드바 너비 (스플리터 드래그로 변경 가능)
global LV_COL_W  := []   ; 저장된 ListView 컬럼 폭 [c1,c2,c3,c4] (비어있으면 자동 계산)

; 우측 상세패널 분할 모드 — FIXED_50: 항상 50:50 고정, 드래그 불가
global DETAIL_SPLIT_MODE := "FIXED_50"
; RIGHT_ORIG_W: 더 이상 사용하지 않음 (FIXED_50 고정으로 대체). 하위호환 유지용
global RIGHT_ORIG_W := 0

; 스플리터 드래그 상태
global DRAG := { Active:false, Target:"", StartX:0, StartSideW:0, StartOrigW:0, LastT:0, JustEnded:false }
global _LV_Col0W := 76   ; CustomDraw용 column 0 폭 캐시
; 헤더 컬럼 드래그 리사이즈 상태
global _LVHdrTop := 0
global _LVHdrH   := 24
global COLDRAG := { Active:false, ColIdx:0, StartX:0, StartWidths:[], LastT:0 }

; ── 레이아웃 기준선 상수 (BaseY 단일화용) ────────────────────────────────────
; BodyTopY = HDR_H, BodyBottomY = BaseY - 1, BaseY = 바닥선(1px) Y
global LAYOUT := { HDR_H:49, BOT_H:26, TAB_H:30, GRP_H:20, HINT_H:18
    , FILE_HDR_H:52, PIC_LBL_H:26, PIC_FOOT_H:18
    , ACTION_H:61          ; SepAction(1)+4+rel(22)+4+btn(28)+2
    , PIC_H_FIXED:280      ; 미리보기 고정 높이 (타이틀26 + 사진 + 풋18)
    , EXP_DIVIDER_H:28     ; 탐색기 섹션 구분선 높이
    , EXP_TOOLBAR_H:32     ; 탐색기 공통 툴바 높이
    , EXP_PANE_HDR_H:26    ; 탐색기 각 패널 헤더 높이
    , EXP_FOOT_H:20 }      ; 탐색기 각 패널 하단 상태바 높이

; 탐색기 상태 (액자/앨범 각각)
; 주의: EXP 는 AHK 내장함수(Exp)와 충돌 → ExpSt 사용
global ExpSt := {
    FramePath: "",   ; 현재 탐색 중인 액자 폴더
    AlbumPath: "",   ; 현재 탐색 중인 앨범 폴더
    FrameSel:  "",   ; 액자 패널에서 선택된 파일 전체경로
    AlbumSel:  ""    ; 앨범 패널에서 선택된 파일 전체경로
}

; ── 라인 시스템 (3종만 사용) ────────────────────────────────────────────────
; Primary  : 구역 경계(Header/Body/Bottom, LV↔Detail, Orig↔Match, LV헤더↔내용)
; Secondary: 섹션 내부 구분(타이틀 하단, 액션바 상단)
; Accent   : 스플리터 hover/drag 상태에만 적용
global LINE_P := "8899AA"   ; Primary  — 1px 청회색
global LINE_S := "C8D4E0"   ; Secondary — 1px 연청회색
global LINE_A := "2563EB"   ; Accent   — 파란색 (hover/drag 전용)

global FILT := {
    Patterns:    [],  RawText:    "",
    DirPatterns: [],  DirRawText: "",
    FrameKW:     [],  FrameKWText:"",
    AlbumKW:     [],  AlbumKWText:"",
    IgnoreCase:  true,
    UseRegex:    false,
    Excluded:    0
}

global SETTINGS_INI := A_ScriptDir "\settings.ini"
