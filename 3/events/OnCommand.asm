    ; Get identifier (LOWORD)
    movzx     eax, word [wParam]

    ; Check for accelerator
    movzx     ecx, word [wParam + 2]
    mov       edx, dword [lParam]
    test      edx, edx
      jnz     .ProcessControlCommand
    test      ecx, ecx
      jz      .ProcessMenuCommand

.ProcessAccelCommand:
    ; It's accelerator, process it
    cmp       eax, IDM_ACCEL_EXIT
      jne     @F

    invoke    DestroyWindow, [hWnd]
@@:
    jmp       .EndCommand

.ProcessMenuCommand:
    ; It's menu, process it
    jmp       .EndCommand

.ProcessControlCommand:
    ; It's control, process it
    cmp       eax, IDC_BUTTON_NEXT
      je      .ProcessNextBtn
    cmp       eax, IDC_BUTTON_PREVIOUS
      je      .ProcessPreviousBtn
    cmp       eax, IDC_BUTTON_LOAD
      je      .ProcessLoadBtn
    cmp       eax, IDC_BUTTON_SAVE
      je      .ProcessSaveBtn
    jmp       .EndCommand

.ProcessNextBtn:
    stdcall   LabThree.MovePage, 1
    jmp       .EndCommand

.ProcessPreviousBtn:
    stdcall   LabThree.MovePage, -1
    jmp       .EndCommand

.ProcessLoadBtn:
    stdcall   OpenFileDialog.Show, [hWnd], szOpenImageFilter, szPathFilter, 260
    test      eax, eax
      jz      .EndCommand

    stdcall   Pipeline.SubmitFile, szPathFilter
    jmp       .EndCommand

.ProcessSaveBtn:
    mov       eax, [cmApplication.lpCurrentImage]
    test      eax, eax
      jz      .EndCommand

    stdcall   SaveFileDialog.Show, [hWnd], szSaveImageFilter, szSavePathFilter, 260
    test      eax, eax
      jz      .EndCommand

    stdcall   Pipeline.SubmitSave, [cmApplication.lpCurrentImage], szSavePathFilter
    jmp       .EndCommand

.EndCommand: