; void Application.Terminate(UINT code);
Application.Terminate:
    push      ebp
    mov       ebp, esp

    invoke    ExitProcess, dword [ebp + 8]

    leave
    ret       4