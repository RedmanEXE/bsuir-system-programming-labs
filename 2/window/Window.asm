; void Window.CreateBackbuffer(LPMWINDOW lpWindow, HDC hDC)
proc Window.CreateBackbuffer stdcall uses ecx edx ebx esi edi,\
     lpWindow:DWORD, hDC:DWORD
    mov       ebx, [hDC]                    ; hDC
    mov       esi, [lpWindow]               ; cmWindow
    virtual at esi
        window MWINDOW
    end virtual

    ; Create backbuffer DC for window
    invoke    CreateCompatibleDC, ebx
    mov       [window.hBBufMemDC], eax      ; cmWindow.hBBufMemDC
    mov       edi, eax
    ; Create bitmap for backbuffer
    movzx     ecx, word [window.width]      ; cmWindow.width
    movzx     edx, word [window.height]     ; cmWindow.height
    invoke    CreateCompatibleBitmap, ebx, ecx, edx
    mov       [window.hBBufBitmap], eax     ; cmWindow.hBBufBitmap
    ; Select bitmap as backbuffer object
    invoke    SelectObject, edi, eax
    ; Save old bitmap
    mov       [window.hBBufOldBmp], eax     ; cmWindow.hBBufOldBmp

    ret
endp

; HWND Window.CreateWindow(HINSTANCE hInstance, int iWidth, int iHeight, char *lpszClassName,
;                          char *lpszWindowName, WNDPROC fnWindowProc, HBRUSH hbrBg);
proc Window.CreateWindow stdcall uses ecx edx ebx esi edi,\
     hInstance:DWORD, iWidth:DWORD, iHeight:DWORD, lpszClassName:DWORD, lpszWindowName:DWORD,\
     fnWindowProc:DWORD, hbrBg:DWORD
    ; Get HINSTANCE value of the program
    mov       ebx, [hInstance]             ; hInstance
    ; Load lpszClassName and lpszWindowName values into registers
    mov       esi, [lpszClassName]         ; lpszClassName
    mov       edi, [lpszWindowName]        ; lpszWindowName

    ; Load arrow cursor
    invoke    LoadCursor, NULL, IDC_ARROW
    ; Load remaining values
    mov       edx, [fnWindowProc]          ; fnWindowProc
    mov       ecx, [hbrBg]                 ; hbrBg

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
    mov       ecx, [iWidth]   ; iWidth
    mov       edx, [iHeight]  ; iHeight
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
    invoke    AdjustWindowRectEx, eax, WS_OVERLAPPED or WS_CAPTION or WS_SYSMENU or WS_THICKFRAME or WS_MINIMIZEBOX or WS_MAXIMIZEBOX,\
              FALSE, 0
    ; And save results
    mov       ecx, [ebp - 8]
    sub       ecx, [ebp - 16]
    mov       edx, [ebp - 4]
    sub       edx, [ebp - 12]
    leave

    ; Create window
    invoke    CreateWindowEx, 0, esi, edi,\
              WS_VISIBLE or WS_OVERLAPPED or WS_CAPTION or WS_SYSMENU or WS_THICKFRAME or WS_MINIMIZEBOX or WS_MAXIMIZEBOX,\
              CW_USEDEFAULT, CW_USEDEFAULT, ecx, edx, 0, 0, ebx, 0

    ret
endp

; UINT Window.ProcessMessages(HWND hWnd, HACCEL hAccel, LPMSG lpMsg);
proc Window.ProcessMessages stdcall uses ecx edx ebx esi,\
     hWnd:DWORD, hAccel:DWORD, lpMsg:DWORD
    ; Load lpMsg into register
    mov       esi, [lpMsg]         ; lpMsg
    mov       eax, [hWnd]          ; hWnd
    virtual at esi
        msg   MSG
    end virtual

    ; Retrieve message queue status
    invoke    PeekMessage, esi, eax, 0, 0, PM_REMOVE
    cmp       eax, 0
      jle     .NotQuitButEmpty
    movzx     eax, word [msg.message]
    cmp       eax, 0
      jle     .Quit

    ; Check for accelerator
    invoke    TranslateAccelerator, [hWnd], [hAccel], esi
    test      eax, eax
      jnz     @F

    ; And process it
    invoke    TranslateMessage, esi
    invoke    DispatchMessage, esi
@@:

.NotQuitButEmpty:
    mov       eax, 1
.Quit:
    ret
endp
