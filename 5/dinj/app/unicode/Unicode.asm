; BOOL Unicode.CheckForNativeSupport();
proc Unicode.CheckForNativeSupport stdcall uses ecx
    ; Get handle for kernel32.dll
    invoke    GetModuleHandle, szKernelDllName
    test      eax, eax
      jz      .NoNative
    ; Get function
    invoke    GetProcAddress, eax, szTestFunctionName
    test      eax, eax
      jz      .NoNative           ; If there's no function -> Windows 95
    ; Call it
    push      NULL
    call      eax
    test      eax, eax
      jz      .NoNative           ; If returns NULL -> Windows 95/98/ME

    ; Otherwise, Win2000+
    mov       eax, 1
    jmp       .End
.NoNative:
    xor       eax, eax            ; No UTF-16 support
.End:
    ret
endp

; void Unicode.Activate(HANDLE hModule);
proc Unicode.Activate stdcall uses eax ecx ebx esi edi,\
    hModule:DWORD
    
    local     isNativeNT:DWORD
    local     hUnicows:DWORD
    local     hCurrentMod:DWORD
    local     pILT:DWORD
    local     pIAT:DWORD
    local     pfnGMHOriginal:DWORD
    local     szBuffer[256]:BYTE

    ; Check for unsupported version (95/98/ME)
    stdcall   Unicode.CheckForNativeSupport
    mov       [isNativeNT], eax
    test      eax, eax
      jnz     .StartParsing

.LoadUnicows:
    ; If it Windows w/o Unicode support - load unicows.dll (MSLU)
    invoke    LoadLibrary, szUnicoWS
    test      eax, eax
      jz      .End                ; If there's no library - end activation
    mov       [hUnicows], eax
    jmp       .StartParsing

.StartParsing:
    ; Save original value for GetModuleHandle
    ; Because: all names of the libraries stored as ASCII strings
    ; when we rewrite GetModuleHandleA to W - it requires UTF-16 string
    mov       eax, [GetModuleHandle]
    mov       [pfnGMHOriginal], eax

    mov       ebx, [hModule]
    test      ebx, ebx
      jz      .End                ; Check for valid handle

    ; Check for MZ header
    cmp       word [ebx], 'MZ'
      jne     .End

    ; Get PE header offset
    mov       eax, [ebx + 3Ch]
    add       ebx, eax

    ; Check for PE header
    cmp       dword [ebx], 'PE'
      jne     .End

    ; Get import table (RVA dir)
    mov       esi, [ebx + 80h]
    test      esi, esi
      jz      .End                ; If there's no import table - end

    add       esi, [hModule]      ; IMAGE_IMPORT_DESCRIPTOR

.DescriptorLoop:
    ; Offset 12 - RVA of the curr DLL
    mov       eax, [esi + 12]
    test      eax, eax
      jz      .End                ; If there's no any more records

    add       eax, [hModule]
    
    ; Get HMODULE of the system dll
    push      eax
    call      [pfnGMHOriginal]
    mov       [hCurrentMod], eax

    ; Offset 0: ILT (function names)
    mov       ecx, [esi]
    test      ecx, ecx
      jz      .NextDescriptor     ; If there's no ILT
    add       ecx, [hModule]
    mov       [pILT], ecx

    ; Offset 16: IAT
    mov       edx, [esi + 16]
    add       edx, [hModule]
    mov       [pIAT], edx

.ThunkLoop:
    mov       ecx, [pILT]
    mov       eax, [ecx]          ; Read ILT element
    test      eax, eax
      jz      .NextDescriptor     ; If 0 - it's end

    ; Check for function without name
    test      eax, 80000000h
      jnz     .NextThunk

    ; Import by name
    add       eax, [hModule]
    add       eax, 2              ; Skip 2 bytes of HINT

    ; Copy name of the function
    lea       edi, [szBuffer]
.CopyName:
    mov       cl, byte [eax]
    mov       byte [edi], cl
    inc       eax
    inc       edi
    test      cl, cl
      jnz     .CopyName

    ; Check for last char: if A - process function
    ; if no - skip
    cmp       byte [edi - 2], 'A'
      jne     .NextThunk

    ; Change A to W
    mov       byte [edi - 2], 'W'

    ; Find W addr
    cmp       [isNativeNT], 1
      je      .ResolveNative

.ResolveUnicows:
    lea       ecx, [szBuffer]
    invoke    GetProcAddress, [hUnicows], ecx
    jmp       .CheckAddress

.ResolveNative:
    lea       ecx, [szBuffer]
    invoke    GetProcAddress, [hCurrentMod], ecx

.CheckAddress:
    test      eax, eax
      jz      .NextThunk          ; If there's no W function - skip it

    ; Change addr
    mov       edx, [pIAT]
    mov       [edx], eax

.NextThunk:
    add       dword [pILT], 4
    add       dword [pIAT], 4
    jmp       .ThunkLoop

.NextDescriptor:
    add       esi, 20             ; sizeof(IMAGE_IMPORT_DESCRIPTOR)
    jmp       .DescriptorLoop

.End:
    ret
endp

; DWORD Unicode.UTFEnglishToASCII(LPCWSTR lpszSrcUtf16, LPSTR lpDstAnsi);
proc Unicode.UTFEnglishToASCII stdcall uses ecx edx esi edi,\
     lpszSrcUtf16:DWORD, lpDstAnsi:DWORD
    mov       esi, [lpszSrcUtf16]
    mov       edi, [lpDstAnsi]
    xor       ecx, ecx

    test      esi, esi
      jz      .Done
    test      edi, edi
      jz      .Done

.Loop:
    movzx     eax, word [esi]
    add       esi, 2
    test      ax, ax
      jz      .Term

    ; Check for English / Latin / 7-bit ASCII
    cmp       ax, 0x80
      jb      .WriteByte

    ; Check for Cyrillic (U+0410 .. U+044F)
    cmp       ax, 0x0410
      jb      .CheckSpecialOne
    cmp       ax, 0x044F
      ja      .CheckSpecialOne
    sub       ax, 0x0350
    jmp       .WriteByte

.CheckSpecialOne:
    cmp       ax, 0x0401          ; '¨'
      jne     @F
    mov       al, 0xA8
    jmp       .WriteByte
@@:
    cmp       ax, 0x0451          ; '¸'
      jne     .WriteByte
    mov       al, 0xB8

.WriteByte:
    mov       byte [edi], al
    inc       edi
    inc       ecx
    jmp       .Loop

.Term:
    mov       byte [edi], 0

.Done:
    mov       eax, ecx
    ret
endp