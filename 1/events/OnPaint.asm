    ; Check for window sizes
    ; 1. Allocate space for RECT
    sub       esp, sizeof.RECT

    ; 2. Call function
    invoke    GetClientRect, dword [ebp + 8], esp

    ; 3. Free allocated RECT
    mov       ecx, [esp + 8]  ; width
    mov       edx, [esp + 12] ; height
    add       esp, sizeof.RECT
    ; 4. Check for zero-sized window
    cmp       ecx, 0
      jle     .SkipOnDraw
    cmp       edx, 0
      jle     .SkipOnDraw

    ; Get HDC of the backbuffer
    mov       ebx, [cmWindow.hBBufMemDC]

    ; Draw
    mov       eax, [cmSprite.hMemDC]
    test      eax, eax
      jz      @F

    ; Cleanup old zone
    mov       esi, eax
    movzx     ecx, word [cmSprite.ptOldPos.x]
    add       cx, word [cmSprite.bmpInfo.bmWidth]
    movzx     edx, word [cmSprite.ptOldPos.y]
    add       dx, word [cmSprite.bmpInfo.bmHeight]

    ; RECT END
    push      edx
    push      ecx
    movzx     edx, word [cmSprite.ptOldPos.y]
    movzx     ecx, word [cmSprite.ptOldPos.x]
    push      edx
    push      ecx
    ; RECT BEGIN
    mov       edi, esp
    invoke    FillRect, ebx, edi, [cmWindow.hbrBg]
    add       esp, sizeof.RECT

    ; Update "old" position
    mov       ecx, [cmSprite.ptPosition]
    mov       [cmSprite.ptOldPos], ecx

    ; Copy sprite
    movsx     ecx, word [cmSprite.ptPosition.x]
    movsx     edx, word [cmSprite.ptPosition.y]
    invoke    BitBlt, ebx, ecx, edx, dword [cmSprite.bmpInfo.bmWidth],\
              dword [cmSprite.bmpInfo.bmHeight], esi, 0, 0, SRCCOPY

@@:
    ; Allocate space for PAINTSTRUCT
    sub       esp, sizeof.PAINTSTRUCT

    ; Get window DC to draw backbuffer
    invoke    BeginPaint, dword [ebp + 8], esp
    ; Copy backbuffer
    movzx     ecx, word [cmWindow.width]
    movzx     edx, word [cmWindow.height]
    invoke    BitBlt, eax, 0, 0, ecx, edx, ebx,\
              0, 0, SRCCOPY

    ; Release HDC from BeginPaint
    invoke    EndPaint, dword [ebp + 8], esp

    ; Free allocated PAINTSTRUCT
    add       esp, sizeof.PAINTSTRUCT

.SkipOnDraw:
    xor       eax, eax