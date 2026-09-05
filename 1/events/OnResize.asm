    ; Copy width and height by one instruction
    mov       ecx, [ebp + 20]
    mov       dword [cmWindow.width], ecx

    ; Update backbuffer bitmap
    ;
    ; 1. Free old bitmap (but not DC!)
    mov       ebx, [cmWindow.hBBufMemDC]
    ; 1.1 Select old bitmap to free ours bitmap
    invoke    SelectObject, ebx, [cmSprite.hOldBitmap]
    ; 1.2 Delete old bitmap
    invoke    DeleteObject, eax
    ;
    ; 2. Create new bitmap
    stdcall   Window.CreateBackbuffer, cmWindow, ebx