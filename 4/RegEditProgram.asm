; void RegEditProgram.UpdateLayout(HWND hWndParent);
proc RegEditProgram.UpdateLayout stdcall uses ecx edx ebx esi edi,\
     hWndParent:DWORD
    locals
        .rcClient       RECT
        .rcToolbar      RECT
        .rcStatus       RECT
        .nTop           rd 1
        .nHeight        rd 1
        .nStatusHeight  rd 1
        .nListX         rd 1
        .nListWidth     rd 1
    endl

    ; All initialized?
    cmp       [hWndParent], 0
      je      .Done
    cmp       [hToolbar], 0
      je      .Done

    ; Resize toolbar
    stdcall   Toolbar.UpdateSizes, [hToolbar]

    ; Calculate top position of all others
    lea       eax, [.rcToolbar]
    invoke    GetWindowRect, [hToolbar], eax
    mov       eax, [.rcToolbar.bottom]
    sub       eax, [.rcToolbar.top]
    sub       eax, PANEL_TOP_OFFSET
    mov       [.nTop], eax

    ; Get client rect of parent window
    lea       eax, [.rcClient]
    invoke    GetClientRect, [hWndParent], eax

    ; Resize status bar and calculate its height
    mov       [.nStatusHeight], 0
    cmp       [hStatusBar], 0
      je      .SkipStatusBar

    stdcall   StatusBar.UpdateSize, [hStatusBar], [.rcClient.right]
    lea       eax, [.rcStatus]
    invoke    GetWindowRect, [hStatusBar], eax
    mov       eax, [.rcStatus.bottom]
    sub       eax, [.rcStatus.top]
    mov       [.nStatusHeight], eax

.SkipStatusBar:
    ; Calculate available height for client layout
    mov       eax, [.rcClient.bottom]
    sub       eax, [.nTop]
    sub       eax, [.nStatusHeight]
    cmp       eax, 0
      jge     @F
    xor       eax, eax
@@:
    mov       [.nHeight], eax

    ; Bound dwSplitterPos within window
    mov       eax, [.rcClient.right]
    sub       eax, SPLITTER_MIN_RIGHT + SPLITTER_WIDTH
    cmp       eax, SPLITTER_MIN_LEFT
      jge     @F
    mov       eax, SPLITTER_MIN_LEFT
@@:
    cmp       [dwSplitterPos], eax
      jle     @F
    mov       [dwSplitterPos], eax
@@:
    cmp       [dwSplitterPos], SPLITTER_MIN_LEFT
      jge     @F
    mov       [dwSplitterPos], SPLITTER_MIN_LEFT
@@:

    ; Position treeview
    cmp       [hTreeView], 0
      je      .SkipTreeView
    invoke    MoveWindow, [hTreeView], 0, [.nTop], [dwSplitterPos], [.nHeight], TRUE
.SkipTreeView:

    ; Position splitter
    cmp       [hSplitter], 0
      je      .SkipSplitter
    invoke    MoveWindow, [hSplitter], [dwSplitterPos], [.nTop], SPLITTER_WIDTH, [.nHeight], TRUE
.SkipSplitter:

    ; Position listview
    cmp       [hListView], 0
      je      .SkipListView
    mov       eax, [dwSplitterPos]
    add       eax, SPLITTER_WIDTH
    mov       [.nListX], eax

    mov       edx, [.rcClient.right]
    sub       edx, eax
    cmp       edx, 0
      jge     @F
    xor       edx, edx
@@:
    mov       [.nListWidth], edx

    invoke    MoveWindow, [hListView], [.nListX], [.nTop], [.nListWidth], [.nHeight], TRUE
.SkipListView:

.Done:
    ret
endp

; HTREEITEM RegEditProgram.GetSelectedKeyPath(LPWSTR lpszPathBuf, DWORD cchMax, LPDWORD lphRootKeyOut);
; Retrieves selected item from hTreeView, verifies not NULL/hRootComputer,
; and resolves path via Registry.GetItemPath. Returns HTREEITEM on success, 0 on failure.
proc RegEditProgram.GetSelectedKeyPath stdcall uses ecx edx,\
     lpszPathBuf:DWORD, cchMax:DWORD, lphRootKeyOut:DWORD
    locals
        .hItem          rd 1
    endl

    mov       [.hItem], 0

    cmp       [hTreeView], 0
      je      .Done

    stdcall   TreeView.GetSelectedItem, [hTreeView]
    test      eax, eax
      jz      .Done
    cmp       eax, [hRootComputer]
      je      .Done
    mov       [.hItem], eax

    stdcall   Registry.GetItemPath, [hTreeView], [.hItem], [lpszPathBuf], [cchMax], [lphRootKeyOut]
    test      eax, eax
      jnz     .Done

    mov       [.hItem], 0

.Done:
    mov       eax, [.hItem]
    ret
endp

; VOID RegEditProgram.OnAddKey(HWND hWndParent);
proc RegEditProgram.OnAddKey stdcall uses ecx edx ebx esi edi,\
     hWndParent:DWORD
    locals
        .hSelected      rd 1
        .hRootKey       rd 1
        .hNewItem       rd 1
        .hProbeKey      rd 1
        .nKeyIndex      rd 1
        .szSubPath      rw 1024
        .szNewKeyName   rw 260
        .szCandidate    rw 1024
        .szNumBuf       rw 16
        .tvi            TVITEM
    endl

    ; Resolve selected TreeView key path
    lea       eax, [.szSubPath]
    lea       edx, [.hRootKey]
    stdcall   RegEditProgram.GetSelectedKeyPath, eax, 1024, edx
    test      eax, eax
      jz      .CannotAddToComputer
    mov       [.hSelected], eax

    ; Confirmation dialog
    stdcall   MessageBox.Confirm, [hWndParent], szConfirmAddKeyText, szConfirmTitle
    test      eax, eax
      jz      .Done

    ; 1. If parent has not loaded children into TreeView yet, load existing children now!
    invoke    SendMessage, [hTreeView], TVM_GETNEXTITEM, TVGN_CHILD, [.hSelected]
    test      eax, eax
      jnz     .ChildrenAlreadyLoaded

    ; Explicitly populate existing children from registry
    stdcall   Registry.ExpandKey, [hTreeView], [.hSelected]

.ChildrenAlreadyLoaded:
    ; 2. Find a unique new key name: "New Key #1", "New Key #2", ...
    mov       [.nKeyIndex], 1

.FindUniqueNameLoop:
    ; Format candidate name: "New Key #" + index
    lea       edi, [.szNewKeyName]
    stdcall   String.StringCopy, edi, szNewKeyPrefix
    lea       eax, [.szNumBuf]
    stdcall   String.IntToStr, eax, [.nKeyIndex]
    lea       eax, [.szNumBuf]
    stdcall   String.StringCat, edi, eax

    ; Build full path for probe: [.szSubPath] + "\" + [.szNewKeyName]
    lea       edi, [.szCandidate]
    lea       esi, [.szSubPath]
    cmp       word [esi], 0
      je      .ProbeCandidateNoSub

    stdcall   String.StringCopy, edi, esi
    stdcall   String.StringCat, edi, szBackslash
    lea       eax, [.szNewKeyName]
    stdcall   String.StringCat, edi, eax
    jmp       .DoProbe

.ProbeCandidateNoSub:
    lea       eax, [.szNewKeyName]
    stdcall   String.StringCopy, edi, eax

.DoProbe:
    ; Try opening candidate key to see if it exists
    lea       edx, [.hProbeKey]
    invoke    RegOpenKeyEx, [.hRootKey], edi, 0, KEY_READ, edx
    test      eax, eax
      jnz     .UniqueNameFound    ; non-zero means key doesn't exist -> we can use this name!

    ; Key exists! Close probe handle and try next index
    invoke    RegCloseKey, [.hProbeKey]
    inc       [.nKeyIndex]
    cmp       [.nKeyIndex], 100
      jb      .FindUniqueNameLoop

