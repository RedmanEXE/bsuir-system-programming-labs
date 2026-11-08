; HWND TreeView.Create(HWND hWnd, DWORD dwControlId, WORD wX, WORD wY, WORD wWidth,
;                      WORD wHeight, HFONT hFont);
proc TreeView.Create stdcall uses ecx edx esi,\
     hWnd:DWORD, dwControlId:DWORD, wX:DWORD, wY:DWORD, wWidth:DWORD, wHeight:DWORD, hFont:DWORD
    ; Get HINSTANCE of parent window
    invoke    GetWindowLong, [hWnd], GWL_HINSTANCE
    ; Create TreeView control
    invoke    CreateWindowEx, WS_EX_CLIENTEDGE, szTreeViewClassName, NULL,\
              WS_CHILD or WS_VISIBLE or WS_BORDER or WS_TABSTOP or\
              TVS_HASLINES or TVS_LINESATROOT or TVS_HASBUTTONS or TVS_SHOWSELALWAYS,\
              dword [wX], dword [wY], dword [wWidth], dword [wHeight],\
              dword [hWnd], dword [dwControlId], eax, NULL
    mov       esi, eax

    ; Apply font
    invoke    SendMessage, esi, WM_SETFONT, [hFont], TRUE

    xchg      esi, eax
    ret
endp

; HIMAGELIST TreeView.SetImageList(HWND hTreeView, HIMAGELIST hImageList, DWORD dwType);
proc TreeView.SetImageList stdcall uses ecx edx,\
     hTreeView:DWORD, hImageList:DWORD, dwType:DWORD
    ; Just send message
    invoke    SendMessage, [hTreeView], TVM_SETIMAGELIST, [dwType], [hImageList]
    ret
endp

; HTREEITEM TreeView.InsertItem(HWND hTreeView, HTREEITEM hParent, HTREEITEM hInsertAfter,
;                              LPWSTR lpszText, INT iImage, INT iSelectedImage, INT cChildren, LPARAM lParam);
proc TreeView.InsertItem stdcall uses ecx edx ebx edi,\
     hTreeView:DWORD, hParent:DWORD, hInsertAfter:DWORD,\
     lpszText:DWORD, iImage:DWORD, iSelectedImage:DWORD, cChildren:DWORD, lParamVal:DWORD
    locals
        .tvis       TVINSERTSTRUCT
    endl

    ; Clean-up memory
    lea       edi, [.tvis]
    mov       ecx, sizeof.TVINSERTSTRUCT / 4
    xor       eax, eax
    cld
      rep stosd

    ; Create structure
    mov       eax, [hParent]
    mov       ecx, [hInsertAfter]
    mov       [.tvis.hParent], eax
    mov       [.tvis.hInsertAfter], ecx

    ; Create value for mask
    mov       [.tvis.item.mask], TVIF_TEXT or TVIF_IMAGE or TVIF_SELECTEDIMAGE or TVIF_CHILDREN or TVIF_PARAM

    ; Item properties
    mov       eax, [lpszText]
    mov       ecx, [iImage]
    mov       edx, [iSelectedImage]
    mov       ebx, [cChildren]
    mov       [.tvis.item.pszText], eax
    mov       [.tvis.item.iImage], ecx
    mov       [.tvis.item.iSelectedImage], edx
    mov       [.tvis.item.cChildren], ebx
    mov       eax, [lParamVal]
    mov       [.tvis.item.lParam], eax

    ; Insert item (TVM_INSERTITEMW)
    lea       eax, [.tvis]
    invoke    SendMessage, [hTreeView], TVM_INSERTITEMW, 0, eax
    ret
endp

; HIMAGELIST TreeView.CreateRegistryImageList();
; Create list with icons: computer, closed folder, open folder
proc TreeView.CreateRegistryImageList stdcall uses ecx edx ebx esi edi
    locals
        .hIml           rd 1
        .pidl           rd 1
        .hClosedIcon    rd 1
        .hOpenIcon      rd 1
        .shfi           SHFILEINFO
    endl

    mov       [.hClosedIcon], 0
    mov       [.hOpenIcon], 0

    ; Create ImageList for 5 icons
    invoke    ImageList_Create, 16, 16, ILC_COLOR32 or ILC_MASK, 5, 5
    test      eax, eax
      jz      .Failed
    mov       [.hIml], eax

    ; 0. Icon: "My computer" (CSIDL_DRIVES = 0x0011)
    lea       eax, [.pidl]
    invoke    SHGetSpecialFolderLocation, NULL, CSIDL_DRIVES, eax
    test      eax, eax
      jnz     .LoadClosedFolder

    lea       edi, [.shfi]
    mov       ecx, sizeof.SHFILEINFO / 4
    xor       eax, eax
    cld
      rep stosd

    lea       eax, [.shfi]
    invoke    SHGetFileInfo, [.pidl], 0, eax, sizeof.SHFILEINFO,\
              SHGFI_PIDL or SHGFI_ICON or SHGFI_SMALLICON
    test      eax, eax
      jz      .LoadClosedFolder

    invoke    ImageList_ReplaceIcon, [.hIml], -1, [.shfi.hIcon]
    invoke    DestroyIcon, [.shfi.hIcon]

