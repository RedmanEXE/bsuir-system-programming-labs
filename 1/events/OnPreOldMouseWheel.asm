    xor       ebx, ebx
    ; Rebuild fwKeys manually, 'cause old Win95
    ; driver don't fill it for us
    invoke    GetKeyState, VK_CONTROL
    test      ah, 80h
      jz      @F
    or        bx, MK_CONTROL
@@:

    invoke    GetKeyState, VK_LBUTTON
    test      ah, 80h
      jz      @F
    or        bx, MK_LBUTTON
@@:

    invoke    GetKeyState, VK_MBUTTON
    test      ah, 80h
      jz      @F
    or        bx, MK_MBUTTON
@@:

    invoke    GetKeyState, VK_RBUTTON
    test      ah, 80h
      jz      @F
    or        bx, MK_RBUTTON
@@:

    invoke    GetKeyState, VK_SHIFT
    test      ah, 80h
      jz      @F
    or        bx, MK_SHIFT
@@:

    mov       edx, [ebp + 16] ; zDelta
    ; Fill fwKeys
    movzx     eax, dx         ; LOWORD(zDelta)
    shl       ebx, 16         ; HIWORD(fwKeys)
    or        eax, ebx        ; (fwKeys << 16) | (zDelta & 0xFFFF)
    ; Place it
    mov       [ebp + 16], eax
