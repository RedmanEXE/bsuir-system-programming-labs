    ; Destroy pipeline
    stdcall   Pipeline.Destroy

    ; Free font
    invoke    DeleteObject, [cmApplication.hSystemFont]

    push      0
    call      Application.Terminate