; BOOL EditValueDialog.Register(HINSTANCE hInstance);
proc EditValueDialog.Register stdcall uses ecx edx ebx esi edi,\
     hInstance:DWORD
    locals
        .wc WNDCLASSEX
    endl

    lea       edi, [.wc]
    mov       ecx, sizeof.WNDCLASSEX / 4
    xor       eax, eax
    cld
      rep stosd

    invoke    LoadCursor, NULL, IDC_ARROW
    mov       ebx, eax

    mov       [.wc.cbSize], sizeof.WNDCLASSEX
    mov       [.wc.style], CS_HREDRAW or CS_VREDRAW
    mov       [.wc.lpfnWndProc], EditValueDialog.WindowProc
    mov       [.wc.cbClsExtra], 0
    mov       [.wc.cbWndExtra], 0
    mov       eax, [hInstance]
    mov       [.wc.hInstance], eax
    mov       [.wc.hCursor], ebx
    mov       [.wc.hbrBackground], COLOR_BTNFACE + 1
    mov       [.wc.lpszClassName], szEditDialogClassName

    lea       eax, [.wc]
    invoke    RegisterClassEx, eax
    test      eax, eax
      jz      .Failed

    mov       eax, 1
    jmp       .End

.Failed:
    xor       eax, eax
.End:
    ret
endp

; HWND EditValueDialog.Open(HWND hWndParent, LPWSTR lpszTitle, LPWSTR lpszInitialName,
;                           LPWSTR lpszInitialData, DWORD dwType, BOOL bCanEditName);
proc EditValueDialog.Open stdcall uses ecx edx ebx esi edi,\
     hWndParent:DWORD, lpszTitle:DWORD, lpszInitialName:DWORD,\
     lpszInitialData:DWORD, dwType:DWORD, bCanEditName:DWORD
    locals
        .rcParent       RECT
        .nX             rd 1
        .nY             rd 1
        .nWidth         rd 1
        .nHeight        rd 1
        .hDlg           rd 1
        .dwEditStyle    rd 1
        .nCurIndex      rd 1
        .dwCurType      rd 1
    endl

    ; Create state for dialog
    mov       eax, [hWndParent]
    mov       [hEditDialogParent], eax
    mov       eax, [dwType]
    mov       [dwEditDialogType], eax
    mov       eax, [bCanEditName]
    mov       [bEditDialogCanEditName], eax

    ; Clear previous result
    lea       edi, [editDialogResult]
    mov       ecx, sizeof.EDITVALUERESULT / 4
    xor       eax, eax
    cld
      rep stosd

    ; Disable parent window
    invoke    EnableWindow, [hWndParent], FALSE

    ; Calculate position for dialog (to be centered)
    mov       [.nWidth], EDIT_VALUE_DIALOG_WIDTH
    mov       [.nHeight], EDIT_VALUE_DIALOG_HEIGHT

    lea       eax, [.rcParent]
    invoke    GetWindowRect, [hWndParent], eax

    ; nX = rcParent.left + (width - 380) / 2
    mov       eax, [.rcParent.right]
    sub       eax, [.rcParent.left]
    sub       eax, [.nWidth]
    sar       eax, 1
    add       eax, [.rcParent.left]
    cmp       eax, 0
      jge     @F
    xor       eax, eax
@@:
    mov       [.nX], eax

    ; nY = rcParent.top + (height - 195) / 2
    mov       eax, [.rcParent.bottom]
    sub       eax, [.rcParent.top]
    sub       eax, [.nHeight]
    sar       eax, 1
    add       eax, [.rcParent.top]
    cmp       eax, 0
      jge     @F
    xor       eax, eax
@@:
    mov       [.nY], eax

    ; Use default title if NULL title
    mov       esi, [lpszTitle]
    test      esi, esi
      jnz     @F
    mov       esi, szEditStringTitle
@@:

    ; Create dialog window
    invoke    CreateWindowEx, WS_EX_DLGMODALFRAME or WS_EX_TOPMOST,\
              szEditDialogClassName, esi,\
              WS_POPUP or WS_CAPTION or WS_SYSMENU or WS_VISIBLE,\
              [.nX], [.nY], [.nWidth], [.nHeight],\
              [hWndParent], NULL, [cmApplication.hModule], NULL
    test      eax, eax
      jz      .CreateFailed
    mov       [.hDlg], eax
    mov       [hEditDialog], eax

    ; Create Label "Value name:"
    invoke    CreateWindowEx, 0, szStaticClassName, szEditValNameLabelText,\
              WS_CHILD or WS_VISIBLE, 14, 12, 344, 16,\
              [.hDlg], IDC_TEXT_LABEL_VAL_NAME, [cmApplication.hModule], NULL
    invoke    SendMessage, eax, WM_SETFONT, [cmApplication.hSystemFont], TRUE

    ; Create Edit for "Name"
    mov       [.dwEditStyle], WS_CHILD or WS_VISIBLE or WS_BORDER or WS_TABSTOP or ES_AUTOHSCROLL
    cmp       [bCanEditName], 0
      jne     @F
    or        [.dwEditStyle], ES_READONLY