.UniqueNameFound:
    ; 3. Create the new sub-key in registry
    lea       eax, [.szSubPath]
    lea       edx, [.szNewKeyName]
    stdcall   Registry.CreateKey, [.hRootKey], eax, edx
    test      eax, eax
      jnz     .CreateFailed

    ; 4. Set parent item's cChildren = 1 so TreeView displays [+] / [-] button
    mov       [.tvi.mask], TVIF_CHILDREN
    mov       eax, [.hSelected]
    mov       [.tvi.hItem], eax
    mov       [.tvi.cChildren], 1
    lea       eax, [.tvi]
    invoke    SendMessage, [hTreeView], TVM_SETITEMW, 0, eax

    ; 5. Insert the new item into TreeView
    lea       eax, [.szNewKeyName]
    stdcall   TreeView.InsertItem, [hTreeView], [.hSelected], TVI_LAST,\
              eax, 1, 2, 0, 0
    mov       [.hNewItem], eax

    ; 6. Expand parent to view new child
    stdcall   TreeView.ExpandItem, [hTreeView], [.hSelected], TVE_EXPAND

    ; 7. Select created key to update ListView
    stdcall   TreeView.SelectItem, [hTreeView], [.hNewItem]
    jmp       .Done

.CannotAddToComputer:
    stdcall   MessageBox.Warning, [hWndParent], szErrCannotAddRootText, szConfirmTitle
    jmp       .Done

.CreateFailed:
    stdcall   MessageBox.Error, [hWndParent], szErrCreateKeyFailed, szConfirmTitle
.Done:
    ret
endp

; VOID RegEditProgram.OnDeleteItem(HWND hWndParent);
proc RegEditProgram.OnDeleteItem stdcall uses ecx edx ebx esi edi,\
     hWndParent:DWORD
    locals
        .hSelectedTree  rd 1
        .hRootKey       rd 1
        .nSelectedList  rd 1
        .szSubPath      rw 1024
        .szValName      rw 260
    endl

    ; First check if an item is selected in ListView
    stdcall   ListView.GetSelectedItem, [hListView]
    mov       [.nSelectedList], eax
    cmp       eax, -1
      je      .DeleteTreeKey

    ; Delete param
    ; Retrieve value name
    lea       eax, [.szValName]
    stdcall   ListView.GetItemText, [hListView], [.nSelectedList], 0, eax, 260

    ; Ask confirmation
    stdcall   MessageBox.Confirm, [hWndParent], szConfirmDelValueText, szConfirmTitle
    test      eax, eax
      jz      .Done

    ; Get selected TreeView key to resolve root and subkey path
    lea       eax, [.szSubPath]
    lea       edx, [.hRootKey]
    stdcall   RegEditProgram.GetSelectedKeyPath, eax, 1024, edx
    test      eax, eax
      jz      .Done
    mov       [.hSelectedTree], eax

    ; Check if value name is "(Default)"
    lea       eax, [.szValName]
    stdcall   String.Compare, eax, szValDefaultNameText
    test      eax, eax
      jnz     .DeleteNamedValue

    ; Default value: delete with NULL/empty
    lea       eax, [.szSubPath]
    stdcall   Registry.DeleteValue, [.hRootKey], eax, NULL
    jmp       .ReloadValues

.DeleteNamedValue:
    lea       eax, [.szSubPath]
    lea       edx, [.szValName]
    stdcall   Registry.DeleteValue, [.hRootKey], eax, edx

.ReloadValues:
    ; Reload values into ListView
    stdcall   Registry.LoadValues, [hListView], [hTreeView], [.hSelectedTree]
    jmp       .Done

    ; Delete key
