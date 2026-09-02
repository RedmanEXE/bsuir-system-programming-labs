; void Application.Terminate(UINT code);
Application.Terminate:
    add    esp, 4
    call   [ExitProcess]