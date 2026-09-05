; Player.MoveTo(Sprite *cmSprite, Window *cmWindow, int iX, int iY)
Player.MoveTo:
    push      ebp
    mov       ebp, esp
    push      ecx edx ebx esi

    ; Load cmWindow and cmSprite
    mov       edx, [ebp + 12] ; cmWindow
    mov       esi, [ebp + 8]  ; cmSprite
    ; Load iX and iY
    mov       ebx, [ebp + 16] ; iX
    mov       ecx, [ebp + 20] ; iY

    ; Check for X bounds
    cmp       ebx, 0
      jge     @F
    ; If there's X < 0 -> set it to 0
    xor       ebx, ebx
    jmp       ._XCheckPass
@@:
    movzx     eax, word [edx + 4] ; cmWindow.width
    sub       eax, [esi + 16]     ; cmSprite.bmpInfo.bmWidth
    cmp       ebx, eax
      jle     ._XCheckPass
    ; If there's X > cmWindow.width - cmSprite.bmpInfo.bmWidth
    ; -> set it to max bound (this long expression)
    mov       ebx, eax
._XCheckPass:

    ; Check for Y bounds
    cmp       ecx, 0
      jge     @F
    ; If there's Y < 0 -> set it to 0
    xor       ecx, ecx
    jmp       ._YCheckPass
@@:
    movzx     eax, word [edx + 6] ; cmWindow.height
    sub       eax, [esi + 20]     ; cmSprite.bmpInfo.bmHeight
    cmp       ecx, eax
      jle     ._YCheckPass
    ; If there's Y > cmWindow.height - cmSprite.bmpInfo.bmHeight
    ; -> set it to max bound (this long expression)
    mov       ecx, eax
._YCheckPass:

    ; Set this coords to the cmSprite.ptPosition
    mov       word [esi + 12 + sizeof.BITMAP], bx      ; X
    mov       word [esi + 12 + sizeof.BITMAP + 2], cx  ; Y

    pop       esi ebx edx ecx
    leave
    ret       16