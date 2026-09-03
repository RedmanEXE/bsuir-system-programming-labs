; HWND Window.CreateWindow(int iWidth, int iHeight, char *lpszClassName, char *lpszWindowName, WNDPROC fnWindowProc);
Window.CreateWindow:
    push      ebp
    mov       ebp, esp
    push      ecx edx ebx esi edi

    ; Get HINSTANCE value of the program
    invoke    GetModuleHandle, NULL
    mov       ebx, eax
    ; Load lpszClassName and lpszWindowName and fnWindowProc values into registers
    mov       esi, [ebp + 16] ; lpszClassName
    mov       edi, [ebp + 20] ; lpszWindowName
    mov       eax, [ebp + 24] ; fnWindowProc

    ; Create WNDCLASSEX structure
    push      ebp
    mov       ebp, esp
    ; WNDCLASSEX END
    push      NULL
    push      esi
    push      NULL
    push      NULL
    push      NULL
    push      NULL
    push      ebx
    push      0
    push      0
    push      eax
    push      CS_HREDRAW or CS_VREDRAW
    push      sizeof.WNDCLASSEX
    ; WNDCLASSEX BEGIN

    ; And register it
    invoke    RegisterClassEx, esp
    leave

    ; Load width and height into registers
    mov       ecx, [ebp + 8]  ; iWidth
    mov       edx, [ebp + 12] ; iHeight
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
              0, 0, ecx, edx, 0, 0, ebx, 0
    mov       [hWindow], eax

    pop       edi esi ebx edx ecx
    leave
    ret       20

; UINT Window.ProcessMessages(HWND hWnd, LPMSG lpMsg);
Window.ProcessMessages:
    push      ebp
    mov       ebp, esp
    push      edx ebx esi
    ; Load lpMsg into register
    mov       esi, [ebp + 12]
    mov       eax, [ebp + 8]

    ; Retrieve message queue status
    invoke    GetMessage, esi, eax, 0, 0
    cmp       eax, 0
      jle     @F
    mov       ebx, eax

    ; And process it
    invoke    TranslateMessage, esi
    invoke    DispatchMessage, esi

    mov       eax, ebx
@@:
    pop       esi ebx edx
    leave
    ret     8

