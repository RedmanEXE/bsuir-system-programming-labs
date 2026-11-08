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
    cmp       eax, IDC_BUTTON_ADD
      je      .ProcessAddBtn
    cmp       eax, IDC_BUTTON_DELETE
      je      .ProcessDeleteBtn
    cmp       eax, IDC_BUTTON_EDIT
      je      .ProcessEditBtn
    cmp       eax, IDC_BUTTON_UAC
      je      .ProcessUacBtn
    cmp       eax, IDC_BUTTON_AUTOREFRESH
      je      .ProcessAutoRefreshBtn
    jmp       .EndCommand

.ProcessAddBtn:
    ; Check if user is in ListView
    invoke    GetFocus
    cmp       eax, [hListView]
      je      .ProcessAddValue

    stdcall   ListView.GetSelectedItem, [hListView]
    cmp       eax, -1
      jne     .ProcessAddValue

    ; User is in TreeView -> Add Key
    stdcall   RegEditProgram.OnAddKey, [hWnd]
    jmp       .EndCommand

.ProcessAddValue:
    ; Check that an item in TreeView is selected and not My Computer
    stdcall   TreeView.GetSelectedItem, [hTreeView]
    test      eax, eax
      jz      .EndCommand
    cmp       eax, [hRootComputer]
      je      .EndCommand

    stdcall   EditValueDialog.Open, [hWnd], szNewParamTitle, szDefaultNewPrmName, NULL, REG_SZ, TRUE
    jmp       .EndCommand

.ProcessDeleteBtn:
    stdcall   RegEditProgram.OnDeleteItem, [hWnd]
    jmp       .EndCommand

.ProcessEditBtn:
    stdcall   RegEditProgram.OnEditParam, [hWnd]
    jmp       .EndCommand

.ProcessUacBtn:
    stdcall   UAC.RelaunchInAdmin, [hWnd]
    jmp       .EndCommand

.ProcessAutoRefreshBtn:
    invoke    SendMessage, [hToolbar], TB_ISBUTTONCHECKED, IDC_BUTTON_AUTOREFRESH, 0
    test      eax, eax
      jz      .DisableAutoRefresh

    mov       [bAutoRefreshEnabled], 1
    stdcall   TreeView.GetSelectedItem, [hTreeView]
    test      eax, eax
      jz      .EndCommand
    stdcall   Registry.StartMonitorByKeyItem, [hTreeView], eax
    jmp       .EndCommand

.DisableAutoRefresh:
    mov       [bAutoRefreshEnabled], 0
    stdcall   Registry.StopMonitor
    jmp       .EndCommand

.EndCommand: