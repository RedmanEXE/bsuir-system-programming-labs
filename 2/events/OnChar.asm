    ; wParam contains the wide character
    mov       eax, [wParam]
    ; Backspace (0x08) — delete last character
    cmp       eax, 0x08
      jne     ._NotBackspace
    stdcall   Grid.RemoveFromSelectedString, cmGrid
    jmp       ._EndOnChar
._NotBackspace:
    ; Ignore other controls
    cmp       eax, 0x20
      jb      ._EndOnChar
    ; Append character
    stdcall   Grid.AddToSelectedString, cmGrid, eax
._EndOnChar: