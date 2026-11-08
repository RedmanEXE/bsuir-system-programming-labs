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
    ; Fill inject data
    mov       eax, [LoadLibrary]
    mov       [cmInjectData.pLoadLibrary], eax
    mov       eax, [GetProcAddress]
    mov       [cmInjectData.pGetProcAddress], eax

    cld
    ; Copy DLL name
    mov       esi, szPatcherDllName
    mov       edi, cmInjectData.szDllName
    mov       ecx, 12
      rep movsw
    ; Copy DLL function name
    mov       esi, szPatcherFuncName
    mov       edi, cmInjectData.szFuncName
    mov       ecx, 15
      rep movsb
    ; Copy to be replaced
    mov       esi, szToBeReplaced
    mov       edi, cmInjectData.szToBeReplaced
    mov       ecx, 7
      rep movsw
    ; Copy replace with
    mov       esi, szReplaceWith
    mov       edi, cmInjectData.szReplaceWith
    mov       ecx, 7
      rep movsw
    mov       [cmInjectData.cbReplaceSize], 14

    ; Inject to it
    stdcall   Application.Inject, ebx

    stdcall   Application.Terminate, 0
    ret

proc Application.Inject stdcall uses ecx edx ebx esi edi,\
     dwPID: DWORD
    locals
        .dwExtCode     rd 1
        .hChildThread  rd 1
        .dwThreadId    rd 1
    endl

    ; Open process
    invoke    OpenProcess, PROCESS_CREATE_THREAD or PROCESS_VM_READ or PROCESS_VM_WRITE or\
              PROCESS_QUERY_INFORMATION or PROCESS_VM_OPERATION, FALSE, [dwPID]
    test      eax, eax
      jz      .End
    mov       ebx, eax

    ; Allocate memory for structure
    invoke    VirtualAllocEx, ebx, NULL, sizeof.INJECT_DATA, MEM_COMMIT, PAGE_READWRITE
    mov       edi, eax
    ; Write data to it!
    lea       eax, [.dwExtCode]
    invoke    WriteProcessMemory, ebx, edi, cmInjectData, sizeof.INJECT_DATA, eax
    lea       eax, [.dwExtCode]
    invoke    VirtualProtectEx, ebx, edi, sizeof.INJECT_DATA, PAGE_READONLY, eax

    ; Allocate memory for code
    invoke    VirtualAllocEx, ebx, NULL, ExternalCodeSize, MEM_COMMIT, PAGE_EXECUTE_READWRITE
    mov       esi, eax
    ; Write code to it!
    lea       eax, [.dwExtCode]
    invoke    WriteProcessMemory, ebx, esi, Application.ExternalCode, ExternalCodeSize, eax

    ; Create remote thread
    lea      eax, [.dwThreadId]
    invoke   CreateRemoteThread, ebx, NULL, 0, esi, edi, 0, eax
.End:
    ret
endp

proc Application.ExternalCode stdcall uses ebx esi edi,\
     lpParameter: DWORD
    virtual at esi
        .cmInjectData     INJECT_DATA
    end virtual

    ; Set param
    mov      esi, [lpParameter]

    ; Invoke LoadLibraryW
    lea      eax, [.cmInjectData.szDllName]
    invoke   .cmInjectData.pLoadLibrary, eax
    mov      ebx, eax

    ; Get addr of the function to call
    lea      eax, [.cmInjectData.szFuncName]
    invoke   .cmInjectData.pGetProcAddress, ebx, eax
    mov      edi, eax

    ; Invoke ScanAndReplace
    lea      eax, [.cmInjectData.szToBeReplaced]
    lea      ecx, [.cmInjectData.szReplaceWith]
    mov      edx, [.cmInjectData.cbReplaceSize]
    stdcall  edi, eax, ecx, edx

    ret
endp
ExternalCodeSize = $ - Application.ExternalCode

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
    include   './string/String.asm'

section '.data' data readable writeable
    szNotepadClass         du 'Notepad', 0

    szPatcherDllName       du 'patcher.dll', 0
    szPatcherFuncName      db 'ScanAndReplace', 0

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
            user32,                     'user32.dll'

    import  kernel32,\
            LoadLibrary,                'LoadLibraryW',\
            GetProcAddress,             'GetProcAddress',\
            ExitProcess,                'ExitProcess',\
            OpenProcess,                'OpenProcess',\
            VirtualAllocEx,             'VirtualAllocEx',\
            WriteProcessMemory,         'WriteProcessMemory',\
            CreateRemoteThread,         'CreateRemoteThread',\
            VirtualProtectEx,           'VirtualProtectEx'

    import  user32,\
            FindWindow,                 'FindWindowW',\
            GetWindowThreadProcessId,   'GetWindowThreadProcessId'

