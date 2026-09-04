    ; Copy width and height by one instruction
    mov       ecx, [ebp + 20]
    mov       dword [cmWindow.width], ecx