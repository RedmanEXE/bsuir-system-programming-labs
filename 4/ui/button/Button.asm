; HWND Button.CreateButton(HWND hParentWnd, DWORD dwControlId, WORD wX, WORD wY, WORD wWidth, WORD wHeight,
;                          LPSTR lpszButtonText, HANDLE hFont);
proc Button.CreateButton stdcall uses ecx edx esi,\
     hWnd:DWORD, dwControlId:DWORD, wX:DWORD, wY:DWORD, wWidth:DWORD, wHeight:DWORD,\
     lpszButtonText:DWORD, hFont:DWORD
    ; Get HINSTACE of the parent window
    invoke    GetWindowLong, [hWnd], GWL_HINSTANCE
    ; Create button
    invoke    CreateWindowEx, 0, szButtonClassName, dword [lpszButtonText],\
              WS_TABSTOP or WS_VISIBLE or WS_CHILD or BS_PUSHBUTTON,\
              dword [wX], dword [wY], dword [wWidth], dword [wHeight],\
              dword [hWnd], dword [dwControlId], eax, NULL

    mov       esi, eax
    ; Apply new font for button
    invoke    SendMessage, eax, WM_SETFONT, [hFont], TRUE ; TRUE for redraw

    xchg      esi, eax
    ret
endp

; VOID Button.SetEnabled(HWND hButton, BOOL bIsEnabled)
proc Button.SetEnabled stdcall uses ecx edx,\
     hButton:DWORD, bIsEnabled:DWORD
    ; Just call EnableWindow
    invoke    EnableWindow, [hButton], [bIsEnabled]

    ret
endp