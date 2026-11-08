    mov       ebx, [cmWindow.hWindow]

    ; Create UI for window
    ; Toolbar
    stdcall   Toolbar.CreateToolbar, ebx, 0, 0, 0, 0, [cmApplication.hSystemFont]
    mov       [hToolbar], eax

    ; Add "add" button
    stdcall   Icons.LoadIcon, szTextFilePath, FILE_ATTRIBUTE_NORMAL
    stdcall   Toolbar.AddButtonWithIcon, [hToolbar], eax, IDC_BUTTON_ADD
    mov       [hToolbarAddIcon], eax

    ; Add separator
    stdcall   Toolbar.AddButton, [hToolbar], 0, 0, TBSTYLE_SEP, 0, -1

    ; Add "delete" button
    stdcall   Icons.LoadSystemIcon, CSIDL_BITBUCKET
    stdcall   Toolbar.AddButtonWithIcon, [hToolbar], eax, IDC_BUTTON_DELETE
    mov       [hToolbarDeleteIcon], eax

    ; Add "edit" button
    stdcall   Icons.CreateIBeamBitmap
    mov       [hToolbarEditIcon], eax
    stdcall   Toolbar.AddBitmap, [hToolbar], 0, eax
    stdcall   Toolbar.AddButton, [hToolbar], eax, IDC_BUTTON_EDIT, TBSTYLE_BUTTON, TBSTATE_ENABLED, -1

    ; Add separator
    stdcall   Toolbar.AddButton, [hToolbar], 0, 0, TBSTYLE_SEP, 0, -1

    ; Add UAC shield button if running as standard user (Vista+)
    cmp       [bIsRunningAsAdmin], 0
      jne     .SkipUacButton

    invoke    LoadImage, NULL, 32518, IMAGE_ICON, 16, 16, LR_SHARED
    test      eax, eax
      jz      .SkipUacButton
    stdcall   Toolbar.AddButtonWithIcon, [hToolbar], eax, IDC_BUTTON_UAC
    mov       [hToolbarUacIcon], eax

    ; Add separator
    stdcall   Toolbar.AddButton, [hToolbar], 0, 0, TBSTYLE_SEP, 0, -1

.SkipUacButton:
    ; Add Auto-refresh toggle button (default: active / checked)
    mov       [bAutoRefreshEnabled], 1
    stdcall   Icons.CreateRefreshBitmap
    mov       [hToolbarRefreshIcon], eax
    stdcall   Toolbar.AddBitmap, [hToolbar], 0, eax
    stdcall   Toolbar.AddButton, [hToolbar], eax, IDC_BUTTON_AUTOREFRESH,\
              TBSTYLE_CHECK, TBSTATE_ENABLED or TBSTATE_CHECKED, -1

    ; Create synchronization events for registry change monitoring thread
    invoke    CreateEvent, NULL, TRUE, FALSE, NULL
    mov       [hMonitorStopEvent], eax
    invoke    CreateEvent, NULL, FALSE, FALSE, NULL
    mov       [hMonitorChangeEvent], eax

    ; Hide text
    stdcall   Toolbar.HideText, [hToolbar], 0

    ; TreeView
    stdcall   TreeView.Create, ebx, IDC_TREEVIEW_REGISTRY, 0, 0, [dwSplitterPos], 0, [cmApplication.hSystemFont]
    mov       [hTreeView], eax
    ; Create image list for registry
    stdcall   TreeView.CreateRegistryImageList
    mov       [hTreeImageList], eax
    stdcall   TreeView.SetImageList, [hTreeView], [hTreeImageList], TVSIL_NORMAL
    ; Add "My computer" folder
    stdcall   TreeView.InsertItem, [hTreeView], TVI_ROOT, TVI_LAST,\
              szMyComputerText, 0, 0, 1, 0
    mov       [hRootComputer], eax

    ; Add classic root keys using TreeView.InsertRootHive (checks writability for normal vs gray icon)
    stdcall   TreeView.InsertRootHive, [hTreeView], [hRootComputer], szHkcrText, HKEY_CLASSES_ROOT
    stdcall   TreeView.InsertRootHive, [hTreeView], [hRootComputer], szHkcuText, HKEY_CURRENT_USER
    stdcall   TreeView.InsertRootHive, [hTreeView], [hRootComputer], szHklmText, HKEY_LOCAL_MACHINE
    stdcall   TreeView.InsertRootHive, [hTreeView], [hRootComputer], szHkuText, HKEY_USERS
    stdcall   TreeView.InsertRootHive, [hTreeView], [hRootComputer], szHkccText, HKEY_CURRENT_CONFIG

    ; Expand "My computer" folder
    invoke    SendMessage, [hTreeView], TVM_EXPAND, TVE_EXPAND, [hRootComputer]

    ; Splitter
    stdcall   Splitter.Create, ebx, IDC_SPLITTER_WINDOW, [dwSplitterPos], 0, SPLITTER_WIDTH, 0
    mov       [hSplitter], eax

    ; ListView
    stdcall   ListView.Create, ebx, IDC_LISTVIEW_VALUES, 0, 0, 0, 0, [cmApplication.hSystemFont]
    mov       [hListView], eax
    stdcall   ListView.SetExtendedStyle, eax, LVS_EX_FULLROWSELECT
    ; Insert columns
    stdcall   ListView.InsertColumn, [hListView], 0, szColNameText, 170, LVCFMT_LEFT
    stdcall   ListView.InsertColumn, [hListView], 1, szColTypeText, 110, LVCFMT_LEFT
    stdcall   ListView.InsertColumn, [hListView], 2, szColDataText, 260, LVCFMT_LEFT

    ; Status bar
    stdcall   StatusBar.Create, ebx, IDC_STATUSBAR, [cmApplication.hSystemFont]
    mov       [hStatusBar], eax
    stdcall   RegEditProgram.UpdateStatusPath, [hTreeView], [hRootComputer]

    ; Apply changes
    stdcall   RegEditProgram.UpdateLayout, [cmWindow.hWindow]

    ; Initial toolbar state (enables/disables buttons based on selected key writability)
    stdcall   RegEditProgram.UpdateToolbarButtons, [hToolbar], [hTreeView], [hRootComputer]