@@:
    invoke    CreateWindowEx, WS_EX_CLIENTEDGE, szEditClassName, NULL,\
              [.dwEditStyle], 14, 30, 344, 22,\
              [.hDlg], IDC_EDIT_NAME, [cmApplication.hModule], NULL
    mov       [hEditDialogNameCtrl], eax
    invoke    SendMessage, eax, WM_SETFONT, [cmApplication.hSystemFont], TRUE

    ; Create Label "Value type:"
    invoke    CreateWindowEx, 0, szStaticClassName, szEditValTypeLabelText,\
              WS_CHILD or WS_VISIBLE, 14, 58, 344, 16,\
              [.hDlg], IDC_TEXT_LABEL_VAL_TYPE, [cmApplication.hModule], NULL
    invoke    SendMessage, eax, WM_SETFONT, [cmApplication.hSystemFont], TRUE

    ; Create ComboBox for "Type"
    invoke    CreateWindowEx, WS_EX_CLIENTEDGE, szComboBoxClassName, NULL,\
              WS_CHILD or WS_VISIBLE or WS_BORDER or WS_TABSTOP or WS_VSCROLL or CBS_DROPDOWNLIST,\
              14, 76, 344, 160,\
              [.hDlg], IDC_COMBO_TYPE, [cmApplication.hModule], NULL
    mov       [hEditDialogTypeCtrl], eax
    invoke    SendMessage, eax, WM_SETFONT, [cmApplication.hSystemFont], TRUE

    ; Populate ComboBox with registry types
    mov       esi, comboTypesTable
    xor       edi, edi                  ; default match index = 0
    xor       ebx, ebx                  ; loop index = 0
.PopulateComboLoop:
    mov       eax, [esi]
    test      eax, eax
      jz      .PopulateComboDone

    mov       edx, [esi + 4]
    mov       [.dwCurType], edx

    invoke    SendMessage, [hEditDialogTypeCtrl], CB_ADDSTRING, 0, eax
    mov       [.nCurIndex], eax

    invoke    SendMessage, [hEditDialogTypeCtrl], CB_SETITEMDATA, [.nCurIndex], [.dwCurType]

    mov       eax, [.dwCurType]
    cmp       eax, [dwType]
      jne     @F
    mov       eax, [.nCurIndex]
    mov       edi, eax
@@:
    inc       ebx
    add       esi, 8
    jmp       .PopulateComboLoop

.PopulateComboDone:
    invoke    SendMessage, [hEditDialogTypeCtrl], CB_SETCURSEL, edi, 0

    ; Create Label "Value data:"
    invoke    CreateWindowEx, 0, szStaticClassName, szEditValDataLabelText,\
              WS_CHILD or WS_VISIBLE, 14, 106, 344, 16,\
              [.hDlg], IDC_TEXT_LABEL_VAL_DATA, [cmApplication.hModule], NULL
    invoke    SendMessage, eax, WM_SETFONT, [cmApplication.hSystemFont], TRUE

    ; Create Edit for "Data"
    invoke    CreateWindowEx, WS_EX_CLIENTEDGE, szEditClassName, NULL,\
              WS_CHILD or WS_VISIBLE or WS_BORDER or WS_TABSTOP or ES_AUTOHSCROLL,\
              14, 124, 344, 22,\
              [.hDlg], IDC_EDIT_DATA, [cmApplication.hModule], NULL
    mov       [hEditDialogDataCtrl], eax
    invoke    SendMessage, eax, WM_SETFONT, [cmApplication.hSystemFont], TRUE

    ; Create "OK" button
    invoke    CreateWindowEx, 0, szButtonClassName, szBtnOkText,\
              WS_CHILD or WS_VISIBLE or WS_TABSTOP or BS_DEFPUSHBUTTON,\
              192, 160, 80, 24,\
              [.hDlg], IDOK, [cmApplication.hModule], NULL
    mov       [hEditDialogBtnOk], eax
    invoke    SendMessage, eax, WM_SETFONT, [cmApplication.hSystemFont], TRUE

    ; Create "Cancel" button
    invoke    CreateWindowEx, 0, szButtonClassName, szBtnCancelText,\
              WS_CHILD or WS_VISIBLE or WS_TABSTOP or BS_PUSHBUTTON,\
              278, 160, 80, 24,\
              [.hDlg], IDCANCEL, [cmApplication.hModule], NULL
    mov       [hEditDialogBtnCancel], eax
    invoke    SendMessage, eax, WM_SETFONT, [cmApplication.hSystemFont], TRUE

    ; Set text values if provided
    mov       eax, [lpszInitialName]
    test      eax, eax
      jz      @F
    invoke    SendMessage, [hEditDialogNameCtrl], WM_SETTEXT, 0, eax
