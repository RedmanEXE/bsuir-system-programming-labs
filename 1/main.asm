format        PE GUI 3.1
entry         Application.Setup

include       'win32a.inc'
include       'constants.inc'

section '.code' code readable executable
Application.Setup:
    ; Load sprite image
    stdcall   Bitmap.LoadImage, szSpritePath
    mov       [cmSprite.hBitmap], eax

    ; Create main window
    stdcall   Window.CreateWindow, 320, 200, szClassName, szWindowName, Application.WindowProc
    mov       [hWindow], eax

    ; MSG structure
    sub       esp, sizeof.MSG
Application.WindowLoop:
    ; Process window messages
    stdcall   Window.ProcessMessages, dword [hWindow], esp

    cmp       eax, 0
      jg      Application.WindowLoop

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
    cmp       eax, WM_DESTROY
      je      .OnDestroy
    cmp       eax, WM_PAINT
      je      .OnPaint
    jmp       .Default

.OnCreate:
    include   './events/OnCreate.asm'
    jmp       .Default

.OnClose:
    include   './events/OnClose.asm'
    jmp       .End

.OnDestroy:
    include   './events/OnDestroy.asm'
    jmp       .End

.OnPaint:
    include   './events/OnPaint.asm'
    jmp       .End

.Default:
    invoke    DefWindowProc, dword [ebp + 8], dword [ebp + 12], dword [ebp + 16],\
              dword [ebp + 20]

.End:
    pop       esi ebx
    leave
    ret       16

    include   './application/Application.asm'
    include   './bitmap/Bitmap.asm'
    include   './window/Window.asm'

section '.data' data readable writeable
    szClassName       db 'LabOneWindowClass', 0
    szWindowName      db 'Lab 1', 0

    szSpritePath      db 'sprite.bmp', 0

section '.bss' data readable writeable
    hWindow           rd 1
    cmSprite:
        .hBitmap      rd 1
        .hOldBitmap   rd 1
        .hMemDC       rd 1
        .bmpInfo      BITMAP
        .ptPosition   POINTS

section '.import' data import readable writeable
    library   kernel32,           'kernel32.dll',\
              user32,             'user32.dll',\
              gdi32,              'gdi32.dll'

    import    kernel32,\
              GetModuleHandle,    'GetModuleHandleA',\
              ExitProcess,        'ExitProcess'

    import    user32,\
              RegisterClassEx,    'RegisterClassExA',\
              DefWindowProc,      'DefWindowProcA',\
              CreateWindowEx,     'CreateWindowExA',\
              AdjustWindowRectEx, 'AdjustWindowRectEx',\
              GetMessage,         'GetMessageA',\
              TranslateMessage,   'TranslateMessage',\
              DispatchMessage,    'DispatchMessageA',\
              PostQuitMessage,    'PostQuitMessage',\
              BeginPaint,         'BeginPaint',\
              LoadImage,          'LoadImageA',\
              GetClientRect,      'GetClientRect',\
              GetDC,              'GetDC',\
              EndPaint,           'EndPaint',\
              ReleaseDC,          'ReleaseDC'

    import    gdi32,\
              CreateCompatibleDC, 'CreateCompatibleDC',\
              SelectObject,       'SelectObject',\
              GetObject,          'GetObjectA',\
              BitBlt,             'BitBlt',\
              DeleteDC,           'DeleteDC',\
              DeleteObject,       'DeleteObject'



