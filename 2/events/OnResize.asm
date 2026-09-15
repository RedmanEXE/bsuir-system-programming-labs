    ; Copy width and height by one instruction
    mov       ecx, [lParam]
    mov       dword [cmWindow.width], ecx

    ; Update grid sizes
    movzx     eax, word [lParam]
    movzx     ecx, word [lParam + 2]
    stdcall   Grid.Resize, cmGrid, eax, ecx

    ; Update backbuffer bitmap
    ;
    ; 1. Free old bitmap (but not DC!)
    mov       ebx, [cmWindow.hBBufMemDC]
    ; 1.1 Select old bitmap to free ours bitmap
    invoke    SelectObject, ebx, [cmWindow.hBBufOldBmp]
    ; 1.2 Delete old bitmap
    invoke    DeleteObject, eax
    ;
    ; 2. Create new bitmap
    invoke    GetDC, [hWnd]
    push      eax

    ; Create a bitmap from the screen DC
    movzx     ecx, word [cmWindow.width]
    movzx     edx, word [cmWindow.height]
    invoke    CreateCompatibleBitmap, eax, ecx, edx
    mov       [cmWindow.hBBufBitmap], eax
    ; Select it into existing memory DC
    invoke    SelectObject, ebx, eax
    mov       [cmWindow.hBBufOldBmp], eax

    ; Release the window DC
    pop       eax
    invoke    ReleaseDC, [hWnd], eax