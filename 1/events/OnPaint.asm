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

    ; Allocate space for PAINTSTRUCT
    sub       esp, sizeof.PAINTSTRUCT

    ; Get HDC of the window
    invoke    BeginPaint, dword [ebp + 8], esp
    mov       ebx, eax

    ; Draw
    mov       eax, [cmSprite.hMemDC]
    test      eax, eax
      jz      @F

    movzx     ecx, word [cmSprite.ptPosition.x]
    movzx     edx, word [cmSprite.ptPosition.y]
    invoke    BitBlt, ebx, ecx, edx, dword [cmSprite.bmpInfo.bmWidth],\
              dword [cmSprite.bmpInfo.bmHeight], eax, 0, 0, SRCCOPY

@@:
    ; Release HDC from BeginPaint
    invoke    EndPaint, dword [ebp + 8], esp

    ; Free allocated PAINTSTRUCT
    add       esp, sizeof.PAINTSTRUCT

.SkipOnDraw:
    xor       eax, eax