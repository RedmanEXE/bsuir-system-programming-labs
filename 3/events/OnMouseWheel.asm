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

._SkipMouseWheel: