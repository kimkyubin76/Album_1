; ============================================================================
;  액자-앨범 사진 매칭 검수기 v4.0 — 메인 진입점
;  모듈 구조: lib/ 폴더의 15개 모듈을 #Include 로 로드
; ============================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
#DllLoad "*i bcrypt.dll"
#DllLoad "*i gdiplus.dll"

#Include lib/Globals.ahk
#Include lib/PathUtil.ahk
#Include lib/Config.ahk
#Include lib/Filter.ahk
#Include lib/Hash.ahk
#Include lib/GdipUtil.ahk
#Include lib/FileCollect.ahk
#Include lib/ListView.ahk
#Include lib/Preview.ahk
#Include lib/ExplorerPane.ahk
#Include lib/Explorer.ahk
#Include lib/Actions.ahk
#Include lib/Scan.ahk
#Include lib/GuiLayout.ahk
#Include lib/GuiEvents.ahk
#Include lib/GuiSettings.ahk
#Include lib/GuiBuild.ahk

GdipInit()
LoadFilterSettings()
LoadUiSettings()
LoadLvColWidths()
BuildGui()
return
