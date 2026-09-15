    ; Allocate space for PAINTSTRUCT
    sub       esp, sizeof.PAINTSTRUCT
    mov       esi, esp
    ; Get window DC to draw backbuffer
    invoke    BeginPaint, [hWnd], esp
    mov       edi, eax

    ; Check for window sizes
    ; 1. Allocate space for RECT
    sub       esp, sizeof.RECT

    ; 2. Call function
    invoke    GetClientRect, [hWnd], esp

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

    ; Cleanup old zone - clear backbuffer with black
    sub       esp, sizeof.RECT
    mov       dword [esp], 0
    mov       dword [esp + 4], 0
    movzx     eax, word [cmWindow.width]
    mov       dword [esp + 8], eax
    movzx     eax, word [cmWindow.height]
    mov       dword [esp + 12], eax
    invoke    GetStockObject, BLACK_BRUSH
    invoke    FillRect, ebx, esp, eax
    add       esp, sizeof.RECT

    ; Draw
    stdcall   Grid.Draw, cmGrid, ebx

    ; Copy backbuffer
    movzx     ecx, word [cmWindow.width]
    movzx     edx, word [cmWindow.height]
    invoke    BitBlt, edi, 0, 0, ecx, edx, ebx,\
              0, 0, SRCCOPY

.SkipOnDraw:
    ; Release HDC from BeginPaint
    invoke    EndPaint, [hWnd], esi
    ; Free allocated PAINTSTRUCT
    add       esp, sizeof.PAINTSTRUCT

    xor       eax, eax