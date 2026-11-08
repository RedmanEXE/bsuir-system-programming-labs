; BOOL ImageView.Register(HINSTANCE hInstance);
proc ImageView.Register stdcall uses ecx edx ebx esi edi,\
     hInstance:DWORD
    locals
        .wc             WNDCLASSEX
    endl

    ; Check if already registered
    cmp       [bImageViewClassRegistered], 0
      jne     .AlreadyRegistered

    lea       edi, [.wc]
    mov       ecx, sizeof.WNDCLASSEX / 4
    xor       eax, eax
    cld
      rep stosd

    mov       [.wc.cbSize], sizeof.WNDCLASSEX
    mov       [.wc.style], CS_HREDRAW or CS_VREDRAW
    mov       [.wc.lpfnWndProc], ImageView.WindowProc
    mov       [.wc.cbClsExtra], 0
    mov       [.wc.cbWndExtra], 4
    mov       eax, [hInstance]
    mov       [.wc.hInstance], eax
    invoke    LoadCursor, NULL, IDC_ARROW
    mov       [.wc.hCursor], eax
    mov       [.wc.hbrBackground], NULL
    mov       [.wc.lpszMenuName], NULL
    mov       [.wc.lpszClassName], szImageViewClassName
    mov       [.wc.hIconSm], NULL

    lea       eax, [.wc]
    invoke    RegisterClassEx, eax
    test      eax, eax
      jz      .Fail
    mov       [bImageViewClassRegistered], 1

.AlreadyRegistered:
    mov       eax, 1
    ret

.Fail:
    xor       eax, eax
    ret
endp

; HWND ImageView.CreateView(HWND hWndParent, DWORD dwControlId, WORD wX, WORD wY, WORD wWidth, WORD wHeight);
proc ImageView.CreateView stdcall uses ecx edx ebx esi edi,\
     hWndParent:DWORD, dwControlId:DWORD, wX:DWORD, wY:DWORD, wWidth:DWORD, wHeight:DWORD

    ; Get HINSTANCE of parent window
    invoke    GetWindowLong, [hWndParent], GWL_HINSTANCE
    mov       ebx, eax

    ; Register class
    stdcall   ImageView.Register, ebx
    test      eax, eax
      jz      .Fail

    ; Create image view window with client edge border
    invoke    CreateWindowEx, WS_EX_CLIENTEDGE, szImageViewClassName, NULL,\
              WS_CHILD or WS_VISIBLE,\
              dword [wX], dword [wY], dword [wWidth], dword [wHeight],\
              dword [hWndParent], dword [dwControlId], ebx, NULL
    ret

.Fail:
    xor       eax, eax
    ret
endp

; VOID ImageView.SetImage(HWND hImageView, LPMIMAGE lpImage);
proc ImageView.SetImage stdcall uses ecx edx,\
     hImageView:DWORD, lpImage:DWORD
    invoke    SetWindowLong, [hImageView], GWL_USERDATA, [lpImage]
    invoke    InvalidateRect, [hImageView], NULL, TRUE
    invoke    UpdateWindow, [hImageView]
    ret
endp

; LPMIMAGE ImageView.GetImage(HWND hImageView);
proc ImageView.GetImage stdcall uses ecx edx,\
     hImageView:DWORD
    invoke    GetWindowLong, [hImageView], GWL_USERDATA
    ret
endp

; VOID ImageView.Invalidate(HWND hImageView);
proc ImageView.Invalidate stdcall uses ecx edx,\
     hImageView:DWORD
    invoke    InvalidateRect, [hImageView], NULL, FALSE
    invoke    UpdateWindow, [hImageView]
    ret
endp

; LRESULT ImageView.WindowProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam);
proc ImageView.WindowProc stdcall uses ebx esi edi,\
     hWnd:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD
    locals
        .ps             PAINTSTRUCT
        .rc             RECT
        .bih            BITMAPINFOHEADER
        .hDC            rd 1
        .lpImg          rd 1
        .hBgBrush       rd 1
        .dwDstX         rd 1
        .dwDstY         rd 1
        .dwDstW         rd 1
        .dwDstH         rd 1
        .dwClientW      rd 1
        .dwClientH      rd 1
    endl

    mov       eax, [uMsg]
    cmp       eax, WM_PAINT
      je      .OnPaint
    cmp       eax, WM_ERASEBKGND
      je      .OnEraseBkgnd
    cmp       eax, WM_DROPFILES
      je      .OnDropFiles

.Default:
    invoke    DefWindowProc, [hWnd], [uMsg], [wParam], [lParam]
    ret

