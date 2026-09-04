    movzx     eax, byte [ebp + 16]
    ; If it is a number
    cmp       eax, '0'
      jb      @F
    cmp       eax, '9'
      ja      @F

    ; chr -= '0';
    ; int bit = chr & 07h; // max 8 bits in each mask
    ; int idx = chr >> 3;
    sub       eax, '0'
    mov       ecx, eax
    and       ecx, 07h ; bit
    shr       eax, 3   ; idx

    ; OR this bit to the mask[idx]
    ; mask[idx] |= 1 << bit;
    mov       bl, 1
    shl       bl, cl                        ; 1 << bit
    lea       edx, [eax + cmKeyboard.bKeys] ; &mask[idx]
    or        byte [edx], bl                ; or it

    jmp       ._EndKeyDown
@@:
    ; If it is a ABC
    cmp       eax, 'A'
      jb      @F
    cmp       eax, 'Z'
      ja      @F

    ; chr = chr - 'A' + ('9' - '0' + 1);
    ; ...
    sub       eax, 'A'
    add       eax, ('9' - '0' + 1)
    mov       ecx, eax
    and       ecx, 07h ; bit
    shr       eax, 3   ; idx

    ; OR this bit to the mask[idx]
    mov       bl, 1
    shl       bl, cl                        ; 1 << bit
    lea       edx, [eax + cmKeyboard.bKeys] ; &mask[idx]
    or        byte [edx], bl                ; or it
@@:
    ; If it is any other char
    ; break;
._EndKeyDown: