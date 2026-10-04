; VOID LabThree.MovePage(INT direction)
proc LabThree.MovePage stdcall uses ecx edx ebx esi,\
     direction:DWORD
    ; This value is packed one
    movzx     ecx, word [dwPages]     ; curr index
    movzx     edx, word [dwPages + 2] ; total count
    ; Add this direction
    add       ecx, [direction]

    ; Check for lower bound: if ecx < 1, set ecx = 1
    cmp       ecx, 1
      jge     .CheckUpper
    mov       ecx, 1
.CheckUpper:
    ; Check for upper bound: if ecx >= edx, set ecx = edx
    cmp       ecx, edx
      jle     .Save
    mov       ecx, edx
.Save:
    ; Also check for edx == 0 (no pages at all)
    test      edx, edx
      jnz     @F
    xor       ecx, ecx
@@:
    ; Save new values
    mov       word [dwPages], cx      ; curr index
    mov       word [dwPages + 2], dx  ; total count

    ; Update text in PagesTextLabel
    stdcall   PagesTextLabel.Update, [hPagesLabel], szPagesLabelText, ecx, edx

    ; Set buttons to be disabled or enabled
    ; Previous button
    xor       eax, eax
    cmp       ecx, 1
      jle     @F
    not       eax
@@:
    stdcall   Button.SetEnabled, [hPreviousBtn], eax

    ; Next button
    xor       eax, eax
    cmp       ecx, edx
      jge     @F
    not       eax
@@:
    stdcall   Button.SetEnabled, [hNextBtn], eax

    ; Update current image in ImageView and Save button
    test      ecx, ecx
      jz      .NoCurrentImage

    ; 1-based to 0-based index
    mov       eax, ecx
    dec       eax
    mov       esi, [lpImagesList + eax * 4]
    mov       [cmApplication.lpCurrentImage], esi
    stdcall   ImageView.SetImage, [hImageView], esi

    ; Check if this image has finished processing
    virtual at esi
        .curImg MIMAGE
    end virtual

    xor       eax, eax
    cmp       [.curImg.dwChunksRemaining], 0
      jne     @F
    not       eax
@@:
    stdcall   Button.SetEnabled, [hSaveBtn], eax
    ret

.NoCurrentImage:
    mov       [cmApplication.lpCurrentImage], 0
    stdcall   ImageView.SetImage, [hImageView], 0
    stdcall   Button.SetEnabled, [hSaveBtn], FALSE
    ret
endp