.OnDropFiles:
    invoke    GetParent, [hWnd]
    invoke    PostMessage, eax, WM_DROPFILES, [wParam], [lParam]
    xor       eax, eax
    ret

.OnEraseBkgnd:
    mov       eax, 1
    ret

.OnPaint:
    lea       ecx, [.ps]
    invoke    BeginPaint, [hWnd], ecx
    mov       [.hDC], eax

    invoke    GetStockObject, BLACK_BRUSH
    mov       [.hBgBrush], eax

    lea       ecx, [.rc]
    invoke    GetClientRect, [hWnd], ecx

    mov       eax, [.rc.right]
    sub       eax, [.rc.left]
    mov       [.dwClientW], eax
    mov       eax, [.rc.bottom]
    sub       eax, [.rc.top]
    mov       [.dwClientH], eax

    invoke    GetWindowLong, [hWnd], GWL_USERDATA
    mov       [.lpImg], eax
    test      eax, eax
      jz      .DrawEmpty

    mov       esi, eax
    virtual at esi
        .img MIMAGE
    end virtual

    mov       eax, [.img.lpBits]
    test      eax, eax
      jz      .DrawEmpty
    mov       eax, [.img.dwWidth]
    test      eax, eax
      jle     .DrawEmpty
    mov       eax, [.img.dwHeight]
    test      eax, eax
      jle     .DrawEmpty

    ; Calculate scaled destination rect maintaining aspect ratio
    ; Condition: imgWidth * clientH > imgHeight * clientW
    mov       eax, [.img.dwWidth]
    mul       dword [.dwClientH]
    mov       ebx, eax                 ; ebx = imgWidth * clientH

    mov       eax, [.img.dwHeight]
    mul       dword [.dwClientW]       ; eax = imgHeight * clientW

    cmp       ebx, eax
      jbe     .ScaleByHeight

.ScaleByWidth:
    mov       eax, [.dwClientW]
    mov       [.dwDstW], eax
    mov       dword [.dwDstX], 0

    mov       eax, [.img.dwHeight]
    mul       dword [.dwClientW]
    xor       edx, edx
    div       dword [.img.dwWidth]
    mov       [.dwDstH], eax

    ; Center vertically: dstY = (clientH - dstH) / 2
    mov       edx, [.dwClientH]
    sub       edx, eax
    shr       edx, 1
    mov       [.dwDstY], edx
    jmp       .DrawImage

.ScaleByHeight:
    mov       eax, [.dwClientH]
    mov       [.dwDstH], eax
    mov       dword [.dwDstY], 0

    mov       eax, [.img.dwWidth]
    mul       dword [.dwClientH]
    xor       edx, edx
    div       dword [.img.dwHeight]
    mov       [.dwDstW], eax

    ; Center horizontally: dstX = (clientW - dstW) / 2
    mov       edx, [.dwClientW]
    sub       edx, eax
    shr       edx, 1
    mov       [.dwDstX], edx

.DrawImage:
    ; Fill background with black brush
    lea       ecx, [.rc]
    invoke    FillRect, [.hDC], ecx, [.hBgBrush]

    ; Set stretch mode
    invoke    SetStretchBltMode, [.hDC], COLORONCOLOR

    ; Prepare BITMAPINFOHEADER for 24-bpp DIB
    mov       [.bih.biSize], sizeof.BITMAPINFOHEADER
    mov       eax, [.img.dwWidth]
    mov       [.bih.biWidth], eax
    mov       eax, [.img.dwHeight]
    mov       [.bih.biHeight], eax
    mov       word [.bih.biPlanes], 1
    mov       ax, word [.img.dwBpp]
    mov       word [.bih.biBitCount], ax
    mov       [.bih.biCompression], BI_RGB
    mov       eax, [.img.dwPitch]
    mul       dword [.img.dwHeight]
    mov       [.bih.biSizeImage], eax
    mov       [.bih.biXPelsPerMeter], 0
    mov       [.bih.biYPelsPerMeter], 0
    mov       [.bih.biClrUsed], 0
    mov       [.bih.biClrImportant], 0

    ; Draw DIB to device context
    lea       eax, [.bih]
    invoke    StretchDIBits, [.hDC],\
              [.dwDstX], [.dwDstY], [.dwDstW], [.dwDstH],\
              0, 0, [.img.dwWidth], [.img.dwHeight],\
              [.img.lpBits], eax, DIB_RGB_COLORS, SRCCOPY

    jmp       .PaintDone

.DrawEmpty:
    lea       ecx, [.rc]
    invoke    FillRect, [.hDC], ecx, [.hBgBrush]

.PaintDone:
    lea       ecx, [.ps]
    invoke    EndPaint, [hWnd], ecx
    xor       eax, eax
    ret
endp
