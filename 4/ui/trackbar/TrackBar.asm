; HWND TrackBar.CreateTrackbar(HWND hWndParent, DWORD dwControlId, WORD wX, WORD wY, WORD wWidth, WORD wHeight,
;                              DWORD dwMin, DWORD dwMax, DWORD dwStep);
proc TrackBar.CreateTrackbar stdcall uses ecx edx esi edi,\
     hWnd:DWORD, dwControlId:DWORD, wX:DWORD, wY:DWORD, wWidth:DWORD, wHeight:DWORD,\
     dwMin:DWORD, dwMax:DWORD, dwStep:DWORD

    ; Get HINSTANCE of the parent window
    invoke    GetWindowLong, [hWnd], GWL_HINSTANCE

    ; Create trackbar control
    invoke    CreateWindowEx, 0, szTrackbarClassName, NULL,\
              WS_CHILD or WS_VISIBLE or WS_TABSTOP or TBS_HORZ or TBS_AUTOTICKS,\
              dword [wX], dword [wY], dword [wWidth], dword [wHeight],\
              dword [hWnd], dword [dwControlId], eax, NULL
    test      eax, eax
      jz      .Fail
    mov       esi, eax

    ; Store step in GWL_USERDATA
    invoke    SetWindowLong, esi, GWL_USERDATA, [dwStep]

    ; Set range: min and max
    invoke    SendMessage, esi, TBM_SETRANGEMIN, FALSE, [dwMin]
    invoke    SendMessage, esi, TBM_SETRANGEMAX, TRUE, [dwMax]

    ; Set line and page step sizes
    invoke    SendMessage, esi, TBM_SETLINESIZE, 0, [dwStep]
    invoke    SendMessage, esi, TBM_SETPAGESIZE, 0, [dwStep]

    ; Set tick mark frequency
    invoke    SendMessage, esi, TBM_SETTICFREQ, [dwStep], 0

    mov       eax, esi
    ret

.Fail:
    xor       eax, eax
    ret
endp

; VOID TrackBar.SetPos(HWND hTrackBar, DWORD dwPos);
proc TrackBar.SetPos stdcall uses ecx edx,\
     hTrackBar:DWORD, dwPos:DWORD
    invoke    SendMessage, [hTrackBar], TBM_SETPOS, TRUE, [dwPos]
    ret
endp

; DWORD TrackBar.GetPos(HWND hTrackBar);
proc TrackBar.GetPos stdcall uses ecx edx ebx,\
     hTrackBar:DWORD
    invoke    SendMessage, [hTrackBar], TBM_GETPOS, 0, 0
    mov       ebx, eax

    ; Retrieve dwStep from GWL_USERDATA
    invoke    GetWindowLong, [hTrackBar], GWL_USERDATA
    test      eax, eax
      jz      .NoSnap

    ; Snap raw position to nearest multiple of step:
    ; snapped = ((rawPos + step / 2) / step) * step
    mov       ecx, eax
    mov       eax, ecx
    shr       eax, 1
    add       eax, ebx
    xor       edx, edx
    div       ecx
    mul       ecx
    ret

.NoSnap:
    mov       eax, ebx
    ret
endp

; VOID TrackBar.SetRange(HWND hTrackBar, DWORD dwMin, DWORD dwMax);
proc TrackBar.SetRange stdcall uses ecx edx,\
     hTrackBar:DWORD, dwMin:DWORD, dwMax:DWORD
    invoke    SendMessage, [hTrackBar], TBM_SETRANGEMIN, FALSE, [dwMin]
    invoke    SendMessage, [hTrackBar], TBM_SETRANGEMAX, TRUE, [dwMax]
    ret
endp

; VOID TrackBar.SetStep(HWND hTrackBar, DWORD dwStep);
proc TrackBar.SetStep stdcall uses ecx edx,\
     hTrackBar:DWORD, dwStep:DWORD
    invoke    SetWindowLong, [hTrackBar], GWL_USERDATA, [dwStep]
    invoke    SendMessage, [hTrackBar], TBM_SETLINESIZE, 0, [dwStep]
    invoke    SendMessage, [hTrackBar], TBM_SETPAGESIZE, 0, [dwStep]
    invoke    SendMessage, [hTrackBar], TBM_SETTICFREQ, [dwStep], 0
    ret
endp
