    ; Stop registry monitor
    stdcall   Registry.StopMonitor
    cmp       [hMonitorStopEvent], 0
      je      @F
    invoke    CloseHandle, [hMonitorStopEvent]
    mov       [hMonitorStopEvent], 0
@@:
    cmp       [hMonitorChangeEvent], 0
      je      @F
    invoke    CloseHandle, [hMonitorChangeEvent]
    mov       [hMonitorChangeEvent], 0
@@:
    cmp       [hToolbarRefreshIcon], 0
      je      @F
    invoke    DeleteObject, [hToolbarRefreshIcon]
    mov       [hToolbarRefreshIcon], 0
@@:
        invoke    DeleteObject, [hToolbarAddIcon]
    invoke    DeleteObject, [hToolbarDeleteIcon]
    invoke    DeleteObject, [hToolbarEditIcon]
    cmp       [hToolbarUacIcon], 0
      je      @F
    invoke    DeleteObject, [hToolbarUacIcon]
@@:
    ; Destroy TreeView ImageList
    cmp       [hTreeImageList], 0
      je      @F
    invoke    ImageList_Destroy, [hTreeImageList]
@@:
    ; Then call PostQuitMessage to send WM_QUIT
    invoke    PostQuitMessage, 0