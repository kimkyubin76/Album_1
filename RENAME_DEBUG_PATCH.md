# 앨범 패널 F2 리네임 — 디버그 패치

## 수정된 파일

1. **lib/GuiEvents.ahk** — OnWM_NOTIFY (code=-105) 로그 추가
2. **lib/ExplorerPane.ahk** — _EP_OnKeyDown, _EP_DoRename, _EP_OnEndLabelEdit 로그 + 디스크 검증

---

## 리네임 엔트리포인트 정리

| 위치 | 이벤트 | 핸들러 | ListView |
|------|--------|--------|----------|
| GuiEvents.ahk | WM_NOTIFY code=-105 (LVN_ENDLABELEDIT) | OnWM_NOTIFY → _EP_OnEndLabelEdit | hwndFrom으로 구분 |
| GuiBuild.ahk | OnMessage(0x0100) WM_KEYDOWN | _EP_OnKeyDown | F2 시 side=F/A |
| ExplorerPane.ahk | F2 (VK 0x71) | _EP_DoRename | LVM_EDITLABEL(0x1017) 전송 |
| ExplorerPane.ahk | Shell 컨텍스트 "이름 바꾸기" cmd=1 | _EP_ShowShellMenu → _EP_DoRename | 동일 |

**ListView 구분:**
- **UI.ExpLvF** — 액자 패널 (좌측)
- **UI.ExpLvA** — 앨범 패널 (우측)
- **UI.LV** — 상단 매칭 리스트 (LVS_EDITLABELS 없음 → F2 인라인 편집 미지원)

---

## OutputDebug 로그 예시

### 정상 흐름 (앨범 패널에서 photo.jpg → photo2.jpg 리네임)

```
[RENAME] F2 key hwnd=12345678 side=A (ExpLvF=11111111 ExpLvA=12345678 LV=99999999)
[RENAME] _EP_DoRename lvHwnd=12345678 side=A row=3 oldPath=D:\Album\01\photo.jpg
[RENAME] OnNotify code=-105 hwndFrom=12345678 lv=ExpLvA(앨범) ExpLvF=11111111 ExpLvA=12345678 LV=99999999
[RENAME] handler=_EP_OnEndLabelEdit ENTRY
[RENAME] handler=_EP_OnEndLabelEdit old=D:\Album\01\photo.jpg new=D:\Album\01\photo2.jpg
[RENAME] handler=_EP_OnEndLabelEdit FileMove done
[RENAME] handler=_EP_OnEndLabelEdit diskVerify movedOk=1 oldStill=0
[RENAME] handler=_EP_OnEndLabelEdit SUCCESS return 1
[RENAME] OnNotify → _EP_OnEndLabelEdit returned 1
```

### 핸들러 미경유 시 (LVN_ENDLABELEDIT가 다른 ListView에서 발생)

```
[RENAME] OnNotify code=-105 hwndFrom=99999999 lv=LV(상단매칭리스트) ExpLvF=11111111 ExpLvA=12345678 LV=99999999
[RENAME] OnNotify → NOT routed (hwndFrom not ExpLvF/ExpLvA)
```

### F2가 폴더 패널이 아닌 곳에서 눌렸을 때

```
[RENAME] F2 key hwnd=88888888 → side=empty (not folder panel), skip
```

### _EP_RenamePending 없음 (F2 없이 직접 편집 시도 등)

```
[RENAME] handler=_EP_OnEndLabelEdit ENTRY
[RENAME] handler=_EP_OnEndLabelEdit → reject: no _EP_RenamePending
```

### 디스크 검증 실패 시

```
[RENAME] handler=_EP_OnEndLabelEdit FileMove done
[RENAME] handler=_EP_OnEndLabelEdit diskVerify movedOk=0 oldStill=1
```
→ MsgBox "디스크 검증 실패: 새 경로 존재=N 구경로 잔존=Y"

---

## 디버그 뷰어 실행

OutputDebug 출력 확인:
- **DebugView** (Sysinternals) — https://docs.microsoft.com/sysinternals/downloads/debugview
- 또는 AHK 스크립트 실행 시 `-Debug` 옵션
