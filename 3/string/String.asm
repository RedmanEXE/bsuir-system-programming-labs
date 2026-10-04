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