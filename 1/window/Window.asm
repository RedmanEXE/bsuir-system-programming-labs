; void Window.CreateBackbuffer(Window *cmWindow, HDC hDC)
Window.CreateBackbuffer:
    push      ebp
    mov       ebp, esp
    push      ecx edx ebx esi edi

    mov       ebx, [ebp + 12]      ; hDC
    mov       esi, [ebp + 8]       ; cmWindow
    ; Create backbuffer DC for window
    invoke    CreateCompatibleDC, ebx
    mov       [esi + 12], eax      ; cmWindow.hBBufMemDC
    mov       edi, eax
    ; Create bitmap for backbuffer
    movzx     ecx, word [esi + 4]  ; cmWindow.width
    movzx     edx, word [esi + 6]  ; cmWindow.height
    invoke    CreateCompatibleBitmap, ebx, ecx, edx
    mov       [esi + 16], eax      ; cmWindow.hBBufBitmap
    ; Select bitmap as backbuffer object
    invoke    SelectObject, edi, eax
    ; Save old bitmap
    mov       [esi + 20], eax      ; cmWindow.hBBufOldBmp

    pop       edi esi ebx edx ecx
    leave
    ret       8

; HWND Window.CreateWindow(HINSTANCE hInstance, int iWidth, int iHeight, char *lpszClassName,
;                          char *lpszWindowName, WNDPROC fnWindowProc, HBRUSH hbrBg);
Window.CreateWindow:
    push      ebp
    mov       ebp, esp
    push      ecx edx ebx esi edi

    ; Get HINSTANCE value of the program
    mov       ebx, [ebp + 8]               ; hInstance
    ; Load lpszClassName and lpszWindowName and fnWindowProc values into registers
    mov       esi, [ebp + 20]              ; lpszClassName
    mov       edi, [ebp + 24]              ; lpszWindowName
    mov       edx, [ebp + 28]              ; fnWindowProc

    ; Load arrow cursor
    push      edx
    invoke    LoadCursor, NULL, IDC_ARROW
    pop       edx
    mov       ecx, [ebp + 32]

    ; Create WNDCLASSEX structure
    push      ebp
    mov       ebp, esp
    ; WNDCLASSEX END
    push      NULL                         ; hIconSm
    push      esi                          ; lpszClassName
    push      NULL                         ; lpszMenuName
    push      ecx                          ; hbrBackground
    push      eax                          ; hCursor
    push      NULL                         ; hIcon
    push      ebx                          ; hInstance
    push      0                            ; cbWndExtra
    push      0                            ; cbClsExtra
    push      edx                          ; lpfnWndProc
    push      CS_HREDRAW or CS_VREDRAW     ; style
    push      sizeof.WNDCLASSEX            ; cbSize
    ; WNDCLASSEX BEGIN

    ; And register it
    invoke    RegisterClassEx, esp
    leave

    ; Load width and height into registers
    mov       ecx, [ebp + 12] ; iWidth
    mov       edx, [ebp + 16] ; iHeight
    ; Adjust sizes
    push      ebp
    mov       ebp, esp
    ; RECT END
    push      edx
    push      ecx
    push      0
    push      0
    ; RECT BEGIN
    mov       eax, esp
    invoke    AdjustWindowRectEx, eax, WS_OVERLAPPED or WS_CAPTION or WS_SYSMENU or WS_THICKFRAME,\
              FALSE, 0
    ; And save results
    mov       ecx, [ebp - 8]
    sub       ecx, [ebp - 16]
    mov       edx, [ebp - 4]
    sub       edx, [ebp - 12]
    leave

    ; Create window
    invoke    CreateWindowEx, 0, esi, edi, WS_VISIBLE or WS_OVERLAPPED or WS_CAPTION or WS_SYSMENU or WS_THICKFRAME,\
              CW_USEDEFAULT, CW_USEDEFAULT, ecx, edx, 0, 0, ebx, 0

    pop       edi esi ebx edx ecx
    leave
    ret       28

; UINT Window.ProcessMessages(HWND hWnd, HACCEL hAccel, LPMSG lpMsg);
Window.ProcessMessages:
    push      ebp
    mov       ebp, esp
    push      edx ebx esi
    ; Load lpMsg into register
    mov       esi, [ebp + 16]      ; lpMsg
    mov       eax, [ebp + 8]       ; hWnd

    ; Retrieve message queue status
    invoke    PeekMessage, esi, eax, 0, 0, PM_REMOVE
    cmp       eax, 0
      jle     .NotQuitButEmpty
    movzx     eax, word [esi + 4]
    cmp       eax, 0
      jle     .Quit

    ; Check for accelerator
    invoke    TranslateAccelerator, [ebp + 8], [ebp + 12], esi
    test      eax, eax
      jnz     @F

    ; And process it
    invoke    TranslateMessage, esi
    invoke    DispatchMessage, esi
@@:

.NotQuitButEmpty:
    mov       eax, 1
.Quit:
    pop       esi ebx edx
    leave
    ret       8

