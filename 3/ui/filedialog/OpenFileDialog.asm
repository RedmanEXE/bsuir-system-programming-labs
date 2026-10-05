; BOOL OpenFileDialog.Show(HWND hWndParent, LPWSTR lpszFilter, LPWSTR lpszFilePathBuf, DWORD dwFilePathBufLen);
proc OpenFileDialog.Show stdcall uses ecx edx edi,\
     hWndParent:DWORD, lpszFilter:DWORD, lpszFilePath:DWORD, dwFilePathBufLen:DWORD
    locals
        .ofn            OPENFILENAME
    endl

    ; Cleanup memory
    lea       edi, [.ofn]
    mov       ecx, sizeof.OPENFILENAME / 4
    xor       eax, eax
    cld
      rep stosd

    ; Fill OFN structure
    mov       [.ofn.lStructSize], OPENFILENAME_SIZE_VERSION_400

    mov       eax, [hWndParent]
    mov       [.ofn.hwndOwner], eax

    mov       eax, [lpszFilter]
    mov       [.ofn.lpstrFilter], eax

    mov       eax, [lpszFilePath]
    mov       [.ofn.lpstrFile], eax
    mov       word [eax], 0

    mov       eax, [dwFilePathBufLen]
    mov       [.ofn.nMaxFile], eax

    ; Flags
    mov       [.ofn.Flags], OFN_EXPLORER or OFN_ALLOWMULTISELECT or\
                            OFN_FILEMUSTEXIST or OFN_PATHMUSTEXIST or\
                            OFN_HIDEREADONLY or OFN_NOCHANGEDIR

    ; Open dialog
    lea       eax, [.ofn]
    invoke    GetOpenFileName, eax

    ret
endp

; VOID OpenFileDialog.SubmitFiles(LPWSTR lpszBuffer);
proc OpenFileDialog.SubmitFiles stdcall uses ecx edx ebx esi edi,\
     lpszBuffer:DWORD
    locals
        .szFullPath     rw 260
    endl
    mov       esi, [lpszBuffer]
    test      esi, esi
      jz      .End
    ; Check if buffer is empty
    cmp       word [esi], 0
      je      .End
    ; Find length of the first string (count of WCHARs)
    xor       ecx, ecx
.CountFirstString:
    cmp       word [esi + ecx * 2], 0
      je      .FirstStringDone
    inc       ecx
    cmp       ecx, 260
      jae     .SingleFile              ; Safety bound
    jmp       .CountFirstString
.FirstStringDone:
    test      ecx, ecx
      jz      .End
    ; Check character immediately following the first null terminator:
    ; If it is 0, a single file was selected.
    cmp       word [esi + ecx * 2 + 2], 0
      je      .SingleFile
    ; Otherwise, multiple files were selected:
    ; [esi] = directory string of length ecx WCHARs
    ; [ebx] = pointer to the first file name
    lea       ebx, [esi + ecx * 2 + 2]
.MultiLoop:
    cmp       word [ebx], 0            ; Double null indicates end of list
      je      .End

    ; Construct full path: directory + '\' (if missing) + filename
    lea       edi, [.szFullPath]
    ; 1. Copy directory
    push      esi
    push      ecx
    cld
    rep       movsw
    pop       ecx
    pop       esi
    ; 2. Append backslash if directory does not already end with '\'
    cmp       word [esi + ecx * 2 - 2], '\'
      je      .AfterSlash
    mov       word [edi], '\'
    add       edi, 2
.AfterSlash:
    ; 3. Append filename from ebx until null terminator
    mov       edx, ebx
.CopyFileName:
    mov       ax, word [edx]
    mov       word [edi], ax
    add       edx, 2
    add       edi, 2
    test      ax, ax
      jnz     .CopyFileName
    ; edx now points past the null terminator of current filename
    mov       ebx, edx
    ; 4. Submit constructed full path to pipeline
    lea       eax, [.szFullPath]
    stdcall   Pipeline.SubmitFile, eax
    jmp       .MultiLoop
.SingleFile:
    ; lpszBuffer contains the single complete file path
    stdcall   Pipeline.SubmitFile, esi
.End:
    ret
endp
