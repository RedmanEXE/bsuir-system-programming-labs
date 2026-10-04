format        PE GUI 3.1
entry         Application.Setup

include       'win32w.inc'
include       'macro/proc32.inc'

include       'constants.inc'
include       'macroses.inc'
include       'structures.inc'

section '.code' code readable executable
Application.Setup:
    ; Initialize memory functions
    stdcall   Memory.Initialize
    mov       [cmApplication.hMemHeap], eax
    ; Get HINSTANCE of the program
    invoke    GetModuleHandle, NULL
    mov       [cmApplication.hModule], eax
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

    ; Create main window
    stdcall   Window.CreateWindow, [cmApplication.hModule], WINDOW_INIT_WIDTH, WINDOW_INIT_HEIGHT,\
              szClassName, szWindowName, Application.WindowProc, WINDOW_BACKGROUND_COLOR
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
    cmp       eax, WM_APP_IMAGE_LOADED
      je      .OnImageLoaded
    cmp       eax, WM_APP_CHUNK_READY
      je      .OnChunkReady
    cmp       eax, WM_APP_IMAGE_READY
      je      .OnImageReady
    cmp       eax, WM_APP_IMAGE_SAVED
      je      .OnImageSaved
    cmp       eax, WM_DROPFILES
      je      .OnDropFiles
    cmp       eax, WM_HSCROLL
      je      .OnHScroll
    cmp       eax, WM_CTLCOLORSTATIC
      je      .OnCtlColorStatic
    cmp       eax, WM_CTLCOLORBTN
      je      .OnCtlColorStatic
    jmp       .Default

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

.OnSize:
    include   './events/OnResize.asm'
    jmp       .Default

.OnDropFiles:
    include   './events/OnDropFiles.asm'
    jmp       .End

.OnHScroll:
    include   './events/OnHScroll.asm'
    jmp       .End

.OnImageLoaded:
    mov       edi, [wParam]
    test      edi, edi
      jz      .End

    ; Add newly loaded image to list
    movzx     eax, word [dwPages + 2]
    cmp       eax, MAX_IMAGE_COUNT
      jae     .End

    mov       [lpImagesList + eax * 4], edi
    inc       eax
    mov       word [dwPages + 2], ax
    mov       word [dwPages], ax

    ; Switch to this image and update UI
    stdcall   LabThree.MovePage, 0
    jmp       .End

.OnChunkReady:
    mov       eax, [wParam]
    cmp       eax, [cmApplication.lpCurrentImage]
      jne     .End
    stdcall   ImageView.Invalidate, [hImageView]
    jmp       .End

.OnImageReady:
    mov       eax, [wParam]
    cmp       eax, [cmApplication.lpCurrentImage]
      jne     .End
    stdcall   Button.SetEnabled, [hSaveBtn], TRUE
    stdcall   ImageView.Invalidate, [hImageView]
    jmp       .End

.OnImageSaved:
    jmp       .End

.OnCtlColorStatic:
    include   './events/OnCtlColorStatic.asm'
    jmp       .End

.Default:
    invoke    DefWindowProc, [hWnd], [uMsg], [wParam], [lParam]

.End:
    ret
endp

    include   './LabThree.asm'

    ; Classes
    include   './application/Application.asm'
    include   './memory/Memory.asm'
    include   './string/String.asm'
    include   './system/System.asm'
    include   './window/Window.asm'

    ; Data structures
    include   './ringbuf/ConcurrentRingBuffer.asm'

    ; Multithreading & Pipeline
    include   './threadpool/ThreadPool.asm'
    include   './dispatcher/TaskDispatcher.asm'
    include   './pipeline/Pipeline.asm'

    ; UI elements
    include   './ui/button/Button.asm'
    include   './ui/textlabel/TextLabel.asm'
    include   './ui/textlabel/PagesTextLabel.asm'
    include   './ui/trackbar/TrackBar.asm'
    include   './ui/imageview/ImageView.asm'
    include   './ui/filedialog/OpenFileDialog.asm'
    include   './ui/filedialog/SaveFileDialog.asm'

