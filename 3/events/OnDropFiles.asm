    mov       ebx, [wParam]            ; hDrop

    ; Query number of dropped files (iFile = 0xFFFFFFFF)
    invoke    DragQueryFile, ebx, -1, NULL, 0
    mov       edi, eax                 ; edi = total dropped files
    test      edi, edi
      jz      .DropDone

    xor       esi, esi                 ; esi = current file index
.DropLoop:
    ; Query path for file index esi
    invoke    DragQueryFile, ebx, esi, szDropPathBuffer, 260
    test      eax, eax
      jz      .NextDrop

    ; Submit file to processing pipeline
    stdcall   Pipeline.SubmitFile, szDropPathBuffer

.NextDrop:
    inc       esi
    cmp       esi, edi
      jb      .DropLoop

.DropDone:
    invoke    DragFinish, ebx
