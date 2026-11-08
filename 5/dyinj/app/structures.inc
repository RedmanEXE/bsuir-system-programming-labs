struct INJECT_DATA
    pLoadLibrary      dd ?
    pGetProcAddress   dd ?
    dwTargetPID       dd ?
    szDllName         du 16 dup(?)
    szFuncName        db 32 dup(?)

    szToBeReplaced    du 64 dup(?)
    szReplaceWith     du 64 dup(?)
    cbReplaceSize     dd ?
ends
