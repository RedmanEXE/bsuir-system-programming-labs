    xor       eax, eax
    mov       [cmMouse.wheelAccum], eax
    mov       dword [cmKeyboard.bKeys], eax
    mov       [cmKeyboard.bKeys + 4], al

    mov       [cmWindow.width], WINDOW_INIT_WIDTH
    mov       [cmWindow.height], WINDOW_INIT_HEIGHT

    ; Register splitter class
    stdcall   Splitter.Register, [cmApplication.hModule]
    ; Register edit value dialog class
    stdcall   EditValueDialog.Register, [cmApplication.hModule]