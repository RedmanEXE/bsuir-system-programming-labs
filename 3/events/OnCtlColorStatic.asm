    invoke    SetBkMode, [wParam], TRANSPARENT
    ; Return native background color brush for controls
    mov       eax, COLOR_BTNFACE + 1