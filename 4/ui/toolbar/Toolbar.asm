; HTOOLBAR Toolbar.CreateToolbar(HWND hWnd, WORD wX, WORD wY, WORD wWidth,
;                                WORD wHeight, HFONT hFont);
proc Toolbar.CreateToolbar stdcall uses ecx edx esi,\
     hWnd:DWORD, wX:DWORD, wY:DWORD, wWidth:DWORD, wHeight:DWORD, hFont:DWORD
    ; Get HINSTACE of the parent window
    invoke    GetWindowLong, [hWnd], GWL_HINSTANCE
    ; Create toolbar
    invoke    CreateWindowEx, 0, szToolbarClassName, NULL,\
              WS_CHILD or WS_VISIBLE or TBSTYLE_WRAPABLE or TBSTYLE_FLAT or\
              TBSTYLE_TOOLTIPS, dword [wX], dword [wY], dword [wWidth], dword [wHeight],\
              dword [hWnd], NULL, eax, NULL

    mov       esi, eax
    ; Send TB_BUTTONSTRUCTSIZE message to initialize buttons
    invoke    SendMessage, esi, TB_BUTTONSTRUCTSIZE, sizeof.TBBUTTON, 0

    xchg      esi, eax
    ret
endp

; INT Toolbar.AddString(HTOOLBAR hToolbar, HINSTANCE hInstance, DWORD iString);
proc Toolbar.AddString stdcall uses ecx edx,\
     hToolbar:DWORD, hInstance:DWORD, iString:DWORD
    ; Just send message about new string!
    invoke    SendMessage, [hToolbar], TB_ADDSTRINGW, [hInstance], [iString]

    ret
endp

; DWORD Toolbar.AddBitmap(HTOOLBAR hToolbar, HINSTANCE hInstance, DWORD dwBitmap);
proc Toolbar.AddBitmap stdcall uses ecx edx,\
     hToolbar:DWORD, hInstance:DWORD, dwBitmap:DWORD
    locals
        .cmTBAddBitmap TBADDBITMAP
    endl

    ; Copy data to the structure
    mov       eax, [hInstance]
    mov       ecx, [dwBitmap]
    mov       [.cmTBAddBitmap.hInst], eax
    mov       [.cmTBAddBitmap.nID], ecx

    lea       edx, [.cmTBAddBitmap]
    ; Send message about new bitmap
    invoke    SendMessage, [hToolbar], TB_ADDBITMAP, 1, edx

    ret
endp

; BOOL Toolbar.AddButton(HTOOLBAR hToolbar, INT iBmpIndex, INT idCmd, BYTE bStyle,
;                        BYTE bState, DWORD iButtonText)
proc Toolbar.AddButton stdcall uses ecx edx ebx edi,\
     hToolbar:DWORD, iBmpIndex:DWORD, idCmd:DWORD, bStyle:DWORD, bState:DWORD,\
     iButtonText:DWORD
    locals
        .cmTBButton TBBUTTON
    endl

    ; Clear structure
    lea       edi, [.cmTBButton]
    mov       ecx, sizeof.TBBUTTON / 4
    xor       eax, eax
    cld
      rep stosd

    ; Copy data to the structure
    mov       eax, [iBmpIndex]
    mov       ecx, [idCmd]
    mov       edx, [bStyle]
    mov       ebx, [bState]
    mov       [.cmTBButton.iBitmap], eax
    mov       [.cmTBButton.idCommand], ecx
    mov       [.cmTBButton.fsState], bl
    mov       [.cmTBButton.fsStyle], dl
    mov       [.cmTBButton.dwData], NULL
    mov       eax, [iButtonText]
    mov       [.cmTBButton.iString], eax

    lea       ebx, [.cmTBButton]
    ; Send message about new button
    invoke    SendMessage, [hToolbar], TB_ADDBUTTONS, 1, ebx

    ret
endp

; void Toolbar.HideText(HTOOLBAR hToolbar, iIdx);
proc Toolbar.HideText stdcall uses ecx edx,\
     hToolbar:DWORD, iIdx:DWORD
    ; Just call SendMessage
    invoke    SendMessage, [hToolbar], TB_SETMAXTEXTROWS, [iIdx], 0

    ret
endp

; void Toolbar.UpdateSizes(HTOOLBAR hToolbar);
proc Toolbar.UpdateSizes stdcall uses ecx edx,\
     hToolbar:DWORD
    ; Just send message
    invoke    SendMessage, [hToolbar], TB_AUTOSIZE, 0, 0

    ret
endp

; BOOL Toolbar.EnableButton(HTOOLBAR hToolbar, INT idCmd, BOOL bEnable);
proc Toolbar.EnableButton stdcall uses ecx edx,\
     hToolbar:DWORD, idCmd:DWORD, bEnable:DWORD
    locals
        .lParam         rd 1
    endl

    cmp       [hToolbar], 0
      je      .Done

    mov       eax, [bEnable]
    test      eax, eax
    setnz     al
    movzx     eax, al
    mov       [.lParam], eax

    invoke    SendMessage, [hToolbar], TB_ENABLEBUTTON, [idCmd], [.lParam]

.Done:
    ret
endp


; HBITMAP Toolbar.AddButtonWithIcon(HTOOLBAR hToolbar, HICON hIcon, INT idCmd);
; Converts hIcon to toolbar HBITMAP, destroys hIcon, adds bitmap to toolbar,
; and adds button with idCmd. Returns HBITMAP for cleanup on exit.
proc Toolbar.AddButtonWithIcon stdcall uses ecx edx ebx esi edi,\
     hToolbar:DWORD, hIcon:DWORD, idCmd:DWORD
    locals
        .hBitmap        rd 1
    endl

    mov       [.hBitmap], 0
    cmp       [hIcon], 0
      je      .Done

    stdcall   Icons.ConvertIconToBitmap, [hIcon]
    mov       [.hBitmap], eax
    invoke    DestroyIcon, [hIcon]

    cmp       [.hBitmap], 0
      je      .Done

    stdcall   Toolbar.AddBitmap, [hToolbar], 0, [.hBitmap]
    stdcall   Toolbar.AddButton, [hToolbar], eax, [idCmd], TBSTYLE_BUTTON, TBSTATE_ENABLED, -1

.Done:
    mov       eax, [.hBitmap]
    ret
endp
