    xor       eax, eax
    mov       [cmMouse.wheelAccum], eax
    mov       dword [cmKeyboard.bKeys], eax
    mov       [cmKeyboard.bKeys + 4], al

    mov       [cmWindow.width], WINDOW_INIT_WIDTH
    mov       [cmWindow.height], WINDOW_INIT_HEIGHT

    stdcall   Grid.Initialize, cmGrid, [cmApplication.hMemHeap], WINDOW_INIT_WIDTH,\
              WINDOW_INIT_HEIGHT, GRID_COLS_COUNT, GRID_ROWS_COUNT

    ; Get Device Context of the window
    invoke    GetDC, [hWnd]
    mov       ebx, eax

    ; Create and activate backbuffer
    stdcall   Window.CreateBackbuffer, cmWindow, ebx

    ; Release window's DC
    invoke    ReleaseDC, [hWnd], ebx
