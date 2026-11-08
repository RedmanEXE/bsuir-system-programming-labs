format        PE GUI 3.1 DLL
entry         Library.Setup

include       'win32wx.inc'
include       'macro/proc32.inc'

include       'constants.inc'
include       'structures.inc'

section '.text' code readable executable
proc Library.Setup stdcall uses ecx edx,\
     hInstDLL:DWORD, fdwReason:DWORD, lpvReserved:DWORD
    mov       eax, TRUE
    ret
endp

; MyLibrary.ScanAndReplace(LPTSTR lpszToBeReplaced, LPTSTR lpszReplaceWith,
;                          DWORD cbToBeReplacedSize);
proc MyLibrary.ScanAndReplace stdcall uses eax ecx edx,\
     lpszToBeReplaced: DWORD, lpszReplaceWith: DWORD, cbToBeReplacedSize: DWORD
    locals
        lpCurrentAddress dd 0
    endl

    mov       [lpCurrentAddress], 0

.LoopByMemory:
    invoke    VirtualQuery, [lpCurrentAddress], mbiPageInfo, sizeof.MEMORY_BASIC_INFORMATION
    test      eax, eax
      jz      .LoopEnd

    ; Check for physical page
    cmp       [mbiPageInfo.State], MEM_COMMIT
      jne     .LoopMoveOn

    ; Check for GUARD
    test      [mbiPageInfo.Protect], PAGE_GUARD or PAGE_NOACCESS
      jnz     .LoopMoveOn

    ; Check for RW access
    mov       eax, [mbiPageInfo.Protect]
    and       eax, 0xFF
    cmp       eax, PAGE_READWRITE
      je      .PageValid
    cmp       eax, PAGE_EXECUTE_READWRITE
      je      .PageValid
    jmp       .LoopMoveOn

.PageValid:
    ; Parse it!
    stdcall   Library.ParsePage, [mbiPageInfo.BaseAddress], [mbiPageInfo.RegionSize],\
              [lpszToBeReplaced], [lpszReplaceWith], [cbToBeReplacedSize]

.LoopMoveOn:
    mov       eax, [mbiPageInfo.BaseAddress]
    add       eax, [mbiPageInfo.RegionSize]
    mov       [lpCurrentAddress], eax

    jmp       .LoopByMemory

.LoopEnd:
.EndProc:
    ret
endp

; void Library.ParsePage(LPVOID lpBaseAddr, SIZE_T cbRegionSize,
;                        LPTSTR lpszToBeReplaced, LPTSTR lpszReplaceWith, SIZE_T cbToBeReplacedSize);
proc Library.ParsePage stdcall uses eax ecx edx esi edi,\
    lpBaseAddr:DWORD, cbRegionSize:DWORD, lpszToBeReplaced:DWORD,\
    lpszReplaceWith:DWORD, cbToBeReplacedSize:DWORD

    mov       edi, [lpBaseAddr]
    mov       ecx, [cbRegionSize]

    sub       ecx, [cbToBeReplacedSize]
      jl      .Done

.ScanBuffer:
    ; Compare
    push      ecx
    push      edi

    mov       esi, [lpszToBeReplaced]
    mov       ecx, [cbToBeReplacedSize]
      repe cmpsb

    pop       edi
    pop       ecx

      jne     .Continue

    ; String found
    ; Replace it
    push      ecx
    push      edi

    mov       esi, [lpszReplaceWith]
    mov       ecx, [cbToBeReplacedSize]
      rep movsb

    pop       edi
    pop       ecx

    ; Jump for string len - 1
    mov       eax, [cbToBeReplacedSize]
    dec       eax
    add       edi, eax
    sub       ecx, eax
      jl      .Done

.Continue:
    inc       edi
    dec       ecx
      jge     .ScanBuffer

.Done:
    ret
endp

section '.bss' data readable writeable
    mbiPageInfo         MEMORY_BASIC_INFORMATION

section '.import' import data readable
    library kernel32,                   'kernel32.dll'

    import  kernel32,\
            VirtualQuery,               'VirtualQuery'

section '.export' export data readable
    export  'patcher.dll',\
            MyLibrary.ScanAndReplace,   'ScanAndReplace'

section '.reloc' data readable discardable fixups