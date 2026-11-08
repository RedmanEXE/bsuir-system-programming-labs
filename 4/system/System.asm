; HANDLE System.CreateSystemFont();
proc System.CreateSystemFont stdcall
    local lf:LOGFONT
    ; Locally allocate space for LOGFONT
    lea       eax, [lf]
    invoke    SystemParametersInfo, SPI_GETICONTITLELOGFONT, sizeof.LOGFONT, eax, 0

    ; Create font from info
    lea       eax, [lf]
    invoke    CreateFontIndirect, eax

    ret
endp