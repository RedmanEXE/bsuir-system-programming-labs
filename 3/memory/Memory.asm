; HANDLE Memory.Initialize();
proc Memory.Initialize stdcall uses ecx edx
    invoke    GetProcessHeap
    ret
endp

; LPVOID Memory.Allocate(HANDLE hHeap, SIZE_T dwBytesCount);
proc Memory.Allocate stdcall uses ecx edx,\
     hHeap:DWORD, dwBytesCount:DWORD
    invoke    HeapAlloc, [hHeap], HEAP_ZERO_MEMORY, [dwBytesCount]
    ret
endp

; LPVOID Memory.Reallocate(HANDLE hHeap, LPVOID lpOldPtr, SIZE_T dwNewBytesCount);
proc Memory.Reallocate stdcall uses ecx edx,\
     hHeap:DWORD, lpOldPtr:DWORD, dwNewBytesCount:DWORD
    invoke    HeapReAlloc, [hHeap], HEAP_ZERO_MEMORY, [lpOldPtr], [dwNewBytesCount]
    ret
endp

; BOOL Memory.Free(HANDLE hHeap, LPVOID lpMem);
proc Memory.Free stdcall uses ecx edx,\
     hHeap:DWORD, lpMem:DWORD
    invoke    HeapFree, [hHeap], 0, [lpMem]
    ret
endp