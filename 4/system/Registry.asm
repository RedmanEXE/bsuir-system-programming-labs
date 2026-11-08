; VOID Registry.FormatType(DWORD dwType, LPWSTR lpszDst);
proc Registry.FormatType stdcall uses eax edx,\
     dwType:DWORD, lpszDst:DWORD
    mov       eax, [dwType]
    mov       edx, szTypeRegNoneText
    cmp       eax, REG_SZ
      je      .IsSz
    cmp       eax, REG_DWORD
      je      .IsDword
    cmp       eax, REG_BINARY
      je      .IsBinary
    cmp       eax, REG_EXPAND_SZ
      je      .IsExpandSz
    cmp       eax, REG_MULTI_SZ
      je      .IsMultiSz
    cmp       eax, REG_QWORD
      je      .IsQword
    jmp       .Copy

.IsSz:
    mov       edx, szTypeRegSzText
    jmp       .Copy
.IsDword:
    mov       edx, szTypeRegDwordText
    jmp       .Copy
.IsBinary:
    mov       edx, szTypeRegBinaryText
    jmp       .Copy
.IsExpandSz:
    mov       edx, szTypeRegExpandSzText
    jmp       .Copy
.IsMultiSz:
    mov       edx, szTypeRegMultiSzText
    jmp       .Copy
.IsQword:
    mov       edx, szTypeRegQwordText

.Copy:
    stdcall   String.StringCopy, [lpszDst], edx

.Done:
    ret
endp

; VOID Registry.FormatData(DWORD dwType, LPVOID lpData, DWORD cbData, LPWSTR lpszDst, DWORD cchMax);
proc Registry.FormatData stdcall uses ecx edx,\
     dwType:DWORD, lpData:DWORD, cbData:DWORD, lpszDst:DWORD, cchMax:DWORD
    mov       ecx, [cbData]
    mov       edx, [lpData]
    mov       eax, [dwType]

    test      ecx, ecx
      jz      .EmptyData

    cmp       eax, REG_SZ
      je      .CopyDirectString
    cmp       eax, REG_EXPAND_SZ
      je      .CopyDirectString

    cmp       eax, REG_DWORD
      je      .FormatDwordValue

    cmp       eax, REG_BINARY
      je      .FormatBinaryValue

    cmp       eax, REG_MULTI_SZ
      je      .FormatMultiSzValue

    ; Default: show as binary bytes
    stdcall   String.FormatBinary, edx, ecx, [lpszDst], [cchMax]
    jmp       .Done

.CopyDirectString:
    stdcall   String.StringCopy, [lpszDst], edx
    jmp       .Done

.FormatDwordValue:
    mov       eax, [edx]
    stdcall   String.FormatDword, eax, [lpszDst]
    jmp       .Done

.FormatBinaryValue:
    stdcall   String.FormatBinary, edx, ecx, [lpszDst], [cchMax]
    jmp       .Done

.FormatMultiSzValue:
    stdcall   String.DisplayMultiSz, edx, ecx, [lpszDst], [cchMax]
    jmp       .Done

.EmptyData:
    cmp       eax, REG_SZ
      je      .EmptyString
    cmp       eax, REG_EXPAND_SZ
      je      .EmptyString
    stdcall   String.StringCopy, [lpszDst], szEmptyBinaryText
    jmp       .Done

.EmptyString:
    mov       eax, [lpszDst]
    mov       word [eax], 0

.Done:
    ret
endp

; BOOL Registry.GetItemPath(HWND hTreeView, HTREEITEM hItem, LPWSTR lpszPathBuf,\
;                           DWORD cchMax, LPDWORD lphRootKeyOut);
proc Registry.GetItemPath stdcall uses ecx edx ebx esi edi,\
     hTreeView:DWORD, hItem:DWORD, lpszPathBuf:DWORD, cchMax:DWORD, lphRootKeyOut:DWORD
    locals
        .hNodes         rd 64
        .tvi            TVITEM
        .szNodeText     rw 260
    endl

    ; Clear output
    mov       eax, [lphRootKeyOut]
    mov       dword [eax], 0
    mov       eax, [lpszPathBuf]
    mov       word [eax], 0

    mov       edi, [hItem]
    test      edi, edi
      jz      .Failed

    ; If item is "My computer" root, no registry path exists
    cmp       edi, [hRootComputer]
      je      .Failed

    ; Build string up to "My computer"
    xor       esi, esi                  ; count
.WalkUpLoop:
    test      edi, edi
      jz      .DoneWalk
    cmp       edi, [hRootComputer]
      je      .DoneWalk

    mov       [.hNodes + esi * 4], edi
    inc       esi
    cmp       esi, 64
      jae     .DoneWalk

    invoke    SendMessage, [hTreeView], TVM_GETNEXTITEM, TVGN_PARENT, edi
    mov       edi, eax
    jmp       .WalkUpLoop

