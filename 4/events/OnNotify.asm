    mov       edx, [lParam]
    test      edx, edx
      jz      .SkipNotifyEvent

    mov       eax, [edx + 8]              ; hdr.code
    cmp       eax, TTN_GETDISPINFOW       ; TTN_GETDISPINFOW
      je      .OnTooltipText
    cmp       eax, TTN_GETDISPINFOA       ; TTN_GETDISPINFOA
      je      .OnTooltipText

    ; TreeView item expanding
    cmp       eax, TVN_ITEMEXPANDINGW
      je      .OnTreeItemExpanding
    cmp       eax, TVN_ITEMEXPANDINGA
      je      .OnTreeItemExpanding

    ; TreeView selection changed
    cmp       eax, TVN_SELCHANGEDW
      je      .OnTreeSelChanged
    cmp       eax, TVN_SELCHANGEDA
      je      .OnTreeSelChanged

    ; ListView double click (edit value)
    cmp       eax, NM_DBLCLK
      je      .OnListViewDblClick

    jmp       .SkipNotifyEvent

.OnListViewDblClick:
    mov       eax, [edx + 4]              ; hdr.idFrom
    cmp       eax, IDC_LISTVIEW_VALUES
      jne     .SkipNotifyEvent
    stdcall   RegEditProgram.OnEditParam, [hWnd]
    xor       eax, eax
    jmp       .End

.OnTreeItemExpanding:
    ; Check if action is TVE_EXPAND
    mov       eax, [edx + 12]             ; nmtv.action
    cmp       eax, TVE_EXPAND
      jne     .SkipNotifyEvent

    mov       eax, [edx + 60]             ; nmtv.itemNew.hItem
    stdcall   Registry.ExpandKey, [hTreeView], eax
    xor       eax, eax
    jmp       .End

.OnTreeSelChanged:
    mov       ebx, [edx + 60]             ; nmtv.itemNew.hItem
    stdcall   Registry.LoadValues, [hListView], [hTreeView], ebx
    stdcall   RegEditProgram.UpdateStatusPath, [hTreeView], ebx
    stdcall   RegEditProgram.UpdateToolbarButtons, [hToolbar], [hTreeView], ebx
    cmp       [bAutoRefreshEnabled], 0
      je      @F
    stdcall   Registry.StartMonitorByKeyItem, [hTreeView], ebx
@@:
    xor       eax, eax
    jmp       .End

.OnTooltipText:
    mov       eax, [edx + 4]              ; hdr.idFrom
    cmp       eax, IDC_BUTTON_ADD         ; Add button
      je      .NotifyProcessAddButton
    cmp       eax, IDC_BUTTON_DELETE      ; Delete button
      je      .NotifyProcessDeleteButton
    cmp       eax, IDC_BUTTON_EDIT        ; Edit button
      je      .NotifyProcessEditButton
    cmp       eax, IDC_BUTTON_UAC         ; UAC button
      je      .NotifyProcessUacButton
    cmp       eax, IDC_BUTTON_AUTOREFRESH ; Auto-refresh button
      je      .NotifyProcessAutoRefreshButton
    jmp       .SkipNotifyEvent

.NotifyProcessAddButton:
    ; Use string for this button
    mov       esi, szToolbarAddBtnText
    jmp       .ApplyTooltip

.NotifyProcessDeleteButton:
    ; Use string for this button
    mov       esi, szToolbarDelBtnText
    jmp       .ApplyTooltip

.NotifyProcessEditButton:
    ; Use string for this button
    mov       esi, szToolbarEditBtnText
    jmp       .ApplyTooltip

.NotifyProcessUacButton:
    ; Use string for this button
    mov       esi, szToolbarUacBtnText
    jmp       .ApplyTooltip

.NotifyProcessAutoRefreshButton:
    ; Use string for this button
    mov       esi, szToolbarAutoRefreshBtnText
    jmp       .ApplyTooltip

.ApplyTooltip:
    cmp       dword [edx + 8], -530       ; Check for native support
      je      .SetUnicodeText
.SetAnsiText:
    ; Convert (Win95/98/ME)
    lea       ecx, [edx + 16]
    mov       [edx + 12], ecx             ; lpszText = &szText
    stdcall   Unicode.UTFEnglishToASCII, esi, ecx
    jmp       .EndConverting

.SetUnicodeText:
    ; Just save UTF-16 ptr (Win2000+)
    mov       [edx + 12], esi             ; lpszText = &szUnicodeString
.EndConverting:
    xor       eax, eax
    jmp       .End

.SkipNotifyEvent:
