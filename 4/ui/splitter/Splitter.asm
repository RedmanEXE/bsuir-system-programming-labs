; BOOL Splitter.Register(HINSTANCE hInstance);
proc Splitter.Register stdcall uses ecx edx ebx esi edi,\
     hInstance:DWORD
    locals
        .wc WNDCLASSEX
    endl

    invoke    LoadCursor, NULL, IDC_SIZEWE
    mov       ebx, eax

    ; Clean-up structure
    lea       edi, [.wc]
    mov       ecx, sizeof.WNDCLASSEX / 4
    xor       eax, eax
    cld
      rep stosd

    ; Fill it with custom values
    mov       [.wc.cbSize], sizeof.WNDCLASSEX
    mov       [.wc.style], CS_HREDRAW or CS_VREDRAW
    mov       [.wc.lpfnWndProc], Splitter.WindowProc
    mov       eax, [hInstance]
    mov       [.wc.hInstance], eax
    mov       [.wc.hCursor], ebx
    mov       [.wc.hbrBackground], COLOR_BTNFACE + 1
    mov       [.wc.lpszClassName], szSplitterClassName

    lea       eax, [.wc]
    invoke    RegisterClassEx, eax
    ret
endp

; HWND Splitter.Create(HWND hWndParent, DWORD dwControlId, DWORD dwX, DWORD dwY, DWORD dwWidth, DWORD dwHeight);
proc Splitter.Create stdcall uses ecx edx esi,\
     hWndParent:DWORD, dwControlId:DWORD, dwX:DWORD, dwY:DWORD, dwWidth:DWORD, dwHeight:DWORD
    ; Get HINSTANCE of parent window
    invoke    GetWindowLong, [hWndParent], GWL_HINSTANCE
    ; Create splitter
    invoke    CreateWindowEx, 0, szSplitterClassName, NULL,\
              WS_CHILD or WS_VISIBLE,\
              dword [dwX], dword [dwY], dword [dwWidth], dword [dwHeight],\
              dword [hWndParent], dword [dwControlId], eax, NULL
    ret
endp

; LRESULT CALLBACK Splitter.WindowProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam);
proc Splitter.WindowProc stdcall uses ebx esi edi,\
     hWnd:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD
    locals
        .pt         POINT
        .rcParent   RECT
    endl

    mov       eax, [uMsg]
    cmp       eax, WM_LBUTTONDOWN
      je      .OnLButtonDown
    cmp       eax, WM_MOUSEMOVE
      je      .OnMouseMove
    cmp       eax, WM_LBUTTONUP
      je      .OnLButtonUp
    cmp       eax, WM_CAPTURECHANGED
      je      .OnCaptureChanged
    cmp       eax, WM_SETCURSOR
      je      .OnSetCursor
    jmp       .Default

.OnLButtonDown:
    invoke    SetCapture, [hWnd]
    mov       [bSplitterDragging], 1
    movsx     eax, word [lParam]
    mov       [nSplitterDragOffset], eax
    xor       eax, eax
    ret

.OnMouseMove:
    cmp       [bSplitterDragging], 1
      jne     .Default

    ; Keep resize cursor active during dragging
    invoke    LoadCursor, NULL, IDC_SIZEWE
    invoke    SetCursor, eax

    ; Convert mouse point from splitter client coords to screen
    ; Then to parent client coords
    movsx     eax, word [lParam]
    movsx     edx, word [lParam + 2]
    mov       [.pt.x], eax
    mov       [.pt.y], edx

    lea       eax, [.pt]
    invoke    ClientToScreen, [hWnd], eax

    invoke    GetParent, [hWnd]
    mov       ebx, eax

    lea       eax, [.pt]
    invoke    ScreenToClient, ebx, eax

    ; Request parent client rect for bounds
    lea       eax, [.rcParent]
    invoke    GetClientRect, ebx, eax

    ; Calculate new position and clamp
    mov       esi, [.pt.x]
    sub       esi, [nSplitterDragOffset]

    cmp       esi, SPLITTER_MIN_LEFT
      jge     .CheckMax
    mov       esi, SPLITTER_MIN_LEFT

.CheckMax:
    mov       eax, [.rcParent.right]
    sub       eax, SPLITTER_MIN_RIGHT + SPLITTER_WIDTH
    cmp       eax, SPLITTER_MIN_LEFT
      jl      .ApplyPos
    cmp       esi, eax
      jle     .ApplyPos
    mov       esi, eax

.ApplyPos:
    cmp       [dwSplitterPos], esi
      je      .DoneMove
    mov       [dwSplitterPos], esi
    stdcall   RegEditProgram.UpdateLayout, ebx

.DoneMove:
    xor       eax, eax
    ret

.OnLButtonUp:
    cmp       [bSplitterDragging], 1
      jne     .Default
    mov       [bSplitterDragging], 0
    invoke    ReleaseCapture
    invoke    GetParent, [hWnd]
    stdcall   RegEditProgram.UpdateLayout, eax
    xor       eax, eax
    ret

.OnCaptureChanged:
    mov       [bSplitterDragging], 0
    xor       eax, eax
    ret

.OnSetCursor:
    invoke    LoadCursor, NULL, IDC_SIZEWE
    invoke    SetCursor, eax
    mov       eax, TRUE
    ret

.Default:
    invoke    DefWindowProc, [hWnd], [uMsg], [wParam], [lParam]
    ret
endp
