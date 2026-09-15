    movzx     eax, byte [wParam]

    ; --- Ctrl+B: toggle bold for selected cell ---
    cmp       eax, 'B'
    jne       ._NotCtrlB
    invoke    GetKeyState, VK_CONTROL
    test      ah, 80h
      jz      ._NotCtrlB
    stdcall   Grid.ToggleSelectedBold, cmGrid
    jmp       ._EndKeyDown
._NotCtrlB:

    ; --- Ctrl+I: toggle italic for selected cell ---
    cmp       eax, 'I'
    jne       ._NotCtrlI
    invoke    GetKeyState, VK_CONTROL
    test      ah, 80h
      jz      ._NotCtrlI
    stdcall   Grid.ToggleSelectedItalic, cmGrid
    jmp       ._EndKeyDown
._NotCtrlI:

    ; --- Ctrl+N: change columns count (Shift to decrease) ---
    cmp       eax, 'N'
      jne     ._NotCtrlN
    invoke    GetKeyState, VK_CONTROL
    test      ah, 80h
      jz      ._NotCtrlN
    invoke    GetKeyState, VK_SHIFT
    xor       al, al
    test      ah, 80h
      jz      @F
    or        al, 01h
@@:
    movzx     eax, al
    stdcall   Grid.StepCols, cmGrid, [cmApplication.hMemHeap], eax
    jmp       ._EndKeyDown
._NotCtrlN:

    ; --- Ctrl+M: change rows count (Shift to decrease) ---
    cmp       eax, 'M'
      jne     ._NotCtrlM
    invoke    GetKeyState, VK_CONTROL
    test      ah, 80h
      jz      ._NotCtrlM
    invoke    GetKeyState, VK_SHIFT
    xor       al, al
    test      ah, 80h
      jz      @F
    or        al, 01h
@@:
    movzx     eax, al
    stdcall   Grid.StepRows, cmGrid, [cmApplication.hMemHeap], eax
    jmp       ._EndKeyDown
._NotCtrlM:

    ; --- Arrow keys: move selected cell ---
    cmp       eax, VK_LEFT
      je      ._ArrowLeft
    cmp       eax, VK_RIGHT
      je      ._ArrowRight
    cmp       eax, VK_UP
      je      ._ArrowUp
    cmp       eax, VK_DOWN
      je      ._ArrowDown
    jmp       ._AfterArrows

._ArrowLeft:
    movzx     ecx, word [cmGrid.wSelectedCol]
    dec       ecx
    movzx     edx, word [cmGrid.wSelectedRow]
    stdcall   Grid.SelectCell, cmGrid, ecx, edx
    jmp       ._ArrowEnsureVisible

._ArrowRight:
    movzx     ecx, word [cmGrid.wSelectedCol]
    inc       ecx
    movzx     edx, word [cmGrid.wSelectedRow]
    stdcall   Grid.SelectCell, cmGrid, ecx, edx
    jmp       ._ArrowEnsureVisible

._ArrowUp:
    movzx     ecx, word [cmGrid.wSelectedCol]
    movzx     edx, word [cmGrid.wSelectedRow]
    dec       edx
    stdcall   Grid.SelectCell, cmGrid, ecx, edx
    jmp       ._ArrowEnsureVisible

._ArrowDown:
    movzx     ecx, word [cmGrid.wSelectedCol]
    movzx     edx, word [cmGrid.wSelectedRow]
    inc       edx
    stdcall   Grid.SelectCell, cmGrid, ecx, edx

._ArrowEnsureVisible:
    ; Auto-scroll viewport to keep the selected cell visible
    stdcall   Grid.EnsureVisible, cmGrid, [cmWindow.hBBufMemDC]
    jmp       ._EndKeyDown

._AfterArrows:
    ; --- Original key handling (0-9, A-Z bitmask) ---
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