.LoadClosedFolder:
    ; 1. Icon: Closed folder
    lea       edi, [.shfi]
    mov       ecx, sizeof.SHFILEINFO / 4
    xor       eax, eax
    cld
      rep stosd

    lea       eax, [.shfi]
    invoke    SHGetFileInfo, szButtonClassName, FILE_ATTRIBUTE_DIRECTORY, eax, sizeof.SHFILEINFO,\
              SHGFI_USEFILEATTRIBUTES or SHGFI_ICON or SHGFI_SMALLICON
    test      eax, eax
      jz      .LoadOpenFolder

    mov       eax, [.shfi.hIcon]
    mov       [.hClosedIcon], eax
    invoke    ImageList_ReplaceIcon, [.hIml], -1, [.hClosedIcon]

.LoadOpenFolder:
    ; 2. Icon: Open folder (SHGFI_OPENICON)
    lea       edi, [.shfi]
    mov       ecx, sizeof.SHFILEINFO / 4
    xor       eax, eax
    cld
      rep stosd

    lea       eax, [.shfi]
    invoke    SHGetFileInfo, szButtonClassName, FILE_ATTRIBUTE_DIRECTORY, eax, sizeof.SHFILEINFO,\
              SHGFI_USEFILEATTRIBUTES or SHGFI_ICON or SHGFI_SMALLICON or SHGFI_OPENICON
    test      eax, eax
      jz      .AddGrayIcons

    mov       eax, [.shfi.hIcon]
    mov       [.hOpenIcon], eax
    invoke    ImageList_ReplaceIcon, [.hIml], -1, [.hOpenIcon]

.AddGrayIcons:
    ; 3. Icon: Grayscale closed folder
    stdcall   TreeView.AddGrayscaleIcon, [.hIml], [.hClosedIcon]
    ; 4. Icon: Grayscale open folder
    stdcall   TreeView.AddGrayscaleIcon, [.hIml], [.hOpenIcon]

.CleanupIcons:
    cmp       [.hClosedIcon], 0
      je      @F
    invoke    DestroyIcon, [.hClosedIcon]
@@:
    cmp       [.hOpenIcon], 0
      je      .Done
    invoke    DestroyIcon, [.hOpenIcon]
    jmp       .Done

.Failed:
    xor       eax, eax
    mov       [.hIml], eax

.Done:
    mov       eax, [.hIml]
    ret
endp

; HTREEITEM TreeView.GetSelectedItem(HWND hTreeView);
proc TreeView.GetSelectedItem stdcall uses ecx edx,\
     hTreeView:DWORD
    invoke    SendMessage, [hTreeView], TVM_GETNEXTITEM, TVGN_CARET, 0
    ret
endp

; BOOL TreeView.DeleteItem(HWND hTreeView, HTREEITEM hItem);
proc TreeView.DeleteItem stdcall uses ecx edx,\
     hTreeView:DWORD, hItem:DWORD
    invoke    SendMessage, [hTreeView], TVM_DELETEITEM, 0, [hItem]
    ret
endp

; BOOL TreeView.ExpandItem(HWND hTreeView, HTREEITEM hItem, UINT nCode);
proc TreeView.ExpandItem stdcall uses ecx edx,\
     hTreeView:DWORD, hItem:DWORD, nCode:DWORD
    invoke    SendMessage, [hTreeView], TVM_EXPAND, [nCode], [hItem]
    ret
endp

; BOOL TreeView.SelectItem(HWND hTreeView, HTREEITEM hItem);
proc TreeView.SelectItem stdcall uses ecx edx,\
     hTreeView:DWORD, hItem:DWORD
    invoke    SendMessage, [hTreeView], TVM_SELECTITEM, TVGN_CARET, [hItem]
    ret
endp


; BOOL TreeView.AddGrayscaleIcon(HIMAGELIST hIml, HICON hIcon);
proc TreeView.AddGrayscaleIcon stdcall uses ecx edx ebx,\
     hIml:DWORD, hIcon:DWORD
    cmp       [hIcon], 0
      je      .Done

    stdcall   Icons.CreateGrayscaleIcon, [hIcon]
    test      eax, eax
      jz      .Done
    mov       ebx, eax
    invoke    ImageList_ReplaceIcon, [hIml], -1, ebx
    invoke    DestroyIcon, ebx

.Done:
    ret
endp

; HTREEITEM TreeView.InsertRootHive(HWND hTreeView, HTREEITEM hParent, LPWSTR lpszText, HKEY hRootKey);
; Checks key writability, selects normal (1, 2) or grayscale (3, 4) folder icons,
; and inserts root hive into TreeView with lParam = hRootKey.
proc TreeView.InsertRootHive stdcall uses ecx edx ebx esi edi,\
     hTreeView:DWORD, hParent:DWORD, lpszText:DWORD, hRootKey:DWORD
    locals
        .iClosed        rd 1
        .iOpen          rd 1
    endl

    mov       [.iClosed], 1
    mov       [.iOpen], 2

    stdcall   Registry.IsKeyWritable, [hRootKey], NULL
    test      eax, eax
      jnz     @F

    mov       [.iClosed], 3
    mov       [.iOpen], 4

@@:
    stdcall   TreeView.InsertItem, [hTreeView], [hParent], TVI_LAST,\
              [lpszText], [.iClosed], [.iOpen], 1, [hRootKey]

.Done:
    ret
endp
