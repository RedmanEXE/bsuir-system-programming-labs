; BOOL UAC.IsLaunchedAsAdmin(VOID);
proc UAC.IsLaunchedAsAdmin stdcall uses ecx edx ebx esi edi
    locals
        .bIsAdmin           rd 1
        .hAdvapi            rd 1
        .pfnOpenProcToken   rd 1
        .pfnGetTokenInfo    rd 1
        .hToken             rd 1
        .dwElevation        rd 1
        .cbReturn           rd 1
    endl

    ; Default to 0 on modern OS
    ; Default to 1 on old OSes (Win95..XP)
    mov       [.bIsAdmin], 0
    mov       [.hToken], 0

    ; Check OS version via GetVersion
    invoke    GetVersion
    and       eax, 0FFh                  ; AL = Major OS version
    cmp       eax, 6                     ; Vista = 6.0
      jb      .IsLegacyAdmin             ; If major < 6, UAC don't exists

    ; Windows Vista / 7 / 8 / 10 / 11+ or Wine
    ; Check if running under Wine:
    invoke    GetModuleHandle, szNtdllDllName
    test      eax, eax
      jz      .NotWine
    invoke    GetProcAddress, eax, szWineGetVersionName
    test      eax, eax
      jz      .NotWine
    ; Wine detected: Wine has no UAC, treat as admin
    mov       [.bIsAdmin], 1
    jmp       .Done

.NotWine:
    ; Native Windows Vista+: Check TokenElevation via advapi32.dll
    invoke    LoadLibrary, szAdvapi32DllName
    test      eax, eax
      jz      .Done
    mov       [.hAdvapi], eax

    invoke    GetProcAddress, [.hAdvapi], szOpenProcessTokenName
    test      eax, eax
      jz      .CleanupAdvapi
    mov       [.pfnOpenProcToken], eax

    invoke    GetProcAddress, [.hAdvapi], szGetTokenInfoName
    test      eax, eax
      jz      .CleanupAdvapi
    mov       [.pfnGetTokenInfo], eax

    ; Open process token: OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &.hToken)
    invoke    GetCurrentProcess
    lea       edx, [.hToken]
    push      edx
    push      TOKEN_QUERY
    push      eax
    call      [.pfnOpenProcToken]
    test      eax, eax
      jz      .CleanupAdvapi

    ; Query elevation status:
    ; GetTokenInformation([.hToken], TokenElevation (20), &.dwElevation, sizeof(DWORD), &.cbReturn)
    mov       [.dwElevation], 0
    lea       eax, [.cbReturn]
    push      eax
    push      4
    lea       eax, [.dwElevation]
    push      eax
    push      TokenElevation
    push      [.hToken]
    call      [.pfnGetTokenInfo]
    test      eax, eax
      jz      .CloseTokenHandle

    ; If dwElevation != 0, the token is elevated!
    cmp       [.dwElevation], 0
      je      .CloseTokenHandle
    mov       [.bIsAdmin], 1

.CloseTokenHandle:
    cmp       [.hToken], 0
      je      .CleanupAdvapi
    invoke    CloseHandle, [.hToken]

.CleanupAdvapi:
    invoke    FreeLibrary, [.hAdvapi]
    jmp       .Done

.IsLegacyAdmin:
    mov       [.bIsAdmin], 1

.Done:
    mov       eax, [.bIsAdmin]
    ret
endp

; BOOL UAC.RelaunchInAdmin(HWND hWnd);
proc UAC.RelaunchInAdmin stdcall uses ecx edx ebx esi edi,\
     hWnd:DWORD
    locals
        .szExePath      rw MAX_PATH + 4
        .szDir          rw MAX_PATH + 4
        .bSuccess       rd 1
    endl

    mov       [.bSuccess], 0

    ; Retrieve path to current executable (UTF-16 GetModuleFileNameW)
    lea       eax, [.szExePath]
    invoke    GetModuleFileName, NULL, eax, MAX_PATH
    test      eax, eax
      jz      .Done

    ; Copy UTF-16 path to .szDir and strip filename to get working directory
    lea       esi, [.szExePath]
    lea       edi, [.szDir]
.CopyDirLoop:
    lodsw
    stosw
    test      ax, ax
      jnz     .CopyDirLoop

    ; Find last backslash '\' in UTF-16 .szDir
    lea       edi, [.szDir]
    xor       edx, edx                  ; edx = pointer to last '\'
.FindSlashLoop:
    mov       ax, word [edi]
    test      ax, ax
      jz      .SlashFound
    cmp       ax, '\'
      jne     @F
    mov       edx, edi
@@:
    add       edi, 2
    jmp       .FindSlashLoop

.SlashFound:
    test      edx, edx
      jz      .NoSlash
    mov       word [edx], 0             ; Null-terminate at last '\'
    jmp       .DoLaunch

.NoSlash:
    lea       edx, [.szDir]
    mov       word [edx], 0

.DoLaunch:
    ; Launch with 'runas' verb, [hWnd] parent, and explicit working directory
    lea       edx, [.szDir]
    cmp       word [edx], 0
      jne     @F
    xor       edx, edx
@@:
    lea       eax, [.szExePath]
    invoke    ShellExecute, [hWnd], szRunAsVerb, eax, NULL, edx, SW_SHOWNORMAL
    cmp       eax, 32
      jbe     .Done                     ; <= 32 means error or user cancelled prompt

    mov       [.bSuccess], 1

    ; Close current window gracefully
    mov       eax, [hWnd]
    test      eax, eax
      jz      .DirectExit
    invoke    PostMessage, eax, WM_CLOSE, 0, 0
    jmp       .Done

.DirectExit:
    invoke    ExitProcess, 0

.Done:
    mov       eax, [.bSuccess]
    ret
endp