section '.data' data readable writeable
    szClassName            db 'BWFilterWindowClass', 0
    szWindowName           db 'B/W Filter', 0

    szButtonClassName      du 'BUTTON', 0
    szImageViewClassName   du 'ImageViewControl', 0
    szTrackbarClassName    du 'msctls_trackbar32', 0
    szLoadButtonText       du 'Load new...', 0
    szSaveButtonText       du 'Save it...', 0
    szPrevButtonText       du '<', 0
    szNextButtonText       du '>', 0

    szStaticClassName      du 'STATIC', 0
    szPagesLabelText       du '0 / 0', 10 dup(0)

    szMouseWheelType       du 'MSH_MOUSEWHEEL', 0
    szFontName             du 'Segoe UI', 0

    szOpenImageFilter      du 'Bitmaps (*.bmp)', 0, '*.bmp', 0
                           du 'All files (*.*)', 0, '*.*', 0, 0

    szSaveImageFilter      du 'Bitmaps (*.bmp)', 0, '*.bmp', 0
                           du 'All files (*.*)', 0, '*.*', 0, 0

    szBmpDefExt            du 'bmp', 0

    iccRequiredTypes       INITCOMMONCONTROLSEX\
                           sizeof.INITCOMMONCONTROLSEX,\
                           ICC_STANDARD_CLASSES or ICC_BAR_CLASSES

    dwPages                dw 0, 0

    dwTransformDelayMs     dd DEFAULT_TRANSFORM_DELAY_MS

section '.bss' data readable writeable
    cmApplication          MAPPLICATION
    cmWindow               MWINDOW
    cmKeyboard             MKEYBOARD
    cmMouse                MMOUSE

    hLoadBtn               rd 1
    hSaveBtn               rd 1
    hSpeedTrackbar         rd 1
    hPreviousBtn           rd 1
    hNextBtn               rd 1
    hPagesLabel            rd 1
    hImageView             rd 1

    bImageViewClassRegistered rd 1
    lpImagesList           rd MAX_IMAGE_COUNT

    szPathFilter           rw 260
    szSavePathFilter       rw 260
    szSubmitPathBuffer     rw 260
    szDropPathBuffer       rw 260

    hPipelineStopEvent     rd 1
    hSubmitPathEvent       rd 1

    hLoadQueue             rd 1
    hTransformQueue        rd 1
    hSaveQueue             rd 1

    hLoadPool              rd 1
    hTransformPool         rd 1
    hTaskDispatcher        rd 1

    hPathPusherThread      rd 1
    hLoadWatcherThread     rd 1
    hSaveWorkerThread      rd 1

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
        db                 ' name="Lab3.Application" type="win32"/>', 10
        db                 '  <dependency>', 10
        db                 '    <dependentAssembly>', 10
        db                 '      <assemblyIdentity type="win32" name="Microsoft.Windows.Common-Controls" '
        db                 'version="6.0.0.0" processorArchitecture="*" publicKeyToken="6595b64144ccf1df" language="*"/>', 10
        db                 '    </dependentAssembly>', 10
        db                 '  </dependency>', 10
        db                 '</assembly>'
    endres

section '.import' import data readable writeable
    library   unicows,                    'unicows.dll',\
              kernel32,                   'kernel32.dll',\
              user32,                     'user32.dll',\
              gdi32,                      'gdi32.dll',\
              comctl32,                   'comctl32.dll',\
              shell32,                    'shell32.dll'

    import    unicows,\
              GetModuleHandle,            'GetModuleHandleW',\
              CreateEvent,                'CreateEventW',\
              CreateSemaphore,            'CreateSemaphoreW',\
              CreateFile,                 'CreateFileW',\
              RegisterClassEx,            'RegisterClassExW',\
              DefWindowProc,              'DefWindowProcW',\
              CreateWindowEx,             'CreateWindowExW',\
              GetMessage,                 'GetMessageW',\
              DispatchMessage,            'DispatchMessageW',\
              PostMessage,                'PostMessageW',\
              LoadImage,                  'LoadImageW',\
              LoadCursor,                 'LoadCursorW',\
              LoadAccelerators,           'LoadAcceleratorsW',\
              TranslateAccelerator,       'TranslateAcceleratorW',\
              RegisterWindowMessage,      'RegisterWindowMessageW',\
              DrawText,                   'DrawTextW',\
              GetWindowLong,              'GetWindowLongW',\
              SetWindowLong,              'SetWindowLongW',\
              SendMessage,                'SendMessageW',\
              SystemParametersInfo,       'SystemParametersInfoW',\
              SetWindowText,              'SetWindowTextW',\
              IsDialogMessage,            'IsDialogMessageW',\
              GetObject,                  'GetObjectW',\
              CreateFont,                 'CreateFontW',\
              CreateFontIndirect,         'CreateFontIndirectW',\
              GetOpenFileName,            'GetOpenFileNameW',\
              GetSaveFileName,            'GetSaveFileNameW',\
              DragQueryFile,              'DragQueryFileW'

    import    kernel32,\
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
              SetFilePointer,             'SetFilePointer'

    import    user32,\
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
              GetParent,                  'GetParent'

    import    gdi32,\
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
              SetStretchBltMode,          'SetStretchBltMode'

    import    comctl32,\
              InitCommonControlsEx,       'InitCommonControlsEx'

    import    shell32,\
              DragFinish,                 'DragFinish',\
              DragAcceptFiles,            'DragAcceptFiles'
