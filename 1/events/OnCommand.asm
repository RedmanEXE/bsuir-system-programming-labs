    movzx     eax, word [ebp + 16]     ; LOWORD(wParam)
    cmp       eax, KEY_ID_EXIT
      jne     @F

    invoke    DestroyWindow, [ebp + 8] ; hWnd
@@: