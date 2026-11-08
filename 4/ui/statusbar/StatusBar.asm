; HWND StatusBar.Create(HWND hWnd, DWORD dwControlId, HFONT hFont);
proc StatusBar.Create stdcall uses ecx edx esi,\
     hWnd:DWORD, dwControlId:DWORD, hFont:DWORD
    ; Get HINSTANCE of parent window
    invoke    GetWindowLong, [hWnd], GWL_HINSTANCE
    ; Create StatusBar control
    invoke    CreateWindowEx, 0, szStatusBarClassName, NULL,\
              WS_CHILD or WS_VISIBLE or SBARS_SIZEGRIP,\
              0, 0, 0, 0,\
              dword [hWnd], dword [dwControlId], eax, NULL
    test      eax, eax
      jz      .Done
    mov       esi, eax

    ; Apply font
    cmp       [hFont], 0
      je      @F
    invoke    SendMessage, esi, WM_SETFONT, [hFont], TRUE
@@:
    mov       eax, esi

.Done:
    ret
endp

; VOID StatusBar.UpdateSize(HWND hStatusBar, INT nClientWidth);
proc StatusBar.UpdateSize stdcall uses ecx edx,\
     hStatusBar:DWORD, nClientWidth:DWORD
    locals
        .aParts rd 2
    endl

    cmp       [hStatusBar], 0
      je      .Done

    ; Notify status bar of parent window size change so it repositions at bottom
    invoke    SendMessage, [hStatusBar], WM_SIZE, 0, 0

    ; Configure sections:
    ; If width > 240: Part 0 (path) up to (nClientWidth - 120), Part 1 (item count) to right edge (-1)
    ; Otherwise: 1 part spanning entire width
    mov       eax, [nClientWidth]
    cmp       eax, 240
      jle     .SinglePart

    sub       eax, 120
    mov       [.aParts + 0], eax
    mov       [.aParts + 4], -1
    lea       eax, [.aParts]
    invoke    SendMessage, [hStatusBar], SB_SETPARTS, 2, eax
    jmp       .Done

.SinglePart:
    mov       [.aParts + 0], -1
    lea       eax, [.aParts]
    invoke    SendMessage, [hStatusBar], SB_SETPARTS, 1, eax

.Done:
    ret
endp

; BOOL StatusBar.SetText(HWND hStatusBar, INT iPart, LPWSTR lpszText);
proc StatusBar.SetText stdcall uses ecx edx,\
     hStatusBar:DWORD, iPart:DWORD, lpszText:DWORD

    cmp       [hStatusBar], 0
      je      .Done

    invoke    SendMessage, [hStatusBar], SB_SETTEXTW, [iPart], [lpszText]

.Done:
    ret
endp

; BOOL StatusBar.SetParts(HWND hStatusBar, INT nParts, LPVOID lpPartsArray);
proc StatusBar.SetParts stdcall uses ecx edx,\
     hStatusBar:DWORD, nParts:DWORD, lpPartsArray:DWORD

    cmp       [hStatusBar], 0
      je      .Done

    invoke    SendMessage, [hStatusBar], SB_SETPARTS, [nParts], [lpPartsArray]

.Done:
    ret
endp