.DoneWalk:
    test      esi, esi
      jz      .Failed

    ; Root node in this chain
    mov       ebx, [.hNodes + esi * 4 - 4]

    ; Query lParam, that holds key
    mov       [.tvi.mask], TVIF_HANDLE or TVIF_PARAM
    mov       [.tvi.hItem], ebx
    lea       eax, [.tvi]
    invoke    SendMessage, [hTreeView], TVM_GETITEMW, 0, eax

    mov       eax, [.tvi.lParam]
    test      eax, eax
      jz      .Failed

    mov       edx, [lphRootKeyOut]
    mov       [edx], eax

    ; Reconstruct key path
    ; If count == 1, subpath is empty ("")
    dec       esi                       ; skip itself
    test      esi, esi
      jz      .Success

    mov       ebx, [lpszPathBuf]
    mov       word [ebx], 0

.ConcatLoop:
    dec       esi
    mov       edi, [.hNodes + esi * 4]

    ; If not first path segment, append "\"
    cmp       word [ebx], 0
      je      .GetText
    stdcall   String.StringCat, ebx, szBackslash

.GetText:
    lea       eax, [.szNodeText]
    mov       word [.szNodeText], 0
    mov       [.tvi.mask], TVIF_HANDLE or TVIF_TEXT
    mov       [.tvi.hItem], edi
    mov       [.tvi.pszText], eax
    mov       [.tvi.cchTextMax], 260
    lea       eax, [.tvi]
    invoke    SendMessage, [hTreeView], TVM_GETITEMW, 0, eax

    lea       eax, [.szNodeText]
    stdcall   String.StringCat, ebx, eax

    test      esi, esi
      jnz     .ConcatLoop

.Success:
    mov       eax, 1
    jmp       .Done

.Failed:
    xor       eax, eax

.Done:
    ret
endp

; BOOL Registry.ExpandKey(HWND hTreeView, HTREEITEM hItem);
proc Registry.ExpandKey stdcall uses ecx edx ebx esi edi,\
     hTreeView:DWORD, hItem:DWORD
    locals
        .hRootKey       rd 1
        .hKey           rd 1
        .bNeedClose     rd 1
        .hSubChildKey   rd 1
        .cSubKeys       rd 1
        .dwNameLen      rd 1
        .iImgClosed     rd 1
        .iImgOpen       rd 1
        .nResult        rd 1
        .szSubPath      rw 1024
        .szSubKeyName   rw 260
    endl

    mov       [.nResult], 0

    ; Check for already created
    invoke    SendMessage, [hTreeView], TVM_GETNEXTITEM, TVGN_CHILD, [hItem]
    test      eax, eax
      jnz     .AlreadyHasChildren

    ; Get root path
    lea       eax, [.szSubPath]
    lea       edx, [.hRootKey]
    stdcall   Registry.GetItemPath, [hTreeView], [hItem], eax, 1024, edx
    test      eax, eax
      jz      .Done

    mov       eax, [.hRootKey]
    test      eax, eax
      jz      .Done

    mov       [.bNeedClose], 0
    lea       esi, [.szSubPath]
    cmp       word [esi], 0
      je      .UseRootKey

    ; Open registry key with read permission
    lea       edx, [.hKey]
    invoke    RegOpenKeyEx, [.hRootKey], esi, 0, KEY_READ, edx
    test      eax, eax
      jnz     .Done
    mov       [.bNeedClose], 1
    jmp       .StartEnum

.UseRootKey:
    mov       eax, [.hRootKey]
    mov       [.hKey], eax

.StartEnum:
    ; Get all keys
    xor       esi, esi                  ; dwIndex
.EnumLoop:
    mov       [.dwNameLen], 260
    lea       eax, [.szSubKeyName]
    lea       ecx, [.dwNameLen]
    invoke    RegEnumKeyEx, [.hKey], esi, eax, ecx, NULL, NULL, NULL, NULL
    test      eax, eax
      jnz     .EnumFinished

    ; Check if this child has children
    xor       ebx, ebx                  ; cChildren
    lea       eax, [.szSubKeyName]
    lea       edx, [.hSubChildKey]
    invoke    RegOpenKeyEx, [.hKey], eax, 0, KEY_READ, edx
    test      eax, eax
      jnz     .InsertChildNode

    lea       eax, [.cSubKeys]
    invoke    RegQueryInfoKey, [.hSubChildKey], NULL, NULL, NULL, eax,\
              NULL, NULL, NULL, NULL, NULL, NULL, NULL
    cmp       [.cSubKeys], 0
      jle     .CloseChildProbe
    ; has children -> show [+] button
    mov       ebx, 1

.CloseChildProbe:
    invoke    RegCloseKey, [.hSubChildKey]

.InsertChildNode:
    ; Check if this subkey is writable via Registry.IsKeyWritable
    mov       [.iImgClosed], 1
    mov       [.iImgOpen], 2
    lea       eax, [.szSubKeyName]
    stdcall   Registry.IsKeyWritable, [.hKey], eax
    test      eax, eax
      jnz     .DoInsertChild

    ; Read-only key: gray icons (3: closed gray, 4: open gray)
    mov       [.iImgClosed], 3
    mov       [.iImgOpen], 4

.DoInsertChild:
    lea       eax, [.szSubKeyName]
    stdcall   TreeView.InsertItem, [hTreeView], [hItem], TVI_LAST,\
              eax, [.iImgClosed], [.iImgOpen], ebx, 0

    inc       esi
    jmp       .EnumLoop

.EnumFinished:
    cmp       [.bNeedClose], 0
      je      @F
    invoke    RegCloseKey, [.hKey]
@@:
    mov       [.nResult], 1
    jmp       .Done

.AlreadyHasChildren:
    mov       [.nResult], 1

.Done:
    mov       eax, [.nResult]
    ret
endp

; BOOL Registry.LoadValues(HWND hListView, HWND hTreeView, HTREEITEM hItem);
proc Registry.LoadValues stdcall uses ecx edx ebx esi edi,\
     hListView:DWORD, hTreeView:DWORD, hItem:DWORD
    locals
        .hRootKey       rd 1
        .hKey           rd 1
        .bNeedClose     rd 1
        .dwType         rd 1
        .dwValNameLen   rd 1
        .dwDataLen      rd 1
        .bHasDefault    rd 1
        .nItemIndex     rd 1
        .szSubPath      rw 1024
        .szValName      rw 260
        .szTypeStr      rw 64
        .szFormattedData rw 1024
        .bDataBuf       rb 4096
    endl

    ; Clear ListView
    stdcall   ListView.DeleteAllItems, [hListView]

    ; Get path
    lea       eax, [.szSubPath]
    lea       edx, [.hRootKey]
    stdcall   Registry.GetItemPath, [hTreeView], [hItem], eax, 1024, edx
    test      eax, eax
      jz      .Done

    mov       eax, [.hRootKey]
    test      eax, eax
      jz      .Done

    mov       [.bNeedClose], 0
    lea       esi, [.szSubPath]
    cmp       word [esi], 0
      jne     .OpenQueryKey
    xor       esi, esi

.OpenQueryKey:
    ; Open key to get value
    lea       edx, [.hKey]
    invoke    RegOpenKeyEx, [.hRootKey], esi, 0, KEY_QUERY_VALUE, edx
    test      eax, eax
      jz      .KeyQueryOpened

    ; If RegOpenKeyEx with NULL failed -> use root handle
    lea       esi, [.szSubPath]
    cmp       word [esi], 0
      jne     .InsertDefaultPlaceholder
    mov       eax, [.hRootKey]
    mov       [.hKey], eax
    jmp       .StartEnum

.KeyQueryOpened:
    mov       [.bNeedClose], 1

.StartEnum:
    mov       [.bHasDefault], 0
    xor       esi, esi                  ; dwIndex

.EnumValuesLoop:
    mov       [.dwValNameLen], 260
    mov       [.dwDataLen], 4096
    lea       eax, [.szValName]
    lea       ecx, [.dwValNameLen]
    lea       edx, [.dwType]
    lea       ebx, [.bDataBuf]
    lea       edi, [.dwDataLen]
    invoke    RegEnumValue, [.hKey], esi, eax, ecx, NULL, edx, ebx, edi
    test      eax, eax
      jnz     .EnumValuesFinished

    ; If it is default value -> return "(Default)" text
    cmp       word [.szValName], 0
      jne     .NamedValue
    mov       [.bHasDefault], 1
    mov       edi, szValDefaultNameText
    jmp       .FormatAndInsert

.NamedValue:
    lea       edi, [.szValName]

.FormatAndInsert:
    ; Format Type string
    lea       eax, [.szTypeStr]
    stdcall   Registry.FormatType, [.dwType], eax

    ; Format Data string
    lea       eax, [.bDataBuf]
    lea       edx, [.szFormattedData]
    stdcall   Registry.FormatData, [.dwType], eax, [.dwDataLen], edx, 1024

    ; Insert row into ListView
    stdcall   ListView.InsertItem, [hListView], esi, edi, -1, [.dwType]
    mov       [.nItemIndex], eax

    lea       eax, [.szTypeStr]
    stdcall   ListView.SetItemText, [hListView], [.nItemIndex], 1, eax

    lea       eax, [.szFormattedData]
    stdcall   ListView.SetItemText, [hListView], [.nItemIndex], 2, eax

    inc       esi
    jmp       .EnumValuesLoop

.EnumValuesFinished:
    cmp       [.bNeedClose], 0
      je      @F
    invoke    RegCloseKey, [.hKey]
@@:

    ; If there's no default value -> insert classic placeholder
    cmp       [.bHasDefault], 0
      jne     .Success

.InsertDefaultPlaceholder:
    stdcall   ListView.InsertItem, [hListView], 0, szValDefaultNameText, -1, 0
    mov       [.nItemIndex], eax

    lea       eax, [szValNotSetText]
    stdcall   ListView.SetItemText, [hListView], [.nItemIndex], 2, eax

.Success:
    mov       eax, 1
    jmp       .Done

.Failed:
    xor       eax, eax

.Done:
    ret
endp

; LRESULT Registry.CreateKey(HKEY hRootKey, LPWSTR lpszSubKey, LPWSTR lpszNewKeyName);
proc Registry.CreateKey stdcall uses ecx edx ebx esi edi,\
     hRootKey:DWORD, lpszSubKey:DWORD, lpszNewKeyName:DWORD
    locals
        .hNewKey        rd 1
        .dwDisp         rd 1
        .szCombined     rw 1024
    endl

    ; Combine parent subkey with new key name
    lea       edi, [.szCombined]
    mov       esi, [lpszSubKey]

    test      esi, esi
      jz      .OnlyNewName
    cmp       word [esi], 0
      je      .OnlyNewName

    stdcall   String.StringCopy, edi, esi
    stdcall   String.StringCat, edi, szBackslash
    stdcall   String.StringCat, edi, [lpszNewKeyName]
    jmp       .DoCreate

.OnlyNewName:
    stdcall   String.StringCopy, edi, [lpszNewKeyName]

.DoCreate:
    lea       eax, [.hNewKey]
    lea       edx, [.dwDisp]
    invoke    RegCreateKeyEx, [hRootKey], edi, 0, NULL, REG_OPTION_NON_VOLATILE,\
              KEY_ALL_ACCESS, NULL, eax, edx
    test      eax, eax
      jnz     .Done

    mov       ebx, eax
    invoke    RegCloseKey, [.hNewKey]
    mov       eax, ebx

.Done:
    ret
endp

; LRESULT Registry.DeleteKeyRecursive(HKEY hRootKey, LPWSTR lpszSubKey);
proc Registry.DeleteKeyRecursive stdcall uses ecx edx ebx esi edi,\
     hRootKey:DWORD, lpszSubKey:DWORD
    locals
        .hCurKey        rd 1
        .dwNameLen      rd 1
        .szChildName    rw 260
    endl

    ; Open key to delete sub-keys
    lea       eax, [.hCurKey]
    invoke    RegOpenKeyEx, [hRootKey], [lpszSubKey], 0, KEY_READ or KEY_WRITE, eax
    test      eax, eax
      jnz     .AttemptDirectDelete

    ; Recursively delete all childrens
.DeleteChildrenLoop:
    mov       [.dwNameLen], 260
    lea       eax, [.szChildName]
    lea       ecx, [.dwNameLen]
    invoke    RegEnumKeyEx, [.hCurKey], 0, eax, ecx, NULL, NULL, NULL, NULL
    test      eax, eax
      jnz     .AllChildrenDeleted

    lea       eax, [.szChildName]
    stdcall   Registry.DeleteKeyRecursive, [.hCurKey], eax
    jmp       .DeleteChildrenLoop

.AllChildrenDeleted:
    invoke    RegCloseKey, [.hCurKey]

.AttemptDirectDelete:
    invoke    RegDeleteKey, [hRootKey], [lpszSubKey]
    ret
endp

; LRESULT Registry.SetValue(HKEY hRootKey, LPWSTR lpszSubKey, LPWSTR lpszValName,
;                           DWORD dwType, LPVOID lpData, DWORD cbData);
proc Registry.SetValue stdcall uses ecx edx ebx esi edi,\
     hRootKey:DWORD, lpszSubKey:DWORD, lpszValName:DWORD,\
     dwType:DWORD, lpData:DWORD, cbData:DWORD
    locals
        .hKey           rd 1
        .bNeedClose     rd 1
        .dwDisp         rd 1
    endl

    mov       [.bNeedClose], 0
    mov       esi, [lpszSubKey]
    test      esi, esi
      jz      .SubKeyEmpty
    cmp       word [esi], 0
      jne     .OpenSubKey

.SubKeyEmpty:
    xor       esi, esi

.OpenSubKey:
    ; Attempts
    ; 1. Try RegOpenKeyEx with KEY_READ or KEY_WRITE
    lea       eax, [.hKey]
    invoke    RegOpenKeyEx, [hRootKey], esi, 0, KEY_READ or KEY_WRITE, eax
    test      eax, eax
      jz      .KeyOpened

    ; 2. Try RegOpenKeyEx with KEY_WRITE
    lea       eax, [.hKey]
    invoke    RegOpenKeyEx, [hRootKey], esi, 0, KEY_WRITE, eax
    test      eax, eax
      jz      .KeyOpened

    ; 3. Try RegOpenKeyEx with KEY_SET_VALUE
    lea       eax, [.hKey]
    invoke    RegOpenKeyEx, [hRootKey], esi, 0, KEY_SET_VALUE, eax
    test      eax, eax
      jz      .KeyOpened

    ; 4. Try RegCreateKeyEx
    test      esi, esi
      jz      .TryRootFallback

    lea       eax, [.hKey]
    lea       edx, [.dwDisp]
    invoke    RegCreateKeyEx, [hRootKey], esi, 0, NULL, REG_OPTION_NON_VOLATILE,\
              KEY_READ or KEY_WRITE, NULL, eax, edx
    test      eax, eax
      jz      .KeyOpened

    lea       eax, [.hKey]
    lea       edx, [.dwDisp]
    invoke    RegCreateKeyEx, [hRootKey], esi, 0, NULL, REG_OPTION_NON_VOLATILE,\
              KEY_WRITE, NULL, eax, edx
    test      eax, eax
      jz      .KeyOpened

    lea       eax, [.hKey]
    lea       edx, [.dwDisp]
    invoke    RegCreateKeyEx, [hRootKey], esi, 0, NULL, REG_OPTION_NON_VOLATILE,\
              KEY_SET_VALUE, NULL, eax, edx
    test      eax, eax
      jz      .KeyOpened
    jmp       .Done

.TryRootFallback:
    ; If fail, use handle directly
    mov       eax, [hRootKey]
    mov       [.hKey], eax
    mov       [.bNeedClose], 0
    jmp       .WriteValue

.KeyOpened:
    mov       [.bNeedClose], 1

.WriteValue:
    ; If lpszValName is empty or equals "(Default)" -> pass NULL
    mov       edx, [lpszValName]
    test      edx, edx
      jz      .NullValName
    cmp       word [edx], 0
      je      .NullValName
    jmp       .DoSet

.NullValName:
    xor       edx, edx

.DoSet:
    invoke    RegSetValueEx, [.hKey], edx, 0, [dwType], [lpData], [cbData]
    mov       ebx, eax

    cmp       [.bNeedClose], 0
      je      @F
    invoke    RegCloseKey, [.hKey]
@@:
    mov       eax, ebx

.Done:
    ret
endp

; LRESULT Registry.SetStringValue(HKEY hRootKey, LPWSTR lpszSubKey, LPWSTR lpszValName,
;                                 LPWSTR lpszString, DWORD dwType);
proc Registry.SetStringValue stdcall uses ecx edx esi,\
     hRootKey:DWORD, lpszSubKey:DWORD, lpszValName:DWORD,\
     lpszString:DWORD, dwType:DWORD
    locals
        .emptyStr       rw 1
    endl

    mov       esi, [lpszString]
    test      esi, esi
      jnz     @F
    mov       word [.emptyStr], 0
    lea       esi, [.emptyStr]
@@:
    stdcall   String.StringLen, esi
    lea       ecx, [eax * 2 + 2]        ; cbData
    stdcall   Registry.SetValue, [hRootKey], [lpszSubKey], [lpszValName], [dwType], esi, ecx
    ret
endp

; LRESULT Registry.SetDwordValue(HKEY hRootKey, LPWSTR lpszSubKey, LPWSTR lpszValName, DWORD dwValue);
proc Registry.SetDwordValue stdcall uses ecx edx,     hRootKey:DWORD, lpszSubKey:DWORD, lpszValName:DWORD, dwValue:DWORD
    lea       eax, [dwValue]
    stdcall   Registry.SetValue, [hRootKey], [lpszSubKey], [lpszValName], REG_DWORD, eax, 4
    ret
endp

; LRESULT Registry.SetBinaryValue(HKEY hRootKey, LPWSTR lpszSubKey, LPWSTR lpszValName,
;                                 LPVOID lpData, DWORD cbData);
proc Registry.SetBinaryValue stdcall uses ecx edx,\
     hRootKey:DWORD, lpszSubKey:DWORD, lpszValName:DWORD,\
     lpData:DWORD, cbData:DWORD
    stdcall   Registry.SetValue, [hRootKey], [lpszSubKey], [lpszValName], REG_BINARY, [lpData], [cbData]
    ret
endp

; LRESULT Registry.DeleteValue(HKEY hRootKey, LPWSTR lpszSubKey, LPWSTR lpszValName);
proc Registry.DeleteValue stdcall uses ecx edx ebx esi edi,\
     hRootKey:DWORD, lpszSubKey:DWORD, lpszValName:DWORD
    locals
        .hKey           rd 1
        .bNeedClose     rd 1
    endl

    mov       [.bNeedClose], 0
    mov       esi, [lpszSubKey]
    test      esi, esi
      jz      .SubKeyEmpty
    cmp       word [esi], 0
      jne     .OpenSubKey

.SubKeyEmpty:
    xor       esi, esi

.OpenSubKey:
    lea       eax, [.hKey]
    invoke    RegOpenKeyEx, [hRootKey], esi, 0, KEY_READ or KEY_WRITE, eax
    test      eax, eax
      jz      .KeyOpened

    lea       eax, [.hKey]
    invoke    RegOpenKeyEx, [hRootKey], esi, 0, KEY_WRITE, eax
    test      eax, eax
      jz      .KeyOpened

    lea       eax, [.hKey]
    invoke    RegOpenKeyEx, [hRootKey], esi, 0, KEY_SET_VALUE, eax
    test      eax, eax
      jz      .KeyOpened

    test      esi, esi
      jnz     .Done

    mov       eax, [hRootKey]
    mov       [.hKey], eax
    mov       [.bNeedClose], 0
    jmp       .DeleteVal

.KeyOpened:
    mov       [.bNeedClose], 1

.DeleteVal:
    mov       edx, [lpszValName]
    test      edx, edx
      jz      .NullValName
    cmp       word [edx], 0
      je      .NullValName
    jmp       .DoDelete

.NullValName:
    xor       edx, edx

.DoDelete:
    invoke    RegDeleteValue, [.hKey], edx
    mov       ebx, eax

    cmp       [.bNeedClose], 0
      je      @F
    invoke    RegCloseKey, [.hKey]
@@:
    mov       eax, ebx

.Done:
    ret
endp

; LRESULT Registry.RenameKey(HKEY hRootKey, LPWSTR lpszParentSubKey,
;                            LPWSTR lpszOldName, LPWSTR lpszNewName);
proc Registry.RenameKey stdcall uses ecx edx ebx esi edi,\
     hRootKey:DWORD, lpszParentSubKey:DWORD, lpszOldName:DWORD, lpszNewName:DWORD
    locals
        .szOldFullPath  rw 1024
        .szNewFullPath  rw 1024
    endl

    ; Build old full path
    lea       edi, [.szOldFullPath]
    mov       esi, [lpszParentSubKey]
    test      esi, esi
      jz      .OldOnly

    cmp       word [esi], 0
      je      .OldOnly

    stdcall   String.StringCopy, edi, esi
    stdcall   String.StringCat, edi, szBackslash
    stdcall   String.StringCat, edi, [lpszOldName]
    jmp       .BuildNew

.OldOnly:
    stdcall   String.StringCopy, edi, [lpszOldName]

.BuildNew:
    lea       edi, [.szNewFullPath]
    mov       esi, [lpszParentSubKey]
    test      esi, esi
      jz      .NewOnly

    cmp       word [esi], 0
      je      .NewOnly

    stdcall   String.StringCopy, edi, esi
    stdcall   String.StringCat, edi, szBackslash
    stdcall   String.StringCat, edi, [lpszNewName]
    jmp       .DoCopyAndDelete

.NewOnly:
    stdcall   String.StringCopy, edi, [lpszNewName]

.DoCopyAndDelete:
    ; Create new destination key
    lea       eax, [.szNewFullPath]
    stdcall   Registry.CreateKey, [hRootKey], NULL, eax
    test      eax, eax
      jnz     .Done

    ; Delete old key
    lea       eax, [.szOldFullPath]
    stdcall   Registry.DeleteKeyRecursive, [hRootKey], eax

.Done:
    ret
endp

; BOOL Registry.IsKeyWritable(HKEY hRootKey, LPCWSTR lpszSubKey);
proc Registry.IsKeyWritable stdcall uses ecx edx ebx esi edi,\
     hRootKey:DWORD, lpszSubKey:DWORD
    locals
        .hKey           rd 1
        .bWritable      rd 1
    endl

    mov       [.bWritable], 0
    mov       esi, [lpszSubKey]
    test      esi, esi
      jz      .SubKeyEmpty

    cmp       word [esi], 0
      jne     .CheckOpen

.SubKeyEmpty:
    xor       esi, esi

.CheckOpen:
    lea       eax, [.hKey]
    invoke    RegOpenKeyEx, [hRootKey], esi, 0, KEY_SET_VALUE or KEY_CREATE_SUB_KEY, eax
    test      eax, eax
      jz      .Success

    ; If fail -> try KEY_SET_VALUE alone
    lea       eax, [.hKey]
    invoke    RegOpenKeyEx, [hRootKey], esi, 0, KEY_SET_VALUE, eax
    test      eax, eax
      jnz     .Done

.Success:
    mov       [.bWritable], 1
    invoke    RegCloseKey, [.hKey]

.Done:
    mov       eax, [.bWritable]
    ret
endp

; LPWSTR Registry.GetHiveName(HKEY hRootKey);
proc Registry.GetHiveName stdcall uses edx,\
     hRootKey:DWORD
    locals
        .lpHiveName     rd 1
    endl

    mov       [.lpHiveName], 0
    mov       eax, [hRootKey]
    cmp       eax, HKEY_CURRENT_USER
      je      .IsHkcu
    cmp       eax, HKEY_LOCAL_MACHINE
      je      .IsHklm
    cmp       eax, HKEY_CLASSES_ROOT
      je      .IsHkcr
    cmp       eax, HKEY_USERS
      je      .IsHku
    cmp       eax, HKEY_CURRENT_CONFIG
      je      .IsHkcc
    jmp       .Done

.IsHkcu:
    mov       [.lpHiveName], szHkcuText
    jmp       .Done
.IsHklm:
    mov       [.lpHiveName], szHklmText
    jmp       .Done
.IsHkcr:
    mov       [.lpHiveName], szHkcrText
    jmp       .Done
.IsHku:
    mov       [.lpHiveName], szHkuText
    jmp       .Done
.IsHkcc:
    mov       [.lpHiveName], szHkccText

.Done:
    mov       eax, [.lpHiveName]
    ret
endp

; DWORD Registry.ParseType(LPWSTR lpszTypeStr);
proc Registry.ParseType stdcall uses esi edi,\
     lpszTypeStr:DWORD

    mov       esi, [lpszTypeStr]
    test      esi, esi
      jz      .DefaultSz

    stdcall   String.Compare, esi, szTypeRegDwordText
    test      eax, eax
      jz      .IsDword

    stdcall   String.Compare, esi, szTypeRegBinaryText
    test      eax, eax
      jz      .IsBinary

    stdcall   String.Compare, esi, szTypeRegMultiSzText
    test      eax, eax
      jz      .IsMultiSz

    stdcall   String.Compare, esi, szTypeRegExpandSzText
    test      eax, eax
      jz      .IsExpandSz

    stdcall   String.Compare, esi, szTypeRegQwordText
    test      eax, eax
      jz      .IsQword

    stdcall   String.Compare, esi, szTypeRegSzText
    test      eax, eax
      jz      .IsSz

.DefaultSz:
    mov       eax, REG_SZ
    jmp       .Done

.IsDword:
    mov       eax, REG_DWORD
    jmp       .Done
.IsBinary:
    mov       eax, REG_BINARY
    jmp       .Done
.IsMultiSz:
    mov       eax, REG_MULTI_SZ
    jmp       .Done
.IsExpandSz:
    mov       eax, REG_EXPAND_SZ
    jmp       .Done
.IsQword:
    mov       eax, REG_QWORD
    jmp       .Done
.IsSz:
    mov       eax, REG_SZ

.Done:
    ret
endp

; VOID Registry.StartMonitorByKeyItem(HWND hTreeView, HTREEITEM hItem);
proc Registry.StartMonitorByKeyItem stdcall uses ecx edx ebx esi edi,\
     hTreeView:DWORD, hItem:DWORD
    locals
        .szPath         rw 1024
        .hRootKey       rd 1
        .dwThreadId     rd 1
    endl

    ; Stop existing monitor
    stdcall   Registry.StopMonitor

    ; If auto-refresh disabled -> do not start
    cmp       [bAutoRefreshEnabled], 0
      je      .Done

    mov       eax, [hItem]
    test      eax, eax
      jz      .Done
    cmp       eax, [hRootComputer]
      je      .Done

    lea       eax, [.szPath]
    lea       edx, [.hRootKey]
    stdcall   Registry.GetItemPath, [hTreeView], [hItem], eax, 1024, edx
    test      eax, eax
      jz      .Done

    lea       esi, [.szPath]
    cmp       word [esi], 0
      jne     @F
    xor       esi, esi
@@:
    lea       eax, [hMonitorKey]
    invoke    RegOpenKeyEx, [.hRootKey], esi, 0, KEY_NOTIFY or KEY_READ, eax
    test      eax, eax
      jnz     .Done

    mov       eax, [hItem]
    mov       [hMonitorItem], eax

    invoke    ResetEvent, [hMonitorStopEvent]

    lea       eax, [.dwThreadId]
    invoke    CreateThread, NULL, 0, Registry.MonitorThreadProc, NULL, 0, eax
    mov       [hMonitorThread], eax

.Done:
    ret
endp

; VOID Registry.StopMonitor(VOID);
proc Registry.StopMonitor stdcall uses ecx edx ebx esi edi
    cmp       [hMonitorStopEvent], 0
      je      .CloseThread

    invoke    SetEvent, [hMonitorStopEvent]

.CloseThread:
    cmp       [hMonitorThread], 0
      je      .CloseKey

    invoke    WaitForSingleObject, [hMonitorThread], 500
    invoke    CloseHandle, [hMonitorThread]
    mov       [hMonitorThread], 0

.CloseKey:
    cmp       [hMonitorKey], 0
      je      .ResetItem

    invoke    RegCloseKey, [hMonitorKey]
    mov       [hMonitorKey], 0

.ResetItem:
    mov       [hMonitorItem], 0
    ret
endp

; DWORD Registry.MonitorThreadProc(LPVOID lpParam);
proc Registry.MonitorThreadProc stdcall uses ecx edx ebx esi edi,\
     lpParam:DWORD
    locals
        .hEvents        rd 2
    endl

    mov       eax, [hMonitorStopEvent]
    mov       [.hEvents + 0], eax
    mov       eax, [hMonitorChangeEvent]
    mov       [.hEvents + 4], eax

.MonitorLoop:
    ; dwNotifyFilter = (REG_NOTIFY_CHANGE_NAME or REG_NOTIFY_CHANGE_ATTRIBUTES or REG_NOTIFY_CHANGE_LAST_SET)
    invoke    RegNotifyChangeKeyValue, [hMonitorKey], FALSE, 7, [hMonitorChangeEvent], TRUE
    test      eax, eax
      jnz     .ExitLoop

    lea       eax, [.hEvents]
    invoke    WaitForMultipleObjects, 2, eax, FALSE, INFINITE
    cmp       eax, WAIT_OBJECT_0
      je      .ExitLoop
    cmp       eax, WAIT_OBJECT_0 + 1
      jne     .ExitLoop

    invoke    Sleep, 50

    invoke    PostMessage, [cmWindow.hWindow], WM_APP_REGISTRY_CHANGED, [hMonitorKey], [hMonitorItem]
    jmp       .MonitorLoop

.ExitLoop:
    xor       eax, eax
    ret
endp

; VOID Registry.SyncChildNodes(HWND hTreeView, HTREEITEM hItem);
proc Registry.SyncChildNodes stdcall uses ecx edx ebx esi edi,\
     hTreeView:DWORD, hItem:DWORD
    locals
        .hFirstChild    rd 1
        .hCurChild      rd 1
        .hNextChild     rd 1
        .szSubPath      rw 1024
        .hRootKey       rd 1
        .hKey           rd 1
        .bNeedClose     rd 1
        .cSubKeys       rd 1
        .tvi            TVITEM
    endl

    mov       eax, [hItem]
    test      eax, eax
      jz      .Done
    cmp       eax, [hRootComputer]
      je      .Done

    ; Check if hItem has children in TreeView
    invoke    SendMessage, [hTreeView], TVM_GETNEXTITEM, TVGN_CHILD, [hItem]
    mov       [.hFirstChild], eax
    test      eax, eax
      jz      .CheckCollapsedChildren

    ; Node has children and expanded
    ; Delete all existing children of hItem
    mov       eax, [.hFirstChild]
    mov       [.hCurChild], eax
.DeleteChildrenLoop:
    cmp       [.hCurChild], 0
      je      .ReExpandChildren
    invoke    SendMessage, [hTreeView], TVM_GETNEXTITEM, TVGN_NEXT, [.hCurChild]
    mov       [.hNextChild], eax
    invoke    SendMessage, [hTreeView], TVM_DELETEITEM, 0, [.hCurChild]
    mov       eax, [.hNextChild]
    mov       [.hCurChild], eax
    jmp       .DeleteChildrenLoop

.ReExpandChildren:
    ; Re-build children
    stdcall   Registry.ExpandKey, [hTreeView], [hItem]
    jmp       .Done

.CheckCollapsedChildren:
    ; Node hasn't children
    ; Check if registry actually
    lea       eax, [.szSubPath]
    lea       edx, [.hRootKey]
    stdcall   Registry.GetItemPath, [hTreeView], [hItem], eax, 1024, edx
    test      eax, eax
      jz      .Done

    mov       [.bNeedClose], 0
    lea       esi, [.szSubPath]
    cmp       word [esi], 0
      je      .UseHiveRoot

    lea       edx, [.hKey]
    invoke    RegOpenKeyEx, [.hRootKey], esi, 0, KEY_READ, edx
    test      eax, eax
      jnz     .Done
    mov       [.bNeedClose], 1
    jmp       .QueryChildCount

.UseHiveRoot:
    mov       eax, [.hRootKey]
    mov       [.hKey], eax

.QueryChildCount:
    mov       [.cSubKeys], 0
    lea       eax, [.cSubKeys]
    invoke    RegQueryInfoKey, [.hKey], NULL, NULL, NULL, eax,\
              NULL, NULL, NULL, NULL, NULL, NULL, NULL

    cmp       [.bNeedClose], 0
      je      @F
    invoke    RegCloseKey, [.hKey]
@@:
    ; Update cChildren on hItem:
    ; If cSubKeys > 0 -> cChildren = 1,
    ; otherwise cChildren = 0
    xor       ebx, ebx
    cmp       [.cSubKeys], 0
      jle     @F
    mov       ebx, 1
@@:
    mov       [.tvi.mask], 0x0040        ; TVIF_CHILDREN
    mov       eax, [hItem]
    mov       [.tvi.hItem], eax
    mov       [.tvi.cChildren], ebx
    lea       eax, [.tvi]
    invoke    SendMessage, [hTreeView], TVM_SETITEM, 0, eax

.Done:
    ret
endp
