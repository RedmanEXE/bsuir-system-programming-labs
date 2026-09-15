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

    ; Create background brush
    invoke    CreateSolidBrush, 0
    mov       [cmWindow.hbrBg], eax

    ; Create main window
    stdcall   Window.CreateWindow, [cmApplication.hModule], WINDOW_INIT_WIDTH, WINDOW_INIT_HEIGHT,\
              szClassName, szWindowName, Application.WindowProc, eax
    mov       [cmWindow.hWindow], eax

    ; MSG structure
    sub       esp, sizeof.MSG
Application.WindowLoop:
    ; Process window messages
    stdcall   Window.ProcessMessages, [cmWindow.hWindow], [cmApplication.hAccelTable], esp

    cmp       eax, 0
      jle     .Exit
.ReDraw:
    ; Place WM_PAINT event to the queue
    invoke    InvalidateRect, dword [cmWindow.hWindow], NULL, FALSE

    include   './events/OnPhysicsProcess.asm'

    ; Sleep for 1ms to create some sort of CPU "optimization"
    ; invoke    Sleep, 1

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
    cmp       eax, WM_CHAR
      je      .OnChar
    cmp       eax, WM_DESTROY
      je      .OnDestroy
    cmp       eax, WM_ERASEBKGND
      je      .OnEraseBkg
    cmp       eax, WM_KEYDOWN
      je      .OnKeyDown
    cmp       eax, WM_KEYUP
      je      .OnKeyUp
    cmp       eax, WM_PAINT
      je      .OnPaint
    cmp       eax, WM_SIZE
      je      .OnSize
    mov       ecx, [cmApplication.uOldWheelMsgID]
    cmp       eax, ecx
      je      .OnOldMouseWheel
    cmp       eax, WM_MOUSEWHEEL
      je      .OnMouseWheel
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

.OnChar:
    include   './events/OnChar.asm'
    jmp       .End

.OnDestroy:
    include   './events/OnDestroy.asm'
    jmp       .End

.OnEraseBkg:
    include   './events/OnEraseBkg.asm'
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

.OnPaint:
    include   './events/OnPaint.asm'
    jmp       .End

.OnSize:
    include   './events/OnResize.asm'
    jmp       .Default

.Default:
    invoke    DefWindowProc, [hWnd], [uMsg], [wParam], [lParam]

.End:
    ret
endp

    include   './application/Application.asm'
    include   './grid/Grid.asm'
    include   './memory/Memory.asm'
    include   './window/Window.asm'

section '.data' data readable writeable
    szClassName            du 'LabTwoWindowClass', 0
    szWindowName           du 'Lab 2', 0

    szMouseWheelType       du 'MSH_MOUSEWHEEL', 0
    szFontName             du 'Segoe UI', 0

section '.bss' data readable writeable
    cmApplication          MAPPLICATION
    cmWindow               MWINDOW
    cmGrid                 MGRID
    cmKeyboard             MKEYBOARD
    cmMouse                MMOUSE

section '.rsrc' resource data readable
    directory              RT_ACCELERATOR, accelerators

    resource               accelerators, 1, LANG_NEUTRAL, acAccelTable

    resdata acAccelTable
        raccel             FVIRTKEY or FCONTROL or FALT, 'X', KEY_ID_EXIT, 0
        raccel             FVIRTKEY or FSHIFT or FALT,   'C', KEY_ID_EXIT, RACCEL_LAST
    endres

section '.import' import data readable writeable
    library   kernel32,               'kernel32.dll',\
              user32,                 'user32.dll',\
              gdi32,                  'gdi32.dll'

    import    kernel32,\
              GetModuleHandle,        'GetModuleHandleW',\
              ExitProcess,            'ExitProcess',\
              Sleep,                  'Sleep',\
              GetProcessHeap,         'GetProcessHeap',\
              HeapAlloc,              'HeapAlloc',\
              HeapReAlloc,            'HeapReAlloc',\
              HeapFree,               'HeapFree'

    import    user32,\
              RegisterClassEx,        'RegisterClassExW',\
              DefWindowProc,          'DefWindowProcW',\
              CreateWindowEx,         'CreateWindowExW',\
              AdjustWindowRectEx,     'AdjustWindowRectEx',\
              PeekMessage,            'PeekMessageW',\
              TranslateMessage,       'TranslateMessage',\
              DispatchMessage,        'DispatchMessageW',\
              PostQuitMessage,        'PostQuitMessage',\
              BeginPaint,             'BeginPaint',\
              LoadImage,              'LoadImageW',\
              GetClientRect,          'GetClientRect',\
              GetDC,                  'GetDC',\
              EndPaint,               'EndPaint',\
              ReleaseDC,              'ReleaseDC',\
              InvalidateRect,         'InvalidateRect',\
              LoadCursor,             'LoadCursorW',\
              FillRect,               'FillRect',\
              LoadAccelerators,       'LoadAcceleratorsW',\
              TranslateAccelerator,   'TranslateAcceleratorW',\
              DestroyWindow,          'DestroyWindow',\
              RegisterWindowMessage,  'RegisterWindowMessageW',\
              GetKeyState,            'GetKeyState',\
              FrameRect,              'FrameRect',\
              DrawText,               'DrawTextW'

    import    gdi32,\
              CreateCompatibleDC,     'CreateCompatibleDC',\
              SelectObject,           'SelectObject',\
              GetObject,              'GetObjectW',\
              BitBlt,                 'BitBlt',\
              DeleteDC,               'DeleteDC',\
              DeleteObject,           'DeleteObject',\
              CreateSolidBrush,       'CreateSolidBrush',\
              CreateCompatibleBitmap, 'CreateCompatibleBitmap',\
              GetStockObject,         'GetStockObject',\
              SetBkMode,              'SetBkMode',\
              SetTextColor,           'SetTextColor',\
              CreateFont,             'CreateFontW'



