; void Grid.Initialize(LPMGRID lpGrid, HANDLE hMem, WORD width, WORD height, WORD wColsCount, WORD wRowsCount);
proc Grid.Initialize stdcall uses ecx edx ebx esi,\
     lpGrid:DWORD, hMem:DWORD, width:DWORD, height:DWORD, wColsCount:DWORD, wRowsCount:DWORD
    mov       esi, [lpGrid]  ; lpGrid
    virtual at esi
        .grid MGRID
    end virtual

    ; Save params
    mov       eax, [wColsCount]
    mov       ecx, [wRowsCount]
    mov       ebx, [width]
    mov       edx, [height]
    mov       [.grid.wColsCount], ax
    mov       [.grid.wRowsCount], cx
    ; Default selection at (0, 0)
    xor       eax, eax
    mov       [.grid.wSelectedCol], ax
    mov       [.grid.wSelectedRow], ax
    mov       [.grid.scrollY], eax

    ; Create fonts: normal, bold, italic, bold+italic
    invoke    CreateFont, 16, 0, 0, 0, 400, 0, 0, 0, 1, 0, 0, 0, 0, szFontName
    mov       [.grid.hFontNormal], eax
    invoke    CreateFont, 16, 0, 0, 0, 700, 0, 0, 0, 1, 0, 0, 0, 0, szFontName
    mov       [.grid.hFontBold], eax
    invoke    CreateFont, 16, 0, 0, 0, 400, 1, 0, 0, 1, 0, 0, 0, 0, szFontName
    mov       [.grid.hFontItalic], eax
    invoke    CreateFont, 16, 0, 0, 0, 700, 1, 0, 0, 1, 0, 0, 0, 0, szFontName
    mov       [.grid.hFontBoldItalic], eax

    ; Calculate new col width
    stdcall   Grid.Resize, esi, ebx, edx

    ; Get area of the grid (wColsCount * wRowsCount)
    movzx     eax, word [.grid.wColsCount]
    movzx     ecx, word [.grid.wRowsCount]
    imul      eax, ecx
    ; And in bytes for strings (512 bytes per cell)
    shl       eax, 9                ; * 512

    ; Allocate memory for strings in cells (zero-initialized)
    stdcall   Memory.Allocate, [hMem], eax
    mov       [.grid.lpStrs], eax

    ret
endp

; void Grid.SelectCell(LPMGRID lpGrid, DWORD col, DWORD row);
proc Grid.SelectCell stdcall uses ecx edx esi,\
     lpGrid:DWORD, col:DWORD, row:DWORD
    mov       esi, [lpGrid]
    virtual at esi
        .grid MGRID
    end virtual

    ; Check col
    movzx     ecx, word [.grid.wColsCount]
    test      ecx, ecx
      jz      .ZeroCol
    dec       ecx                   ; max valid index
    mov       eax, [col]
    test      eax, eax
      jge     @f
    xor       eax, eax
@@:
    cmp       eax, ecx
      jle     @f
    mov       eax, ecx
@@:
    mov       [.grid.wSelectedCol], ax
    jmp       .ColDone
.ZeroCol:
    mov       [.grid.wSelectedCol], 0
.ColDone:

    ; Check row
    movzx     ecx, word [.grid.wRowsCount]
    test      ecx, ecx
      jz      .ZeroRow
    dec       ecx
    mov       eax, [row]
    test      eax, eax
      jge     @f
    xor       eax, eax
@@:
    cmp       eax, ecx
      jle     @f
    mov       eax, ecx
@@:
    mov       [.grid.wSelectedRow], ax
    jmp       .RowDone
.ZeroRow:
    mov       [.grid.wSelectedRow], 0
.RowDone:

    ret
endp