.DeleteTreeKey:
    lea       eax, [.szSubPath]
    lea       edx, [.hRootKey]
    stdcall   RegEditProgram.GetSelectedKeyPath, eax, 1024, edx
    test      eax, eax
      jz      .CannotDeleteComputer
    mov       [.hSelectedTree], eax

    ; Cannot delete root hives (whose parent is [hRootComputer])
    invoke    SendMessage, [hTreeView], TVM_GETNEXTITEM, TVGN_PARENT, [.hSelectedTree]
    cmp       eax, [hRootComputer]
      je      .CannotDeleteRootHive

    ; Ask confirmation
    stdcall   MessageBox.Confirm, [hWndParent], szConfirmDelKeyText, szConfirmTitle
    test      eax, eax
      jz      .Done

    ; Delete key in registry recursively
    lea       eax, [.szSubPath]
    stdcall   Registry.DeleteKeyRecursive, [.hRootKey], eax
    test      eax, eax
      jnz     .DeleteKeyFailed

    ; Remove from TreeView
    stdcall   TreeView.DeleteItem, [hTreeView], [.hSelectedTree]
    jmp       .Done

.CannotDeleteComputer:
    stdcall   MessageBox.Warning, [hWndParent], szErrCannotDelRootText, szConfirmTitle
    jmp       .Done

.CannotDeleteRootHive:
    stdcall   MessageBox.Warning, [hWndParent], szErrCannotDelHiveText, szConfirmTitle
    jmp       .Done

.DeleteKeyFailed:
    stdcall   MessageBox.Error, [hWndParent], szErrDeleteKeyFailed, szConfirmTitle
.Done:
    ret
endp



; VOID RegEditProgram.OnEditParam(HWND hWndParent);
proc RegEditProgram.OnEditParam stdcall uses ecx edx ebx esi edi,\
     hWndParent:DWORD
    locals
        .hSelectedTree  rd 1
        .hRootKey       rd 1
        .nSelectedList  rd 1
        .dwType         rd 1
        .szName         rw 260
        .szTypeStr      rw 64
        .szData         rw 1024
        .szSubPath      rw 1024
    endl

    ; Ensure a valid tree key is selected
    lea       eax, [.szSubPath]
    lea       edx, [.hRootKey]
    stdcall   RegEditProgram.GetSelectedKeyPath, eax, 1024, edx
    test      eax, eax
      jz      .Done
    mov       [.hSelectedTree], eax

    ; Check if an item in ListView is selected
    stdcall   ListView.GetSelectedItem, [hListView]
    mov       [.nSelectedList], eax
    cmp       eax, -1
      je      .NewParam

    ; Edit existing value: retrieve value name from Column 0
    lea       eax, [.szName]
    stdcall   ListView.GetItemText, [hListView], [.nSelectedList], 0, eax, 260

    ; Retrieve type string from Column 1 and map to registry type
    lea       eax, [.szTypeStr]
    stdcall   ListView.GetItemText, [hListView], [.nSelectedList], 1, eax, 64
    lea       eax, [.szTypeStr]
    stdcall   Registry.ParseType, eax
    mov       [.dwType], eax

    ; Retrieve data text from Column 2
    lea       eax, [.szData]
    stdcall   ListView.GetItemText, [hListView], [.nSelectedList], 2, eax, 1024

    ; Check if "(value not set)"
    lea       eax, [.szData]
    stdcall   String.Compare, eax, szValNotSetText
    test      eax, eax
      jnz     .CheckEmptyBinary
    mov       word [.szData], 0
    jmp       .OpenDlg

.CheckEmptyBinary:
    ; Check if "(zero-length binary value)"
    lea       eax, [.szData]
    stdcall   String.Compare, eax, szEmptyBinaryText
    test      eax, eax
      jnz     .CheckDwordRaw
    mov       word [.szData], 0
    jmp       .OpenDlg

.CheckDwordRaw:
    ; For DWORD / QWORD: strip hex formatted prefix and parentheses (e.g. "0x00000001 (1)" -> "1")
    cmp       [.dwType], REG_DWORD
      je      .FormatRawNumber
    cmp       [.dwType], REG_QWORD
      je      .FormatRawNumber
    jmp       .OpenDlg

.FormatRawNumber:
    lea       eax, [.szData]
    stdcall   String.StrToInt, eax
    lea       edx, [.szData]
    stdcall   String.IntToStr, edx, eax

.OpenDlg:
    lea       eax, [.szName]
    lea       edx, [.szData]
    stdcall   EditValueDialog.Open, [hWndParent], szEditParamTitle, eax, edx, [.dwType], FALSE
    jmp       .Done

.NewParam:
    ; Create new value
    stdcall   EditValueDialog.Open, [hWndParent], szNewParamTitle, szDefaultNewPrmName, NULL, REG_SZ, TRUE
.Done:
    ret
endp

; VOID RegEditProgram.OnValueSubmitted(WPARAM wParam, LPARAM lParam);
proc RegEditProgram.OnValueSubmitted stdcall uses ecx edx ebx esi edi,\
     wParam:DWORD, lParam:DWORD
    locals
        .hSelectedTree  rd 1
        .hRootKey       rd 1
        .dwErrCode      rd 1
        .dwDataLen      rd 1
        .dwDataVal      rd 2
        .szSubPath      rw 1024
        .szErrBuf       rw 1024
        .szNumBuf       rw 32
        .bDataBuf       rb 4096
    endl

    virtual at esi
        .result EDITVALUERESULT
    end virtual

    ; Check if user confirmed with IDOK
    cmp       [wParam], IDOK
      jne     .Done

    mov       esi, [lParam]
    test      esi, esi
      jz      .Done

    ; Get selected TreeView item and path
    lea       eax, [.szSubPath]
    lea       edx, [.hRootKey]
    stdcall   RegEditProgram.GetSelectedKeyPath, eax, 1024, edx
    test      eax, eax
      jz      .Done
    mov       [.hSelectedTree], eax

    ; Check if value name is "(Default)"
    lea       eax, [.result.szName]
    stdcall   String.Compare, eax, szValDefaultNameText
    test      eax, eax
      jz      .DefaultValue
    cmp       word [.result.szName], 0
      je      .DefaultValue
    lea       ebx, [.result.szName]     ; ebx = pointer to value name
    jmp       .DispatchSave

.DefaultValue:
    xor       ebx, ebx                  ; ebx = NULL (default value)

.DispatchSave:
    mov       eax, [.result.dwType]
    cmp       eax, REG_DWORD
      je      .SaveDword
    cmp       eax, REG_QWORD
      je      .SaveQword
    cmp       eax, REG_BINARY
      je      .SaveBinary
    cmp       eax, REG_MULTI_SZ
      je      .SaveMultiSz
    jmp       .SaveString

.SaveDword:
    lea       eax, [.result.szData]
    stdcall   String.StrToInt, eax
    mov       [.dwDataVal], eax
    lea       eax, [.szSubPath]
    lea       edx, [.dwDataVal]
    stdcall   Registry.SetValue, [.hRootKey], eax, ebx, REG_DWORD, edx, 4
    jmp       .CheckResult

.SaveQword:
    lea       eax, [.result.szData]
    stdcall   String.StrToInt, eax
    mov       [.dwDataVal], eax
    mov       [.dwDataVal + 4], 0
    lea       eax, [.szSubPath]
    lea       edx, [.dwDataVal]
    stdcall   Registry.SetValue, [.hRootKey], eax, ebx, REG_QWORD, edx, 8
    jmp       .CheckResult

.SaveBinary:
    lea       eax, [.result.szData]
    lea       edx, [.bDataBuf]
    stdcall   String.HexToBytes, eax, edx, 4096
    mov       [.dwDataLen], eax
    lea       eax, [.szSubPath]
    lea       edx, [.bDataBuf]
    stdcall   Registry.SetValue, [.hRootKey], eax, ebx, REG_BINARY, edx, [.dwDataLen]
    jmp       .CheckResult

.SaveMultiSz:
    lea       eax, [.result.szData]
    lea       edx, [.bDataBuf]
    stdcall   String.FormatMultiSz, eax, edx, 4096
    mov       [.dwDataLen], eax
    lea       eax, [.szSubPath]
    lea       edx, [.bDataBuf]
    stdcall   Registry.SetValue, [.hRootKey], eax, ebx, REG_MULTI_SZ, edx, [.dwDataLen]
    jmp       .CheckResult

.SaveString:
    lea       eax, [.szSubPath]
    lea       edx, [.result.szData]
    stdcall   Registry.SetStringValue, [.hRootKey], eax, ebx, edx, [.result.dwType]

.CheckResult:
    test      eax, eax
      jz      .Reload
    mov       [.dwErrCode], eax

    ; Format detailed error message with error code and path
    lea       edi, [.szErrBuf]
    stdcall   String.StringCopy, edi, szErrSetValuePrefix
    lea       eax, [.szNumBuf]
    stdcall   String.IntToStr, eax, [.dwErrCode]
    lea       eax, [.szNumBuf]
    stdcall   String.StringCat, edi, eax
    stdcall   String.StringCat, edi, szErrSetValueMid
    lea       eax, [.szSubPath]
    stdcall   String.StringCat, edi, eax
    stdcall   String.StringCat, edi, szErrSetValueName
    lea       eax, [.result.szName]
    stdcall   String.StringCat, edi, eax

    stdcall   MessageBox.Error, [cmWindow.hWindow], edi, szConfirmTitle
    jmp       .Done

.Reload:
    ; Refresh ListView
    stdcall   Registry.LoadValues, [hListView], [hTreeView], [.hSelectedTree]

.Done:
    ret
endp

; VOID RegEditProgram.UpdateStatusPath(HWND hTreeView, HTREEITEM hItem);
proc RegEditProgram.UpdateStatusPath stdcall uses ecx edx ebx esi edi,\
     hTreeView:DWORD, hItem:DWORD
    locals
        .hRootKey       rd 1
        .lpHiveName     rd 1
        .nItemCount     rd 1
        .szSubPath      rw 1024
        .szFullPath     rw 1024
        .szCountBuf     rw 32
        .szNumBuf       rw 16
    endl

    cmp       [hStatusBar], 0
      je      .Done

    ; Call Registry.GetItemPath
    lea       eax, [.szSubPath]
    lea       edx, [.hRootKey]
    stdcall   Registry.GetItemPath, [hTreeView], [hItem], eax, 1024, edx
    test      eax, eax
      jz      .ShowComputer

    ; Match hive name from root key using Registry.GetHiveName
    stdcall   Registry.GetHiveName, [.hRootKey]
    test      eax, eax
      jz      .ShowComputer
    mov       [.lpHiveName], eax

.BuildPath:
    lea       ebx, [.szFullPath]
    stdcall   String.StringCopy, ebx, szMyComputerText
    stdcall   String.StringCat, ebx, szBackslash
    stdcall   String.StringCat, ebx, [.lpHiveName]

    cmp       word [.szSubPath], 0
      je      .SetStatusText

    stdcall   String.StringCat, ebx, szBackslash
    lea       eax, [.szSubPath]
    stdcall   String.StringCat, ebx, eax

.SetStatusText:
    stdcall   StatusBar.SetText, [hStatusBar], 0, ebx
    jmp       .UpdateCount

.ShowComputer:
    stdcall   StatusBar.SetText, [hStatusBar], 0, szMyComputerText

