; ============================================================
;  lib/GdipUtil.ahk — GDI+ 초기화 + 이미지 로드/회전/썸네일
;  의존: Globals.ahk (GDIP_TOKEN), PathUtil.ahk (Max, Min)
;  외부: gdiplus.dll
; ============================================================

GdipInit() {
    global GDIP_TOKEN
    _gdipSI := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
    NumPut("UInt", 1, _gdipSI, 0)
    DllCall("gdiplus\GdiplusStartup", "Ptr*", &GDIP_TOKEN, "Ptr", _gdipSI, "Ptr", 0)
}

; 이미지 로드 → EXIF 회전 → 썸네일 생성 → HBITMAP 반환
_GdipLoadRotated(path, maxW, maxH) {
    pImg := 0
    r    := DllCall("gdiplus\GdipLoadImageFromFile", "WStr", path, "Ptr*", &pImg, "Int")
    if r || !pImg
        return 0

    orient := 1
    try {
        propSize := 0
        if !DllCall("gdiplus\GdipGetPropertyItemSize"
                , "Ptr", pImg, "UInt", 0x0112, "UInt*", &propSize, "Int") && propSize > 0 {
            propBuf := Buffer(propSize, 0)
            if !DllCall("gdiplus\GdipGetPropertyItem"
                    , "Ptr", pImg, "UInt", 0x0112, "UInt", propSize, "Ptr", propBuf, "Int") {
                pVal   := NumGet(propBuf, 8 + A_PtrSize, "Ptr")
                orient := NumGet(pVal, 0, "UShort")
            }
        }
    }
    if orient > 1 && orient <= 8 {
        rf := Map(2,4, 3,2, 4,6, 5,5, 6,1, 7,7, 8,3)
        DllCall("gdiplus\GdipImageRotateFlip", "Ptr", pImg, "Int", rf[orient])
    }

    imgW := 0, imgH := 0
    DllCall("gdiplus\GdipGetImageWidth",  "Ptr", pImg, "UInt*", &imgW)
    DllCall("gdiplus\GdipGetImageHeight", "Ptr", pImg, "UInt*", &imgH)
    if imgW < 1 || imgH < 1 {
        DllCall("gdiplus\GdipDisposeImage", "Ptr", pImg)
        return 0
    }

    ratio := Min(maxW / imgW, maxH / imgH)
    drawW := Max(1, Integer(imgW * ratio))
    drawH := Max(1, Integer(imgH * ratio))
    offX  := Integer((maxW - drawW) / 2)
    offY  := Integer((maxH - drawH) / 2)

    pThumb := 0
    DllCall("gdiplus\GdipCreateBitmapFromScan0"
        , "Int", maxW, "Int", maxH, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &pThumb)
    if !pThumb {
        DllCall("gdiplus\GdipDisposeImage", "Ptr", pImg)
        return 0
    }
    pG := 0
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", pThumb, "Ptr*", &pG)
    if pG {
        DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", pG, "Int", 7)
        pBrush := 0
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFFFFFFFF, "Ptr*", &pBrush)
        if pBrush {
            DllCall("gdiplus\GdipFillRectangleI", "Ptr", pG, "Ptr", pBrush
                , "Int", 0, "Int", 0, "Int", maxW, "Int", maxH)
            DllCall("gdiplus\GdipDeleteBrush", "Ptr", pBrush)
        }
        DllCall("gdiplus\GdipDrawImageRectI", "Ptr", pG, "Ptr", pImg
            , "Int", offX, "Int", offY, "Int", drawW, "Int", drawH)
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", pG)
    }

    hBmp := 0
    DllCall("gdiplus\GdipCreateHBITMAPFromBitmap"
        , "Ptr", pThumb, "Ptr*", &hBmp, "UInt", 0x00FFFFFF)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", pThumb)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", pImg)
    return hBmp
}
