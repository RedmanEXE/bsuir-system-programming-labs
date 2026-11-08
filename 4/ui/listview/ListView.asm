; HWND ListView.Create(HWND hWnd, DWORD dwControlId, WORD wX, WORD wY, WORD wWidth,
;                      WORD wHeight, HFONT hFont);
proc ListView.Create stdcall uses ecx edx esi,\
     hWnd:DWORD, dwControlId:DWORD, wX:DWORD, wY:DWORD, wWidth:DWORD, wHeight:DWORD, hFont:DWORD
    ; Get HINSTANCE of parent window
    invoke    GetWindowLong, [hWnd], GWL_HINSTANCE
    ; Create ListView control in report mode
    invoke    CreateWindowEx, WS_EX_CLIENTEDGE, szListViewClassName, NULL,\
              WS_CHILD or WS_VISIBLE or WS_BORDER or WS_TABSTOP or\
              LVS_REPORT or LVS_SHOWSELALWAYS or LVS_SINGLESEL,\
              dword [wX], dword [wY], dword [wWidth], dword [wHeight],\
              dword [hWnd], dword [dwControlId], eax, NULL
    mov       esi, eax

    ; Apply system font
    invoke    SendMessage, esi, WM_SETFONT, [hFont], TRUE

    xchg      esi, eax
    ret
endp

; DWORD ListView.SetExtendedStyle(HWND hListView, DWORD dwExStyle);
proc ListView.SetExtendedStyle stdcall uses ecx edx,\
     hListView:DWORD, dwExStyle:DWORD
    ; Just send message
    invoke    SendMessage, [hListView], LVM_SETEXTENDEDLISTVIEWSTYLE, 0, [dwExStyle]

    ret
endp

; INT ListView.InsertColumn(HWND hListView, INT iCol, LPWSTR lpszText, INT iWidth, INT iFmt);
proc ListView.InsertColumn stdcall uses ecx edx edi,\
     hListView:DWORD, iCol:DWORD, lpszText:DWORD, iWidth:DWORD, iFmt:DWORD
    locals
        .lvc LVCOLUMN
    endl

    ; Clean-up structure
    lea       edi, [.lvc]
    mov       ecx, sizeof.LVCOLUMN / 4
    xor       eax, eax
    cld
      rep stosd

    mov       [.lvc.mask], LVCF_FMT or LVCF_WIDTH or LVCF_TEXT or LVCF_SUBITEM
    mov       eax, [iFmt]
    mov       [.lvc.fmt], eax
    mov       eax, [iWidth]
    mov       [.lvc.cx], eax
    mov       eax, [lpszText]
    mov       [.lvc.pszText], eax
    mov       eax, [iCol]
    mov       [.lvc.iSubItem], eax

    lea       eax, [.lvc]
    invoke    SendMessage, [hListView], LVM_INSERTCOLUMNW, [iCol], eax
    ret
endp

; INT ListView.InsertItem(HWND hListView, INT iItem, LPWSTR lpszText, INT iImage, LPARAM lParamVal);
proc ListView.InsertItem stdcall uses ecx edx edi,\
     hListView:DWORD, iItem:DWORD, lpszText:DWORD, iImage:DWORD, lParamVal:DWORD
    locals
        .lvi LVITEM
    endl

    ; Clean-up structure
    lea       edi, [.lvi]
    mov       ecx, sizeof.LVITEM / 4
    xor       eax, eax
    cld
      rep stosd

    mov       [.lvi.mask], LVIF_TEXT or LVIF_IMAGE or LVIF_PARAM
    mov       eax, [iItem]
    mov       [.lvi.iItem], eax
    mov       [.lvi.iSubItem], 0
    mov       eax, [lpszText]
    mov       [.lvi.pszText], eax
    mov       eax, [iImage]
    mov       [.lvi.iImage], eax
    mov       eax, [lParamVal]
    mov       [.lvi.lParam], eax

    lea       eax, [.lvi]
    invoke    SendMessage, [hListView], LVM_INSERTITEMW, 0, eax
    ret
