; LPMCONCURRENTRINGBUFFER ConcurrentRingBuffer.Initialize(DWORD dwItemSize,
;                                                         DWORD dwCapacity)
proc ConcurrentRingBuffer.Initialize stdcall uses ecx edx ebx esi,\
     dwItemSize:DWORD, dwCapacity:DWORD
    ; 1. Allocate the structure itself
    stdcall   Memory.Allocate, [cmApplication.hMemHeap], sizeof.MCONCURRENTRINGBUFFER
    test      eax, eax
      jz      .Fail
    mov       esi, eax

    virtual at esi
        .rb MCONCURRENTRINGBUFFER
    end virtual

    ; 2. Allocate the data buffer: dwItemSize * dwCapacity bytes
    mov       eax, [dwItemSize]
    mul       dword [dwCapacity]
    stdcall   Memory.Allocate, [cmApplication.hMemHeap], eax
    test      eax, eax
      jz      .FailFreeStruct
    mov       [.rb.lpBuffer], eax

    ; 3. Store dimensions
    mov       eax, [dwItemSize]
    mov       [.rb.dwItemSize], eax
    mov       eax, [dwCapacity]
    mov       [.rb.dwCapacity], eax

    ; 4. Create counting semaphores
    invoke    CreateSemaphore, NULL, 0, [dwCapacity], NULL
    test      eax, eax
      jz      .FailFreeBuffer
    mov       [.rb.hSemaphoreItems], eax

    invoke    CreateSemaphore, NULL, [dwCapacity], [dwCapacity], NULL
    test      eax, eax
      jz      .FailFreeItemsSem
    mov       [.rb.hSemaphoreSlots], eax

    ; 5. Initialize the critical section
    lea       eax, [.rb.critSection]
    invoke    InitializeCriticalSection, eax

    mov       eax, esi
    jmp       .End

.FailFreeItemsSem:
    invoke    CloseHandle, [.rb.hSemaphoreItems]
.FailFreeBuffer:
    stdcall   Memory.Free, [cmApplication.hMemHeap], [.rb.lpBuffer]
.FailFreeStruct:
    stdcall   Memory.Free, [cmApplication.hMemHeap], esi
.Fail:
    xor       eax, eax
.End:
    ret
endp

; VOID ConcurrentRingBuffer.Destroy(LPMCONCURRENTRINGBUFFER lpRingBuffer)
proc ConcurrentRingBuffer.Destroy stdcall uses ecx edx esi,\
     lpRingBuffer:DWORD
    mov       esi, [lpRingBuffer]
    test      esi, esi
      jz      .End

    virtual at esi
        .rb MCONCURRENTRINGBUFFER
    end virtual

    ; Close semaphores
    cmp       [.rb.hSemaphoreItems], 0
      je      @F
    invoke    CloseHandle, [.rb.hSemaphoreItems]
@@:
    cmp       [.rb.hSemaphoreSlots], 0
      je      @F
    invoke    CloseHandle, [.rb.hSemaphoreSlots]
@@:
    ; Delete critical section
    lea       eax, [.rb.critSection]
    invoke    DeleteCriticalSection, eax

    ; Free data buffer
    cmp       [.rb.lpBuffer], 0
      je      @F
    stdcall   Memory.Free, [cmApplication.hMemHeap], [.rb.lpBuffer]
@@:
    ; Free ring buffer structure
    stdcall   Memory.Free, [cmApplication.hMemHeap], esi

.End:
    ret
endp

; HANDLE ConcurrentRingBuffer.GetWaitHandle(LPMCONCURRENTRINGBUFFER lpRingBuffer)
proc ConcurrentRingBuffer.GetWaitHandle stdcall uses edx,\
     lpRingBuffer:DWORD
    mov       edx, [lpRingBuffer]
    virtual at edx
        .rb MCONCURRENTRINGBUFFER
    end virtual
    mov       eax, [.rb.hSemaphoreItems]
    ret
endp

; BOOL ConcurrentRingBuffer.AddItem(LPMCONCURRENTRINGBUFFER lpRingBuffer,
;                                   LPVOID lpItem)
; Returns: TRUE (1) on success, FALSE (0) if the buffer is full.
proc ConcurrentRingBuffer.AddItem stdcall uses ecx edx ebx esi edi,\
     lpRingBuffer:DWORD, lpItem:DWORD
    mov       esi, [lpRingBuffer]
    virtual at esi
        .rb MCONCURRENTRINGBUFFER
    end virtual

    ; Enter critical section
    lea       eax, [.rb.critSection]
    invoke    EnterCriticalSection, eax

    ; Check whether the buffer is full
    mov       eax, [.rb.dwCount]
    cmp       eax, [.rb.dwCapacity]
      jae     .Full

    ; Calculate destination address: lpBuffer + dwHead * dwItemSize
    mov       eax, [.rb.dwHead]
    mul       dword [.rb.dwItemSize]
    mov       edi, [.rb.lpBuffer]
    add       edi, eax

    ; Copy the item into the buffer
    mov       ebx, esi
    mov       ecx, [.rb.dwItemSize]
    mov       esi, [lpItem]
    cld
    rep       movsb
    mov       esi, ebx

    ; head = (head + 1) % capacity
    mov       eax, [.rb.dwHead]
    inc       eax
    cmp       eax, [.rb.dwCapacity]
      jb      @F
    xor       eax, eax
@@:
    mov       [.rb.dwHead], eax

    ; Update items count
    inc       dword [.rb.dwCount]

    ; Leave critical section
    lea       eax, [.rb.critSection]
    invoke    LeaveCriticalSection, eax

    ; Signal 1 available item
    invoke    ReleaseSemaphore, [.rb.hSemaphoreItems], 1, NULL

    mov       eax, TRUE
    jmp       .End

.Full:
    lea       eax, [.rb.critSection]
    invoke    LeaveCriticalSection, eax
    xor       eax, eax

.End:
    ret
endp

; BOOL ConcurrentRingBuffer.RemoveItemClaimed(LPMCONCURRENTRINGBUFFER lpRingBuffer,
;                                             LPVOID lpOutItem)
proc ConcurrentRingBuffer.RemoveItemClaimed stdcall uses ecx edx ebx esi edi,\
     lpRingBuffer:DWORD, lpOutItem:DWORD
    mov       esi, [lpRingBuffer]
    virtual at esi
        .rb MCONCURRENTRINGBUFFER
    end virtual

    ; Enter critical section
    lea       eax, [.rb.critSection]
    invoke    EnterCriticalSection, eax

    ; Calculate source address: lpBuffer + dwTail * dwItemSize
    mov       eax, [.rb.dwTail]
    mul       dword [.rb.dwItemSize]

    mov       ecx, [.rb.dwItemSize]
    mov       edi, [lpOutItem]
    mov       ebx, esi
    mov       esi, [.rb.lpBuffer]
    add       esi, eax

    ; Copy the item from the buffer to the caller's output
    cld
      rep movsb
    mov       esi, ebx

    ; tail = (tail + 1) % capacity
    mov       eax, [.rb.dwTail]
    inc       eax
    cmp       eax, [.rb.dwCapacity]
      jb      @F
    xor       eax, eax
@@:
    mov       [.rb.dwTail], eax

    ; Update count
    dec       dword [.rb.dwCount]

    ; Leave critical section
    lea       eax, [.rb.critSection]
    invoke    LeaveCriticalSection, eax

    ; Signal 1 free slot
    invoke    ReleaseSemaphore, [.rb.hSemaphoreSlots], 1, NULL

    mov       eax, TRUE
    ret
endp

; BOOL ConcurrentRingBuffer.RemoveItem(LPMCONCURRENTRINGBUFFER lpRingBuffer,
;                                      LPVOID lpOutItem)
; Returns: TRUE (1) on success, FALSE (0) if the buffer is empty.
proc ConcurrentRingBuffer.RemoveItem stdcall uses ecx edx esi,\
     lpRingBuffer:DWORD, lpOutItem:DWORD
    mov       esi, [lpRingBuffer]
    virtual at esi
        .rb MCONCURRENTRINGBUFFER
    end virtual

    ; Check if an item is available without blocking
    mov       eax, [.rb.hSemaphoreItems]
    invoke    WaitForSingleObject, eax, 0
    cmp       eax, WAIT_OBJECT_0
      jne     .Empty

    stdcall   ConcurrentRingBuffer.RemoveItemClaimed, esi, [lpOutItem]
    mov       eax, TRUE
    jmp       .End

.Empty:
    xor       eax, eax
.End:
    ret
endp

; BOOL ConcurrentRingBuffer.WaitForItem(LPMCONCURRENTRINGBUFFER lpRingBuffer,
;                                       LPVOID lpOutItem, DWORD dwTimeoutMs)
proc ConcurrentRingBuffer.WaitForItem stdcall uses ecx edx esi,\
     lpRingBuffer:DWORD, lpOutItem:DWORD, dwTimeoutMs:DWORD
    mov       esi, [lpRingBuffer]
    virtual at esi
        .rb MCONCURRENTRINGBUFFER
    end virtual

    ; Wait for available item
    mov       eax, [.rb.hSemaphoreItems]
    invoke    WaitForSingleObject, eax, [dwTimeoutMs]
    cmp       eax, WAIT_OBJECT_0
      jne     .TimeoutOrFailed

    stdcall   ConcurrentRingBuffer.RemoveItemClaimed, esi, [lpOutItem]
    mov       eax, TRUE
    jmp       .End

.TimeoutOrFailed:
    xor       eax, eax
.End:
    ret
endp
