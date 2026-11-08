; BOOL SaveFileDialog.Show(HWND hWndParent, LPWSTR lpszFilter, LPWSTR lpszFilePathBuf, DWORD dwFilePathBufLen);
proc SaveFileDialog.Show stdcall uses ecx edx edi,\
     hWndParent:DWORD, lpszFilter:DWORD, lpszFilePath:DWORD, dwFilePathBufLen:DWORD
    locals
        .ofnSave        OPENFILENAME
    endl

    ; Cleanup memory
    lea       edi, [.ofnSave]
    mov       ecx, sizeof.OPENFILENAME / 4
    xor       eax, eax
    cld
      rep stosd

    ; Fill OFN structure
    mov       [.ofnSave.lStructSize], OPENFILENAME_SIZE_VERSION_400

    mov       eax, [hWndParent]
    mov       [.ofnSave.hwndOwner], eax

    mov       eax, [lpszFilter]
    mov       [.ofnSave.lpstrFilter], eax

    mov       eax, [lpszFilePath]
    mov       [.ofnSave.lpstrFile], eax
    mov       word [eax], 0

    mov       eax, [dwFilePathBufLen]
    mov       [.ofnSave.nMaxFile], eax

    ; Flags
    mov       [.ofnSave.Flags], OFN_EXPLORER or OFN_PATHMUSTEXIST or\
                                OFN_HIDEREADONLY or OFN_OVERWRITEPROMPT or OFN_NOCHANGEDIR

    ; Set default file extension
    mov       [.ofnSave.lpstrDefExt], szBmpDefExt

    ; Open dialog
    lea       eax, [.ofnSave]
    invoke    GetSaveFileName, eax

    ret
endp
