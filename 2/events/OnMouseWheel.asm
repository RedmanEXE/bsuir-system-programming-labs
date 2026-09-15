    mov       eax, [wParam]
    mov       ecx, eax

    ; Get only position (high-word)
    shr       ecx, 16
    movsx     ecx, cx

    ; If WHEEL_DELTA is 0
    test      ecx, ecx
      jz      ._SkipMouseWheel

    test      eax, MK_SHIFT
      jz      @F
    ; If there's [SHIFT] pressed, negate WHEEL_DELTA
    neg       ecx
@@:
    ; Add to general accumulator
    add       [cmMouse.wheelAccum], ecx

    ; Scroll the grid: negative delta = scroll down, positive = scroll up
    ; Each WHEEL_DELTA (120) scrolls by ~40 pixels
    ; ecx = positive means scroll up (decrease scrollY), negative means scroll down
    neg       ecx                   ; invert: wheel up -> negative delta for scrollY
    mov       eax, ecx
    ; Invert EDX, if lower than 0
    xor       edx, edx
    cmp       eax, 0
      jge     @F
    not       edx
@@:
    mov       ecx, 20
    idiv      ecx                   ; eax = scaled scroll delta
    stdcall   Grid.Scroll, cmGrid, [cmWindow.hBBufMemDC], eax

._SkipMouseWheel: