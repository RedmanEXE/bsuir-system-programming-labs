; LPMTASKDISPATCHER TaskDispatcher.Create(LPMCONCURRENTRINGBUFFER lpSourceQueue,
;                                         LPMTHREADPOOL lpTargetPool,
;                                         DWORD dwChunkCount,
;                                         LPVOID pfnChunkRoutine)
proc TaskDispatcher.Create stdcall uses ecx edx ebx esi edi,\
     lpSourceQueue:DWORD, lpTargetPool:DWORD, dwChunkCount:DWORD, pfnChunkRoutine:DWORD
    locals
        .dwDispThreadId rd 1
    endl

    ; 1. Allocate structure
    stdcall   Memory.Allocate, [cmApplication.hMemHeap], sizeof.MTASKDISPATCHER
    test      eax, eax
      jz      .Fail
    mov       esi, eax

    virtual at esi
        .disp MTASKDISPATCHER
    end virtual

    ; 2. Initialize fields
    mov       eax, [lpSourceQueue]
    mov       [.disp.lpSourceQueue], eax
    mov       eax, [lpTargetPool]
    mov       [.disp.lpTargetPool], eax
    mov       eax, [pfnChunkRoutine]
    mov       [.disp.pfnChunkRoutine], eax

    mov       eax, [dwChunkCount]
    cmp       eax, 0
      ja      @F
    mov       eax, 4
@@:
    mov       [.disp.dwChunkCount], eax
    mov       [.disp.bRunning], 1

    ; 3. Create stop event
    invoke    CreateEvent, NULL, TRUE, FALSE, NULL
    test      eax, eax
      jz      .FailFreeStruct
    mov       [.disp.hStopEvent], eax

    ; 4. Spawn dispatcher thread
    lea       eax, [.dwDispThreadId]
    invoke    CreateThread, NULL, 0, TaskDispatcher.DispatcherThreadProc, esi, 0, eax
    test      eax, eax
      jz      .FailFreeStopEv
    mov       [.disp.hThread], eax

    mov       eax, esi
    jmp       .End

.FailFreeStopEv:
    invoke    CloseHandle, [.disp.hStopEvent]
.FailFreeStruct:
    stdcall   Memory.Free, [cmApplication.hMemHeap], esi
.Fail:
    xor       eax, eax
.End:
    ret
endp

; DWORD TaskDispatcher.DispatcherThreadProc(LPVOID lpParam)
proc TaskDispatcher.DispatcherThreadProc stdcall uses ecx edx ebx esi edi,\
     lpParam:DWORD
    locals
        .waitHandles    MWAITHANDLES2
        .lpImagePtr     rd 1
        .dwChunkH       rd 1
        .dwTotalH       rd 1
        .dwIdx          rd 1
    endl

    mov       esi, [lpParam]
    virtual at esi
        .disp MTASKDISPATCHER
    end virtual

    mov       eax, [.disp.hStopEvent]
    mov       [.waitHandles.h0], eax

    stdcall   ConcurrentRingBuffer.GetWaitHandle, [.disp.lpSourceQueue]
    mov       [.waitHandles.h1], eax

.DispatchLoop:
    lea       eax, [.waitHandles]
    invoke    WaitForMultipleObjects, 2, eax, FALSE, INFINITE

    cmp       eax, WAIT_OBJECT_0
      je      .ExitDispatcher

    cmp       eax, WAIT_OBJECT_0 + 1
      jne     .DispatchLoop

    lea       eax, [.lpImagePtr]
    stdcall   ConcurrentRingBuffer.RemoveItemClaimed, [.disp.lpSourceQueue], eax
    test      eax, eax
      jz      .DispatchLoop

    mov       edi, [.lpImagePtr]
    test      edi, edi
      jz      .DispatchLoop

    virtual at edi
        .img MIMAGE
    end virtual

    mov       eax, [.disp.dwChunkCount]
    mov       [.img.dwChunksTotal], eax
    mov       [.img.dwChunksRemaining], eax

    ; Calculate chunk height = height / chunkCount
    mov       eax, [.img.dwHeight]
    mov       [.dwTotalH], eax
    xor       edx, edx
    div       dword [.disp.dwChunkCount]
    cmp       eax, 0
      ja      @F
    mov       eax, 1
@@:
    mov       [.dwChunkH], eax

    xor       ebx, ebx
.ChunkLoop:
    cmp       ebx, [.disp.dwChunkCount]
      jae     .DispatchLoop

    mov       [.dwIdx], ebx

    ; Allocate MCHUNKTRANSFORMTASK on heap
    stdcall   Memory.Allocate, [cmApplication.hMemHeap], sizeof.MCHUNKTRANSFORMTASK
    test      eax, eax
      jz      .NextChunk

    virtual at eax
        .chunk MCHUNKTRANSFORMTASK
    end virtual

    mov       [.chunk.lpImage], edi
    mov       edx, [.dwIdx]
    mov       [.chunk.dwChunkIndex], edx

    ; StartY = chunkIndex * chunkH
    mov       ecx, edx
    imul      ecx, [.dwChunkH]
    cmp       ecx, [.dwTotalH]
      jb      @F
    mov       ecx, [.dwTotalH]
@@:
    mov       [.chunk.dwStartY], ecx

    ; EndY = (chunkIndex == last) ? totalHeight : StartY + chunkH
    mov       edx, [.dwIdx]
    inc       edx
    cmp       edx, [.disp.dwChunkCount]
      je      .LastChunk
    add       ecx, [.dwChunkH]
    cmp       ecx, [.dwTotalH]
      jb      @F
    mov       ecx, [.dwTotalH]
@@:
    mov       [.chunk.dwEndY], ecx
    jmp       .EnqueueChunk

.LastChunk:
    mov       ecx, [.dwTotalH]
    mov       [.chunk.dwEndY], ecx

.EnqueueChunk:
    stdcall   ThreadPool.QueueTask, [.disp.lpTargetPool], [.disp.pfnChunkRoutine], eax

    ; Check if this was the last chunk
    mov       edx, [.dwIdx]
    inc       edx
    cmp       edx, [.disp.dwChunkCount]
      jae     .NextChunk

    ; Pacing delay between assigning chunks
    mov       eax, [dwTransformDelayMs]
    test      eax, eax
      jz      .NextChunk
    invoke    WaitForSingleObject, [.disp.hStopEvent], eax
    cmp       eax, WAIT_OBJECT_0
      je      .ExitDispatcher

.NextChunk:
    inc       ebx
    jmp       .ChunkLoop

.ExitDispatcher:
    xor       eax, eax
    ret
endp

; VOID TaskDispatcher.Destroy(LPMTASKDISPATCHER lpDispatcher)
proc TaskDispatcher.Destroy stdcall uses ecx edx ebx esi,\
     lpDispatcher:DWORD
    mov       esi, [lpDispatcher]
    test      esi, esi
      jz      .End

    virtual at esi
        .disp MTASKDISPATCHER
    end virtual

    mov       [.disp.bRunning], 0

    invoke    SetEvent, [.disp.hStopEvent]
    invoke    WaitForSingleObject, [.disp.hThread], INFINITE

    invoke    CloseHandle, [.disp.hThread]
    invoke    CloseHandle, [.disp.hStopEvent]

    stdcall   Memory.Free, [cmApplication.hMemHeap], esi

.End:
    ret
endp
