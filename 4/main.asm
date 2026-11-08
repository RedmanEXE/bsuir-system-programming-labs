format        PE GUI 3.1
entry         Application.Setup

include       'win32w.inc'
include       'macro/proc32.inc'

include       'constants.inc'
include       'macroses.inc'
include       'structures.inc'

section '.code' code readable executable
Application.Setup:
    ; Get HINSTANCE of the program
    invoke    GetModuleHandle, NULL
    mov       [cmApplication.hModule], eax

    ; Activate unicode support
    stdcall   Unicode.Activate, eax

    ; Initialize memory functions
    stdcall   Memory.Initialize
    mov       [cmApplication.hMemHeap], eax

    ; And load accelerators table
    invoke    LoadAccelerators, eax, 1
    mov       [cmApplication.hAccelTable], eax
    ; Register for MSH_MOUSEWHEEL messages
    invoke    RegisterWindowMessage, szMouseWheelType
    mov       [cmApplication.uOldWheelMsgID], eax

    ; Call function to initialize new funky buttons
    invoke    InitCommonControlsEx, iccRequiredTypes
    ; Load system font to include into UI elements
    stdcall   System.CreateSystemFont
    mov       [cmApplication.hSystemFont], eax

    ; Check if launched with administrator rights
    stdcall   UAC.IsLaunchedAsAdmin
    mov       [bIsRunningAsAdmin], eax

    mov       edi, szWindowName
    cmp       eax, 0
      je      @F
    mov       edi, szWindowNameAdmin
@@:
    ; Create main window
    stdcall   Window.CreateWindow, [cmApplication.hModule], WINDOW_INIT_WIDTH, WINDOW_INIT_HEIGHT,\
              szClassName, edi, Application.WindowProc, WINDOW_BACKGROUND_COLOR
    mov       [cmWindow.hWindow], eax

    ; Call code, that initializes buttons and other UI elements
    include   './events/OnInit.asm'

    ; MSG structure
    sub       esp, sizeof.MSG
Application.WindowLoop:
    ; Process window messages
    stdcall   Window.ProcessMessages, [cmWindow.hWindow], [cmApplication.hAccelTable], esp

    cmp       eax, 0
      jle     .Exit
.ReDraw:
    include   './events/OnPhysicsProcess.asm'

    jmp       Application.WindowLoop

.Exit:
    ; Free MSG structure
    add       esp, sizeof.MSG

    stdcall   Application.Terminate, 0
    ret

proc Application.WindowProc stdcall uses ebx esi,\
     hWnd:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD

    mov       eax, [uMsg]
    cmp       eax, WM_CREATE
      je      .OnCreate
    cmp       eax, WM_CLOSE
      je      .OnClose
    cmp       eax, WM_COMMAND
      je      .OnCommand
    cmp       eax, WM_DESTROY
      je      .OnDestroy
    cmp       eax, WM_KEYDOWN
      je      .OnKeyDown
    cmp       eax, WM_KEYUP
      je      .OnKeyUp
    cmp       eax, WM_SIZE
      je      .OnSize
    mov       ecx, [cmApplication.uOldWheelMsgID]
    cmp       eax, ecx
      je      .OnOldMouseWheel
    cmp       eax, WM_MOUSEWHEEL
      je      .OnMouseWheel
    cmp       eax, WM_NOTIFY
      je      .OnNotify
    cmp       eax, WM_DROPFILES
      je      .OnDropFiles
    cmp       eax, WM_CTLCOLORSTATIC
      je      .OnCtlColorStatic
    cmp       eax, WM_CTLCOLORBTN
      je      .OnCtlColorStatic
    cmp       eax, WM_APP_VALUE_SUBMITTED
      je      .OnValueSubmitted
    cmp       eax, WM_APP_REGISTRY_CHANGED
      je      .OnRegistryChanged
    jmp       .Default

.OnValueSubmitted:
    stdcall   RegEditProgram.OnValueSubmitted, [wParam], [lParam]
    jmp       .End

.OnRegistryChanged:
    stdcall   RegEditProgram.OnRegistryChanged, [wParam], [lParam]
    jmp       .End

.OnCreate:
    include   './events/OnCreate.asm'
    jmp       .Default

.OnClose:
    include   './events/OnClose.asm'
    jmp       .End

.OnCommand:
    include   './events/OnCommand.asm'
    jmp       .End

.OnDestroy:
    include   './events/OnDestroy.asm'
    jmp       .End

.OnKeyDown:
    include   './events/OnKeyDown.asm'
    jmp       .End

.OnKeyUp:
    include   './events/OnKeyUp.asm'
    jmp       .End

.OnOldMouseWheel:
    include   './events/OnPreOldMouseWheel.asm'
.OnMouseWheel:
    include   './events/OnMouseWheel.asm'
    jmp       .End

.OnNotify:
    include   './events/OnNotify.asm'
    jmp       .Default

.OnSize:
    include   './events/OnResize.asm'
    jmp       .Default

.OnDropFiles:
    include   './events/OnDropFiles.asm'
    jmp       .End

.OnCtlColorStatic:
    include   './events/OnCtlColorStatic.asm'
    jmp       .End

.Default:
    invoke    DefWindowProc, [hWnd], [uMsg], [wParam], [lParam]

.End:
    ret
endp

    include   './RegEditProgram.asm'

    ; Classes
    include   './application/Application.asm'
    include   './icons/Icons.asm'
    include   './memory/Memory.asm'
    include   './string/String.asm'
    include   './system/System.asm'
    include   './system/Registry.asm'
    include   './system/UAC.asm'
    include   './unicode/Unicode.asm'
    include   './window/Window.asm'

    ; UI elements
    include   './ui/button/Button.asm'
    include   './ui/dialog/EditValueDialog.asm'
    include   './ui/listview/ListView.asm'
    include   './ui/messagebox/MessageBox.asm'
    include   './ui/splitter/Splitter.asm'
    include   './ui/statusbar/StatusBar.asm'
    include   './ui/textlabel/TextLabel.asm'
    include   './ui/toolbar/Toolbar.asm'
    include   './ui/treeview/TreeView.asm'

section '.data' data readable writeable
    szUnicoWS              db 'unicows.dll', 0
    szKernelDllName        db 'kernel32.dll', 0
    szTestFunctionName     db 'GetModuleHandleW', 0

    szAdvapi32DllName      du 'advapi32.dll', 0
    szOpenProcessTokenName db 'OpenProcessToken', 0
    szGetTokenInfoName     db 'GetTokenInformation', 0
    szShell32DllName       du 'shell32.dll', 0
    szIsUserAnAdminName    db 'IsUserAnAdmin', 0
    szRunAsVerb            du 'runas', 0
    szNtdllDllName         du 'ntdll.dll', 0
    szWineGetVersionName   db 'wine_get_version', 0

    szClassName            du 'ReRegEditWindowClass', 0
    szWindowName           du 'Re:Registry editor', 0
    szWindowNameAdmin      du 'Re:Registry editor (Administrator)', 0

    szButtonClassName      du 'BUTTON', 0
    szStaticClassName      du 'STATIC', 0
    szImageViewClassName   du 'ImageViewControl', 0
    szTrackbarClassName    du 'msctls_trackbar32', 0
    szToolbarClassName     du 'ToolbarWindow32', 0
    szTreeViewClassName    du 'SysTreeView32', 0
    szListViewClassName    du 'SysListView32', 0
    szSplitterClassName    du 'ReSplitterClass', 0
    szEditDialogClassName  du 'ReEditValueDialogClass', 0
    szEditClassName        du 'EDIT', 0
    szComboBoxClassName    du 'COMBOBOX', 0
    szStatusBarClassName   du 'msctls_statusbar32', 0

    szToolbarAddBtnText    du 'Add key', 0
    szToolbarDelBtnText    du 'Delete key', 0
    szToolbarEditBtnText   du 'Edit key', 0
    szToolbarUacBtnText    du 'Restart as Administrator', 0
    szToolbarAutoRefreshBtnText du 'Auto-refresh', 0

    szMyComputerText       du 'My computer', 0
    szHkcrText             du 'HKEY_CLASSES_ROOT', 0
    szHkcuText             du 'HKEY_CURRENT_USER', 0
    szHklmText             du 'HKEY_LOCAL_MACHINE', 0
    szHkuText              du 'HKEY_USERS', 0
    szHkccText             du 'HKEY_CURRENT_CONFIG', 0

    szColNameText          du 'Name', 0
    szColTypeText          du 'Type', 0
    szColDataText          du 'Data', 0

    szBackslash            du '\', 0
    szEmptyBinaryText      du '(zero-length binary value)', 0
    szTypeRegNoneText      du 'REG_NONE', 0
    szTypeRegSzText        du 'REG_SZ', 0
    szTypeRegExpandSzText  du 'REG_EXPAND_SZ', 0
    szTypeRegBinaryText    du 'REG_BINARY', 0
    szTypeRegDwordText     du 'REG_DWORD', 0
    szTypeRegMultiSzText   du 'REG_MULTI_SZ', 0
    szTypeRegQwordText     du 'REG_QWORD', 0
    szValDefaultNameText   du '(Default)', 0
    szValNotSetText        du '(value not set)', 0

    szConfirmTitle         du 'Confirm', 0
    szConfirmAddKeyText    du 'Are you sure you want to create a new key under the selected item?', 0
    szConfirmDelKeyText    du 'Are you sure you want to delete this key and all of its subkeys?', 0
    szConfirmDelValueText  du 'Are you sure you want to delete this value?', 0

    szErrCannotAddRootText du 'Keys cannot be created directly in "My computer".', 0
    szErrCannotDelRootText du 'The selected item cannot be deleted.', 0
    szErrCannotDelHiveText du 'Root registry hives cannot be deleted.', 0
    szErrCreateKeyFailed   du 'Failed to create key. Access is denied or invalid path.', 0
    szErrDeleteKeyFailed   du 'Failed to delete key. Access is denied.', 0
    szErrSetValueFailed    du 'Failed to set value. Access is denied.', 0
    szErrSetValuePrefix    du 'Failed to set value (Error: ', 0
    szErrSetValueMid       du ').', 13, 10, 13, 10, 'sub-key: ', 0
    szErrSetValueName      du 13, 10, 'Value: ', 0

    szNewKeyPrefix         du 'New key #', 0

    szEditStringTitle      du 'Edit string', 0
    szEditDwordTitle       du 'Edit DWORD', 0
    szNewValueTitle        du 'New value', 0
    szEditValNameLabelText du 'Value &name:', 0
    szEditValDataLabelText du 'Value &data:', 0
    szBtnOkText            du 'OK', 0
    szBtnCancelText        du 'Cancel', 0
    szEditValTypeLabelText du 'Value &type:', 0
    szEditParamTitle       du 'Edit param', 0
    szEditBinaryTitle      du 'Edit binary value', 0
    szNewParamTitle        du 'New param', 0
    szDefaultNewPrmName    du 'New param #1', 0

    szItemsSuffixText      du ' item(s)', 0

    dwSplitterPos          dd SPLITTER_DEFAULT_POS

    comboTypesTable:
        dd        szTypeRegSzText, REG_SZ
        dd        szTypeRegDwordText, REG_DWORD
        dd        szTypeRegBinaryText, REG_BINARY
        dd        szTypeRegExpandSzText, REG_EXPAND_SZ
        dd        szTypeRegMultiSzText, REG_MULTI_SZ
        dd        szTypeRegQwordText, REG_QWORD
        dd        0, 0

    szTextFilePath         du '.txt', 0

    szMouseWheelType       du 'MSH_MOUSEWHEEL', 0
    szFontName             du 'Segoe UI', 0

    szOpenImageFilter      du 'Bitmaps (*.bmp)', 0, '*.bmp', 0
                           du 'All files (*.*)', 0, '*.*', 0, 0

    szSaveImageFilter      du 'Bitmaps (*.bmp)', 0, '*.bmp', 0
                           du 'All files (*.*)', 0, '*.*', 0, 0

    szBmpDefExt            du 'bmp', 0

    iccRequiredTypes       INITCOMMONCONTROLSEX\
                           sizeof.INITCOMMONCONTROLSEX,\
                           ICC_STANDARD_CLASSES or ICC_BAR_CLASSES or ICC_LISTVIEW_CLASSES

section '.bss' data readable writeable
    cmApplication          MAPPLICATION
    cmWindow               MWINDOW
    cmKeyboard             MKEYBOARD
    cmMouse                MMOUSE

    hToolbar               rd 1
    hToolbarAddIcon        rd 1
    hToolbarDeleteIcon     rd 1
    hToolbarEditIcon       rd 1
    hToolbarUacIcon        rd 1
    hToolbarRefreshIcon    rd 1
    bAutoRefreshEnabled    rd 1
    hMonitorThread         rd 1
    hMonitorStopEvent      rd 1
    hMonitorChangeEvent    rd 1
    hMonitorKey            rd 1
    hMonitorItem           rd 1
    bIsRunningAsAdmin      rd 1

    hTreeView              rd 1
    hTreeImageList         rd 1
    hRootComputer          rd 1

    hSplitter              rd 1
    bSplitterDragging      rd 1
    nSplitterDragOffset    rd 1

    hListView              rd 1
    hStatusBar             rd 1

    hEditDialog            rd 1
    hEditDialogParent      rd 1
    hEditDialogNameCtrl    rd 1
    hEditDialogTypeCtrl    rd 1
    hEditDialogDataCtrl    rd 1
    hEditDialogBtnOk       rd 1
    hEditDialogBtnCancel   rd 1
    dwEditDialogType       rd 1
    bEditDialogCanEditName rd 1
    bEditDialogRegistered  rd 1

    editDialogResult       EDITVALUERESULT

    szPathFilter           rw 8192
    szSavePathFilter       rw 260
    szSubmitPathBuffer     rw 260
    szDropPathBuffer       rw 260

section '.rsrc' resource data readable
    directory              RT_ACCELERATOR, accelerators,\
                           RT_MANIFEST, manifests
    resource               accelerators, 1, LANG_NEUTRAL, acAccelTable
    resdata acAccelTable
        raccel             FVIRTKEY or FCONTROL, 'C', IDM_ACCEL_EXIT, RACCEL_LAST
    endres

    resource               manifests, 1, LANG_NEUTRAL, szManifestData
    resdata szManifestData
        db                 '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>', 10
        db                 '<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">', 10
        db                 '  <assemblyIdentity version="1.0.0.0" processorArchitecture="*"'
        db                 ' name="ReRegEdit.Application" type="win32"/>', 10
        db                 '  <dependency>', 10
        db                 '    <dependentAssembly>', 10
        db                 '      <assemblyIdentity type="win32" name="Microsoft.Windows.Common-Controls" '
        db                 'version="6.0.0.0" processorArchitecture="*" publicKeyToken="6595b64144ccf1df" language="*"/>', 10
        db                 '    </dependentAssembly>', 10
        db                 '  </dependency>', 10
        db                 '  <trustInfo xmlns="urn:schemas-microsoft-com:asm.v2">', 10
        db                 '    <security>', 10
        db                 '      <requestedPrivileges>', 10
        db                 '        <requestedExecutionLevel level="asInvoker" uiAccess="false"/>', 10
        db                 '      </requestedPrivileges>', 10
        db                 '    </security>', 10
        db                 '  </trustInfo>', 10
        db                 '</assembly>'
    endres

section '.import' import data readable writeable
    library kernel32,                   'kernel32.dll',\
            user32,                     'user32.dll',\
            gdi32,                      'gdi32.dll',\
            advapi32,                   'advapi32.dll',\
            comctl32,                   'comctl32.dll',\
            comdlg32,                   'comdlg32.dll',\
            shell32,                    'shell32.dll'

    import  kernel32,\
            GetModuleHandle,            'GetModuleHandleA',\
            CreateEvent,                'CreateEventA',\
            CreateSemaphore,            'CreateSemaphoreA',\
            CreateFile,                 'CreateFileA',\
            LoadLibrary,                'LoadLibraryA',\
            ExitProcess,                'ExitProcess',\
            Sleep,                      'Sleep',\
            GetProcessHeap,             'GetProcessHeap',\
            HeapAlloc,                  'HeapAlloc',\
            HeapReAlloc,                'HeapReAlloc',\
            HeapFree,                   'HeapFree',\
            InitializeCriticalSection,  'InitializeCriticalSection',\
            DeleteCriticalSection,      'DeleteCriticalSection',\
            EnterCriticalSection,       'EnterCriticalSection',\
            LeaveCriticalSection,       'LeaveCriticalSection',\
            CreateThread,               'CreateThread',\
            ExitThread,                 'ExitThread',\
            CloseHandle,                'CloseHandle',\
            WaitForSingleObject,        'WaitForSingleObject',\
            WaitForMultipleObjects,     'WaitForMultipleObjects',\
            SetEvent,                   'SetEvent',\
            ResetEvent,                 'ResetEvent',\
            ReleaseSemaphore,           'ReleaseSemaphore',\
            WriteFile,                  'WriteFile',\
            ReadFile,                   'ReadFile',\
            SetFilePointer,             'SetFilePointer',\
            GetProcAddress,             'GetProcAddress',\
            GetVersion,                 'GetVersion',\
            GetModuleFileName,          'GetModuleFileNameA',\
            FreeLibrary,                'FreeLibrary',\
            GetCurrentProcess,          'GetCurrentProcess'

    import  user32,\
            RegisterClassEx,            'RegisterClassExA',\
            DefWindowProc,              'DefWindowProcA',\
            CreateWindowEx,             'CreateWindowExA',\
            GetMessage,                 'GetMessageA',\
            DispatchMessage,            'DispatchMessageA',\
            PostMessage,                'PostMessageA',\
            LoadImage,                  'LoadImageA',\
            LoadCursor,                 'LoadCursorA',\
            LoadAccelerators,           'LoadAcceleratorsA',\
            TranslateAccelerator,       'TranslateAcceleratorA',\
            RegisterWindowMessage,      'RegisterWindowMessageA',\
            DrawText,                   'DrawTextA',\
            GetWindowLong,              'GetWindowLongA',\
            SetWindowLong,              'SetWindowLongA',\
            SendMessage,                'SendMessageA',\
            SystemParametersInfo,       'SystemParametersInfoA',\
            SetWindowText,              'SetWindowTextA',\
            IsDialogMessage,            'IsDialogMessageA',\
            AdjustWindowRectEx,         'AdjustWindowRectEx',\
            TranslateMessage,           'TranslateMessage',\
            PostQuitMessage,            'PostQuitMessage',\
            BeginPaint,                 'BeginPaint',\
            GetClientRect,              'GetClientRect',\
            GetDC,                      'GetDC',\
            EndPaint,                   'EndPaint',\
            ReleaseDC,                  'ReleaseDC',\
            InvalidateRect,             'InvalidateRect',\
            FillRect,                   'FillRect',\
            DestroyWindow,              'DestroyWindow',\
            GetKeyState,                'GetKeyState',\
            FrameRect,                  'FrameRect',\
            EnableWindow,               'EnableWindow',\
            UpdateWindow,               'UpdateWindow',\
            MoveWindow,                 'MoveWindow',\
            GetParent,                  'GetParent',\
            DestroyIcon,                'DestroyIcon',\
            DrawIconEx,                 'DrawIconEx',\
            SetCapture,                 'SetCapture',\
            ReleaseCapture,             'ReleaseCapture',\
            GetWindowRect,              'GetWindowRect',\
            ClientToScreen,             'ClientToScreen',\
            ScreenToClient,             'ScreenToClient',\
            SetCursor,                  'SetCursor',\
            MessageBox,                 'MessageBoxA',\
            SetForegroundWindow,        'SetForegroundWindow',\
            SetFocus,                   'SetFocus',\
            GetFocus,                   'GetFocus',\
            GetIconInfo,                'GetIconInfo',\
            CreateIconIndirect,         'CreateIconIndirect',\
            GetSysColorBrush,           'GetSysColorBrush'

    import  gdi32,\
            GetObject,                  'GetObjectA',\
            CreateFont,                 'CreateFontA',\
            CreateFontIndirect,         'CreateFontIndirectA',\
            CreateCompatibleDC,         'CreateCompatibleDC',\
            SelectObject,               'SelectObject',\
            BitBlt,                     'BitBlt',\
            DeleteDC,                   'DeleteDC',\
            DeleteObject,               'DeleteObject',\
            CreateSolidBrush,           'CreateSolidBrush',\
            CreateCompatibleBitmap,     'CreateCompatibleBitmap',\
            GetStockObject,             'GetStockObject',\
            SetBkMode,                  'SetBkMode',\
            SetTextColor,               'SetTextColor',\
            StretchDIBits,              'StretchDIBits',\
            SetStretchBltMode,          'SetStretchBltMode',\
            CreateDIBSection,           'CreateDIBSection'

    import  advapi32,\
            RegOpenKeyEx,               'RegOpenKeyExA',\
            RegCloseKey,                'RegCloseKey',\
            RegCreateKeyEx,             'RegCreateKeyExA',\
            RegDeleteKey,               'RegDeleteKeyA',\
            RegDeleteValue,             'RegDeleteValueA',\
            RegEnumKeyEx,               'RegEnumKeyExA',\
            RegEnumValue,               'RegEnumValueA',\
            RegQueryInfoKey,            'RegQueryInfoKeyA',\
            RegQueryValueEx,            'RegQueryValueExA',\
            RegSetValueEx,              'RegSetValueExA',\
            RegNotifyChangeKeyValue,    'RegNotifyChangeKeyValue'

    import  comdlg32,\
            GetOpenFileName,            'GetOpenFileNameA',\
            GetSaveFileName,            'GetSaveFileNameA'

    import  comctl32,\
            InitCommonControlsEx,       'InitCommonControlsEx',\
            ImageList_Create,           'ImageList_Create',\
            ImageList_ReplaceIcon,      'ImageList_ReplaceIcon',\
            ImageList_Destroy,          'ImageList_Destroy'

    import  shell32,\
            DragQueryFile,              'DragQueryFileA',\
            DragFinish,                 'DragFinish',\
            DragAcceptFiles,            'DragAcceptFiles',\
            SHGetFileInfo,              'SHGetFileInfoA',\
            SHGetSpecialFolderLocation, 'SHGetSpecialFolderLocation',\
            ExtractIconEx,              'ExtractIconExA',\
            ShellExecute,               'ShellExecuteA'
