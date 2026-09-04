    xor       eax, eax
    mov       [cmSprite.ptPosition], eax
    mov       [cmSprite.ptOldPos], eax

    ; Get Device Context of the window
    invoke    GetDC, dword [ebp + 8]
    mov       ebx, eax

    ; Create DC for bitmap
    invoke    CreateCompatibleDC, eax
    mov       [cmSprite.hMemDC], eax
    ; And select bitmap to draw
    invoke    SelectObject, eax, [cmSprite.hBitmap]
    mov       [cmSprite.hOldBitmap], eax
    ; Get info about bitmap
    invoke    GetObject, [cmSprite.hBitmap], sizeof.BITMAP, cmSprite.bmpInfo

    ; Release window's DC
    invoke    ReleaseDC, dword [ebp + 8], ebx