; void Grid.AddToSelectedString(LPMGRID lpGrid, DWORD wChar);
proc Grid.AddToSelectedString stdcall uses ecx edx ebx esi,\
     lpGrid:DWORD, wChar:DWORD
    mov       esi, [lpGrid]
    virtual at esi
        .grid MGRID
    end virtual

    ; Check if buffer exists
    cmp       [.grid.lpStrs], 0
      je      .Full

    ; Calculate pointer
    ; offset = (wSelectedRow * wColsCount + wSelectedCol) * 512
    movzx     eax, word [.grid.wSelectedRow]
    movzx     ecx, word [.grid.wColsCount]
    imul      eax, ecx
    movzx     edx, word [.grid.wSelectedCol]
    add       eax, edx
    shl       eax, 9                ; * 512
    add       eax, [.grid.lpStrs]
    mov       ebx, eax              ; ebx = pointer to cell string slot

    ; Read current length (word at offset 2)
    movzx     ecx, word [ebx + 2]   ; ecx = current char count
    ; Check capacity, max 254 chars
    cmp       ecx, 254
      jge     .Full

    ; Append character: slot[4 + ecx*2] = wChar
    mov       ax, word [wChar]
    mov       word [ebx + 4 + ecx*2], ax

    ; Increment length
    inc       ecx
    mov       word [ebx + 2], cx

.Full:
    ret
endp

; void Grid.RemoveFromSelectedString(LPMGRID lpGrid);
proc Grid.RemoveFromSelectedString stdcall uses ecx edx ebx esi,\
     lpGrid:DWORD
    mov       esi, [lpGrid]
    virtual at esi
        .grid MGRID
    end virtual

    ; Check if buffer exists
    cmp       [.grid.lpStrs], 0
    je        .Empty

    ; Calculate pointer to the selected cell's string slot
    movzx     eax, word [.grid.wSelectedRow]
    movzx     ecx, word [.grid.wColsCount]
    imul      eax, ecx
    movzx     edx, word [.grid.wSelectedCol]
    add       eax, edx
    shl       eax, 9                ; * 512
    add       eax, [.grid.lpStrs]
    mov       ebx, eax

    ; Read current length (word at offset 2)
    movzx     ecx, word [ebx + 2]
    test      ecx, ecx
    jz        .Empty                ; nothing to delete

    ; Decrement length
    dec       ecx
    mov       word [ebx + 2], cx

.Empty:
    ret
endp

; void Grid.ToggleSelectedBold(LPMGRID lpGrid);
proc Grid.ToggleSelectedBold stdcall uses ecx edx ebx esi,\
     lpGrid:DWORD
    mov       esi, [lpGrid]
    virtual at esi
        .grid MGRID
    end virtual

    ; Check if buffer exists
    cmp       [.grid.lpStrs], 0
    je        .Done

    ; Calculate pointer to the selected cell's string slot
    movzx     eax, word [.grid.wSelectedRow]
    movzx     ecx, word [.grid.wColsCount]
    imul      eax, ecx
    movzx     edx, word [.grid.wSelectedCol]
    add       eax, edx
    shl       eax, 9                ; * 512
    add       eax, [.grid.lpStrs]
    mov       ebx, eax

    ; Toggle bit 0 of flags (offset 0)
    xor       word [ebx], 1

.Done:
    ret
endp

; void Grid.ToggleSelectedItalic(LPMGRID lpGrid);
proc Grid.ToggleSelectedItalic stdcall uses ecx edx ebx esi,\
     lpGrid:DWORD
    mov       esi, [lpGrid]
    virtual at esi
        .grid MGRID
    end virtual

    ; Check if buffer exists
    cmp       [.grid.lpStrs], 0
    je        .Done

    ; Calculate pointer to the selected cell's string slot
    movzx     eax, word [.grid.wSelectedRow]
    movzx     ecx, word [.grid.wColsCount]
    imul      eax, ecx
    movzx     edx, word [.grid.wSelectedCol]
    add       eax, edx
    shl       eax, 9                ; * 512
    add       eax, [.grid.lpStrs]
    mov       ebx, eax

    ; Toggle bit 1 of flags (offset 0)
    xor       word [ebx], 2

.Done:
    ret
endp

; DWORD Grid.CalculateRowHeight(LPMGRID lpGrid, HDC hDC, DWORD rowIndex);
proc Grid.CalculateRowHeight stdcall uses ebx esi edi,\
     lpGrid:DWORD, hDC:DWORD, rowIndex:DWORD
    locals
        rc      RECT
        maxH    dd ?
        colIdx  dd ?
    endl

    mov       esi, [lpGrid]
    virtual at esi
        .grid MGRID
    end virtual

    mov       [maxH], 0

    ; If 0 columns or no buffer, return 0
    movzx     eax, word [.grid.wColsCount]
    test      eax, eax
      jz      .EmptyCalc
    cmp       [.grid.lpStrs], 0
      jz      .EmptyCalc

    ; Calculate base pointer for this row's strings
    ; offset = rowIndex * wColsCount * 512
    movzx     eax, word [.grid.wColsCount]
    imul      eax, [rowIndex]
    shl       eax, 9                ; * 512
    add       eax, [.grid.lpStrs]
    mov       ebx, eax              ; ebx = ptr to first cell string in row

    mov       [colIdx], 0

.CalcLoop:
    movzx     ecx, word [.grid.wColsCount]
    cmp       [colIdx], ecx
      jge     .CalcDone

    ; Get string length (second word at [ebx + 2])
    movzx     eax, word [ebx + 2]
    test      eax, eax
      jz      .CalcNext             ; empty cell — skip

    ; Select appropriate font: normal (0), bold (1), italic (2), bold+italic (3)
    movzx     edx, word [ebx]       ; flags at offset 0
    and       edx, 3
    cmp       edx, 1
      je      .UseBoldFont
    cmp       edx, 2
      je      .UseItalicFont
    cmp       edx, 3
      je      .UseBoldItalicFont
    invoke    SelectObject, [hDC], [.grid.hFontNormal]
    jmp       .FontSelected
.UseBoldFont:
    invoke    SelectObject, [hDC], [.grid.hFontBold]
    jmp       .FontSelected
.UseItalicFont:
    invoke    SelectObject, [hDC], [.grid.hFontItalic]
    jmp       .FontSelected
.UseBoldItalicFont:
    invoke    SelectObject, [hDC], [.grid.hFontBoldItalic]
.FontSelected:

    ; Set up RECT for DT_CALCRECT
    mov       [rc.left], 0
    mov       [rc.top], 0
    movzx     edx, word [.grid.wColWidth]
    sub       edx, 6                ; 3px padding on each side
      jle     .CalcNext
    mov       [rc.right], edx
    mov       [rc.bottom], 0

    ; DrawText with DT_CALCRECT | DT_WORDBREAK | DT_EDITCONTROL | DT_NOPREFIX
    movzx     eax, word [ebx + 2]   ; reload string length (SelectObject clobbered eax!)
    lea       edx, [ebx + 4]        ; string data starts at offset 4
    lea       ecx, [rc]
    invoke    DrawText, [hDC], edx, eax, ecx, DT_CALCRECT or DT_WORDBREAK or DT_EDITCONTROL or DT_NOPREFIX

    ; Update maxH if this cell is smaller
    mov       eax, [rc.bottom]
    cmp       eax, [maxH]
      jle     .CalcNext
    mov       [maxH], eax

.CalcNext:
    add       ebx, 512             ; move to next cell's string slot
    inc       [colIdx]
    jmp       .CalcLoop

.CalcDone:
    mov       eax, [maxH]
    ; Check minimum height (min(16, realHeight))
    cmp       eax, 16
      jge     @f
    mov       eax, 16
@@:
    ; Add 6px vertical padding (3 top + 3 bottom)
    add       eax, 6
    ret

.EmptyCalc:
    xor       eax, eax
    ret
endp

; DWORD Grid.GetTotalHeight(LPMGRID lpGrid, HDC hDC);
proc Grid.GetTotalHeight stdcall uses ebx esi edi,\
     lpGrid:DWORD, hDC:DWORD
    mov       esi, [lpGrid]
    virtual at esi
        .grid MGRID
    end virtual

    xor       edi, edi              ; accumulated total height
    xor       ebx, ebx              ; row counter

.RowLoop:
    movzx     eax, word [.grid.wRowsCount]
    cmp       ebx, eax
      jge     .Done

    stdcall   Grid.CalculateRowHeight, [lpGrid], [hDC], ebx
    add       edi, eax
    inc       ebx
    jmp       .RowLoop

.Done:
    mov       eax, edi
    ret
endp

; DWORD Grid.HashStringColor(LPCWSTR lpStr, DWORD dwLen);
proc Grid.HashStringColor stdcall uses esi edi,\
     lpStr:DWORD, dwLen:DWORD
    mov       esi, [lpStr]
    mov       ecx, [dwLen]
    test      ecx, ecx
      jz      .Empty

    ; FNV-1a hash (32-bit)
    mov       edi, 0x811C9DC5       ; FNV offset basis
    shl       ecx, 1                ; char count -> byte count (wchar = 2 bytes)
.HashLoop:
    movzx     eax, byte [esi]
    xor       edi, eax              ; hash ^= byte
    imul      edi, 0x01000193       ; hash *= FNV prime
    inc       esi
    dec       ecx
      jnz     .HashLoop

    ; Convert hash to pastel COLORREF
    mov       eax, edi
    mov       edx, eax
    shr       edx, 16
    xor       eax, edx
    ; Pastel range: each RGB component in [160..223]
    and       eax, 0x003F3F3F      ; 0-63 per component
    add       eax, 0x00A0A0A0      ; shift to 160-223
    ret

.Empty:
    ; Default color for empty string: soft light gray
    mov       eax, 0x00D0D0D0
    ret
endp

; void Grid.Scroll(LPMGRID lpGrid, HDC hDC, DWORD delta);
proc Grid.Scroll stdcall uses ebx esi edi,\
     lpGrid:DWORD, hDC:DWORD, delta:DWORD
    mov       esi, [lpGrid]
    virtual at esi
        .grid MGRID
    end virtual

    ; Calculate maxScroll = max(0, totalHeight - viewportHeight)
    stdcall   Grid.GetTotalHeight, [lpGrid], [hDC]
    mov       edi, eax              ; edi = total height
    movzx     ebx, word [.grid.height]
    sub       edi, ebx              ; edi = totalHeight - height
    test      edi, edi
      jge     @f
    xor       edi, edi              ; if totalHeight <= viewport, maxScroll = 0
@@:

    ; New scrollY = scrollY + delta
    mov       eax, [.grid.scrollY]
    add       eax, [delta]

    ; Check for >= 0
    test      eax, eax
      jge     @f
    xor       eax, eax
@@:
    ; Check for <= maxScroll
    cmp       eax, edi
      jle     @f
    mov       eax, edi
@@:
    mov       [.grid.scrollY], eax
    ret
endp

; void Grid.EnsureVisible(LPMGRID lpGrid, HDC hDC);
proc Grid.EnsureVisible stdcall uses ecx edx ebx esi edi,\
     lpGrid:DWORD, hDC:DWORD
    locals
        selTop   dd ?
        selBot   dd ?
    endl

    mov       esi, [lpGrid]
    virtual at esi
        .grid MGRID
    end virtual

    ; If 0 rows or 0 cols or no buffer, exit
    movzx     eax, word [.grid.wRowsCount]
    test      eax, eax
      jz      .Done
    movzx     eax, word [.grid.wColsCount]
    test      eax, eax
      jz      .Done
    cmp       [.grid.lpStrs], 0
      jz      .Done

    ; Calculate Y position of selected row by summing heights of preceding rows
    xor       edi, edi              ; edi = accumulated Y
    xor       ebx, ebx              ; ebx = row counter

.SumLoop:
    movzx     eax, word [.grid.wSelectedRow]
    cmp       ebx, eax
      jge     .SumDone

    stdcall   Grid.CalculateRowHeight, [lpGrid], [hDC], ebx
    add       edi, eax
    inc       ebx
    jmp       .SumLoop

