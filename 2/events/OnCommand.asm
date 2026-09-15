    movzx     eax, word [wParam]       ; LOWORD(wParam)
    cmp       eax, KEY_ID_EXIT
      jne     @F

    invoke    DestroyWindow, [hWnd]    ; hWnd
@@: