; HBITMAP Icons.ConvertIconToBitmap(HICON hIcon);
proc Icons.ConvertIconToBitmap stdcall uses ecx edx ebx esi edi,\
     hIcon:DWORD
    locals
        .rc             RECT
        .hScreenDC      rd 1
        .hMemDC         rd 1
        .hBitmap        rd 1
        .hOldBitmap     rd 1
    endl

    ; Check for valid icon handle
    mov       ebx, [hIcon]
    test      ebx, ebx
      jz      .Failed

    ; Get screen DC to create a full-color compatible bitmap
    invoke    GetDC, NULL
    test      eax, eax
      jz      .Failed
    mov       [.hScreenDC], eax

    ; Create memory DC
    invoke    CreateCompatibleDC, [.hScreenDC]
    test      eax, eax
      jz      .CleanupScreenDC
    mov       [.hMemDC], eax

    ; Create compatible bitmap (16x16 standard toolbar icon size)
    invoke    CreateCompatibleBitmap, [.hScreenDC], 16, 16
    test      eax, eax
      jz      .CleanupMemDC
    mov       [.hBitmap], eax

    ; Select bitmap into memory DC
    invoke    SelectObject, [.hMemDC], [.hBitmap]
    mov       [.hOldBitmap], eax

    ; Setup RECT for background fill (0, 0, 16, 16)
    mov       [.rc.left], 0
    mov       [.rc.top], 0
    mov       [.rc.right], 16
    mov       [.rc.bottom], 16

    ; Fill background with COLOR_BTNFACE
    lea       eax, [.rc]
    invoke    FillRect, [.hMemDC], eax, COLOR_BTNFACE + 1

    ; Draw the icon onto memory DC
    invoke    DrawIconEx, [.hMemDC], 0, 0, [hIcon], 16, 16, 0, NULL, DI_NORMAL

    ; Restore original bitmap in memory DC
    invoke    SelectObject, [.hMemDC], [.hOldBitmap]

    ; Cleanup DCs
    invoke    DeleteDC, [.hMemDC]
    invoke    ReleaseDC, NULL, [.hScreenDC]

    ; Return HBITMAP handle
    mov       eax, [.hBitmap]
    jmp       .Done

.CleanupMemDC:
    invoke    DeleteDC, [.hMemDC]

.CleanupScreenDC:
    invoke    ReleaseDC, NULL, [.hScreenDC]

.Failed:
    xor       eax, eax

.Done:
    ret
endp

; HICON Icons.LoadIcon(LPSTR lpszPath, DWORD dwFileAttributes);
proc Icons.LoadIcon stdcall uses ecx edx edi,\
     lpszPath:DWORD, dwFileAttributes:DWORD
    locals
        .cmShfi         SHFILEINFO
    endl
    ; Cleanup memory
    lea       edi, [.cmShfi]
    mov       ecx, sizeof.SHFILEINFO / 4
    xor       eax, eax
    cld
      rep stosd
    ; Determine flags: request small icon
    mov       edx, SHGFI_ICON or SHGFI_SMALLICON
    ; If file attributes are passed, do not access disk directly
    cmp       [dwFileAttributes], 0
      je      @F
    or        edx, SHGFI_USEFILEATTRIBUTES
@@:
    ; Retrieve icon via SHGetFileInfo
    lea       eax, [.cmShfi]
    invoke    SHGetFileInfo, [lpszPath], [dwFileAttributes], eax, sizeof.SHFILEINFO, edx
    test      eax, eax
      jz      .Failed
    ; Return HICON
    mov       eax, [.cmShfi.hIcon]
    jmp       .End
.Failed:
    xor       eax, eax

.End:
    ret
endp

