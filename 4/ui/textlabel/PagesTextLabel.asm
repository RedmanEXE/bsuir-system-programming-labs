; BOOL PagesTextLabel.Update(HWND hTextLabel, LPSTR lpszTextBuffer, DWORD dwCurrPageIdx,
;                            DWORD dwTotalPages);
proc PagesTextLabel.Update stdcall uses ecx edx esi,\
     hTextLabel:DWORD, lpszTextBuffer:DWORD, dwCurrPageIdx:DWORD, dwTotalPages:DWORD
    ; Format string
    mov       esi, [lpszTextBuffer]
    ; 1. Add current page index
    stdcall   String.IntToStr, esi, [dwCurrPageIdx]
    shl       eax, 1
    add       esi, eax
    ; 2. Add delimeter between two numbers
    mov       word [esi], ' '
    mov       word [esi + 2], '/'
    mov       word [esi + 4], ' '
    add       esi, 6
    ; 3. Add total pages count
    stdcall   String.IntToStr, esi, [dwTotalPages]
    shl       eax, 1
    add       esi, eax

    stdcall   TextLabel.SetText, [hTextLabel], [lpszTextBuffer]
    ret
endp
