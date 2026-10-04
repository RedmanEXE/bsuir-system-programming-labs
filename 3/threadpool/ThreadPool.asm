; LPMTHREADPOOL ThreadPool.Create(DWORD dwThreadCount, DWORD dwQueueCapacity)
proc ThreadPool.Create stdcall uses ecx edx ebx esi edi,\
     dwThreadCount:DWORD, dwQueueCapacity:DWORD
    locals
        .hQueue         rd 1
        .hStopEv        rd 1
        .dwPoolThreadId rd 1
    endl

    ; 1. Allocate MTHREADPOOL structure
    stdcall   Memory.Allocate, [cmApplication.hMemHeap], sizeof.MTHREADPOOL
    test      eax, eax
      jz      .Fail
    mov       esi, eax

    virtual at esi
        .pool MTHREADPOOL
    end virtual

    ; 2. Clamp thread count to [1, MAX_POOL_THREADS]
    mov       eax, [dwThreadCount]
    cmp       eax, 0
      ja      @F
    mov       eax, DEFAULT_POOL_THREADS
@@:
    cmp       eax, MAX_POOL_THREADS
      jbe     @F
    mov       eax, MAX_POOL_THREADS
@@:
    mov       [.pool.dwThreadCount], eax

    ; 3. Create manual-reset stop event
    invoke    CreateEvent, NULL, TRUE, FALSE, NULL
    test      eax, eax
      jz      .FailFreeStruct
    mov       [.pool.hStopEvent], eax
    mov       [.hStopEv], eax

    ; 4. Create task queue
    stdcall   ConcurrentRingBuffer.Initialize, sizeof.MTHREADPOOLTASK, [dwQueueCapacity]
    test      eax, eax
      jz      .FailFreeStopEv
    mov       [.pool.lpTaskQueue], eax
    mov       [.hQueue], eax

    mov       [.pool.bRunning], 1

    ; 5. Spawn worker threads
    xor       ebx, ebx
.SpawnLoop:
    cmp       ebx, [.pool.dwThreadCount]
      jae     .Success

    lea       eax, [.dwPoolThreadId]
    invoke    CreateThread, NULL, 0, ThreadPool.WorkerThreadProc, esi, 0, eax
    test      eax, eax
      jz      .FailSpawn

    mov       [.pool.hThreads + ebx * 4], eax
    inc       ebx
    jmp       .SpawnLoop

.Success:
    mov       eax, esi
    jmp       .End

.FailSpawn:
    mov       [.pool.dwThreadCount], ebx
    stdcall   ThreadPool.Destroy, esi
    xor       eax, eax
    jmp       .End

.FailFreeStopEv:
    invoke    CloseHandle, [.hStopEv]
.FailFreeStruct:
    stdcall   Memory.Free, [cmApplication.hMemHeap], esi
.Fail:
    xor       eax, eax
.End:
    ret
endp

; BOOL ThreadPool.QueueTask(LPMTHREADPOOL lpThreadPool, LPVOID pfnRoutine, LPVOID lpContext)
proc ThreadPool.QueueTask stdcall uses ecx edx ebx esi,\
     lpThreadPool:DWORD, pfnRoutine:DWORD, lpContext:DWORD
    locals
        .task           MTHREADPOOLTASK
    endl

    mov       esi, [lpThreadPool]
    test      esi, esi
      jz      .Fail

    virtual at esi
        .pool MTHREADPOOL
    end virtual

    ; Check if pool is active
    cmp       [.pool.bRunning], 1
      jne     .Fail

    ; Prepare task structure
    mov       eax, [pfnRoutine]
    mov       [.task.pfnRoutine], eax
    mov       eax, [lpContext]
    mov       [.task.lpContext], eax

    ; Push to concurrent ring buffer
    lea       eax, [.task]
    stdcall   ConcurrentRingBuffer.AddItem, [.pool.lpTaskQueue], eax
    jmp       .End

.Fail:
    xor       eax, eax
.End:
    ret
endp

; DWORD ThreadPool.WorkerThreadProc(LPVOID lpParam)
proc ThreadPool.WorkerThreadProc stdcall uses ecx edx ebx esi edi,\
     lpParam:DWORD
    locals
        .waitHandles    MWAITHANDLES2
        .task           MTHREADPOOLTASK
    endl

    mov       esi, [lpParam]
    virtual at esi
        .pool MTHREADPOOL
    end virtual

    ; Setup wait handles: [0] = stop event, [1] = queue semaphore
    mov       eax, [.pool.hStopEvent]
    mov       [.waitHandles.h0], eax

    stdcall   ConcurrentRingBuffer.GetWaitHandle, [.pool.lpTaskQueue]
    mov       [.waitHandles.h1], eax

.WorkLoop:
    lea       eax, [.waitHandles]
    invoke    WaitForMultipleObjects, 2, eax, FALSE, INFINITE

    cmp       eax, WAIT_OBJECT_0
      je      .ExitWorker

    cmp       eax, WAIT_OBJECT_0 + 1
      jne     .WorkLoop

.ExecuteTask:
    lea       eax, [.task]
    stdcall   ConcurrentRingBuffer.RemoveItemClaimed, [.pool.lpTaskQueue], eax
    test      eax, eax
      jz      .WorkLoop

    cmp       [.task.pfnRoutine], 0
      je      .WorkLoop

    push      [.task.lpContext]
    call      [.task.pfnRoutine]

    jmp       .WorkLoop

.ExitWorker:
    xor       eax, eax
    ret
endp

; VOID ThreadPool.Destroy(LPMTHREADPOOL lpThreadPool)
proc ThreadPool.Destroy stdcall uses ecx edx ebx esi edi,\
     lpThreadPool:DWORD
    mov       esi, [lpThreadPool]
    test      esi, esi
      jz      .End

    virtual at esi
        .pool MTHREADPOOL
    end virtual

    ; 1. Mark pool as stopping
    mov       [.pool.bRunning], 0

    ; 2. Signal stop event
    invoke    SetEvent, [.pool.hStopEvent]

    ; 3. Wait for all worker threads to finish
    cmp       [.pool.dwThreadCount], 0
      je      .CloseHandles
    lea       eax, [.pool.hThreads]
    invoke    WaitForMultipleObjects, [.pool.dwThreadCount], eax, TRUE, INFINITE

.CloseHandles:
    xor       ebx, ebx
.CloseThreadLoop:
    cmp       ebx, [.pool.dwThreadCount]
      jae     .CleanupObjects
    mov       eax, [.pool.hThreads + ebx * 4]
    test      eax, eax
      jz      @F
    invoke    CloseHandle, eax
@@:
    inc       ebx
    jmp       .CloseThreadLoop

.CleanupObjects:
    invoke    CloseHandle, [.pool.hStopEvent]

    stdcall   ConcurrentRingBuffer.Destroy, [.pool.lpTaskQueue]

    stdcall   Memory.Free, [cmApplication.hMemHeap], esi

.End:
    ret
endp