.SumDone:
    mov       [selTop], edi         ; top Y of selected row (absolute)

    ; Get height of selected row itself
    movzx     eax, word [.grid.wSelectedRow]
    stdcall   Grid.CalculateRowHeight, [lpGrid], [hDC], eax
    add       edi, eax
    mov       [selBot], edi         ; bottom Y of selected row (absolute)

    ; Viewport bounds [scrollY..scrollY + grid.height)
    mov       ecx, [.grid.scrollY]
    movzx     edx, word [.grid.height]

    ; If selTop < scrollY, scroll up
    mov       eax, [selTop]
    cmp       eax, ecx
      jge     .CheckBottom
    mov       [.grid.scrollY], eax
    jmp       .CheckScroll

.CheckBottom:
    ; If selBot > scrollY + height, scroll down
    mov       eax, ecx
    add       eax, edx              ; eax = scrollY + viewportH
    cmp       [selBot], eax
      jle     .CheckScroll
    mov       eax, [selBot]
    sub       eax, edx              ; eax = selBot - viewportH
    mov       [.grid.scrollY], eax

.CheckScroll:
    ; Check scrollY for [0, maxScroll]
    stdcall   Grid.GetTotalHeight, [lpGrid], [hDC]
    mov       edi, eax
    movzx     ebx, word [.grid.height]
    sub       edi, ebx
    test      edi, edi
      jge     @f
    xor       edi, edi
@@:
    mov       eax, [.grid.scrollY]
    test      eax, eax
      jge       @f
    xor       eax, eax
@@:
    cmp       eax, edi
      jle       @f
    mov       eax, edi
@@:
    mov       [.grid.scrollY], eax

.Done:
    ret
endp

; void Grid.Draw(LPMGRID lpGrid, HDC hDC);
proc Grid.Draw stdcall uses ecx edx ebx esi edi,\
     lpGrid:DWORD, hDC:DWORD
    locals
        rc         RECT
        rcText     RECT
        rowH       dd ?
        rowIdx     dd ?
        colIdx     dd ?
        curY       dd ?
        hBlackBrush dd ?
        hWhiteBrush dd ?
        hSelBrush   dd ?
        lpRowStr   dd ?
    endl

    ; Bind addresses
    mov       esi, [lpGrid]
    virtual at esi
        .grid MGRID
    end virtual
    mov       ebx, [hDC]

    ; If 0 cols, 0 rows, or no buffer: draw nothing!
    movzx     eax, word [.grid.wColsCount]
    test      eax, eax
      jz      .EmptyGrid
    movzx     eax, word [.grid.wRowsCount]
    test      eax, eax
      jz      .EmptyGrid
    cmp       [.grid.lpStrs], 0
      jz      .EmptyGrid

    ; Get stock brushes: white for cell borders, black for inner background
    invoke    GetStockObject, WHITE_BRUSH
    mov       [hWhiteBrush], eax

    invoke    GetStockObject, BLACK_BRUSH
    mov       [hBlackBrush], eax

    ; Create red brush for selected cell border
    invoke    CreateSolidBrush, 0x000000FF    ; red (COLORREF = 0x00BBGGRR)
    mov       [hSelBrush], eax

    ; Set transparent background mode for text drawing
    invoke    SetBkMode, ebx, TRANSPARENT

    ; Row loop
    ; Start Y at negative scrollY so rows scroll upward
    mov       eax, [.grid.scrollY]
    neg       eax
    mov       [curY], eax
    mov       [rowIdx], 0

.RowLoop:
    movzx     eax, word [.grid.wRowsCount]
    cmp       [rowIdx], eax
      jge     .EndDraw

    ; Calculate row height based on text content
    stdcall   Grid.CalculateRowHeight, [lpGrid], ebx, [rowIdx]
    mov       [rowH], eax

    ; If this row is entirely above the viewport, skip drawing but advance Y
    mov       eax, [curY]
    add       eax, [rowH]
    test      eax, eax
      jle     .SkipRow              ; row bottom <= 0 -> invisible above

    ; If row top is below viewport, we're done (all remaining rows below too)
    movzx     eax, word [.grid.height]
    cmp       [curY], eax
      jge     .EndDraw

    ; Calculate pointer to the first cell string in this row
    movzx     eax, word [.grid.wColsCount]
    imul      eax, [rowIdx]
    shl       eax, 9                ; * 512
    add       eax, [.grid.lpStrs]
    mov       [lpRowStr], eax

    ; Column loop
    mov       [colIdx], 0
    movzx     edi, word [.grid.wColWidth]   ; edi = column width (callee-saved)

.ColLoop:
    movzx     eax, word [.grid.wColsCount]
    cmp       [colIdx], eax
      jge     .NextRow

    ; Build cell RECT
    mov       eax, [colIdx]
    imul      eax, edi                   ; eax = colIdx * colWidth
    mov       [rc.left], eax
    add       eax, edi
    mov       [rc.right], eax
    mov       eax, [curY]
    mov       [rc.top], eax
    add       eax, [rowH]
    mov       [rc.bottom], eax

    ; 1. Fill cell with BLACK background
    lea       eax, [rc]
    invoke    FillRect, ebx, eax, [hBlackBrush]

    ; 2. Draw cell border:
    movzx     eax, word [.grid.wSelectedCol]
    cmp       eax, [colIdx]
      jne     .NormalBorder
    movzx     eax, word [.grid.wSelectedRow]
    cmp       eax, [rowIdx]
      jne     .NormalBorder

    ; Selected cell -> red frame
    ; Outer border
    lea       eax, [rc]
    invoke    FrameRect, ebx, eax, [hSelBrush]
    ; Inner border
    mov       eax, [rc.left]
    inc       eax
    mov       [rcText.left], eax
    mov       eax, [rc.top]
    inc       eax
    mov       [rcText.top], eax
    mov       eax, [rc.right]
    dec       eax
    mov       [rcText.right], eax
    mov       eax, [rc.bottom]
    dec       eax
    mov       [rcText.bottom], eax
    lea       eax, [rcText]
    invoke    FrameRect, ebx, eax, [hSelBrush]
    jmp       .AfterBorder

.NormalBorder:
    ; White border
    lea       eax, [rc]
    invoke    FrameRect, ebx, eax, [hWhiteBrush]

.AfterBorder:
    ; 3. Draw cell text (if length > 0)
    mov       ecx, [lpRowStr]
    movzx     eax, word [ecx + 2]        ; string length (second word at offset 2)
    test      eax, eax
      jz      .NoText

    ; Select appropriate font: normal (0), bold (1), italic (2), bold+italic (3)
    movzx     edx, word [ecx]            ; flags
    and       edx, 3
    cmp       edx, 1
      je      .DrawUseBoldFont
    cmp       edx, 2
      je      .DrawUseItalicFont
    cmp       edx, 3
      je      .DrawUseBoldItalicFont
    invoke    SelectObject, ebx, [.grid.hFontNormal]
    jmp       .DrawFontReady
.DrawUseBoldFont:
    invoke    SelectObject, ebx, [.grid.hFontBold]
    jmp       .DrawFontReady
.DrawUseItalicFont:
    invoke    SelectObject, ebx, [.grid.hFontItalic]
    jmp       .DrawFontReady
.DrawUseBoldItalicFont:
    invoke    SelectObject, ebx, [.grid.hFontBoldItalic]
.DrawFontReady:

    ; Re-read string pointer & length
    mov       ecx, [lpRowStr]
    movzx     eax, word [ecx + 2]        ; length

    ; Set text color based on string content hash
    push      eax
    lea       edx, [ecx + 4]             ; string data
    stdcall   Grid.HashStringColor, edx, eax
    invoke    SetTextColor, ebx, eax
    pop       eax

    ; Build inner text RECT with 3px padding on each side
    push      eax                        ; save string length
    mov       edx, [rc.left]
    add       edx, 3
    mov       [rcText.left], edx
    mov       edx, [rc.top]
    add       edx, 3
    mov       [rcText.top], edx
    mov       edx, [rc.right]
    sub       edx, 3
    mov       [rcText.right], edx
    mov       edx, [rc.bottom]
    sub       edx, 3
    mov       [rcText.bottom], edx
    pop       eax                        ; restore string length

    mov       ecx, [lpRowStr]
    movzx     eax, word [ecx + 2]        ; reload string length cleanly
    lea       edx, [ecx + 4]             ; string data (starts at offset 4)
    lea       ecx, [rcText]
    invoke    DrawText, ebx, edx, eax, ecx, DT_WORDBREAK or DT_EDITCONTROL or DT_NOPREFIX

