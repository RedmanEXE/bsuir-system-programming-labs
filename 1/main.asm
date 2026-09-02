format        PE GUI 3.1
entry         Application.Setup

include       'win32a.inc'
include       'constants.inc'

section '.code' code readable executable
Application.Setup:
    push      Application.WindowProc
    push      szWindowName
    push      szClassName
    push      200
    push      320
    call      Window.CreateWindow
    mov       [hWindow], eax

    push      0
    call      Application.Terminate

    include   './window/Window.asm'
    include   './application/Application.asm'

Application.WindowProc:
    ret       16

section '.idata' data readable writeable
    szClassName       db 'LabOneWindowClass'
    szWindowName      db 'Lab 1'

section '.udata' data readable writeable
    hWindow           rd 1

section '.import' data import readable writeable
    library   kernel32,           'kernel32.dll',\
              user32,             'user32.dll',\
              gdi32,              'gdi32.dll'

    import    kernel32,\
              GetModuleHandle,    'GetModuleHandleA',\
              ExitProcess,        'ExitProcess'

    import    gdi32,\
              RegisterClassEx,    'RegisterClassExA',\
              DefWindowProc,      'DefWindowProcA',\
              CreateWindowEx,     'CreateWindowExA',\
              AdjustWindowRectEx, 'AdjustWindowRectEx'