; HICON Icons.LoadSystemIcon(DWORD dwIcon);
proc Icons.LoadSystemIcon stdcall uses ecx edx edi,\
     dwIcon:DWORD
    locals
        .pidl           rd 1
        .shfi           SHFILEINFO
    endl
    ; Get PIDL
    lea       eax, [.pidl]
    invoke    SHGetSpecialFolderLocation, NULL, [dwIcon], eax
    test      eax, eax
      jnz     .Failed
    ; Clean-up struct
    lea       edi, [.shfi]
    mov       ecx, sizeof.SHFILEINFO / 4
    xor       eax, eax
    cld
      rep stosd
    ; Load icon
    lea       eax, [.shfi]
    invoke    SHGetFileInfo, [.pidl], 0, eax, sizeof.SHFILEINFO,\
              SHGFI_PIDL or SHGFI_ICON or SHGFI_SMALLICON
    test      eax, eax
      jz      .Failed
    ; Return HICON
    mov       eax, [.shfi.hIcon]
    jmp       .Done

.Failed:
    xor       eax, eax

.Done:
    ret
endp

; HBITMAP Icons.CreateIBeamBitmap();
proc Icons.CreateIBeamBitmap stdcall uses ecx edx ebx esi edi
    locals
        .rc             RECT
        .hScreenDC      rd 1
        .hMemDC         rd 1
        .hBitmap        rd 1
        .hOldBitmap     rd 1
        .hBrush         rd 1
    endl

    ; Get screen DC
    invoke    GetDC, NULL
    test      eax, eax
      jz      .Failed
    mov       [.hScreenDC], eax

    ; Create memory DC
    invoke    CreateCompatibleDC, [.hScreenDC]
    test      eax, eax
      jz      .CleanupScreenDC
    mov       [.hMemDC], eax

    ; Create 16x16 bitmap
    invoke    CreateCompatibleBitmap, [.hScreenDC], 16, 16
    test      eax, eax
      jz      .CleanupMemDC
    mov       [.hBitmap], eax

    ; Select bitmap into memory DC
    invoke    SelectObject, [.hMemDC], [.hBitmap]
    mov       [.hOldBitmap], eax

    ; 1. Fill entire 16x16 with COLOR_BTNFACE
    mov       [.rc.left], 0
    mov       [.rc.top], 0
    mov       [.rc.right], 16
    mov       [.rc.bottom], 16
    lea       eax, [.rc]
    invoke    FillRect, [.hMemDC], eax, COLOR_BTNFACE + 1

    ; 2. Get black brush for drawing the I-beam
    invoke    GetStockObject, BLACK_BRUSH
    mov       [.hBrush], eax

    ; 3. Draw top serif (horizontal bar: x=5..10, y=2)
    mov       [.rc.left], 5
    mov       [.rc.top], 2
    mov       [.rc.right], 11
    mov       [.rc.bottom], 3
    lea       eax, [.rc]
    invoke    FillRect, [.hMemDC], eax, [.hBrush]

    ; Top serif down-ticks (ears at x=5 and x=10, y=3)
    mov       [.rc.left], 5
    mov       [.rc.top], 3
    mov       [.rc.right], 6
    mov       [.rc.bottom], 4
    lea       eax, [.rc]
    invoke    FillRect, [.hMemDC], eax, [.hBrush]

    mov       [.rc.left], 10
    mov       [.rc.top], 3
    mov       [.rc.right], 11
    mov       [.rc.bottom], 4
    lea       eax, [.rc]
    invoke    FillRect, [.hMemDC], eax, [.hBrush]

    ; 4. Draw stem (vertical bar: x=7..8, y=3..13)
    mov       [.rc.left], 7
    mov       [.rc.top], 3
    mov       [.rc.right], 9
    mov       [.rc.bottom], 13
    lea       eax, [.rc]
    invoke    FillRect, [.hMemDC], eax, [.hBrush]

    ; 5. Bottom serif up-ticks (ears at x=5 and x=10, y=12)
    mov       [.rc.left], 5
    mov       [.rc.top], 12
    mov       [.rc.right], 6
    mov       [.rc.bottom], 13
    lea       eax, [.rc]
    invoke    FillRect, [.hMemDC], eax, [.hBrush]

    mov       [.rc.left], 10
    mov       [.rc.top], 12
    mov       [.rc.right], 11
    mov       [.rc.bottom], 13
    lea       eax, [.rc]
    invoke    FillRect, [.hMemDC], eax, [.hBrush]

    ; Bottom serif (horizontal bar: x=5..10, y=13)
    mov       [.rc.left], 5
    mov       [.rc.top], 13
    mov       [.rc.right], 11
    mov       [.rc.bottom], 14
    lea       eax, [.rc]
    invoke    FillRect, [.hMemDC], eax, [.hBrush]

    ; Unselect bitmap
    invoke    SelectObject, [.hMemDC], [.hOldBitmap]

    ; Cleanup DCs
    invoke    DeleteDC, [.hMemDC]
    invoke    ReleaseDC, NULL, [.hScreenDC]

    mov       eax, [.hBitmap]
    jmp       .Done