.UpdateCount:
    ; Update Part 1 with item count from ListView if ListView exists
    cmp       [hListView], 0
      je      .Done
    invoke    SendMessage, [hListView], LVM_GETITEMCOUNT, 0, 0
    mov       [.nItemCount], eax

    lea       eax, [.szNumBuf]
    stdcall   String.IntToStr, eax, [.nItemCount]

    lea       edi, [.szCountBuf]
    lea       eax, [.szNumBuf]
    stdcall   String.StringCopy, edi, eax
    stdcall   String.StringCat, edi, szItemsSuffixText

    stdcall   StatusBar.SetText, [hStatusBar], 1, edi

.Done:
    ret
endp


; VOID RegEditProgram.UpdateToolbarButtons(HWND hToolbar, HWND hTreeView, HTREEITEM hItem);
; Updates enabled state of IDC_BUTTON_ADD, IDC_BUTTON_DELETE, IDC_BUTTON_EDIT
; based on current key permissions.
proc RegEditProgram.UpdateToolbarButtons stdcall uses ecx edx ebx esi edi,\
     hToolbar:DWORD, hTreeView:DWORD, hItem:DWORD
    locals
        .hRootKey       rd 1
        .szSubPath      rw 1024
        .bWritable      rd 1
        .bCanDelete     rd 1
    endl

    mov       [.bWritable], 0
    mov       [.bCanDelete], 0

    cmp       [hToolbar], 0
      je      .Done
    cmp       [hTreeView], 0
      je      .Done

    mov       eax, [hItem]
    test      eax, eax
      jz      .ApplyState

    cmp       eax, [hRootComputer]
      je      .ApplyState

    ; Resolve key path and root hive
    lea       eax, [.szSubPath]
    lea       edx, [.hRootKey]
    stdcall   Registry.GetItemPath, [hTreeView], [hItem], eax, 1024, edx
    test      eax, eax
      jz      .ApplyState

    ; Check if key is writable
    lea       eax, [.szSubPath]
    stdcall   Registry.IsKeyWritable, [.hRootKey], eax
    mov       [.bWritable], eax
    test      eax, eax
      jz      .ApplyState

    ; If writable, check if it is a root hive (whose parent is hRootComputer)
    invoke    SendMessage, [hTreeView], TVM_GETNEXTITEM, TVGN_PARENT, [hItem]
    cmp       eax, [hRootComputer]
      je      .ApplyState
    mov       [.bCanDelete], 1

.ApplyState:
    stdcall   Toolbar.EnableButton, [hToolbar], IDC_BUTTON_ADD, [.bWritable]
    stdcall   Toolbar.EnableButton, [hToolbar], IDC_BUTTON_DELETE, [.bCanDelete]
    stdcall   Toolbar.EnableButton, [hToolbar], IDC_BUTTON_EDIT, [.bWritable]

.Done:
    ret
endp


; VOID RegEditProgram.OnRegistryChanged(HKEY hKey, HTREEITEM hItem);
; Called on WM_APP_REGISTRY_CHANGED when registry changes are detected.
proc RegEditProgram.OnRegistryChanged stdcall uses ecx edx ebx esi edi,\
     hKey:DWORD, hItem:DWORD

    ; Check if auto-refresh is enabled
    cmp       [bAutoRefreshEnabled], 0
      je      .Done

    ; Verify that the changed item is still the selected item in TreeView
    stdcall   TreeView.GetSelectedItem, [hTreeView]
    cmp       eax, [hItem]
      jne     .Done

    ; 1. Reload ListView values
    stdcall   Registry.LoadValues, [hListView], [hTreeView], [hItem]

    ; 2. Synchronize TreeView child nodes
    stdcall   Registry.SyncChildNodes, [hTreeView], [hItem]

    ; 3. Update toolbar buttons state (Add, Edit, Delete)
    stdcall   RegEditProgram.UpdateToolbarButtons, [hToolbar], [hTreeView], [hItem]

.Done:
    ret
endp