endp

; BOOL ListView.SetItemText(HWND hListView, INT iItem, INT iSubItem, LPWSTR lpszText);
proc ListView.SetItemText stdcall uses ecx edx edi,\
     hListView:DWORD, iItem:DWORD, iSubItem:DWORD, lpszText:DWORD
    locals
        .lvi LVITEM
    endl

    lea       edi, [.lvi]
    mov       ecx, sizeof.LVITEM / 4
    xor       eax, eax
    cld
      rep stosd

    mov       [.lvi.mask], LVIF_TEXT
    mov       eax, [iItem]
    mov       [.lvi.iItem], eax
    mov       eax, [iSubItem]
    mov       [.lvi.iSubItem], eax
    mov       eax, [lpszText]
    mov       [.lvi.pszText], eax

    lea       eax, [.lvi]
    invoke    SendMessage, [hListView], LVM_SETITEMTEXTW, [iItem], eax
    ret
endp

; BOOL ListView.DeleteAllItems(HWND hListView);
proc ListView.DeleteAllItems stdcall uses ecx edx,\
     hListView:DWORD

    invoke    SendMessage, [hListView], LVM_DELETEALLITEMS, 0, 0
    ret
endp

; INT ListView.GetSelectedItem(HWND hListView);
proc ListView.GetSelectedItem stdcall uses ecx edx,\
     hListView:DWORD
    invoke    SendMessage, [hListView], LVM_GETNEXTITEM, -1, LVNI_SELECTED
    ret
endp

; INT ListView.GetItemText(HWND hListView, INT iItem, INT iSubItem, LPWSTR lpszBuffer, INT cchTextMax);
proc ListView.GetItemText stdcall uses ecx edx edi,\
     hListView:DWORD, iItem:DWORD, iSubItem:DWORD, lpszBuffer:DWORD, cchTextMax:DWORD
    locals
        .lvi LVITEM
    endl

    lea       edi, [.lvi]
    mov       ecx, sizeof.LVITEM / 4
    xor       eax, eax
    cld
      rep stosd

    mov       [.lvi.mask], LVIF_TEXT
    mov       eax, [iItem]
    mov       [.lvi.iItem], eax
    mov       eax, [iSubItem]
    mov       [.lvi.iSubItem], eax
    mov       eax, [lpszBuffer]
    mov       [.lvi.pszText], eax
    mov       eax, [cchTextMax]
    mov       [.lvi.cchTextMax], eax

    lea       eax, [.lvi]
    invoke    SendMessage, [hListView], LVM_GETITEMTEXTW, [iItem], eax
    ret
endp

; BOOL ListView.DeleteItem(HWND hListView, INT iItem);
proc ListView.DeleteItem stdcall uses ecx edx,\
     hListView:DWORD, iItem:DWORD
    invoke    SendMessage, [hListView], LVM_DELETEITEM, [iItem], 0
    ret
endp

; LPARAM ListView.GetItemParam(HWND hListView, INT iItem);
proc ListView.GetItemParam stdcall uses ecx edx edi,\
     hListView:DWORD, iItem:DWORD
    locals
        .lvi LVITEM
    endl

    lea       edi, [.lvi]
    mov       ecx, sizeof.LVITEM / 4
    xor       eax, eax
    cld
      rep stosd

    mov       [.lvi.mask], LVIF_PARAM
    mov       eax, [iItem]
    mov       [.lvi.iItem], eax
    mov       [.lvi.iSubItem], 0

    lea       eax, [.lvi]
    invoke    SendMessage, [hListView], LVM_GETITEMW, 0, eax
    test      eax, eax
      jz      .Failed
    mov       eax, [.lvi.lParam]
    jmp       .End

.Failed:
    xor       eax, eax
.End:
    ret
endp