.NoText:
    add       [lpRowStr], 512            ; advance to next cell's string slot
    inc       [colIdx]
    jmp       .ColLoop

.SkipRow:
    ; Row is above viewport — just advance Y, no drawing
    mov       eax, [rowH]
    add       [curY], eax
    inc       [rowIdx]
    jmp       .RowLoop

.NextRow:
    ; Advance Y position
    mov       eax, [rowH]
    add       [curY], eax

    inc       [rowIdx]
    jmp       .RowLoop

.EndDraw:
    ; Delete the custom selection brush
    invoke    DeleteObject, [hSelBrush]

.EmptyGrid:
    ret
endp

; void Grid.Resize(LPMGRID lpGrid, DWORD width, DWORD height);
proc Grid.Resize stdcall uses ecx edx ebx esi,\
     lpGrid:DWORD, width:DWORD, height:DWORD
    mov       esi, [lpGrid]
    virtual at esi
        .grid MGRID
    end virtual

    mov       eax, [width]
    mov       edx, [height]
    movzx     ecx, [.grid.wColsCount]

    ; Save new values to the structure
    mov       [.grid.width], ax
    mov       [.grid.height], dx
    ; Calculate new col width (protect against div by 0)
    test      ecx, ecx
      jz      .ZeroCols
    xor       edx, edx
    div       ecx
    mov       [.grid.wColWidth], ax
    ret

.ZeroCols:
    mov       [.grid.wColWidth], 0
    ret
endp

; void Grid.SetDimensions(LPMGRID lpGrid, HANDLE hMem, DWORD newCols, DWORD newRows);
proc Grid.SetDimensions stdcall uses ecx edx ebx esi edi,\
     lpGrid:DWORD, hMem:DWORD, newCols:DWORD, newRows:DWORD
    locals
        oldStrs     dd ?
        newStrs     dd ?
        oldCols     dd ?
        oldRows     dd ?
        copyCols    dd ?
        copyRows    dd ?
        r           dd ?
        c           dd ?
    endl

    mov       esi, [lpGrid]
    virtual at esi
        .grid MGRID
    end virtual

    ; Validate new dimensions (min 0, max 16)
    cmp       [newCols], 0
      jl      .Done
    cmp       [newCols], 16
      jg      .Done
    cmp       [newRows], 0
      jl      .Done
    cmp       [newRows], 16
      jg      .Done

    ; Save old info
    movzx     eax, word [.grid.wColsCount]
    mov       [oldCols], eax
    movzx     eax, word [.grid.wRowsCount]
    mov       [oldRows], eax
    mov       eax, [.grid.lpStrs]
    mov       [oldStrs], eax

    ; Check if new grid is empty (0 cols or 0 rows)
    cmp       [newCols], 0
      je      .EmptyGrid
    cmp       [newRows], 0
      je      .EmptyGrid

    ; Allocate new buffer: newCols * newRows * 512
    mov       eax, [newCols]
    imul      eax, [newRows]
    shl       eax, 9                ; * 512
    stdcall   Memory.Allocate, [hMem], eax
    test      eax, eax
      jz      .Done
    mov       [newStrs], eax

    ; If there was no old buffer (e.g. was empty grid), skip copying
    cmp       [oldStrs], 0
      je      .UpdateFields

    ; Determine copy bounds, min(oldCols, newCols), min(oldRows, newRows)
    mov       eax, [oldCols]
    cmp       eax, [newCols]
      jle     @f
    mov       eax, [newCols]
@@:
    mov       [copyCols], eax

    mov       eax, [oldRows]
    cmp       eax, [newRows]
      jle     @f
    mov       eax, [newRows]
@@:
    mov       [copyRows], eax

    ; Copy cell by cell
    mov       [r], 0
