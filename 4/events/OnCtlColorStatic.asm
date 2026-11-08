    invoke    SetBkMode, [wParam], TRANSPARENT
    ; Return native background color brush for controls
    invoke    GetSysColorBrush, COLOR_BTNFACE