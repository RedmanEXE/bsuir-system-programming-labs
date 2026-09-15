; void Application.Terminate(UINT code);
proc Application.Terminate stdcall,\
     code:DWORD
    invoke    ExitProcess, [code]
    ret
endp