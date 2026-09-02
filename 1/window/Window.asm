; HWND Window.CreateWindow(int iWidth, int iHeight, char *lpszClassName, char *lpszWindowName, WNDPROC fnWindowProc);
Window.CreateWindow:
    push    ebp
    mov     ebp, esp
    push    ecx edx ebx esi edi

    ; Get HINSTANCE value of the program
    push    NULL
    call    [GetModuleHandle]
    mov     ebx, eax
    ; Load lpszClassName and lpszWindowName and fnWindowProc values into registers
    mov     esi, [ebp + 16] ; lpszClassName
    mov     edi, [ebp + 20] ; lpszWindowName
    mov     eax, [ebp + 24] ; fnWindowProc

    ; Create WNDCLASSEX structure
    push    ebp
    mov     ebp, esp
    ; WNDCLASSEX END
    push    NULL
    push    esi
    push    NULL
    push    NULL
    push    NULL
    push    NULL
    push    ebx
    push    0
    push    0
    push    eax
    push    CS_HREDRAW or CS_VREDRAW
    push    sizeof.WNDCLASSEX
    ; WNDCLASSEX BEGIN

    ; And register it
    push    esp
    call    [RegisterClassEx]
    leave

    ; Load width and height into registers
    mov     ecx, [ebp + 8]  ; iWidth
    mov     edx, [ebp + 12] ; iHeight
    ; Adjust sizes
    push    ebp
    mov     ebp, esp
    ; RECT END
    push    ecx
    push    edx
    push    0
    push    0
    ; RECT BEGIN
    mov     eax, esp
    push    0
    push    FALSE
    push    WS_OVERLAPPED or WS_CAPTION or WS_SYSMENU or WS_THICKFRAME
    push    eax
    call    [AdjustWindowRectEx]
    ; And save results
    mov     ecx, [ebp - 8]
    sub     ecx, [ebp - 16]
    mov     edx, [ebp - 4]
    sub     edx, [ebp - 12]
    leave

    ; Create window
    push    0
    push    ebx
    push    0
    push    0
    push    edx
    push    ecx
    push    0
    push    0
    push    WS_VISIBLE or WS_OVERLAPPED or WS_CAPTION or WS_SYSMENU or WS_THICKFRAME
    push    edi
    push    esi
    push    0
    call    [CreateWindowEx]
    mov     [hWindow], eax

    pop     edi esi ebx edx ecx
    leave
    ret     20