@@:
    mov       eax, [lpszInitialData]
    test      eax, eax
      jz      @F
    invoke    SendMessage, [hEditDialogDataCtrl], WM_SETTEXT, 0, eax
@@:

    ; Focus Edit control
    cmp       [bCanEditName], 0
      jne     .FocusName
    invoke    SetFocus, [hEditDialogDataCtrl]
    invoke    SendMessage, [hEditDialogDataCtrl], EM_SETSEL, 0, -1
    jmp       .FocusDone
.FocusName:
    invoke    SetFocus, [hEditDialogNameCtrl]
    invoke    SendMessage, [hEditDialogNameCtrl], EM_SETSEL, 0, -1
.FocusDone:

    invoke    UpdateWindow, [.hDlg]
    mov       eax, [.hDlg]
    jmp       .End

.CreateFailed:
    invoke    EnableWindow, [hWndParent], TRUE
.Failed:
    xor       eax, eax
.End:
    ret
endp

; VOID EditValueDialog.Close(HWND hWnd, UINT uResultCode);
proc EditValueDialog.Close stdcall uses ecx edx ebx esi edi,\
     hWnd:DWORD, uResultCode:DWORD

    mov       ebx, [hEditDialogParent]

    ; If user confirmed with IDOK -> get text from controls
    cmp       [uResultCode], IDOK
      jne     .Cancelled

    ; Retrieve "Name"
    lea       eax, [editDialogResult.szName]
    invoke    SendMessage, [hEditDialogNameCtrl], WM_GETTEXT, 260, eax

    ; Retrieve "Data"
    lea       eax, [editDialogResult.szData]
    invoke    SendMessage, [hEditDialogDataCtrl], WM_GETTEXT, 1024, eax

    ; Retrieve selected type from ComboBox
    invoke    SendMessage, [hEditDialogTypeCtrl], CB_GETCURSEL, 0, 0
    cmp       eax, CB_ERR
      je      .UseDefaultType
    invoke    SendMessage, [hEditDialogTypeCtrl], CB_GETITEMDATA, eax, 0
    cmp       eax, CB_ERR
      je      .UseDefaultType
    mov       [editDialogResult.dwType], eax
    jmp       .TypeRetrieved

.UseDefaultType:
    mov       eax, [dwEditDialogType]
    test      eax, eax
      jnz     @F
    mov       eax, REG_SZ
@@:
    mov       [editDialogResult.dwType], eax

.TypeRetrieved:
    mov       [editDialogResult.bSuccess], 1
    jmp       .ReenableParent

.Cancelled:
    mov       [editDialogResult.bSuccess], 0

.ReenableParent:
    ; Clear dialog handle and destroy dialog window
    mov       [hEditDialog], 0
    invoke    DestroyWindow, [hWnd]

    ; Re-enable parent window and bring to front
    test      ebx, ebx
      jz      .Done
    invoke    EnableWindow, ebx, TRUE
    invoke    SetForegroundWindow, ebx
    invoke    SetFocus, ebx

    ; Send result message to parent now that it is enabled and focused
    cmp       [uResultCode], IDOK
      jne     .SendCancel
    lea       eax, [editDialogResult]
    invoke    SendMessage, ebx, WM_APP_VALUE_SUBMITTED, IDOK, eax
    jmp       .Done

.SendCancel:
    invoke    SendMessage, ebx, WM_APP_VALUE_SUBMITTED, IDCANCEL, 0

.Done:
    ret
endp

; LRESULT CALLBACK EditValueDialog.WindowProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam);
proc EditValueDialog.WindowProc stdcall uses ebx esi edi,\
     hWnd:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD

    mov       eax, [uMsg]
    cmp       eax, WM_COMMAND
      je      .OnCommand
    cmp       eax, WM_CLOSE
      je      .OnClose
    cmp       eax, WM_CTLCOLORSTATIC
      je      .OnCtlColorStatic
    cmp       eax, WM_CTLCOLORBTN
      je      .OnCtlColorStatic
    jmp       .Default

.OnCommand:
    movzx     eax, word [wParam]
    cmp       eax, IDOK
      je      .OnOk
    cmp       eax, IDCANCEL
      je      .OnCancel
    jmp       .Default

.OnOk:
    stdcall   EditValueDialog.Close, [hWnd], IDOK
    xor       eax, eax
    jmp       .End

.OnCancel:
    stdcall   EditValueDialog.Close, [hWnd], IDCANCEL
    xor       eax, eax
    jmp       .End

.OnClose:
    stdcall   EditValueDialog.Close, [hWnd], IDCANCEL
    xor       eax, eax
    jmp       .End

.OnCtlColorStatic:
    invoke    SetBkMode, [wParam], TRANSPARENT
    ; Return native background color brush for controls
    invoke    GetSysColorBrush, COLOR_BTNFACE
    jmp       .End

.Default:
    invoke    DefWindowProc, [hWnd], [uMsg], [wParam], [lParam]

.End:
    ret
endp