.CleanupMemDC:
    invoke    DeleteDC, [.hMemDC]

.CleanupScreenDC:
    invoke    ReleaseDC, NULL, [.hScreenDC]

.Failed:
    xor       eax, eax

.Done:
    ret
endp

; HBITMAP Icons.CreateRefreshBitmap();
; Creates a native 16x16 Refresh (circular arrows) bitmap for toolbar
proc Icons.CreateRefreshBitmap stdcall uses ecx edx ebx esi edi
    locals
        .rc             RECT
        .hScreenDC      rd 1
        .hMemDC         rd 1
        .hBitmap        rd 1
        .hOldBitmap     rd 1
        .hBrush         rd 1
    endl

    ; Get screen DC
    invoke    GetDC, NULL
    test      eax, eax
      jz      .Failed
    mov       [.hScreenDC], eax

    ; Create memory DC
    invoke    CreateCompatibleDC, [.hScreenDC]
    test      eax, eax
      jz      .CleanupScreenDC
    mov       [.hMemDC], eax

    ; Create 16x16 bitmap
    invoke    CreateCompatibleBitmap, [.hScreenDC], 16, 16
    test      eax, eax
      jz      .CleanupMemDC
    mov       [.hBitmap], eax

    ; Select bitmap into memory DC
    invoke    SelectObject, [.hMemDC], [.hBitmap]
    mov       [.hOldBitmap], eax

    ; 1. Fill entire 16x16 with COLOR_BTNFACE
    mov       [.rc.left], 0
    mov       [.rc.top], 0
    mov       [.rc.right], 16
    mov       [.rc.bottom], 16
    lea       eax, [.rc]
    invoke    FillRect, [.hMemDC], eax, COLOR_BTNFACE + 1

    ; 2. Black brush for arrows
    invoke    GetStockObject, BLACK_BRUSH
    mov       [.hBrush], eax

    ; Upper arc:
    ; Top bar: x=6..11, y=3..5
    mov       [.rc.left], 6
    mov       [.rc.top], 3
    mov       [.rc.right], 11
    mov       [.rc.bottom], 5
    lea       eax, [.rc]
    invoke    FillRect, [.hMemDC], eax, [.hBrush]

    ; Left upper down-curve: x=4..6, y=4..8
    mov       [.rc.left], 4
    mov       [.rc.top], 4
    mov       [.rc.right], 6
    mov       [.rc.bottom], 8
    lea       eax, [.rc]
    invoke    FillRect, [.hMemDC], eax, [.hBrush]

    ; Right upper down-curve: x=10..12, y=4..7
    mov       [.rc.left], 10
    mov       [.rc.top], 4
    mov       [.rc.right], 12
    mov       [.rc.bottom], 7
    lea       eax, [.rc]
    invoke    FillRect, [.hMemDC], eax, [.hBrush]

    ; Upper arrowhead (pointing right-down at x=11..13, y=2..6):
    mov       [.rc.left], 11
    mov       [.rc.top], 2
    mov       [.rc.right], 13
    mov       [.rc.bottom], 4
    lea       eax, [.rc]
    invoke    FillRect, [.hMemDC], eax, [.hBrush]

    mov       [.rc.left], 12
    mov       [.rc.top], 4
    mov       [.rc.right], 14
    mov       [.rc.bottom], 6
    lea       eax, [.rc]
    invoke    FillRect, [.hMemDC], eax, [.hBrush]

    ; Lower arc:
    ; Bottom bar: x=5..10, y=11..13
    mov       [.rc.left], 5
    mov       [.rc.top], 11
    mov       [.rc.right], 10
    mov       [.rc.bottom], 13
    lea       eax, [.rc]
    invoke    FillRect, [.hMemDC], eax, [.hBrush]

    ; Right lower up-curve: x=10..12, y=8..12
    mov       [.rc.left], 10
    mov       [.rc.top], 8
    mov       [.rc.right], 12
    mov       [.rc.bottom], 12
    lea       eax, [.rc]
    invoke    FillRect, [.hMemDC], eax, [.hBrush]

    ; Left lower up-curve: x=4..6, y=9..12
    mov       [.rc.left], 4
    mov       [.rc.top], 9
    mov       [.rc.right], 6
    mov       [.rc.bottom], 12
    lea       eax, [.rc]
    invoke    FillRect, [.hMemDC], eax, [.hBrush]

    ; Lower arrowhead (pointing left-up at x=2..4, y=10..14):
    mov       [.rc.left], 3
    mov       [.rc.top], 12
    mov       [.rc.right], 5
    mov       [.rc.bottom], 14
    lea       eax, [.rc]
    invoke    FillRect, [.hMemDC], eax, [.hBrush]

    mov       [.rc.left], 2
    mov       [.rc.top], 10
    mov       [.rc.right], 4
    mov       [.rc.bottom], 12
    lea       eax, [.rc]
    invoke    FillRect, [.hMemDC], eax, [.hBrush]

    ; Center pixel spacer: clear center (x=6..10, y=5..11) with BTNFACE
    mov       [.rc.left], 6
    mov       [.rc.top], 5
    mov       [.rc.right], 10
    mov       [.rc.bottom], 11
    lea       eax, [.rc]
    invoke    FillRect, [.hMemDC], eax, COLOR_BTNFACE + 1

    ; Cleanup DCs and restore bitmap
    invoke    SelectObject, [.hMemDC], [.hOldBitmap]
    invoke    DeleteDC, [.hMemDC]
    invoke    ReleaseDC, NULL, [.hScreenDC]

    mov       eax, [.hBitmap]
    jmp       .Done

