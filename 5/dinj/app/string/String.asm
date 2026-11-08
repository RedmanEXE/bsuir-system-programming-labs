; DWORD String.IntToStr(LPWSTR lpszString, INT number);
proc String.IntToStr stdcall uses ecx edx ebx edi,\
     lpszString:DWORD, number:DWORD
    mov     edi, [lpszString]
    mov     eax, [number]
    mov     ebx, edi
    mov     ecx, 10

    ; Check for negative
    test    eax, eax
      jns   .ExtractDigits
    
    mov     word [edi], '-'
    add     edi, 2
    mov     ebx, edi
    neg     eax

    ; Divide digits in reversed loop
.ExtractDigits:
    xor     edx, edx
    div     ecx
    add     edx, '0'
    mov     word [edi], dx
    add     edi, 2
    test    eax, eax
      jnz   .ExtractDigits

    ; Terminate string
    mov     word [edi], 0
    ; Calculate length
    mov     eax, edi
    sub     eax, [lpszString]
    shr     eax, 1

    ; Reverse string (without NULL)
    sub     edi, 2
.Loop:
    cmp     ebx, edi
      jae   .End

    ; Just two-pointers approach
    mov     cx, word [ebx]
    mov     dx, word [edi]
    mov     word [ebx], dx
    mov     word [edi], cx

    add     ebx, 2
    sub     edi, 2
    jmp     .Loop

.End:
    ret
endp

; DWORD String.StringLen(LPCWSTR lpStr);
proc String.StringLen stdcall uses esi,\
     lpStr:DWORD
    mov       esi, [lpStr]
    xor       eax, eax
    test      esi, esi
      jz      .Done

.Loop:
    cmp       word [esi + eax * 2], 0
      je      .Done
    inc       eax
    jmp       .Loop

.Done:
    ret
endp

; VOID String.StringCopy(LPWSTR lpDst, LPCWSTR lpSrc);
proc String.StringCopy stdcall uses esi edi,\
     lpDst:DWORD, lpSrc:DWORD
    mov       edi, [lpDst]
    mov       esi, [lpSrc]
    test      edi, edi
      jz      .Done
    test      esi, esi
      jz      .Empty

.Loop:
    mov       ax, word [esi]
    mov       word [edi], ax
    add       esi, 2
    add       edi, 2
    test      ax, ax
      jnz     .Loop
    jmp       .Done

.Empty:
    mov       word [edi], 0
.Done:
    ret
endp

; VOID String.StringCat(LPWSTR lpDst, LPCWSTR lpSrc);
proc String.StringCat stdcall uses esi edi,\
     lpDst:DWORD, lpSrc:DWORD
    mov       edi, [lpDst]
    mov       esi, [lpSrc]
    test      edi, edi
      jz      .Done
    test      esi, esi
      jz      .Done

.FindEnd:
    cmp       word [edi], 0
      je      .CopyLoop
    add       edi, 2
    jmp       .FindEnd

.CopyLoop:
    mov       ax, word [esi]
    mov       word [edi], ax
    add       esi, 2
    add       edi, 2
    test      ax, ax
      jnz     .CopyLoop

.Done:
    ret
endp

; VOID String.FormatDword(DWORD dwVal, LPWSTR lpszDst);
proc String.FormatDword stdcall uses ecx edx ebx esi edi,\
     dwVal:DWORD, lpszDst:DWORD

    mov       edi, [lpszDst]

    ; Write prefix "0x"
    mov       word [edi + 0], '0'
    mov       word [edi + 2], 'x'
    add       edi, 4

    ; Format 8 hex digits
    mov       ebx, [dwVal]
    mov       ecx, 8
.HexLoop:
    rol       ebx, 4
    mov       eax, ebx
    and       eax, 0x0F
    cmp       al, 10
      jb      @F
    add       al, 'A' - 10 - '0'
@@:
    add       al, '0'
    mov       byte [edi], al
    mov       byte [edi + 1], 0
    add       edi, 2
    dec       ecx
      jnz     .HexLoop

    ; Write " ("
    mov       word [edi + 0], ' '
    mov       word [edi + 2], '('
    add       edi, 4

    ; Format decimal part using existing String.IntToStr
    stdcall   String.IntToStr, edi, [dwVal]
    lea       edi, [edi + eax * 2]

    ; Write ")" and null terminator
    mov       word [edi + 0], ')'
    mov       word [edi + 2], 0

.Done:
    ret
endp

; VOID String.FormatBinary(LPVOID lpData, DWORD cbData, LPWSTR lpszDst, DWORD cchMax);
proc String.FormatBinary stdcall uses ecx edx ebx esi edi,\
     lpData:DWORD, cbData:DWORD, lpszDst:DWORD, cchMax:DWORD
    mov       edi, [lpszDst]
    mov       esi, [lpData]
    mov       ecx, [cbData]

    test      ecx, ecx
      jnz     .HasData

    ; Zero-length binary value
    stdcall   String.StringCopy, edi, szEmptyBinaryText
    jmp       .Done

.HasData:
    ; Limit to 64 bytes
    cmp       ecx, 64
      jbe     @F
    mov       ecx, 64
@@:

.ByteLoop:
    movzx     eax, byte [esi]
    inc       esi

    ; High half-byte
    mov       edx, eax
    shr       edx, 4
    and       edx, 0x0F
    cmp       dl, 10
      jb      @F
    add       dl, 'a' - 10 - '0'
@@:
    add       dl, '0'
    mov       byte [edi], dl
    mov       byte [edi + 1], 0
    add       edi, 2

    ; Low half-byte
    mov       edx, eax
    and       edx, 0x0F
    cmp       dl, 10
      jb      @F
    add       dl, 'a' - 10 - '0'
@@:
    add       dl, '0'
    mov       byte [edi], dl
    mov       byte [edi + 1], 0
    add       edi, 2

    ; Separator space
    mov       word [edi], ' '
    add       edi, 2

    dec       ecx
      jnz     .ByteLoop

    ; Replace trailing space with NULL terminator
    sub       edi, 2
    mov       word [edi], 0

.Done:
    ret
endp

; INT String.Compare(LPCWSTR lpStr1, LPCWSTR lpStr2);
proc String.Compare stdcall uses esi edi,\
     lpStr1:DWORD, lpStr2:DWORD
    mov       esi, [lpStr1]
    mov       edi, [lpStr2]
    test      esi, esi
      jz      .CheckNull
    test      edi, edi
      jz      .NotEqual

.Loop:
    mov       ax, word [esi]
    mov       cx, word [edi]
    cmp       ax, cx
      jne     .NotEqual
    test      ax, ax
      jz      .Equal
    add       esi, 2
    add       edi, 2
    jmp       .Loop

.CheckNull:
    test      edi, edi
      jz      .Equal
.NotEqual:
    mov       eax, 1
    jmp       .Done

.Equal:
    xor       eax, eax
.Done:
    ret
endp


; DWORD String.StrToInt(LPCWSTR lpszString);
proc String.StrToInt stdcall uses ecx edx ebx esi,     lpszString:DWORD
    mov       esi, [lpszString]
    test      esi, esi
      jz      .DoneZero

.SkipSpaces:
    cmp       word [esi], ' '
      je      .NextSpace
    cmp       word [esi], 9
      jne     .CheckHexPrefix
.NextSpace:
    add       esi, 2
    jmp       .SkipSpaces

.CheckHexPrefix:
    cmp       word [esi], '0'
      jne     .ParseDec
    cmp       word [esi + 2], 'x'
      je      .IsHex
    cmp       word [esi + 2], 'X'
      je      .IsHex
    jmp       .ParseDec

.IsHex:
    add       esi, 4
    xor       eax, eax
.HexLoop:
    movzx     edx, word [esi]
    cmp       dx, '0'
      jb      .Done
    cmp       dx, '9'
      jbe     .HexDigit
    cmp       dx, 'A'
      jb      .Done
    cmp       dx, 'F'
      jbe     .HexUpper
    cmp       dx, 'a'
      jb      .Done
    cmp       dx, 'f'
      ja      .Done
    sub       dx, 'a' - 10
    jmp       .AccumHex
.HexUpper:
    sub       dx, 'A' - 10
    jmp       .AccumHex
.HexDigit:
    sub       dx, '0'
.AccumHex:
    shl       eax, 4
    add       eax, edx
    add       esi, 2
    jmp       .HexLoop

.ParseDec:
    xor       eax, eax
.DecLoop:
    movzx     edx, word [esi]
    cmp       dx, '0'
      jb      .Done
    cmp       dx, '9'
      ja      .Done
    sub       dx, '0'
    imul      eax, 10
    add       eax, edx
    add       esi, 2
    jmp       .DecLoop

.DoneZero:
    xor       eax, eax
.Done:
    ret
endp

; DWORD String.HexToBytes(LPCWSTR lpszString, LPVOID lpDst, DWORD cbMax);
proc String.HexToBytes stdcall uses ecx edx ebx esi edi,     lpszString:DWORD, lpDst:DWORD, cbMax:DWORD
    locals
        .bHighNibble rd 1
    endl

    mov       esi, [lpszString]
    mov       edi, [lpDst]
    xor       ebx, ebx                  ; byte count = 0

    test      esi, esi
      jz      .Done
    test      edi, edi
      jz      .Done

    ; If starts with '(', e.g. "(zero-length binary value)" -> empty
    cmp       word [esi], '('
      je      .Done

.Loop:
    movzx     eax, word [esi]
    test      ax, ax
      jz      .Done

    ; Skip delimiters
    cmp       ax, ' '
      je      .NextChar
    cmp       ax, 9
      je      .NextChar
    cmp       ax, ','
      je      .NextChar
    cmp       ax, 13
      je      .NextChar
    cmp       ax, 10
      je      .NextChar

    ; Check buffer limit
    cmp       ebx, [cbMax]
      jae     .Done

    ; First hex char
    stdcall   .CharToNibble, eax
    cmp       eax, -1
      je      .NextChar
    mov       [.bHighNibble], eax

    ; Look ahead at next char
    movzx     edx, word [esi + 2]
    test      dx, dx
      jz      .SingleNibble
    cmp       dx, ' '
      je      .SingleNibble
    cmp       dx, 9
      je      .SingleNibble
    cmp       dx, ','
      je      .SingleNibble

    stdcall   .CharToNibble, edx
    cmp       eax, -1
      je      .SingleNibble

    ; Two nibbles: (high << 4) | low
    mov       edx, [.bHighNibble]
    shl       edx, 4
    or        edx, eax
    mov       byte [edi + ebx], dl
    inc       ebx
    add       esi, 4                    ; used 2 chars
    jmp       .Loop

.SingleNibble:
    mov       edx, [.bHighNibble]
    mov       byte [edi + ebx], dl
    inc       ebx
    add       esi, 2                    ; used 1 char
    jmp       .Loop

.NextChar:
    add       esi, 2
    jmp       .Loop

.Done:
    mov       eax, ebx
    jmp       .End

.CharToNibble:
    mov       eax, [esp + 4]
    cmp       eax, '0'
      jb      .InvalidChar
    cmp       eax, '9'
      jbe     .Digit
    cmp       eax, 'A'
      jb      .InvalidChar
    cmp       eax, 'F'
      jbe     .Upper
    cmp       eax, 'a'
      jb      .InvalidChar
    cmp       eax, 'f'
      ja      .InvalidChar
    sub       eax, 'a' - 10
    jmp       .End
.Upper:
    sub       eax, 'A' - 10
    jmp       .End
.Digit:
    sub       eax, '0'
    jmp       .End
.InvalidChar:
    mov       eax, -1
.End:
    ret
endp

; DWORD String.FormatMultiSz(LPCWSTR lpszSrc, LPVOID lpDst, DWORD cbMax);
proc String.FormatMultiSz stdcall uses ecx edx ebx esi edi,     lpszSrc:DWORD, lpDst:DWORD, cbMax:DWORD
    mov       esi, [lpszSrc]
    mov       edi, [lpDst]
    xor       ebx, ebx                  ; byte offset

    test      esi, esi
      jz      .Empty
    test      edi, edi
      jz      .Done
    cmp       word [esi], 0
      je      .Empty

.Loop:
    movzx     eax, word [esi]
    test      ax, ax
      jz      .TermList

    ; Check for delimiters
    cmp       ax, 13
      je      .Delimiter
    cmp       ax, 10
      je      .Delimiter
    cmp       ax, '|'
      je      .Delimiter

    ; Check space in buffer: room for char + 2 nulls
    lea       edx, [ebx + 4]
    cmp       edx, [cbMax]
      jae     .TermList

    mov       word [edi + ebx], ax
    add       ebx, 2
    add       esi, 2
    jmp       .Loop

.Delimiter:
    test      ebx, ebx
      jz      .SkipDelim
    cmp       word [edi + ebx - 2], 0
      je      .SkipDelim

    lea       edx, [ebx + 4]
    cmp       edx, [cbMax]
      jae     .TermList

    mov       word [edi + ebx], 0
    add       ebx, 2

.SkipDelim:
    add       esi, 2
    jmp       .Loop

.TermList:
    test      ebx, ebx
      jz      .Empty
    cmp       word [edi + ebx - 2], 0
      je      @F
    mov       word [edi + ebx], 0
    add       ebx, 2
@@:
    mov       word [edi + ebx], 0
    add       ebx, 2
    mov       eax, ebx
    jmp       .Done

.Empty:
    mov       word [edi], 0
    mov       word [edi + 2], 0
    mov       eax, 4
.Done:
    ret
endp

; VOID String.DisplayMultiSz(LPCWSTR lpData, DWORD cbData, LPWSTR lpszDst, DWORD cchMax);
proc String.DisplayMultiSz stdcall uses ecx edx ebx esi edi,\
     lpData:DWORD, cbData:DWORD, lpszDst:DWORD, cchMax:DWORD
    mov       esi, [lpData]
    mov       edi, [lpszDst]
    mov       ecx, [cbData]
    mov       edx, [cchMax]

    test      edi, edi
      jz      .Done
    test      edx, edx
      jz      .Done

    test      esi, esi
      jz      .Empty
    test      ecx, ecx
      jz      .Empty

    shr       ecx, 1                    ; cbData -> character count
    dec       edx                       ; leave space for NULL
    xor       ebx, ebx                  ; characters written

.Loop:
    test      ecx, ecx
      jz      .TermOutput
    cmp       ebx, edx
      jae     .TermOutput

    movzx     eax, word [esi]
    test      ax, ax
      jz      .HandleNull

    ; Normal character
    mov       word [edi + ebx * 2], ax
    inc       ebx
    add       esi, 2
    dec       ecx
    jmp       .Loop

.HandleNull:
    ; Check if this is the end of the multi-string
    cmp       ecx, 1
      jbe     .TermOutput
    cmp       word [esi + 2], 0
      je      .TermOutput

    ; Replace NULL with space if we already wrote characters
    test      ebx, ebx
      jz      .SkipNull
    cmp       word [edi + ebx * 2 - 2], ' '
      je      .SkipNull

    mov       word [edi + ebx * 2], ' '
    inc       ebx

.SkipNull:
    add       esi, 2
    dec       ecx
    jmp       .Loop

.TermOutput:
    mov       word [edi + ebx * 2], 0
    jmp       .Done

.Empty:
    mov       word [edi], 0

.Done:
    ret
endp
