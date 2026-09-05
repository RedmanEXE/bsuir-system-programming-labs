    xor       eax, eax
    mov       [cmSprite.ptPosition], eax
    mov       [cmSprite.ptOldPos], eax
    mov       [cmSprite.ptMoveAccum], eax
    mov       [cmMouse.wheelAccum], eax
    mov       dword [cmKeyboard.bKeys], eax
    mov       [cmKeyboard.bKeys + 4], al

    mov       [cmWindow.width], WINDOW_INIT_WIDTH
    mov       [cmWindow.height], WINDOW_INIT_HEIGHT

    ; Get Device Context of the window
    invoke    GetDC, dword [ebp + 8]
    mov       ebx, eax

    ; Create and activate backbuffer
    stdcall   Window.CreateBackbuffer, cmWindow, ebx

    ; Create DC for sprite's bitmap
    invoke    CreateCompatibleDC, ebx
    mov       [cmSprite.hMemDC], eax
    ; And select bitmap to draw
    invoke    SelectObject, eax, [cmSprite.hBitmap]
    mov       [cmSprite.hOldBitmap], eax
    ; Get info about bitmap
    invoke    GetObject, [cmSprite.hBitmap], sizeof.BITMAP, cmSprite.bmpInfo

    ; Release window's DC
    invoke    ReleaseDC, dword [ebp + 8], ebx
