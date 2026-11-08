; HWND TextLabel.CreateLabel(HWND hParentWnd, DWORD dwControlId, WORD wX, WORD wY, WORD wWidth,
;                            WORD wHeight, LPSTR lpszButtonText, DWORD dwFlags, HANDLE hFont);
proc TextLabel.CreateLabel stdcall uses ecx edx esi,\
     hWnd:DWORD, dwControlId:DWORD, wX:DWORD, wY:DWORD, wWidth:DWORD, wHeight:DWORD, lpszLabelText:DWORD,\
     dwFlags:DWORD, hFont:DWORD
    ; Get HINSTACE of the parent window
    invoke    GetWindowLong, [hWnd], GWL_HINSTANCE
    ; Create button
    mov       ecx, [dwFlags]
    and       ecx, SS_LEFT or SS_CENTER or SS_RIGHT or SS_CENTERIMAGE or\
                   SS_LEFTNOWORDWRAP or SS_SIMPLE
    or        ecx, WS_VISIBLE or WS_CHILD
    invoke    CreateWindowEx, 0, szStaticClassName, dword [lpszLabelText], ecx,\
              dword [wX], dword [wY], dword [wWidth], dword [wHeight], dword [hWnd], NULL, eax, NULL

    mov       esi, eax
    ; Apply new font for button
    invoke    SendMessage, eax, WM_SETFONT, [hFont], TRUE ; TRUE for redraw

    xchg      esi, eax
    ret
endp

; BOOL TextLabel.SetText(HWND hTextLabel, LPSTR lpszNewText);
proc TextLabel.SetText stdcall uses ecx edx esi,\
     hTextLabel:DWORD, lpszNewText:DWORD
    ; Set text with SetWindowText
    invoke  SetWindowText, [hTextLabel], [lpszNewText]

    ret
endp
