format        PE GUI 3.1
entry         Application.Setup

include       'win32a.inc'
include       'constants.inc'
include       'macroses.inc'

section '.code' code readable executable
Application.Setup:
    ; Get HINSTANCE of the program
    invoke    GetModuleHandle, NULL
    mov       [hModule], eax
    ; And load accelerators table
    invoke    LoadAccelerators, eax, 1
    mov       [hAccelTable], eax
    ; Register for MSH_MOUSEWHEEL messages
    invoke    RegisterWindowMessage, szMouseWheelType
    mov       [uOldWheelMsgID], eax

    ; Load sprite image
    stdcall   Bitmap.LoadImage, szSpritePath
    mov       [cmSprite.hBitmap], eax

    ; Create background brush
    invoke    CreateSolidBrush, 0
    mov       [cmWindow.hbrBg], eax

    ; Create main window
    stdcall   Window.CreateWindow, [hModule], WINDOW_INIT_WIDTH, WINDOW_INIT_HEIGHT,\
              szClassName, szWindowName, Application.WindowProc, eax
    mov       [cmWindow.hWindow], eax

    ; MSG structure
    sub       esp, sizeof.MSG
Application.WindowLoop:
    ; Process window messages
    stdcall   Window.ProcessMessages, [cmWindow.hWindow], [hAccelTable], esp

    cmp       eax, 0
      jle     @F
.ReDraw:
    ; Place WM_PAINT event to the queue
    invoke    InvalidateRect, dword [cmWindow.hWindow], NULL, FALSE

    include   './events/OnPhysicsProcess.asm'

    ; Sleep for 1ms to create some sort of CPU "optimization"
    ; invoke    Sleep, 1

    jmp       Application.WindowLoop
@@:

    ; Free MSG structure
    add       esp, sizeof.MSG

    stdcall   Application.Terminate, 0
    ret

Application.WindowProc:
    push      ebp
    mov       ebp, esp
    push      ebx esi

    mov       eax, [ebp + 12]
    cmp       eax, WM_CREATE
      je      .OnCreate
    cmp       eax, WM_CLOSE
      je      .OnClose
    cmp       eax, WM_COMMAND
      je      .OnCommand
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
    mov       ecx, [uOldWheelMsgID]
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
    invoke    DefWindowProc, dword [ebp + 8], dword [ebp + 12], dword [ebp + 16],\
              dword [ebp + 20]

.End:
    pop       esi ebx
    leave
    ret       16

    include   './application/Application.asm'
    include   './bitmap/Bitmap.asm'
    include   './player/Player.asm'
    include   './window/Window.asm'

section '.data' data readable writeable
    szClassName       db 'LabOneWindowClass', 0
    szWindowName      db 'Lab 1', 0

    szMouseWheelType  db 'MSH_MOUSEWHEEL', 0

    szSpritePath      db 'sprite.bmp', 0

section '.bss' data readable writeable
    hAccelTable       rd 1
    hModule           rd 1
    uOldWheelMsgID    rd 1
    cmWindow:
        .hWindow      rd 1
        .width        rw 1
        .height       rw 1
        .hbrBg        rd 1
        .hBBufMemDC   rd 1
        .hBBufBitmap  rd 1
        .hBBufOldBmp  rd 1
    cmSprite:
        .hBitmap      rd 1
        .hOldBitmap   rd 1
        .hMemDC       rd 1
        .bmpInfo      BITMAP
        .ptPosition   POINTS
        .ptOldPos     POINTS
        .ptMoveAccum  POINTS
    cmKeyboard:              ; 0         8         16        24        32        40
        .bKeys        rb 5   ; [01234567][89ABCDEF][GHIJKLMN][OPQRSTUV][WXYZ    ]
    cmMouse:
        .wheelAccum   rd 1

section '.rsrc' resource data readable
    directory         RT_ACCELERATOR, accelerators

    resource          accelerators, 1, LANG_NEUTRAL, acAccelTable

    resdata acAccelTable
        raccel        FVIRTKEY or FCONTROL or FALT, 'X', KEY_ID_EXIT, 0
        raccel        FVIRTKEY or FSHIFT or FALT,   'C', KEY_ID_EXIT, RACCEL_LAST
    endres

section '.import' import data readable writeable
    library   kernel32,               'kernel32.dll',\
              user32,                 'user32.dll',\
              gdi32,                  'gdi32.dll'

    import    kernel32,\
              GetModuleHandle,        'GetModuleHandleA',\
              ExitProcess,            'ExitProcess',\
              Sleep,                  'Sleep'

    import    user32,\
              RegisterClassEx,        'RegisterClassExA',\
              DefWindowProc,          'DefWindowProcA',\
              CreateWindowEx,         'CreateWindowExA',\
              AdjustWindowRectEx,     'AdjustWindowRectEx',\
              PeekMessage,            'PeekMessageA',\
              TranslateMessage,       'TranslateMessage',\
              DispatchMessage,        'DispatchMessageA',\
              PostQuitMessage,        'PostQuitMessage',\
              BeginPaint,             'BeginPaint',\
              LoadImage,              'LoadImageA',\
              GetClientRect,          'GetClientRect',\
              GetDC,                  'GetDC',\
              EndPaint,               'EndPaint',\
              ReleaseDC,              'ReleaseDC',\
              InvalidateRect,         'InvalidateRect',\
              LoadCursor,             'LoadCursorA',\
              FillRect,               'FillRect',\
              LoadAccelerators,       'LoadAcceleratorsA',\
              TranslateAccelerator,   'TranslateAcceleratorA',\
              DestroyWindow,          'DestroyWindow',\
              RegisterWindowMessage,  'RegisterWindowMessageA',\
              GetKeyState,            'GetKeyState'

    import    gdi32,\
              CreateCompatibleDC,     'CreateCompatibleDC',\
              SelectObject,           'SelectObject',\
              GetObject,              'GetObjectA',\
              BitBlt,                 'BitBlt',\
              DeleteDC,               'DeleteDC',\
              DeleteObject,           'DeleteObject',\
              CreateSolidBrush,       'CreateSolidBrush',\
              CreateCompatibleBitmap, 'CreateCompatibleBitmap'