.RowLoop:
    mov       eax, [r]
    cmp       eax, [copyRows]
      jge     .CopyDone

    mov       [c], 0
.ColLoop:
    mov       eax, [c]
    cmp       eax, [copyCols]
      jge     .NextRow

    ; src = oldStrs + (r * oldCols + c) * 512
    mov       eax, [r]
    imul      eax, [oldCols]
    add       eax, [c]
    shl       eax, 9
    add       eax, [oldStrs]
    mov       edx, eax              ; edx = src

    ; dst = newStrs + (r * newCols + c) * 512
    mov       eax, [r]
    imul      eax, [newCols]
    add       eax, [c]
    shl       eax, 9
    add       eax, [newStrs]
    mov       edi, eax              ; edi = dst

    ; Copy 512 bytes = 128 dwords
    push      esi
    mov       esi, edx
    mov       ecx, 128
      rep movsd
    pop       esi

    inc       [c]
    jmp       .ColLoop

.NextRow:
    inc       [r]
    jmp       .RowLoop

.CopyDone:
    ; Free old buffer
    stdcall   Memory.Free, [hMem], [oldStrs]

.UpdateFields:
    mov       eax, [newStrs]
    mov       [.grid.lpStrs], eax
    mov       eax, [newCols]
    mov       [.grid.wColsCount], ax
    mov       eax, [newRows]
    mov       [.grid.wRowsCount], ax

    ; Recalculate col width
    movzx     ecx, word [.grid.width]
    movzx     edx, word [.grid.height]
    stdcall   Grid.Resize, esi, ecx, edx

    ; Check selection
    movzx     ecx, word [.grid.wSelectedCol]
    movzx     edx, word [.grid.wSelectedRow]
    stdcall   Grid.SelectCell, esi, ecx, edx
    jmp       .Done

.EmptyGrid:
    cmp       [oldStrs], 0
      je      @f
    stdcall   Memory.Free, [hMem], [oldStrs]
@@:
    mov       [.grid.lpStrs], 0
    mov       eax, [newCols]
    mov       [.grid.wColsCount], ax
    mov       eax, [newRows]
    mov       [.grid.wRowsCount], ax
    mov       [.grid.wColWidth], 0
    mov       [.grid.wSelectedCol], 0
    mov       [.grid.wSelectedRow], 0
    mov       [.grid.scrollY], 0

.Done:
    ret
endp

; void Grid.StepCols(LPMGRID lpGrid, HANDLE hMem, DWORD bDecrease);
proc Grid.StepCols stdcall uses esi,\
     lpGrid:DWORD, hMem:DWORD, bDecrease:DWORD
    mov       esi, [lpGrid]
    virtual at esi
        .grid MGRID
    end virtual

    movzx     eax, word [.grid.wColsCount]
    cmp       [bDecrease], 0
      jne     .Dec
    ; Increment cols (up to 10)
    cmp       eax, 10
      jge     .Done
    inc       eax
    jmp       .Apply
.Dec:
    ; Decrement cols (down to 0)
    test      eax, eax
      jz      .Done
    dec       eax
.Apply:
    movzx     edx, word [.grid.wRowsCount]
    stdcall   Grid.SetDimensions, esi, [hMem], eax, edx
.Done:
    ret
endp

; void Grid.StepRows(LPMGRID lpGrid, HANDLE hMem, DWORD bDecrease);
proc Grid.StepRows stdcall uses esi,\
     lpGrid:DWORD, hMem:DWORD, bDecrease:DWORD
    mov       esi, [lpGrid]
    virtual at esi
        .grid MGRID
    end virtual

    movzx     eax, word [.grid.wRowsCount]
    cmp       [bDecrease], 0
      jne     .Dec
    ; Increment rows (up to 10)
    cmp       eax, 10
      jge     .Done
    inc       eax
    jmp       .Apply
.Dec:
    ; Decrement rows (down to 0)
    test      eax, eax
      jz      .Done
    dec       eax
.Apply:
    movzx     ecx, word [.grid.wColsCount]
    stdcall   Grid.SetDimensions, esi, [hMem], ecx, eax
.Done:
    ret
endp