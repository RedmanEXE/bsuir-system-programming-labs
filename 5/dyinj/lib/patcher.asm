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

; MyLibrary.ScanAndReplace(DWORD dwPID, LPTSTR lpszToBeReplaced, LPTSTR lpszReplaceWith,
;                          DWORD cbToBeReplacedSize);
proc MyLibrary.ScanAndReplace stdcall uses eax ebx ecx edx,\
     dwPID: DWORD, lpszToBeReplaced: DWORD, lpszReplaceWith: DWORD,\
     cbToBeReplacedSize: DWORD
    locals
        lpCurrentAddress dd 0
    endl

    ; Open process to get handle
    invoke    OpenProcess, PROCESS_VM_READ or PROCESS_VM_WRITE or PROCESS_QUERY_INFORMATION or\
              PROCESS_VM_OPERATION, TRUE, [dwPID]
    test      eax, eax
      jz      .EndProc
    mov       ebx, eax

    mov       [lpCurrentAddress], 0

.LoopByMemory:
    invoke    VirtualQueryEx, ebx, [lpCurrentAddress], mbiPageInfo, sizeof.MEMORY_BASIC_INFORMATION
    test      eax, eax
      jz      .LoopEnd

    ; Check for physical page
    cmp       [mbiPageInfo.State], MEM_COMMIT
      jne     .LoopMoveOn

    ; Check for RW access
    mov       eax, [mbiPageInfo.Protect]
    and       eax, PAGE_READWRITE
      jz      .LoopMoveOn

    ; Parse it!
    stdcall   Library.ParsePage, ebx, [mbiPageInfo.BaseAddress], [mbiPageInfo.RegionSize],\
              [lpszToBeReplaced], [lpszReplaceWith], [cbToBeReplacedSize]

.LoopMoveOn:
    mov       eax, [mbiPageInfo.BaseAddress]
    add       eax, [mbiPageInfo.RegionSize]
    mov       [lpCurrentAddress], eax

    jmp       .LoopByMemory

.LoopEnd:
    invoke    CloseHandle, ebx

.EndProc:
    ret
endp

; void Library.ParsePage(HMODULE hModule, LPVOID lpBaseAddr, SIZE_T cbRegionSize,
;                        LPTSTR lpszToBeReplaced, LPTSTR lpszReplaceWith, SIZE_T cbToBeReplacedSize);
proc Library.ParsePage stdcall uses eax ecx edx ebx esi edi,\
    hModule:DWORD, lpBaseAddr:DWORD, cbRegionSize:DWORD, lpszToBeReplaced:DWORD,\
    lpszReplaceWith:DWORD, cbToBeReplacedSize:DWORD

    locals
        .lpCurrAddr    rd 1
        .dwBytesLeft   rd 1
        .dwBytesRead   rd 1
        .dwReadSize    rd 1
    endl

    mov       eax, [lpBaseAddr]
    mov       [.lpCurrAddr], eax
    mov       eax, [cbRegionSize]
    mov       [.dwBytesLeft], eax

.LoopRead:
    cmp       [.dwBytesLeft], 0
      jle     .Done               ; If left == 0 => end

    ; Calculate size of the chunk to read
    mov       eax, CHUNK_SIZE
    cmp       [.dwBytesLeft], eax
      jge     @F
    mov       eax, [.dwBytesLeft] ; If less than 64kB => read all
@@:
    mov       [.dwReadSize], eax

    ; Read chunk
    lea       eax, [.dwBytesRead]
    invoke    ReadProcessMemory, [hModule], [.lpCurrAddr], aMemoryPage, [.dwReadSize], eax
    test      eax, eax
      jz      .NextChunk          ; If chunk is protected, skip it

    ; Scan buffer for strings
    mov       ecx, [.dwBytesRead]
    sub       ecx, [cbToBeReplacedSize]
      jl      .NextChunk          ; If remaining length less than string len, next chunk

    lea       edi, [aMemoryPage]

.ScanBuffer:
    ; Compare
    push      ecx
    push      edi

    mov       esi, [lpszToBeReplaced]
    mov       ecx, [cbToBeReplacedSize]
      repe cmpsb

    pop       edi
    pop       ecx

      jne     .Continue         ; String not found

    ; String found
    mov       eax, edi
    sub       eax, aMemoryPage
    add       eax, [.lpCurrAddr]

    ; Replace it
    push      ecx
    invoke    WriteProcessMemory, [hModule], eax, [lpszReplaceWith], [cbToBeReplacedSize], 0
    pop       ecx

    ; Jump for string len - 1
    mov       eax, [cbToBeReplacedSize]
    dec       eax
    add       edi, eax
    sub       ecx, eax
      jl      .NextChunk        ; Check for bounds

.Continue:
    inc       edi               ; Move for 1 char
    dec       ecx
      jge     .ScanBuffer

.NextChunk:
    ; Check for chunk bounds
    cmp       [.dwReadSize], CHUNK_SIZE
      jl      .Done

    ; Jump for chunk size - (string len - 1)
    mov       eax, CHUNK_SIZE
    sub       eax, [cbToBeReplacedSize]
    inc       eax

    add       [.lpCurrAddr], eax
    sub       [.dwBytesLeft], eax
    jmp       .LoopRead

.Done:
    ret
endp

section '.bss' data readable writeable
    aMemoryPage         rb CHUNK_SIZE
    mbiPageInfo         MEMORY_BASIC_INFORMATION

section '.import' import data readable
    library kernel32,                   'kernel32.dll'

    import  kernel32,\
            OpenProcess,                'OpenProcess',\
            VirtualQueryEx,             'VirtualQueryEx',\
            ReadProcessMemory,          'ReadProcessMemory',\
            WriteProcessMemory,         'WriteProcessMemory',\
            CloseHandle,                'CloseHandle'

section '.export' export data readable
    export  'patcher.dll',\
            MyLibrary.ScanAndReplace,   'ScanAndReplace'

section '.reloc' data readable discardable fixups
