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
    mov       [.ofn.Flags], OFN_EXPLORER or OFN_FILEMUSTEXIST or OFN_PATHMUSTEXIST or\
                            OFN_HIDEREADONLY or OFN_NOCHANGEDIR

    ; Open dialog
    lea       eax, [.ofn]
    invoke    GetOpenFileName, eax

    ret
endp