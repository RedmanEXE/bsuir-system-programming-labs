    mov       eax, [cmSprite.hMemDC]
    test      eax, eax
      jz      @F
    ; Restore old bitmap
    invoke    SelectObject, eax, [cmSprite.hOldBitmap]
    invoke    DeleteDC, [cmSprite.hMemDC]
@@:

    mov       eax, [cmSprite.hBitmap]
    test      eax, eax
      jz      @F
    ; And free bitmap
    invoke    DeleteObject, eax
@@:
    ; Then call PostQuitMessage to send WM_QUIT
    invoke    PostQuitMessage, 0