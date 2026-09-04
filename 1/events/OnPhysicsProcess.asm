    mov       al, [cmKeyboard.bKeys + 4]
    test      al, 01h                     ; W
      jz      @F

    ; When W is pressed
    mov       cx, [cmSprite.ptPosition.y]
    ; If Y pos in greater than 0
    test      cx, cx
      jz      @F
    dec       cx
    mov       [cmSprite.ptPosition.y], cx
@@:

    mov       al, [cmKeyboard.bKeys + 1]
    test      al, 04h                     ; A
      jz      @F

    ; When A is pressed
    mov       cx, [cmSprite.ptPosition.x]
    ; If X pos in greater than 0
    test      cx, cx
      jz      @F
    dec       cx
    mov       [cmSprite.ptPosition.x], cx
@@:

    mov       al, [cmKeyboard.bKeys + 3]
    test      al, 10h                     ; S
      jz      @F

    ; When S is pressed
    mov       cx, [cmSprite.ptPosition.y]
    movzx     edx, [cmWindow.height]
    sub       edx, [cmSprite.bmpInfo.bmHeight]
    ; If Y pos in lower than window.height
    cmp       cx, dx
      jae     @F
    inc       cx
    mov       [cmSprite.ptPosition.y], cx
@@:

    mov       al, [cmKeyboard.bKeys + 1]
    test      al, 20h                     ; D
      jz      @F

    ; When D is pressed
    mov       cx, [cmSprite.ptPosition.x]
    movzx     edx, [cmWindow.width]
    sub       edx, [cmSprite.bmpInfo.bmWidth]
    ; If X pos in lower than window.width - sprite.width
    cmp       cx, dx
      jae     @F
    inc       cx
    mov       [cmSprite.ptPosition.x], cx
@@: