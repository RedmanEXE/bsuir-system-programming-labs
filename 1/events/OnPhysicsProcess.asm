    xor       ebx, ebx                    ; X change buffer
    xor       esi, esi                    ; Y change buffer

    ; Process mouse
    mov       eax, [cmMouse.wheelAccum]
    ; If wheelAccum > -120 && wheelAccum < 120 -> Skip this process
    cmp       eax, WHEEL_DELTA
      jge     @F
    cmp       eax, -WHEEL_DELTA
      jle     @F
    jmp       ._SkipMouseInPhysics
@@:
    ; Fill EDX with sign bit
    xor       edx, edx
    cmp       eax, 0
      jge     @F
    not       edx
@@:
    mov       ecx, WHEEL_DELTA
    idiv      ecx
    ; Return wheelAccum % 120 into the buffer
    mov       [cmMouse.wheelAccum], edx
    ; Change X and Y for wheelAccum / 120
    add       ebx, eax
    add       esi, eax

._SkipMouseInPhysics:
    movsx     ecx, [cmSprite.ptMoveAccum.x]   ; X movement accum
    movsx     edx, [cmSprite.ptMoveAccum.y]   ; Y movement accum
    ; Process keyboard
    mov       al, [cmKeyboard.bKeys + 4]
    test      al, 01h                     ; W
      jz      @F

    ; When W is pressed
    dec       edx
@@:

    mov       al, [cmKeyboard.bKeys + 1]
    test      al, 04h                     ; A
      jz      @F

    ; When A is pressed
    dec       ecx
@@:

    mov       al, [cmKeyboard.bKeys + 3]
    test      al, 10h                     ; S
      jz      @F

    ; When S is pressed
    inc       edx
@@:

    mov       al, [cmKeyboard.bKeys + 1]
    test      al, 20h                     ; D
      jz      @F

    ; When D is pressed
    inc       ecx
@@:
    ; Process this accumulated values
    mov       edi, edx
    ; X
    mov       eax, ecx
    xor       edx, edx
    cmp       eax, 0
      jge     @F
    not       edx
@@:
    mov       ecx, KEYBOARD_SPEED
    ; moveX = accumX / KEYBOARD_SPEED
    idiv      ecx
    add       ebx, eax
    ; Save accumX % KEYBOARD_SPEED for future
    ; calculations
    mov       [cmSprite.ptMoveAccum.x], dx

    ; Y
    mov       eax, edi
    xor       edx, edx
    cmp       eax, 0
      jge     @F
    not       edx
@@:
    mov       ecx, KEYBOARD_SPEED
    ; moveY = accumY / KEYBOARD_SPEED
    idiv      ecx
    add       esi, eax
    ; Save accumY % KEYBOARD_SPEED for future
    ; calculations
    mov       [cmSprite.ptMoveAccum.y], dx

    ; Send request to move player on another position
    movzx     eax, [cmSprite.ptPosition.x]
    add       ebx, eax
    movzx     eax, [cmSprite.ptPosition.y]
    add       esi, eax
    stdcall   Player.MoveTo, cmSprite, cmWindow, ebx, esi


