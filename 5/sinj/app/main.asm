format        PE GUI 3.1
entry         Application.Setup

include       'win32w.inc'
include       'macro/proc32.inc'

include       'constants.inc'
include       'structures.inc'

section '.code' code readable executable
Application.Setup:
    ; Get PID of the notepad
    stdcall   GetNotepadPID
    test      eax, eax
      jnz     @F
    stdcall   Application.Terminate, 1
@@:
    mov       ebx, eax
    ; Inject to it
    invoke    ScanAndReplace, ebx, szToBeReplaced, szReplaceWith, 14

    stdcall   Application.Terminate, 0
    ret

proc GetNotepadPID uses ecx edx
    locals
        dwTargetPID       dd 0
    endl

    ; Get "Notepad" window
    invoke  FindWindow, szNotepadClass, 0
    test    eax, eax
    jz      .NotFound

    ; Search for PID by window
    lea     ecx, [dwTargetPID]
    invoke  GetWindowThreadProcessId, eax, ecx
    
    mov     eax, [dwTargetPID]
    jmp     .End

.NotFound:
    xor     eax, eax        ; no
.End:
    ret
endp

    ; Classes
    include   './application/Application.asm'

section '.data' data readable writeable
    szNotepadClass         du 'Notepad', 0

    szToBeReplaced         du 'Replace'
    szReplaceWith          du 'ThisOne'

section '.bss' data readable writeable
    cmInjectData           INJECT_DATA

section '.rsrc' resource data readable
    directory              RT_MANIFEST, manifests
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
            patcher,                    'patcher.dll'

    import  kernel32,\
            ExitProcess,                'ExitProcess'

    import  user32,\
            FindWindow,                 'FindWindowW',\
            GetWindowThreadProcessId,   'GetWindowThreadProcessId'

    import  patcher,\
            ScanAndReplace,             'ScanAndReplace'