.CleanupMemDC:
    invoke    DeleteDC, [.hMemDC]

.CleanupScreenDC:
    invoke    ReleaseDC, NULL, [.hScreenDC]

.Failed:
    xor       eax, eax

.Done:
    ret
endp

; HICON Icons.CreateGrayscaleIcon(HICON hIcon);
; Converts a 16x16 icon to grayscale while preserving mask/transparency.
; Works natively on Windows 95+.
proc Icons.CreateGrayscaleIcon stdcall uses ecx edx ebx esi edi,\
     hIcon:DWORD
    locals
        .ii             ICONINFO
        .bmi            BITMAPINFOHEADER
        .hScreenDC      rd 1
        .hMemDC         rd 1
        .hDIB           rd 1
        .hOldBmp        rd 1
        .pBits          rd 1
        .hGrayIcon      rd 1
    endl

    mov       [.hGrayIcon], 0
    mov       [.hScreenDC], 0
    mov       [.hMemDC], 0
    mov       [.hDIB], 0
    mov       [.ii.hbmMask], 0
    mov       [.ii.hbmColor], 0

    cmp       [hIcon], 0
      je      .Done

    ; Extract icon information (mask and color bitmaps)
    lea       eax, [.ii]
    invoke    GetIconInfo, [hIcon], eax
    test      eax, eax
      jz      .Done

    ; Create memory DC compatible with screen
    invoke    GetDC, NULL
    test      eax, eax
      jz      .CleanupII
    mov       [.hScreenDC], eax

    invoke    CreateCompatibleDC, [.hScreenDC]
    test      eax, eax
      jz      .ReleaseScreenDC
    mov       [.hMemDC], eax

    ; Fill BITMAPINFOHEADER for 16x16 32-bit DIB
    lea       edi, [.bmi]
    mov       ecx, sizeof.BITMAPINFOHEADER / 4
    xor       eax, eax
    cld
      rep stosd

    mov       [.bmi.biSize], sizeof.BITMAPINFOHEADER
    mov       [.bmi.biWidth], 16
    mov       [.bmi.biHeight], 16
    mov       [.bmi.biPlanes], 1
    mov       [.bmi.biBitCount], 32
    mov       [.bmi.biCompression], BI_RGB

    ; Create DIBSection to directly access pixel bytes
    lea       eax, [.bmi]
    lea       edx, [.pBits]
    invoke    CreateDIBSection, [.hMemDC], eax, DIB_RGB_COLORS, edx, NULL, 0
    test      eax, eax
      jz      .CleanupMemDC
    mov       [.hDIB], eax

    ; Select DIB into memory DC
    invoke    SelectObject, [.hMemDC], [.hDIB]
    mov       [.hOldBmp], eax

    ; Draw the original icon onto the 32-bit DIB
    invoke    DrawIconEx, [.hMemDC], 0, 0, [hIcon], 16, 16, 0, NULL, DI_NORMAL

    ; Convert the 16x16 pixels (256 DWORDs) to grayscale
    mov       esi, [.pBits]
    test      esi, esi
      jz      .RestoreDIB

    mov       ecx, 256
.GrayLoop:
    ; Pixel format in 32-bit DIB is BGRA:
    ; [esi+0] = B, [esi+1] = G, [esi+2] = R, [esi+3] = A
    movzx     eax, byte [esi + 2]        ; R
    imul      eax, 77
    movzx     edx, byte [esi + 1]        ; G
    imul      edx, 150
    add       eax, edx
    movzx     edx, byte [esi + 0]        ; B
    imul      edx, 29
    add       eax, edx
    shr       eax, 8                     ; Gray = (R*77 + G*150 + B*29) >> 8

    mov       byte [esi + 0], al         ; B
    mov       byte [esi + 1], al         ; G
    mov       byte [esi + 2], al         ; R
    add       esi, 4
    dec       ecx
      jnz     .GrayLoop

.RestoreDIB:
    invoke    SelectObject, [.hMemDC], [.hOldBmp]

    ; Replace color bitmap in ICONINFO with our grayscale DIB
    cmp       [.ii.hbmColor], 0
      je      @F
    invoke    DeleteObject, [.ii.hbmColor]
@@:
    mov       eax, [.hDIB]
    mov       [.ii.hbmColor], eax

    ; Create new grayscale icon
    lea       eax, [.ii]
    invoke    CreateIconIndirect, eax
    mov       [.hGrayIcon], eax

    ; Clean up DIB bitmap
    invoke    DeleteObject, [.hDIB]

.CleanupMemDC:
    invoke    DeleteDC, [.hMemDC]

.ReleaseScreenDC:
    invoke    ReleaseDC, NULL, [.hScreenDC]

.CleanupII:
    ; Clean up mask bitmap from GetIconInfo
    cmp       [.ii.hbmMask], 0
      je      .Done
    invoke    DeleteObject, [.ii.hbmMask]

.Done:
    mov       eax, [.hGrayIcon]
    ret
endp
