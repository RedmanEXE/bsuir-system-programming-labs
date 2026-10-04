    ; Save new client width and height
    mov       ecx, [lParam]
    mov       dword [cmWindow.width], ecx

    ; Check if controls have been created
    cmp       [hLoadBtn], 0
      je      .SkipResizeLayout

    ; Get client dimensions: esi = clientW, edi = clientH
    movzx     esi, cx
    shr       ecx, 16
    movzx     edi, cx

    ; Minimum dimensions sanity clamp
    cmp       esi, 200
      jge     @F
    mov       esi, 200
@@:
    cmp       edi, 150
      jge     @F
    mov       edi, 150
@@:

    ; 1. Load button: x = clientW - 115, y = 10, w = 105, h = 25
    mov       eax, esi
    sub       eax, 115
    invoke    MoveWindow, [hLoadBtn], eax, 10, 105, 25, TRUE

    ; 2. Save button: x = clientW - 115, y = 45, w = 105, h = 25
    mov       eax, esi
    sub       eax, 115
    invoke    MoveWindow, [hSaveBtn], eax, 45, 105, 25, TRUE

    ; 3. Speed trackbar: x = clientW - 115, y = 80, w = 105, h = 30
    mov       eax, esi
    sub       eax, 115
    invoke    MoveWindow, [hSpeedTrackbar], eax, 80, 105, 30, TRUE

    ; 4. Pager Y position: pagerY = clientH - 35
    mov       ebx, edi
    sub       ebx, 35

    ; 5. ImageView: x = 10, y = 10
    ; Width: imgW = clientW - 135
    ; Height: imgH = pagerY - 20
    mov       ecx, esi
    sub       ecx, 135
    cmp       ecx, 50
      jge     @F
    mov       ecx, 50
@@:
    mov       edx, ebx
    sub       edx, 20
    cmp       edx, 40
      jge     @F
    mov       edx, 40
@@:
    invoke    MoveWindow, [hImageView], 10, 10, ecx, edx, TRUE

    ; 6. Pager controls under ImageView (fixed horizontal layout):
    ; Previous button: x = 10, y = pagerY, w = 25, h = 25
    invoke    MoveWindow, [hPreviousBtn], 10, ebx, 25, 25, TRUE

    ; Pages label: x = 45, y = pagerY, w = 110, h = 25
    invoke    MoveWindow, [hPagesLabel], 45, ebx, 110, 25, TRUE

    ; Next button: x = 165, y = pagerY, w = 25, h = 25
    invoke    MoveWindow, [hNextBtn], 165, ebx, 25, 25, TRUE

.SkipResizeLayout: