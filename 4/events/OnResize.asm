    ; Save new client width and height
    mov       ecx, [lParam]
    mov       dword [cmWindow.width], ecx

    ; Check if controls have been created
    cmp       [hToolbar], 0
      je      .SkipResizeLayout

    ; Resize layout
    stdcall   RegEditProgram.UpdateLayout, [hWnd]

.SkipResizeLayout: